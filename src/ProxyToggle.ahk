; ============================================================
; ProxyToggle — 一键切换 Windows 系统代理
; AutoHotkey v2 脚本
;
; 功能:
;   - 快捷键一键开启/关闭系统代理 (默认 Ctrl+Alt+P)
;   - 屏幕右下角常驻指示器显示代理状态
;   - 图形化设置: 代理地址 / 快捷键 / 提示样式 / 开机启动
;   - CLI 模式: toggle / status / gui
;
; 配置: 首次运行自动生成 config.ini（与本文件同目录）
; ============================================================
#Requires AutoHotkey v2.0
#SingleInstance Force

SetWorkingDir(A_ScriptDir)

global AppName := "ProxyToggle"
global AppVersion := "1.0.0"

; ---------------- 默认配置（首次运行写入 config.ini） ----------------
global cfgPath := A_ScriptDir "\config.ini"
global ProxyAddr := "192.168.31.110:7890"   ; 代理地址（支持 "host:port" 或 "socks=host:port"）
global HotkeyCombo := "^!p"                  ; 快捷键（^=Ctrl  !=Alt  +=Shift  #=Win）
global ShowIndicator := true                 ; 是否显示提示
global Transparency := 180                   ; 透明度 0~255
global FontSize := 16                        ; 提示字号
global GuiWidth := 200                       ; 提示窗口宽度
global GuiHeight := 60                       ; 提示窗口高度
global AutoStart := false                    ; 是否开机启动

; ---------------- 运行时状态 ----------------
global ProxyGui := ""        ; 指示器窗口对象
global ToggleHotkey := ""    ; 当前已注册的热键
global SettingsGui := ""     ; 设置窗口对象
global HotkeyEdit := ""      ; 设置窗口中的快捷键输入框
global StatusLabel := ""     ; 设置窗口中的状态提示
global CaptureHook := ""     ; 快捷键监听 InputHook
global Capturing := false    ; 是否正在监听快捷键
global CaptureMods := Map()  ; 监听期间按下的修饰键 vk 集合
global PreviewGui := ""      ; 设置窗口中的提示框预览

; ============================================================
; 入口
; ============================================================
LoadConfig()

if (A_Args.Length > 0) {
    switch A_Args[1] {
        case "toggle":
            ToggleProxy(false)
            ExitApp()
        case "status":
            PrintStatus()
            ExitApp()
        case "gui":
            OpenSettingsGui()
    }
}

ApplySettings()        ; 注册热键、同步开机启动、重建托盘菜单
CheckAndShowStatus()   ; 按当前代理状态同步指示器

TrayTip(AppName, "代理切换脚本已启动`n快捷键 " ReadableHotkey(HotkeyCombo) " 已生效", "Iconi")
Persistent

; ============================================================
; 配置读写
; ============================================================

LoadConfig() {
    global ProxyAddr, HotkeyCombo, ShowIndicator, Transparency, FontSize, GuiWidth, GuiHeight, AutoStart
    if not FileExist(cfgPath) {
        SaveConfig()   ; 生成默认配置
        return
    }
    NormalizeIniBom()  ; 修复被外部编辑器写成 "UTF-8 带 BOM" 的配置（会导致首个小节读不到）
    ProxyAddr := IniRead(cfgPath, "General", "ProxyAddr", "192.168.31.110:7890")
    HotkeyCombo := IniRead(cfgPath, "General", "Hotkey", "^!p")
    ShowIndicator := (IniRead(cfgPath, "Indicator", "Show", "1") = "1")
    Transparency := Clamp(IniRead(cfgPath, "Indicator", "Transparency", "180"), 0, 255)
    FontSize := Clamp(IniRead(cfgPath, "Indicator", "FontSize", "16"), 8, 48)
    GuiWidth := Clamp(IniRead(cfgPath, "Indicator", "Width", "200"), 100, 800)
    GuiHeight := Clamp(IniRead(cfgPath, "Indicator", "Height", "60"), 40, 400)
    AutoStart := (IniRead(cfgPath, "Startup", "AutoStart", "0") = "1")
}

SaveConfig() {
    IniWrite(ProxyAddr, cfgPath, "General", "ProxyAddr")
    IniWrite(HotkeyCombo, cfgPath, "General", "Hotkey")
    IniWrite(ShowIndicator ? 1 : 0, cfgPath, "Indicator", "Show")
    IniWrite(Transparency, cfgPath, "Indicator", "Transparency")
    IniWrite(FontSize, cfgPath, "Indicator", "FontSize")
    IniWrite(GuiWidth, cfgPath, "Indicator", "Width")
    IniWrite(GuiHeight, cfgPath, "Indicator", "Height")
    IniWrite(AutoStart ? 1 : 0, cfgPath, "Startup", "AutoStart")
}

; AHK 的 IniRead 无法正确解析"UTF-8 带 BOM"文件的第一小节（BOM 字符混入节名，导致读不到）。
; 检测到 UTF-8 BOM (EF BB BF) 时，重写为不带 BOM 的 UTF-8（内容与注释原样保留）。
NormalizeIniBom() {
    if not HasUtf8Bom()
        return
    try {
        text := FileRead(cfgPath)
        f := FileOpen(cfgPath, "w", "UTF-8-RAW")
        f.Write(text)
        f.Close()
    } catch {
        ; 重写失败时忽略，按默认值继续
    }
}

; 读取文件前 3 个字节判断是否为 UTF-8 BOM。
; AHK 的 FileOpen/RawRead 会自动跳过 BOM，因此改用 Win32 API 直接读原始字节。
HasUtf8Bom() {
    try {
        hFile := DllCall("CreateFile", "Str", cfgPath, "UInt", 0x80000000, "UInt", 0x1, "Ptr", 0, "UInt", 3, "UInt", 0, "Ptr", 0, "Ptr")
        if (hFile = -1 or hFile = 0)
            return false
        bytes := Buffer(3)
        nRead := 0
        ok := DllCall("ReadFile", "Ptr", hFile, "Ptr", bytes, "UInt", 3, "UInt*", &nRead, "Ptr", 0)
        DllCall("CloseHandle", "Ptr", hFile)
        if not ok or nRead < 3
            return false
        return (NumGet(bytes, 0, "UChar") = 0xEF and NumGet(bytes, 1, "UChar") = 0xBB and NumGet(bytes, 2, "UChar") = 0xBF)
    } catch {
        return false
    }
}

Clamp(value, min, max) {
    try {
        v := Integer(value)
    } catch {
        return min
    }
    if (v < min)
        return min
    if (v > max)
        return max
    return v
}

; ============================================================
; 热键 / 托盘 / 开机启动
; ============================================================

ApplySettings() {
    global ToggleHotkey, HotkeyCombo
    ; 注销旧热键
    if (ToggleHotkey != "" and ToggleHotkey != HotkeyCombo)
        try Hotkey(ToggleHotkey, "Off")
    ; 注册新热键（非法则回退默认）
    ; 注意: 必须显式传 "On" 选项 —— 热键一旦被 "Off" 过，仅传回调重新注册不会启用它
    if (HotkeyCombo != "") {
        try {
            Hotkey(HotkeyCombo, ToggleProxy, "On")
        } catch {
            TrayTip(AppName, "快捷键 " HotkeyCombo " 无效，已恢复默认 ^!p", "Iconi")
            HotkeyCombo := "^!p"
            try Hotkey(HotkeyCombo, ToggleProxy, "On")
            SaveConfig()
        }
        ToggleHotkey := HotkeyCombo
    }
    SyncAutoStart()
    BuildTrayMenu()
}

BuildTrayMenu() {
    A_TrayMenu.Delete()
    A_TrayMenu.Add("切换代理 (" ReadableHotkey(HotkeyCombo) ")", (*) => ToggleProxy())
    A_TrayMenu.Add()
    A_TrayMenu.Add("开机启动", (*) => ToggleAutoStart())
    if (AutoStart)
        A_TrayMenu.Check("开机启动")
    A_TrayMenu.Add()
    A_TrayMenu.Add("设置...", (*) => OpenSettingsGui())
    A_TrayMenu.Add()
    A_TrayMenu.Add("退出脚本", (*) => ExitApp())
}

ToggleAutoStart(*) {
    global AutoStart
    AutoStart := !AutoStart
    SaveConfig()
    SyncAutoStart()
    if (AutoStart)
        A_TrayMenu.Check("开机启动")
    else
        A_TrayMenu.Uncheck("开机启动")
    TrayTip(AppName, AutoStart ? "已开启开机启动" : "已关闭开机启动", "Iconi")
}

SyncAutoStart() {
    runKey := "HKCU\Software\Microsoft\Windows\CurrentVersion\Run"
    if (AutoStart)
        RegWrite(StartCommand(), "REG_SZ", runKey, "ProxyToggle")
    else
        try RegDelete(runKey, "ProxyToggle")
}

StartCommand() {
    if (A_IsCompiled)
        return '"' A_ScriptFullPath '"'
    return '"' A_AhkPath '" "' A_ScriptFullPath '"'
}

ReadableHotkey(combo) {
    s := combo
    s := StrReplace(s, "^", "{CTRL}")
    s := StrReplace(s, "!", "{ALT}")
    s := StrReplace(s, "#", "{WIN}")
    s := StrReplace(s, "+", "{SHIFT}")
    s := StrReplace(s, "{CTRL}", "Ctrl+")
    s := StrReplace(s, "{ALT}", "Alt+")
    s := StrReplace(s, "{WIN}", "Win+")
    s := StrReplace(s, "{SHIFT}", "Shift+")
    return s
}

; ============================================================
; 核心切换
; ============================================================

ToggleProxy(ShowHint := true) {
    regPath := "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings"
    try {
        enabled := RegRead(regPath, "ProxyEnable")
    } catch {
        enabled := "0"
    }

    if (enabled = "0") {
        ; ---- 开启代理 ----
        RegWrite(ProxyAddr, "REG_SZ", regPath, "ProxyServer")
        RegWrite(1, "REG_DWORD", regPath, "ProxyEnable")
        RefreshProxySettings()
        if (ShowHint and ShowIndicator)
            ShowProxyIndicator(true)
    } else {
        ; ---- 关闭代理 ----
        RegWrite(0, "REG_DWORD", regPath, "ProxyEnable")
        RefreshProxySettings()
        if (ShowHint)
            ShowProxyIndicator(false)
    }
}

RefreshProxySettings() {
    ; 通知系统代理设置已变更并刷新，立即生效
    ; INTERNET_OPTION_SETTINGS_CHANGED = 39, INTERNET_OPTION_REFRESH = 42
    DllCall("wininet.dll\InternetSetOption", "Ptr", 0, "UInt", 39, "Ptr", 0, "UInt", 0)
    DllCall("wininet.dll\InternetSetOption", "Ptr", 0, "UInt", 42, "Ptr", 0, "UInt", 0)
}

; ============================================================
; 常驻指示器
; ============================================================

ShowProxyIndicator(Show) {
    global ProxyGui
    if (Show) {
        if (ProxyGui != "") {
            try ProxyGui.Destroy()
            ProxyGui := ""
        }
        ProxyGui := Gui()
        ProxyGui.BackColor := "Black"
        ProxyGui.SetFont("s" FontSize " Bold", "Segoe UI, Microsoft YaHei, Segoe UI Emoji")
        ProxyGui.AddText("cLime", "🔌 代理已打开")
        ProxyGui.Opt("+AlwaysOnTop -Caption +ToolWindow +E0x20")

        x := A_ScreenWidth - GuiWidth - 20
        y := A_ScreenHeight - GuiHeight - 20
        ProxyGui.Show("x" x " y" y " w" GuiWidth " h" GuiHeight " NoActivate")

        WinSetTransparent(Transparency, ProxyGui.Hwnd)
    } else {
        if (ProxyGui != "") {
            try ProxyGui.Destroy()
            ProxyGui := ""
        }
    }
}

CheckAndShowStatus() {
    regPath := "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings"
    try {
        enabled := RegRead(regPath, "ProxyEnable")
        if (enabled = "1" and ShowIndicator)
            ShowProxyIndicator(true)
        else
            ShowProxyIndicator(false)
    } catch {
        ShowProxyIndicator(false)
    }
}

; ============================================================
; 设置窗口
; ============================================================

OpenSettingsGui(*) {
    global SettingsGui, HotkeyEdit, StatusLabel
    if (SettingsGui != "") {
        try SettingsGui.Show()
        return
    }
    g := Gui("+AlwaysOnTop", AppName " 设置")
    g.SetFont("s10", "Segoe UI, Microsoft YaHei")

    g.AddText("xm", "代理地址:")
    g.AddEdit("x+8 w280 vProxyAddr", ProxyAddr)

    g.AddText("xm", "快捷键:")
    HotkeyEdit := g.AddEdit("x+8 w180 vHotkey", HotkeyCombo)
    g.AddButton("x+8 w80", "监听...").OnEvent("Click", StartHotkeyCapture)
    StatusLabel := g.AddText("xm w400", "提示：点击“监听...”后按下新的快捷键组合")

    g.AddText("xm", "显示提示:")
    g.AddCheckbox("x+8 vShowInd " . (ShowIndicator ? "Checked" : ""), "显示代理状态提示")

    g.AddText("xm", "提示透明度:")
    g.AddEdit("x+8 w60 vTransp", Transparency).OnEvent("Change", UpdatePreview)
    g.AddText("x+16", "字号:")
    g.AddEdit("x+8 w60 vFontSz", FontSize).OnEvent("Change", UpdatePreview)
    g.AddText("x+16", "宽度:")
    g.AddEdit("x+8 w60 vWinW", GuiWidth).OnEvent("Change", UpdatePreview)
    g.AddText("x+16", "高度:")
    g.AddEdit("x+8 w60 vWinH", GuiHeight).OnEvent("Change", UpdatePreview)

    g.AddText("xm", "开机启动:")
    g.AddCheckbox("x+8 vAutoStart " . (AutoStart ? "Checked" : ""), "系统启动时自动运行")

    g.AddText("xm w400", "透明度 0-255，字号 8-48，宽度 100-800，高度 40-400，越界自动修正")
    g.AddText("xm cGray", "▼ 下方为提示框实时预览（与右下角提示框样式一致）")

    g.AddButton("xm w120 Default", "保存并应用").OnEvent("Click", SaveSettings)
    g.AddButton("x+12 w90", "取消").OnEvent("Click", CloseSettingsGui)

    SettingsGui := g
    g.Show("w440")
    UpdatePreview()   ; 显示初始预览
}

; 读取设置窗口当前输入，实时重建提示框预览（与实际提示框参数一致）
UpdatePreview(*) {
    global PreviewGui, SettingsGui
    if (SettingsGui = "")
        return
    values := SettingsGui.Submit(false)
    transp := Clamp(values.Transp, 0, 255)
    fSize := Clamp(values.FontSz, 8, 48)
    pWidth := Clamp(values.WinW, 100, 800)
    pHeight := Clamp(values.WinH, 40, 400)

    if (PreviewGui != "") {
        try PreviewGui.Destroy()
        PreviewGui := ""
    }
    PreviewGui := Gui()
    PreviewGui.BackColor := "Black"
    PreviewGui.SetFont("s" fSize " Bold", "Segoe UI, Microsoft YaHei, Segoe UI Emoji")
    PreviewGui.AddText("cLime", "🔌 代理已打开")
    PreviewGui.Opt("+AlwaysOnTop -Caption +ToolWindow +E0x20")

    ; 定位到设置窗口正下方（放不下则放到上方）
    SettingsGui.GetPos(&sx, &sy, &sw, &sh)
    px := sx
    py := sy + sh + 8
    if (py + pHeight > A_ScreenHeight)
        py := sy - pHeight - 8
    PreviewGui.Show("x" px " y" py " w" pWidth " h" pHeight " NoActivate")
    WinSetTransparent(transp, PreviewGui.Hwnd)
}

SaveSettings(*) {
    global SettingsGui, ProxyAddr, HotkeyCombo, ShowIndicator, Transparency, FontSize, GuiWidth, GuiHeight, AutoStart
    g := SettingsGui
    values := g.Submit(false)

    newAddr := Trim(values.ProxyAddr)
    if (newAddr = "") {
        MsgBox("代理地址不能为空。", AppName, "Icon!")
        return
    }
    newHotkey := Trim(values.Hotkey)
    if (newHotkey = "") {
        MsgBox("快捷键不能为空。", AppName, "Icon!")
        return
    }
    ; 校验快捷键格式（先注册再注销，失败则报错并保留原设置）
    ; 随后 ApplySettings 会用 "On" 显式重新启用，因此这里 Off 掉不影响最终结果
    try {
        Hotkey(newHotkey, ToggleProxy, "On")
        Hotkey(newHotkey, "Off")
    } catch {
        MsgBox("快捷键无效或格式错误：" newHotkey "`n`n请使用 AHK 语法，例如 ^!p 表示 Ctrl+Alt+P。", AppName, "Icon!")
        return
    }

    ProxyAddr := newAddr
    HotkeyCombo := newHotkey
    ShowIndicator := (values.ShowInd = 1)
    Transparency := Clamp(values.Transp, 0, 255)
    FontSize := Clamp(values.FontSz, 8, 48)
    GuiWidth := Clamp(values.WinW, 100, 800)
    GuiHeight := Clamp(values.WinH, 40, 400)
    AutoStart := (values.AutoStart = 1)

    SaveConfig()
    ApplySettings()

    ; 按新样式重建指示器
    regPath := "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings"
    try {
        enabled := RegRead(regPath, "ProxyEnable")
        if (enabled = "1" and ShowIndicator)
            ShowProxyIndicator(true)
        else
            ShowProxyIndicator(false)
    } catch {
        ShowProxyIndicator(false)
    }

    TrayTip(AppName, "设置已保存并生效", "Iconi")
    CloseSettingsGui()
}

CloseSettingsGui(*) {
    global SettingsGui, PreviewGui
    StopCapture()
    if (PreviewGui != "") {
        try PreviewGui.Destroy()
        PreviewGui := ""
    }
    if (SettingsGui != "") {
        try SettingsGui.Destroy()
        SettingsGui := ""
    }
}

; ============================================================
; 快捷键监听（捕获下一次按键组合）
; ============================================================

StartHotkeyCapture(*) {
    global CaptureHook, Capturing, StatusLabel, CaptureMods
    if (Capturing)
        return
    Capturing := true
    CaptureMods.Clear()
    ; 无结束键：Enter/Esc/Tab 等也可被捕获为快捷键（Esc 在回调中做"取消"处理）
    CaptureHook := InputHook("", "")
    ; 监听期间按键透传，不拦截用户输入
    CaptureHook.VisibleText := true
    CaptureHook.VisibleNonText := true
    ; N = Notify：对所有按键启用 OnKeyDown/OnKeyUp 通知（KeyOpt 合法选项为 E/I/N/S/V）
    CaptureHook.KeyOpt("{All}", "N")
    CaptureHook.OnKeyDown := CaptureKeyDown
    CaptureHook.Start()
    if (StatusLabel != "")
        StatusLabel.Text := "请按下新的快捷键组合…（10 秒内，按 Esc 取消）"
    SetTimer(StopCaptureTimeout, -10000)
}

; 是否为修饰键（覆盖中性 VK 与左右 VK，如 LCtrl=0xA2 / RCtrl=0xA3）
IsModifierVk(vk) {
    return (vk = 0x10 or vk = 0x11 or vk = 0x12 or vk = 0x5B or vk = 0x5C
        or vk = 0xA0 or vk = 0xA1 or vk = 0xA2 or vk = 0xA3 or vk = 0xA4 or vk = 0xA5)
}

; 根据已按下的修饰键集合构建 AHK 前缀（^=Ctrl !=Alt +=Shift #=Win）
ModsToPrefix() {
    global CaptureMods
    prefix := ""
    if (CaptureMods.Has(0x11) or CaptureMods.Has(0xA2) or CaptureMods.Has(0xA3))
        prefix .= "^"
    if (CaptureMods.Has(0x12) or CaptureMods.Has(0xA4) or CaptureMods.Has(0xA5))
        prefix .= "!"
    if (CaptureMods.Has(0x10) or CaptureMods.Has(0xA0) or CaptureMods.Has(0xA1))
        prefix .= "+"
    if (CaptureMods.Has(0x5B) or CaptureMods.Has(0x5C))
        prefix .= "#"
    return prefix
}

CaptureKeyDown(ih, vk, sc) {
    global Capturing, CaptureMods, HotkeyEdit, StatusLabel
    if (!Capturing)
        return
    ; 修饰键：记录状态后继续监听，等待主键（支持 Ctrl+Alt+P 等组合键）
    if (IsModifierVk(vk)) {
        CaptureMods[vk] := true
        return
    }
    ; 注意: "vkXX scYYY"（带空格）是无效格式，须写作 "vkXXscYYY"
    keyName := GetKeyName(Format("vk{:02X}sc{:03X}", vk, sc))
    if (keyName = "")
        return
    if (keyName = "Esc" or keyName = "Escape") {
        StopCapture()   ; 按 Esc 取消监听
        return
    }
    combo := ModsToPrefix() . keyName
    if (HotkeyEdit != "")
        HotkeyEdit.Text := combo
    if (StatusLabel != "")
        StatusLabel.Text := "已捕获: " combo " — 点击“保存并应用”生效"
    StopCapture()
}

StopCapture() {
    global CaptureHook, Capturing, StatusLabel, CaptureMods
    if (!Capturing)
        return
    Capturing := false
    CaptureMods.Clear()
    try CaptureHook.Stop()
    SetTimer(StopCaptureTimeout, 0)
    if (StatusLabel != "")
        StatusLabel.Text := "提示：点击“监听...”后按下新的快捷键组合"
}

StopCaptureTimeout() {
    if (Capturing) {
        StopCapture()
        TrayTip(AppName, "快捷键监听已超时", "Iconi")
    }
}

; ============================================================
; CLI 辅助
; ============================================================

PrintStatus() {
    regPath := "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings"
    try {
        enabled := RegRead(regPath, "ProxyEnable")
    } catch {
        enabled := "0"
    }
    server := ""
    try server := RegRead(regPath, "ProxyServer")
    if (enabled = "1")
        FileAppend("ON " server "`n", "*")
    else
        FileAppend("OFF`n", "*")
}

; 退出时清理指示器
OnExit((*) => ShowProxyIndicator(false))
