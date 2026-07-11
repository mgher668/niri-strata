# DMS 主题配色生成功能 — 详细研究报告

> 研究对象: `temp/DankMaterialShell/`
> 日期: 2026-07-10

---

## 1. 架构总览

```
                    ┌─ 壁纸 ──┐
                    │  或      │
                    │ hex 色 ──┤
                    │  或      │
                    │ 预设主题 │
                    └────┬─────┘
                         ▼
                    matugen (Rust)
                    "image" / "hex"
                         │
                         ▼
              dms matugen queue (Go)
              填模板 → 写文件到磁盘
                         │
            ┌────────────┼────────────┐
            ▼            ▼            ▼
     Quickshell 色板   GTK CSS     Qt conf
     (dank16 JSON)    (~/.config/  (~/.config/
                       gtk-3.0/)   qt5ct/)
            │            │            │
            ▼            ▼            ▼
      shell 主题     GTK 应用    Qt 应用
```

### 关键原则

1. **matugen 是唯一颜色引擎** — 所有 30+ 颜色从 matugen 输出
2. **daemon 只发 IPC 信号，不写文件** — Go daemon (`dms`) 通过 DMSService 发 `theme.auto.getState` IPC 消息
3. **Quickshell 是唯一文件写入者** — `SessionData.saveSettings()` → `session.json`；`SettingsData` → `settings.json`
4. **两个独立字段**: `themeModeAutoEnabled`（用户是否开自动） + `isLightMode`（当前亮/暗）

---

## 2. 核心数据模型

### 2.1 SessionData（持久化到 `session.json`）

**文件**: `quickshell/Common/SessionData.qml`

| 字段 | 类型 | 谁写 | 含义 |
|---|---|---|---|
| `isLightMode` (L31) | `property bool` | 用户 或 daemon | 当前实际亮/暗 |
| `themeModeAutoEnabled` (L167) | `property bool` | 用户 | 是否启用自动切换 |
| `themeModeAutoMode` (L168) | `property string` | 用户 | `"time"` 或 `"location"` |
| `themeModeStartHour/Minute` (L169-170) | `property int` | 用户 | 暗色开始时间 |
| `themeModeEndHour/Minute` (L171-172) | `property int` | 用户 | 亮色开始时间 |
| `latitude` / `longitude` (L162-163) | `property real` | 用户 | 经纬度 |
| `themeModeNextTransition` (L174) | `property string` | daemon | 下次切换的描述 |

**写入**: `SessionData.setLightMode(lightMode)` (L301):
```javascript
function setLightMode(lightMode) {
    isSwitchingMode = true;
    syncWallpaperForCurrentMode(lightMode);  // 亮/暗不同壁纸
    isLightMode = lightMode;
    saveSettings();  // → 写 session.json
}
```

**文件**: `SessionData.saveSettings()` → `FileView.setText()` → `session.json`

### 2.2 Theme（不持久化，运行时常驻）

**文件**: `quickshell/Common/Theme.qml` (2656行)

| 属性 | 含义 |
|---|---|
| `isLightMode` (L36) | 绑定到 `SessionData.isLightMode`，决定暗/亮调色板 |
| `currentTheme` (L34) | 当前主题名：`"purple"`, `"dynamic"`, `"custom"` 等 |
| `matugenColors` (L105) | matugen 输出的完整 30+ 颜色对象 |
| `matugenAvailable` (L98) | `command -v matugen` 检测 |
| `dank16` (L113) | 从 matugenColors 提取的暗/亮 16 色 |

### 2.3 SettingsData（持久化到 `settings.json`）

**文件**: `quickshell/Common/SettingsData.qml` (140436字节，极大)

主题相关 key（部分）:
- `currentThemeName` — 主题名
- `iconTheme` — 图标主题
- `matugenScheme` — matugen 配色方案 (`"scheme-tonal-spot"` 等)
- `gtkAvailable`, `qt5ctAvailable`, `qt6ctAvailable` — 工具可用性
- `wallpaperPath` — 壁纸路径
- `runUserMatugenTemplates` — 是否运行用户自定义模板

---

## 3. 完整执行流程

### 3.1 启动时

**Theme.qml `Component.onCompleted`** (L143-202):

```
1. 创建 state 目录
2. 检查 matugen 是否安装
3. 如果是动态主题 → setDesiredTheme("image", wallpaperPath)
4. 如果是预设主题 → setDesiredTheme("hex", primaryColor, ..., stockColors)
5. 连接 SessionData.isLightModeChanged → onLightModeChanged()
6. 启动 themeModeAutomation (如启用)
```

**关键**: 不管是动态还是预设，**都走 matugen**——预设主题把主色当 hex 输入 matugen，生成完整调色板。

### 3.2 用户或 daemon 切换亮/暗

```
Theme.setLightMode(light, savePrefs=true, enableTransition=false)
    │
    ├─ enableTransition? → 屏幕过渡动画 → 延迟执行
    │
    ├─ SessionData.setLightMode(light)
    │       ├─ wallPaperSync()
    │       ├─ isLightMode = light
    │       └─ saveSettings() → session.json
    │
    ├─ PortalService.setLightMode(light)  // 通知桌面门户
    ├─ SettingsData.updateCosmicThemeMode(light)
    └─ generateSystemThemesFromCurrentTheme()
            │
            └─ 100ms debounce → _executeThemeGeneration()
                    │
                    └─ setDesiredTheme(kind, value, isLight, ...)
```

### 3.3 setDesiredTheme — 触发 matugen 生成

**文件**: `Theme.qml` (L507-536)

```javascript
function setDesiredTheme(kind, value, isLight, iconTheme, matugenType, stockColors) {
    const args = [
        "dms", "matugen", "queue",
        "--state-dir", stateDir,
        "--shell-dir", shellDir,
        "--config-dir", configDir,
        "--kind", kind,        // "image" | "hex"
        "--value", value,      // 壁纸路径 | "#42a5f5"
        "--mode", isLight ? "light" : "dark",
        "--icon-theme", iconTheme,
        "--matugen-type", matugenType,  // "scheme-tonal-spot" 等
    ];
    // 调用 Go daemon: dms matugen queue
    Proc.runCommand("matugenWorker", args, callback);
}
```

**dms matugen queue** 做什么:
1. 运行 `matugen image wallpaper.png` 或 `matugen image "#42a5f5"`
2. matugen 输出 JSON 颜色数据（30+ 色）
3. dms 用模板引擎把颜色填入模板文件
4. 写输出到磁盘各路径
5. 回到 Quickshell 触发 matugenCompleted 信号

### 3.4 matugen 完成后的回调

**文件**: `Theme.qml` (matugenCompleted 信号处理)

matugen 完成后，dms 发回结果。Quickshell 收到后:
1. 存储 `matugenColors` 颜色数据
2. 解析 `dank16`（暗/亮 16 色调色板）
3. 运行 `gtkApplier` → `scripts/gtk.sh`
4. 运行 `qtApplier` → `scripts/qt.sh`

### 3.5 gtk.sh — GTK 主题应用

**文件**: `quickshell/scripts/gtk.sh` (129行)

```
1. GTK3: ~/.config/gtk-3.0/gtk.css → symlink → dank-colors.css
2. GTK4: ~/.config/gtk-4.0/gtk.css → 注入 @import "dank-colors.css"
3. 链接 adw-gtk3 主题的 assets（图标资源）
```

GTK 颜色 CSS 由 matugen 模板 `matugen/templates/gtk-colors.css` 和 `matugen/templates/gtk-light-colors.css` 生成，定义:
- `@define-color accent_bg_color`
- `@define-color window_bg_color`
- `@define-color headerbar_bg_color`
- `@define-color sidebar_bg_color`
- 等 20+ 个 GTK CSS 变量

### 3.6 qt.sh — Qt 主题应用

**文件**: `quickshell/scripts/qt.sh` (89行)

```
1. 检查 matugen 生成的 ~/.local/share/color-schemes/DankMatugen.colors
2. 写 ~/.config/qt5ct/qt5ct.conf：custom_palette=true, color_scheme_path=...
3. 写 ~/.config/qt6ct/qt6ct.conf：同上
```


### 3.7 auto 模式（时间/位置自动切换）

**文件**: `Theme.qml`, `SessionData.qml`

```
dms Go daemon
  │
  │ IPC: theme.auto.getState
  ▼
DMSService.___onThemeAutoStateUpdate(data)
  │   data: { isLight, nextTransition, config }
  │
  ▼
Theme.applyThemeAutoState(state)
  │   如果 SessionData.themeModeAutoEnabled == true
  │   且 config.mode 匹配
  │
  └─ Theme.setLightMode(state.isLight, true, true)
       │
       └─ 同上 3.2 流程
```

**DMS daemon 不写任何文件**。它通过 Quickshell 的 DMSService IPC 通道发 JSON 消息，Theme 接收后调用 `setLightMode()`，后者写 `session.json`。文件始终由 Quickshell 独占写入。

---

## 4. 预设主题系统

### 4.1 StockThemes.js

**文件**: `quickshell/Common/StockThemes.js` (13KB+)

```javascript
const StockThemes = {
    DARK: {
        blue: { primary: "#42a5f5", surface: "#101418", ... },
        green: { primary: "#66bb6a", ... },
        purple: { primary: "#ce93d8", ... },  // 默认
        catppuccin: { ... },
        nord: { ... },
        tokyonight: { ... },
        // ... 总共 40+ 主题
    },
    LIGHT: {
        // 对应的亮色版本
    }
}
```

每个主题约 30 个颜色字段: `primary`, `secondary`, `tertiary`, `surface`, `surfaceText`, `surfaceVariant`, `background`, `error`, `warning`, `success` 等。

### 4.2 选择预设主题

用户选预设主题时，走 matugen 流程——把 `primary` 值当 hex 色输入 matugen:
```javascript
setDesiredTheme("hex", themeData.primary, isLight, iconTheme, themeData.matugen_type, stockColors)
```

`stockColors` 是一个完整颜色对象（`buildMatugenColorsFromTheme` 构造），**替代** matugen 自动生成的色值。这样预设主题的颜色定义完全由 StockThemes.js 控制，matugen 只负责生成应用配置（GTK CSS、Qt conf 等）。

---

## 5. 颜色管线详解

### 5.1 matugen 输出 (dank16)

```javascript
// Theme.qml L113-137
readonly property var dank16: {
    const raw = matugenColors?.dank16;
    // 提取 16 个颜色, 每个有 dark/light/default 三份
    return { dark: { color0..color15 }, light: { color0..color15 }, default: { color0..color15 } };
}
```

### 5.2 颜色属性推导

**文件**: `Theme.qml` L530-610

matugen 颜色 → Theme 属性:
```javascript
property color primary: currentThemeData.primary
property color surface: currentThemeData.surface
property color surfaceHover: withAlpha(surfaceVariant, 0.08)
property color surfacePressed: withAlpha(surfaceVariant, 0.12)
property color surfaceSelected: withAlpha(surfaceVariant, 0.15)
property color primaryHover: withAlpha(primary, 0.12)
```

约 60+ 个颜色属性都是 `currentThemeData` 的别名或 `withAlpha()` 派生。

### 5.3 withAlpha 函数

```javascript
function withAlpha(c, a) {
    return Qt.rgba(c.r, c.g, c.b, a);
}
```

把任意基础色 + 透明度 → 半透明色。

---

## 6. 模板系统（应用生成）

### 6.1 模板文件列表

**目录**: `quickshell/matugen/configs/` (25个 `.toml` 文件)

| 模板 | 目标 |
|---|---|
| `gtk3-dark.toml` / `gtk3-light.toml` | `~/.config/gtk-3.0/dank-colors.css` |
| `qt5ct.toml` / `qt6ct.toml` | `~/.config/qt5ct/` / `~/.config/qt6ct/` |
| `niri.toml` | niri 颜色配置片段 |
| `kcolorscheme.toml` | KDE 配色方案 |
| `ghostty.toml` / `kitty.toml` / `foot.toml` / `alacritty.toml` / `wezterm.toml` | 终端配色 |
| `neovim.toml` / `vscode.toml` / `emacs.toml` / `zed.toml` | 编辑器配色 |
| `firefox.toml` / `zenbrowser.toml` / `pywalfox.toml` | 浏览器配色 |
| `vesktop.toml` / `vencord.toml` / `equibop.toml` | Discord mod 配色 |
| `hyprland.toml` / `mangowc.toml` | 合成器配色 |
| `dgop.toml` | DGOP |

### 6.2 自定义 CSS 模板

**目录**: `quickshell/matugen/templates/`

- `gtk-colors.css` — GTK 暗色 CSS 模板
- `gtk-light-colors.css` — GTK 亮色 CSS 模板（补充 adw-gtk3 的亮色修复）
- `firefox-userchrome.css` — Firefox userChrome.css
- `vesktop.css` / `vesktop-base.css` — Vesktop Discord 主题
- `zen-userchrome.css` — Zen Browser

---

## 7. 文件路径约定

| 用途 | 路径 |
|---|---|
| Quickshell session 数据 | `~/.config/dms/session.json` |
| Quickshell 设置 | `~/.config/dms/settings.json` |
| matugen 状态/缓存 | `~/.cache/DankMaterialShell/` |
| GTK3 颜色 CSS | `~/.config/gtk-3.0/dank-colors.css` |
| GTK3 CSS 链接 | `~/.config/gtk-3.0/gtk.css` → symlink → `dank-colors.css` |
| GTK4 CSS 导入 | `~/.config/gtk-4.0/gtk.css` (含 `@import`) |
| Qt 配色方案 | `~/.local/share/color-schemes/DankMatugen.colors` |
| qt5ct 配置 | `~/.config/qt5ct/qt5ct.conf` |
| qt6ct 配置 | `~/.config/qt6ct/qt6ct.conf` |
| matugen 源码 | `quickshell/matugen/configs/*.toml` |
| matugen 模板 | `quickshell/matugen/templates/*.css` |
| gtk 脚本 | `quickshell/scripts/gtk.sh` |
| qt 脚本 | `quickshell/scripts/qt.sh` |

---

## 8. niri-strata 可借鉴的部分

### 已实现
- [x] `Theme._isLight` 绑定到 mode（dark/light/auto）
- [x] `Theme._autoLight` 运行时属性（daemon 通过 Bridge 设）
- [x] 内置预设调色板 (`ThemePresets.js` — 6套 × 暗/亮)
- [x] `Theme.colors.surfaceHover` / `buttonHover` / `activeTabBg`（半透明派生色）
- [x] Rust daemon 写独立状态文件（`auto-theme-state.json`）
- [x] `AutoThemeBridge` 读状态文件 → 设 `_autoLight`

### 可借鉴（Phase B: matugen 动态调色板）
- [ ] matugen 集成：`Process` 跑 `matugen image --json`
- [ ] 解析 JSON → 更新 `Theme._palette`
- [ ] `themeId` 新增 `"dynamic"` 选项
- [ ] 壁纸选择器 UI

### 可借鉴（Phase C: 系统主题导出）
- [ ] GTK: 写 `~/.config/gtk-3.0/niri-strata-colors.css` + symlink
- [ ] GTK4: 写 `~/.config/gtk-4.0/niri-strata-colors.css` + `@import`
- [ ] Qt: 写 `~/.config/qt5ct/qt5ct.conf` + `qt6ct/qt6ct.conf`
- [ ] 以上脚本 (`scripts/gtk-colors.sh`, `scripts/qt-colors.sh`)
- [ ] 降级处理：matugen 未装 → 不崩溃

---

## 9. niri-strata vs DMS 架构对比

| 维度 | DMS | niri-strata (当前) |
|---|---|---|
| 颜色引擎 | matugen (Rust) + 40+ 预设 | 6 套内置预设 |
| 预设格式 | StockThemes.js × 暗/亮双份 | ThemePresets.js × 暗/亮双份 |
| 调色板大小 | 30+ 色 | 30 色 |
| daemon | Go (`dms`), 通过 IPC | Rust, 写状态文件 |
| 自动切换 | daemon IPC → SessionData | daemon file → Bridge → Theme._autoLight |
| 亮/暗字段 | 两个独立字段 | 一个字段 + 运行时属性 |
| GTK 同步 | gtk.sh (CSS + symlink) | 无 |
| Qt 同步 | qt.sh (qt5ct/qt6ct conf) | 无 |
| 终端同步 | matugen 模板 | 无 |
| 编辑器同步 | matugen 模板 | 无 |
| 浏览器同步 | matugen 模板 | 无 |
