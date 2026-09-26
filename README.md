# ChatGPT Desktop Startup Fix

一份来自 Windows 本地排障经历的 PowerShell 修复脚本和操作记录，针对特定的 `cua_node` runtime staging 不完整现象。

这不是 OpenAI 官方修复工具，也不是所有“ChatGPT 无窗口”问题的通用解决办法。说明中的原因分析是该次排障的推断；包名、目录布局及行为可能随应用版本变化。

## 文件

- `Fix-ChatGPTRuntime.ps1`：检测 staging、复制安装包内 runtime、校验并尝试重新启动应用。
- `修复ChatGPT启动.bat`：调用同目录 PowerShell 脚本。
- `chatgpt桌面应用启动失败解决.txt`：原始排障步骤与分析。

## 使用

1. 先阅读排障说明，并确认本机存在对应的 runtime 缺失现象。
2. 保存工作并关闭 ChatGPT；检查脚本中的路径和操作是否适用于当前安装版本。
3. 将两个脚本放在同一目录，双击 `修复ChatGPT启动.bat`。
4. 如需排查执行结果，查看同目录生成的 `ChatGPT启动修复.log`。

脚本会结束匹配的 ChatGPT 进程、向本地 runtime 目录复制文件，并永久删除匹配的 staging 目录。运行前应自行保存需要保留的数据。文件存在性检查不等同于完整 runtime 校验。

脚本依赖 Windows PowerShell、`Get-AppxPackage` 和 `xcopy`，并从本机已安装应用读取 runtime；本仓库不附带应用二进制、runtime 或第三方安装包。

## 隐私与发布范围

本仓库仅发布脚本和文字说明，不发布真实运行日志、崩溃转储、凭据或本机诊断导出。脚本通过环境变量和包查询获取安装路径，不包含作者的个人目录或账户凭据。

运行产生的日志可能记录用户名路径、安装目录和本机 runtime 标识，已通过 `.gitignore` 排除。若要在 issue 中分享日志，请先检查并脱敏；忽略规则不会替你清理手动粘贴的内容。

## 验证范围

发布前仅进行脚本静态语法检查和发布文件隐私检查，没有为了发布而执行修复脚本，也未验证它在其他机器或应用版本上的修复效果。
