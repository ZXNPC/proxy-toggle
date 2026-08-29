# Changelog

本项目所有重要变更都会记录在此文件中。

格式基于 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/)，
版本号遵循 [语义化版本](https://semver.org/lang/zh-CN/)。

## [1.0.0] - 2025-06

### 新增
- 一键切换 Windows 系统代理（注册表 `Internet Settings\ProxyEnable`），默认快捷键 `Ctrl+Alt+P`
- 屏幕右下角常驻状态指示器（黑底绿字，透明度/字号可调，尺寸随字号自动计算）
- 图形化设置窗口（托盘菜单或 `gui` 参数打开）：代理地址、快捷键（监听式捕获，界面显示可读形式如 Ctrl+Alt+P）、提示开关、透明度/字号滑块、开机启动
- 设置界面内实时预览提示框样式（随滑块即时刷新）
- 一键还原默认设置（代理 `127.0.0.1:7890`、快捷键 `Ctrl+Alt+P`、透明度 180、字号 16）
- 开机启动开关：写入/删除 `HKCU\...\Run` 注册表项（支持编译版 exe 与源码运行两种模式）
- CLI 模式：`toggle`（切换一次）、`status`（输出状态）、`gui`（打开设置）
- 切换后调用 `InternetSetOption` 刷新系统代理设置，立即生效
- 首次运行自动生成 `config.ini` 默认配置；兼容"UTF-8 带 BOM"的配置文件自动规范化
- 本地一键编译脚本 `scripts/build.ps1`
- GitHub Actions 工作流：自动编译 .exe、上传 artifact、打 tag 自动发布 Release
