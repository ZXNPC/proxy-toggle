<div align="center">

# ProxyToggle 🔌

**一键切换 Windows 系统代理的小工具** — AutoHotkey v2 编写

按下快捷键即可开启/关闭系统代理，屏幕右下角常驻指示器实时显示状态。

</div>

## 特性

- ⚡ 快捷键一键开关系统代理（默认 `Ctrl+Alt+P`，可在设置中自定义）
- 🖥️ 屏幕右下角常驻指示器，显示"代理已打开"（黑底绿字、置顶、点击穿透）
- 🎨 图形化设置：代理地址、快捷键、提示开关、透明度、字号、窗口大小，**设置界面实时预览提示框样式**
- 🚀 开机启动开关（写入/删除注册表 Run 项）
- 🔄 切换后立即刷新系统代理设置（`InternetSetOption`），无需重启浏览器
- 📄 配置文件 `config.ini` 自动生成，也支持手动编辑
- 🧩 CLI 模式：`toggle` / `status` / `gui`
- 🏗️ 完整 CI：GitHub Actions 自动编译 `.exe` 并发布 Release

## 快速开始

### 方式一：直接使用 Release 版本（推荐）

1. 到 [Releases](../../releases) 下载最新的 `ProxyToggle-vX.Y.Z.exe`
2. 双击运行，按 `Ctrl+Alt+P` 即可切换代理
3. 托盘图标右键 → **设置...** 修改代理地址、快捷键、提示样式、开机启动
4. 首次运行会在 exe 同目录自动生成 `config.ini`

### 方式二：运行源码

1. 安装 [AutoHotkey v2](https://www.autohotkey.com/download/)
2. 双击 `src\ProxyToggle.ahk` 运行（或在命令行 `autohotkey64.exe src\ProxyToggle.ahk`）

> ⚠️ 提示：本工具**不是代理软件**，只负责开关 Windows 系统代理设置。
> 你需要先有可用的代理服务（如 Clash、v2ray 等），然后在设置中填入其监听地址（如 `127.0.0.1:7890`）。

## 使用说明

### 默认快捷键

| 操作 | 快捷键 |
|---|---|
| 切换代理 | `Ctrl+Alt+P` |
| 打开设置 | 托盘菜单 → 设置... |
| 查看状态 | 托盘图标 / 屏幕右下角指示器 |

### 设置界面

托盘图标右键 → **设置...**，可配置：

- **代理地址**：`host:port`（HTTP），或 `socks=host:port`（SOCKS）
- **快捷键**：点击"监听..."后按下新的组合键即可捕获
- **显示提示**：是否显示右下角状态指示器
- **提示透明度 / 字号 / 宽度 / 高度**：指示器外观（越界自动修正）
- **开机启动**：勾选后随系统启动

### CLI 模式

```bat
ProxyToggle.exe status   :: 输出当前状态 (ON/OFF)
ProxyToggle.exe toggle   :: 切换一次代理并退出
ProxyToggle.exe gui      :: 打开设置窗口
```

## 配置文件 config.ini

首次运行自动生成，位于脚本/exe 同目录。也可参考 [config.example.ini](config.example.ini) 手动创建：

```ini
[General]
ProxyAddr=192.168.31.110:7890   ; 代理地址（host:port 或 socks=host:port）
Hotkey=^!p                      ; 快捷键（^=Ctrl !=Alt +=Shift #=Win）

[Indicator]
Show=1                          ; 是否显示提示 (1/0)
Transparency=180                ; 透明度 0~255
FontSize=16                     ; 字号
Width=200                       ; 窗口宽度
Height=60                       ; 窗口高度

[Startup]
AutoStart=0                     ; 开机启动 (1/0)
```

> 修改配置文件后需重启脚本生效；用设置窗口修改则立即生效。

## 编译为 EXE

### 方式一：GitHub Actions（推荐）

1. 把本项目推送到你的 GitHub 仓库
2. 打标签触发自动构建并发布：

   ```bat
   git tag v1.0.0
   git push origin v1.0.0
   ```

3. Actions 完成（约 1-2 分钟）后，[Releases](../../releases) 页面自动生成 Release 并附带 `ProxyToggle-v1.0.0.exe`
4. 推送代码到 main 分支也会自动构建（Actions → Artifacts 可下载），PR 仅验证编译

### 方式二：本地编译

1. 下载 [Ahk2Exe v2](https://github.com/AutoHotkey/Ahk2Exe/releases/latest/download/Ahk2Exe.zip) 并解压（zip 内含 AutoHotkey v2 运行时）
2. 运行：

   ```powershell
   .\scripts\build.ps1 -Ahk2Exe "D:\tools\Ahk2Exe\Ahk2Exe.exe"
   ```

3. 产物输出到 `dist\ProxyToggle.exe`（可选 `-Out` / `-Icon` 参数，详见脚本注释）

> 编译参数说明：`/compress 0` 不压缩二进制，减少杀毒软件误报。

## 常见问题（FAQ）

**Q: 快捷键不生效？**
A: 可能与其他软件冲突或格式无效。打开设置 → 重新设置快捷键，或检查托盘提示。
也可直接编辑 `config.ini` 的 `Hotkey` 字段（语法：`^`=Ctrl `!`=Alt `+`=Shift `#`=Win）。

**Q: 切换后浏览器/软件没有走代理？**
A: 本工具切换的是 Windows 系统代理。个别软件需重启或重新加载才读取新设置；
脚本已调用 `InternetSetOption` 刷新，多数场景即时生效。

**Q: 为什么显示"代理已打开"但实际没生效？**
A: 请确认设置中的代理地址对应的代理软件正在运行且端口正确。

**Q: 杀毒软件/Windows SmartScreen 报毒？**
A: AutoHotkey 编译的 exe 未做代码签名，部分杀软会误报。编译时已使用 `/compress 0`（不压缩）降低误报率；
如仍误报，请添加信任，或自行用源码运行/编译。正式签名（代码签名证书）不在本项目范围内。

**Q: 配置文件用记事本保存后代理地址不生效了？**
A: 某些旧版记事本会把文件保存为"UTF-8 带 BOM"，会导致脚本读不到第一个小节。
脚本已内置自动修复：检测到 BOM 会自动重写为正常格式（内容与注释保留）。

**Q: 想用自定义图标？**
A: 把图标命名为 `assets\app.ico` 放入仓库，CI 和本地 build.ps1 会自动使用它编译。

**Q: 开机启动后提示"找不到脚本"？**
A: 源码模式下开机启动会调用 AHK 解释器 + 完整脚本路径（已做引号处理），
请勿移动脚本位置；推荐直接使用编译版 exe。

## 开发

```
proxy-toggle/
├── .github/workflows/build.yml   # CI: 编译 + Release
├── src/ProxyToggle.ahk           # 主脚本（全部逻辑）
├── scripts/build.ps1             # 本地编译脚本
├── config.example.ini            # 配置示例
└── assets/                       # 可选 app.ico
```

测试小贴士：CLI 模式便于自动化验证

```bat
autohotkey64.exe src\ProxyToggle.ahk status
autohotkey64.exe src\ProxyToggle.ahk toggle
```

## 致谢

- [AutoHotkey v2](https://www.autohotkey.com/) / [Ahk2Exe](https://github.com/AutoHotkey/Ahk2Exe)

## License

[MIT](LICENSE)
