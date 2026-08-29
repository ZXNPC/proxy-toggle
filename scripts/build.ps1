<#
.SYNOPSIS
    使用 Ahk2Exe (AutoHotkey v2 官方编译器) 将 src/ProxyToggle.ahk 编译为 .exe。

.DESCRIPTION
    自动探测 Ahk2Exe.exe 与 AutoHotkey64.exe（编译基础文件）；
    未安装时给出下载指引。也可通过参数手动指定。

.EXAMPLE
    .\scripts\build.ps1
    .\scripts\build.ps1 -Out "dist\ProxyToggle.exe"
    .\scripts\build.ps1 -Ahk2Exe "D:\tools\Ahk2Exe\Ahk2Exe.exe" -Icon "assets\app.ico"

.NOTES
    Ahk2Exe v2 下载: https://github.com/AutoHotkey/Ahk2Exe/releases/latest/download/Ahk2Exe.zip
    （zip 内含 AutoHotkey v2 运行时，无需单独安装 AutoHotkey）
#>
[CmdletBinding()]
param(
    [string]$Ahk2Exe = "",
    [string]$Out = "",
    [string]$Icon = ""
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot          # scripts\ -> 仓库根目录
$in   = Join-Path $root "src\ProxyToggle.ahk"
if (-not (Test-Path $in)) { throw "未找到脚本: $in" }
if (-not $Out) { $Out = Join-Path $root "dist\ProxyToggle.exe" }

# ---------- 探测 Ahk2Exe.exe ----------
if (-not $Ahk2Exe) {
    $candidates = @()
    $cmd = Get-Command Ahk2Exe.exe -ErrorAction SilentlyContinue
    if ($cmd) { $candidates += $cmd.Source }
    $candidates += @(
        "C:\Program Files\AutoHotkey\Compiler\Ahk2Exe.exe",
        "C:\Program Files (x86)\AutoHotkey\Compiler\Ahk2Exe.exe",
        (Join-Path $env:LOCALAPPDATA "Programs\AutoHotkey\Compiler\Ahk2Exe.exe"),
        (Join-Path $env:USERPROFILE "scoop\apps\autohotkey\current\Compiler\Ahk2Exe.exe")
    )
    $Ahk2Exe = $candidates | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1
}
if (-not $Ahk2Exe -or -not (Test-Path $Ahk2Exe)) {
    throw @"
未找到 Ahk2Exe.exe。

请先下载 Ahk2Exe v2（zip 内含 AutoHotkey v2 运行时）:
  https://github.com/AutoHotkey/Ahk2Exe/releases/latest/download/Ahk2Exe.zip

解压后通过 -Ahk2Exe 参数指定路径，例如:
  .\scripts\build.ps1 -Ahk2Exe "D:\tools\Ahk2Exe\Ahk2Exe.exe"
"@
}

# ---------- 探测 base: AutoHotkey64.exe ----------
$base = Get-ChildItem (Split-Path $Ahk2Exe) -Recurse -Filter "AutoHotkey64.exe" -ErrorAction SilentlyContinue |
    Select-Object -First 1
if (-not $base) {
    $ahkDir = "C:\Program Files\AutoHotkey\v2"
    if (Test-Path (Join-Path $ahkDir "AutoHotkey64.exe")) {
        $base = Get-Item (Join-Path $ahkDir "AutoHotkey64.exe")
    }
}
if (-not $base) {
    throw "未找到 AutoHotkey64.exe（编译基础文件）。请安装 AutoHotkey v2 或使用包含它的 Ahk2Exe 目录。"
}

# ---------- 编译 ----------
New-Item -ItemType Directory -Force (Split-Path $Out) | Out-Null
$ahkArgs = @("/in", $in, "/out", $Out, "/base", $base.FullName, "/compress", "0", "/silent")
if ($Icon) {
    if (-not (Test-Path $Icon)) { throw "图标文件不存在: $Icon" }
    $ahkArgs += @("/icon", (Resolve-Path $Icon))
}

Write-Host "Ahk2Exe : $Ahk2Exe"
Write-Host "Base    : $($base.FullName)"
Write-Host "Compile : $in"
Write-Host "Output  : $Out"
# Ahk2Exe 是 GUI 程序：PowerShell 的 & 调用不会等待其退出，必须用 Start-Process -Wait
$p = Start-Process -FilePath $Ahk2Exe -ArgumentList $ahkArgs -Wait -PassThru -WindowStyle Hidden
if ($p.ExitCode -ne 0) { throw "编译失败，Ahk2Exe 退出码: $($p.ExitCode)" }
if (-not (Test-Path $Out)) { throw "编译产物不存在: $Out" }

$size = (Get-Item $Out).Length / 1KB
Write-Host ("`n编译成功: {0} ({1:N0} KB)" -f $Out, $size) -ForegroundColor Green
Write-Host "提示: 将 config.ini（如已生成）放到 exe 同目录即可使用相同配置。"
