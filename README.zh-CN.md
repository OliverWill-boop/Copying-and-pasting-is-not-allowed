# 禁止复制粘贴（Auto Input Helper）

中文 | [English](./README.md)

![Windows](https://img.shields.io/badge/platform-Windows-0078D6?style=for-the-badge)
![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?style=for-the-badge)
![Release Bundle](https://img.shields.io/badge/release-included-2EA043?style=for-the-badge)

本仓库包含 **Auto Input Helper**，一个轻量级的 Windows 自动输入工具，可以在倒计时结束后，把文本逐字发送到当前焦点输入框。

它适合这些场景：

- 某些输入框不允许直接粘贴（禁用复制粘贴）
- 先准备好文本，再把光标切到目标位置后自动输入
- 想给别人分享一个简单直接、不需要解释太多的小工具

## 功能亮点

- 简单直观的图形界面流程：输入文本，点击 `Start`，等待倒计时后自动输入
- 支持调整倒计时时间和输入速度
- 自动保存本地设置
- 内置日志，方便定位异常
- 仓库内直接附带可分发的 `.exe`
- 同时保留源码和打包脚本，便于二次修改

## 工作流程

1. 启动程序。
2. 输入或粘贴要发送的文本。
3. 点击 `Start`。
4. 在倒计时结束前，把光标移动到目标输入框。
5. 程序会把文本逐字发送到当前焦点控件。

## 项目结构

```text
.
|-- auto_input_gui_fixed.ps1   # 图形界面主脚本
|-- auto_input_cli.ps1         # 命令行版本
|-- build_exe_clean.ps1        # 打包 EXE 的脚本
|-- release/
|   |-- AutoInputHelper.exe    # 可直接分发的成品
|   `-- release_readme.txt
|-- README.md
`-- README.zh-CN.md
```

## 快速开始

### 方式一：直接运行打包好的 EXE

打开：

`release/AutoInputHelper.exe`

### 方式二：从源码运行

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -STA -File .\auto_input_gui_fixed.ps1
```

## 如何重新打包 EXE

如果您想重新构建独立可执行文件：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\build_exe_clean.ps1
```

输出文件为：

`AutoInputHelper.exe`

## 日志与排错

图形界面版本运行时，会在程序同目录生成日志：

- `auto_input_gui.log`

它主要用于定位这些问题：

- 启动失败
- 焦点检测异常
- 运行时错误

## 注意事项

- 当前工具主要面向 Windows 环境。
- 不同应用对键盘消息的处理方式不同，兼容性可能略有差异。
- 第一次运行打包后的 `.exe` 时，某些安全软件可能会先扫描一下，这是比较常见的情况。

## 发布成品

仓库中已经附带可直接分享的发布目录：

[`release/`](./release)

## 后续可扩展方向

- 支持全局热键取消输入
- 进一步增强对更多应用的兼容性
- 增加目标应用预设
- 增加托盘模式或迷你模式

## License

本项目采用 MIT License，详见 `LICENSE`。
