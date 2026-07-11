use serde::Deserialize;
use std::fs;
use std::path::PathBuf;
use std::process;
use std::thread;
use std::time::{Duration, SystemTime, UNIX_EPOCH};

const POLL_SECS: u64 = 120;
const MIN_SLEEP: u64 = 5;
static mut FAKE_NOW: Option<u64> = None;

#[derive(Deserialize, Default)]
struct Settings {
    #[serde(default)] #[serde(rename = "autoMode")] auto_mode: String,
    #[serde(default = "d18")] #[serde(rename = "autoTimeStart")] auto_time_start: String,
    #[serde(default = "d6")] #[serde(rename = "autoTimeEnd")] auto_time_end: String,
    #[serde(default)] #[serde(rename = "autoLat")] auto_lat: f64,
    #[serde(default)] #[serde(rename = "autoLng")] auto_lng: f64,
}
fn d18() -> String { "18:00".into() }
fn d6() -> String { "06:00".into() }

fn config() -> PathBuf {
    let b = std::env::var("XDG_CONFIG_HOME").unwrap_or_else(|_| {
        std::env::var("HOME").map(|h| format!("{h}/.config")).unwrap_or_default()
    });
    PathBuf::from(b).join("quickshell/niri-strata")
}
fn spath() -> PathBuf { config().join("settings.json") }
fn stpath() -> PathBuf { config().join("auto-theme-state.json") }
fn rs() -> Option<Settings> { fs::read_to_string(&spath()).ok().and_then(|r| serde_json::from_str(&r).ok()) }
fn ws(m: &str) { let p = stpath(); let t = format!("{}.tmp", p.display()); let _ = fs::write(&t, m); let _ = fs::rename(&t, &p); }
fn rds() -> String { fs::read_to_string(&stpath()).unwrap_or_default().trim().to_string() }

fn now() -> u64 {
    unsafe { if let Some(f) = FAKE_NOW { return f; } }
    SystemTime::now().duration_since(UNIX_EPOCH).unwrap_or_default().as_secs()
}

fn hhmm(s: &str) -> Option<(u32, u32)> {
    let mut p = s.splitn(2, ':');
    let h: u32 = p.next()?.parse().ok()?;
    let m: u32 = p.next()?.parse().ok()?;
    (h < 24 && m < 60).then_some((h, m))
}
fn secs(h: u32, m: u32) -> u64 { (h * 3600 + m * 60) as u64 }
fn next_occ(h: u32, m: u32) -> u64 {
    let n = now(); let td = n - (n % 86400); let t = td + secs(h, m);
    if t > n { t } else { t + 86400 }
}

fn time_switches(s: &Settings) -> (&str, u64) {
    let (sh, sm) = hhmm(&s.auto_time_start).unwrap_or((18, 0));
    let (eh, em) = hhmm(&s.auto_time_end).unwrap_or((6, 0));
    let ss = secs(sh, sm); let es = secs(eh, em);
    let n = now() % 86400;
    let dk = if ss < es { n >= ss || n < es } else { n >= ss && n < es };
    if dk { ("dark", next_occ(eh, em).saturating_sub(now())) }
    else { ("light", next_occ(sh, sm).saturating_sub(now())) }
}

fn to_date(ts: i64) -> (i32, u32, u32) {
    let days = ts / 86400;
    let d = days + 719468i64;
    let era = d / 146097;
    let doe = d - era * 146097;
    let yoe = (doe - doe / 1460 + doe / 36524 - doe / 146096) / 365;
    let y = yoe + era * 400;
    let doy = doe - (365 * yoe + yoe / 4 - yoe / 100);
    let mp = (5 * doy + 2) / 153;
    let day = (doy - (153 * mp + 2) / 5 + 1) as u32;
    let month = if mp < 10 { (mp + 3) as u32 } else { (mp - 9) as u32 };
    let year = if month <= 2 { y + 1 } else { y };
    (year as i32, month, day)
}

fn sun_switches(s: &Settings) -> (&str, u64) {
    if s.auto_lat == 0.0 && s.auto_lng == 0.0 { return time_switches(s); }
    let n = now();
    let td = (n - (n % 86400)) as i64;
    let sf = |ts: i64| -> Option<(i64, i64)> {
        let (y, mo, d) = to_date(ts);
        Some(sunrise::sunrise_sunset(s.auto_lat, s.auto_lng, y, mo, d))
    };
    let (rise, set) = match sf(td) { Some(v) => v, None => return time_switches(s) };
    if n < rise as u64 { return ("dark", (rise as u64).saturating_sub(n).max(MIN_SLEEP)); }
    if n < set as u64 { return ("light", (set as u64).saturating_sub(n).max(MIN_SLEEP)); }
    let (nr, _) = match sf(td + 86400) { Some((r, _)) => (r, 0), None => return time_switches(s) };
    ("dark", (nr as u64).saturating_sub(n).max(MIN_SLEEP))
}

fn check(args: &[String]) {
    let mut s = rs().unwrap_or_default();
    let mut i = 0;
    while i < args.len() {
        match args[i].as_str() {
            "--lat" => { i += 1; if let Some(v) = args.get(i) { s.auto_lat = v.parse().unwrap_or(0.0); } }
            "--lng" => { i += 1; if let Some(v) = args.get(i) { s.auto_lng = v.parse().unwrap_or(0.0); } }
            "--time" => { i += 1;
                if let Some(v) = args.get(i) {
                    if let Some((h, m)) = hhmm(v) {
                        unsafe { FAKE_NOW = Some(now().saturating_sub(now() % 86400) + secs(h, m)); }
                    }
                }
            }
            _ => {}
        }
        i += 1;
    }
    let (mode, wait) = match s.auto_mode.as_str() { "sun" => sun_switches(&s), _ => time_switches(&s) };
    let l = (now() + wait) % 86400;
    println!("mode:     {mode}");
    println!("next in:  {}h {}m", wait / 3600, wait % 3600 / 60);
    println!("next at:  {:02}:{:02} (local)", l / 3600, l % 3600 / 60);
    if s.auto_mode == "sun" { println!("coords:   {:.4}, {:.4}", s.auto_lat, s.auto_lng); }
}

fn main() {
    let args: Vec<String> = std::env::args().collect();
    if args.iter().any(|a| a == "--check") { check(&args); return; }
    loop {
        let s = match rs() { Some(s) => s, None => { thread::sleep(Duration::from_secs(10)); continue; } };
        if s.auto_mode.is_empty() || s.auto_mode == "manual" { process::exit(0); }
        let (d, w) = match s.auto_mode.as_str() { "sun" => sun_switches(&s), _ => time_switches(&s) };
        if rds() != d { ws(d); }
        thread::sleep(Duration::from_secs(w.min(POLL_SECS).max(MIN_SLEEP)));
    }
}
