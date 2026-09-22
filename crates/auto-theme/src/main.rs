use chrono::{DateTime, Datelike, Days, Local, LocalResult, NaiveDate, TimeZone, Timelike};
use serde::Deserialize;
use std::fs::{self, OpenOptions};
use std::io::Write;
use std::path::{Path, PathBuf};
use std::thread;
use std::time::{Duration, SystemTime, UNIX_EPOCH};

const POLL_SECS: u64 = 120;
const MIN_SLEEP: u64 = 5;
static mut FAKE_NOW: Option<u64> = None;

#[derive(Deserialize, Default)]
struct Settings {
    #[serde(default)]
    #[serde(rename = "autoMode")]
    auto_mode: String,
    #[serde(default = "d18")]
    #[serde(rename = "autoTimeStart")]
    auto_time_start: String,
    #[serde(default = "d6")]
    #[serde(rename = "autoTimeEnd")]
    auto_time_end: String,
    #[serde(default)]
    #[serde(rename = "autoLat")]
    auto_lat: f64,
    #[serde(default)]
    #[serde(rename = "autoLng")]
    auto_lng: f64,
}
fn d18() -> String {
    "18:00".into()
}
fn d6() -> String {
    "06:00".into()
}

fn config() -> PathBuf {
    let b = std::env::var("XDG_CONFIG_HOME").unwrap_or_else(|_| {
        std::env::var("HOME")
            .map(|h| format!("{h}/.config"))
            .unwrap_or_default()
    });
    PathBuf::from(b).join("quickshell/niri-strata")
}
fn spath() -> PathBuf {
    config().join("settings.json")
}
fn stpath() -> PathBuf {
    config().join("auto-theme-state.json")
}
fn rs() -> Option<Settings> {
    fs::read_to_string(&spath())
        .ok()
        .and_then(|r| serde_json::from_str(&r).ok())
}
fn ws(m: &str) {
    let p = stpath();
    let t = format!("{}.tmp", p.display());
    let _ = fs::write(&t, m);
    let _ = fs::rename(&t, &p);
}
fn rds() -> String {
    fs::read_to_string(&stpath())
        .unwrap_or_default()
        .trim()
        .to_string()
}

struct InstanceLock {
    path: PathBuf,
}

impl Drop for InstanceLock {
    fn drop(&mut self) {
        let pid = std::process::id().to_string();
        let owns_lock = fs::read_to_string(&self.path)
            .map(|contents| contents.trim() == pid)
            .unwrap_or(false);
        if owns_lock {
            let _ = fs::remove_file(&self.path);
        }
    }
}

fn acquire_instance_lock() -> Option<InstanceLock> {
    let path = config().join("auto-theme.lock");
    for _ in 0..2 {
        match OpenOptions::new().write(true).create_new(true).open(&path) {
            Ok(mut file) => {
                if writeln!(file, "{}", std::process::id()).is_err() {
                    let _ = fs::remove_file(&path);
                    return None;
                }
                return Some(InstanceLock { path });
            }
            Err(error) if error.kind() == std::io::ErrorKind::AlreadyExists => {
                let active = fs::read_to_string(&path)
                    .ok()
                    .and_then(|contents| contents.trim().parse::<u32>().ok())
                    .map(|pid| Path::new(&format!("/proc/{pid}")).exists())
                    .unwrap_or(false);
                if active {
                    return None;
                }
                let _ = fs::remove_file(&path);
            }
            Err(_) => return None,
        }
    }
    None
}

fn now() -> u64 {
    unsafe {
        if let Some(f) = FAKE_NOW {
            return f;
        }
    }
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap_or_default()
        .as_secs()
}

fn local_now() -> DateTime<Local> {
    Local
        .timestamp_opt(now() as i64, 0)
        .single()
        .unwrap_or_else(Local::now)
}

fn hhmm(s: &str) -> Option<(u32, u32)> {
    let mut p = s.splitn(2, ':');
    let h: u32 = p.next()?.parse().ok()?;
    let m: u32 = p.next()?.parse().ok()?;
    (h < 24 && m < 60).then_some((h, m))
}
fn secs(h: u32, m: u32) -> u64 {
    (h * 3600 + m * 60) as u64
}

fn local_at<Tz: TimeZone>(zone: &Tz, date: NaiveDate, h: u32, m: u32) -> Option<DateTime<Tz>> {
    let naive = date.and_hms_opt(h, m, 0)?;
    match zone.from_local_datetime(&naive) {
        LocalResult::Single(dt) | LocalResult::Ambiguous(dt, _) => Some(dt),
        LocalResult::None => None,
    }
}

fn next_occ<Tz: TimeZone>(zone: &Tz, h: u32, m: u32, current: &DateTime<Tz>) -> u64 {
    let mut target = local_at(zone, current.date_naive(), h, m);
    if target
        .as_ref()
        .map(|t| t.timestamp() <= current.timestamp())
        .unwrap_or(true)
    {
        target = current
            .date_naive()
            .checked_add_days(Days::new(1))
            .and_then(|date| local_at(zone, date, h, m));
    }

    target
        .map(|t| t.timestamp().saturating_sub(current.timestamp()))
        .filter(|wait| *wait > 0)
        .map(|wait| wait as u64)
        .unwrap_or(MIN_SLEEP)
}

fn dark_window_contains(day_secs: u32, start: u32, end: u32) -> bool {
    if start < end {
        day_secs >= start && day_secs < end
    } else if start > end {
        day_secs >= start || day_secs < end
    } else {
        // Equal boundaries describe an empty dark interval.
        false
    }
}

fn time_switches_at<Tz: TimeZone>(
    s: &Settings,
    zone: &Tz,
    current: &DateTime<Tz>,
) -> (&'static str, u64) {
    let (sh, sm) = hhmm(&s.auto_time_start).unwrap_or((18, 0));
    let (eh, em) = hhmm(&s.auto_time_end).unwrap_or((6, 0));
    let ss = secs(sh, sm);
    let es = secs(eh, em);
    let day_secs = current.time().num_seconds_from_midnight();
    let dark = dark_window_contains(day_secs, ss as u32, es as u32);
    if dark {
        ("dark", next_occ(zone, eh, em, current))
    } else {
        ("light", next_occ(zone, sh, sm, current))
    }
}

fn time_switches(s: &Settings) -> (&'static str, u64) {
    let current = local_now();
    let zone = Local;
    time_switches_at(s, &zone, &current)
}

fn wait_until(target: i64, current: i64) -> u64 {
    target.saturating_sub(current).max(MIN_SLEEP as i64) as u64
}

fn sun_switches_at(s: &Settings, current: &DateTime<Local>) -> (&'static str, u64) {
    if s.auto_lat == 0.0 && s.auto_lng == 0.0 {
        return time_switches_at(s, &Local, current);
    }
    let date = current.date_naive();
    let sf = |date: NaiveDate| -> Option<(i64, i64)> {
        Some(sunrise::sunrise_sunset(
            s.auto_lat,
            s.auto_lng,
            date.year(),
            date.month(),
            date.day(),
        ))
    };
    let current_ts = current.timestamp();
    let (rise, set) = match sf(date) {
        Some(v) => v,
        None => return time_switches_at(s, &Local, current),
    };
    if current_ts < rise {
        return ("dark", wait_until(rise, current_ts));
    }
    if current_ts < set {
        return ("light", wait_until(set, current_ts));
    }
    let next_date = match date.checked_add_days(Days::new(1)) {
        Some(date) => date,
        None => return time_switches_at(s, &Local, current),
    };
    let (next_rise, _) = match sf(next_date) {
        Some(v) => v,
        None => return time_switches_at(s, &Local, current),
    };
    ("dark", wait_until(next_rise, current_ts))
}

fn sun_switches(s: &Settings) -> (&'static str, u64) {
    let current = local_now();
    sun_switches_at(s, &current)
}

fn check(args: &[String]) {
    let mut s = rs().unwrap_or_default();
    let mut i = 0;
    while i < args.len() {
        match args[i].as_str() {
            "--lat" => {
                i += 1;
                if let Some(v) = args.get(i) {
                    s.auto_lat = v.parse().unwrap_or(0.0);
                }
            }
            "--lng" => {
                i += 1;
                if let Some(v) = args.get(i) {
                    s.auto_lng = v.parse().unwrap_or(0.0);
                }
            }
            "--time" => {
                i += 1;
                if let Some(v) = args.get(i) {
                    if let Some((h, m)) = hhmm(v) {
                        let base = local_now();
                        let zone = Local;
                        if let Some(fake) = local_at(&zone, base.date_naive(), h, m) {
                            unsafe {
                                FAKE_NOW = Some(fake.timestamp() as u64);
                            }
                        }
                    }
                }
            }
            _ => {}
        }
        i += 1;
    }
    let (mode, wait) = match s.auto_mode.as_str() {
        "sun" => sun_switches(&s),
        _ => time_switches(&s),
    };
    let current = local_now();
    let next_at = Local
        .timestamp_opt(current.timestamp().saturating_add(wait as i64), 0)
        .single()
        .unwrap_or(current);
    println!("mode:     {mode}");
    println!("next in:  {}h {}m", wait / 3600, wait % 3600 / 60);
    println!(
        "next at:  {:02}:{:02} (local)",
        next_at.hour(),
        next_at.minute()
    );
    if s.auto_mode == "sun" {
        println!("coords:   {:.4}, {:.4}", s.auto_lat, s.auto_lng);
    }
}

fn main() {
    let args: Vec<String> = std::env::args().collect();
    if args.iter().any(|a| a == "--check") {
        check(&args);
        return;
    }
    let _instance_lock = match acquire_instance_lock() {
        Some(lock) => lock,
        None => return,
    };
    loop {
        let s = match rs() {
            Some(s) => s,
            None => {
                thread::sleep(Duration::from_secs(10));
                continue;
            }
        };
        if s.auto_mode.is_empty() || s.auto_mode == "manual" {
            return;
        }
        let (d, w) = match s.auto_mode.as_str() {
            "sun" => sun_switches(&s),
            _ => time_switches(&s),
        };
        if rds() != d {
            ws(d);
        }
        thread::sleep(Duration::from_secs(w.min(POLL_SECS).max(MIN_SLEEP)));
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use chrono::FixedOffset;

    fn time_settings(start: &str, end: &str) -> Settings {
        let mut settings = Settings::default();
        settings.auto_mode = "time".into();
        settings.auto_time_start = start.into();
        settings.auto_time_end = end.into();
        settings
    }

    fn at(offset: &FixedOffset, hour: u32, minute: u32) -> DateTime<FixedOffset> {
        offset
            .with_ymd_and_hms(2026, 7, 15, hour, minute, 0)
            .single()
            .unwrap()
    }

    #[test]
    fn overnight_schedule_is_dark_at_2133_in_local_plus_eight() {
        let zone = FixedOffset::east_opt(8 * 3600).unwrap();
        let current = at(&zone, 21, 33);
        let settings = time_settings("18:00", "06:00");

        let (mode, wait) = time_switches_at(&settings, &zone, &current);

        assert_eq!(mode, "dark");
        assert_eq!(wait, 8 * 3600 + 27 * 60);
    }

    #[test]
    fn overnight_schedule_is_dark_before_light_boundary() {
        let zone = FixedOffset::east_opt(8 * 3600).unwrap();
        let current = at(&zone, 3, 30);
        let settings = time_settings("18:00", "06:00");

        let (mode, wait) = time_switches_at(&settings, &zone, &current);

        assert_eq!(mode, "dark");
        assert_eq!(wait, 2 * 3600 + 30 * 60);
    }

    #[test]
    fn overnight_schedule_is_light_between_boundaries() {
        let zone = FixedOffset::east_opt(8 * 3600).unwrap();
        let current = at(&zone, 12, 0);
        let settings = time_settings("18:00", "06:00");

        let (mode, wait) = time_switches_at(&settings, &zone, &current);

        assert_eq!(mode, "light");
        assert_eq!(wait, 6 * 3600);
    }

    #[test]
    fn non_overnight_schedule_uses_the_same_interval_rules() {
        let zone = FixedOffset::east_opt(8 * 3600).unwrap();
        let settings = time_settings("06:00", "18:00");

        assert_eq!(
            time_switches_at(&settings, &zone, &at(&zone, 12, 0)).0,
            "dark"
        );
        assert_eq!(
            time_switches_at(&settings, &zone, &at(&zone, 21, 0)).0,
            "light"
        );
    }
}
