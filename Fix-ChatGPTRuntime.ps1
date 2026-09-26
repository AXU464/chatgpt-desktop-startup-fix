# ============================================================
# ChatGPT 启动修复脚本
#
# 检测: ChatGPT 更新后 cua_node runtime 部署失败
#       (.staging-* 目录不完整, 缺少 bin\node_repl.exe)
# 修复: 结束无窗口的僵尸进程 -> 用 xcopy /G 从安装包完整复制
#       runtime -> 校验 -> 清理 staging -> 重新启动 ChatGPT
#
# 用法: 双击同目录下的 修复ChatGPT启动.bat
# 日志: 同目录 ChatGPT启动修复.log
# ============================================================

$scriptDir   = Split-Path -Parent $MyInvocation.MyCommand.Definition
$logFile     = Join-Path $scriptDir 'ChatGPT启动修复.log'
$runtimeRoot = Join-Path $env:LOCALAPPDATA 'OpenAI\Codex\runtimes\cua_node'

function Write-Log {
    param([string]$Msg)
    $line = '{0}  {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Msg
    Add-Content -Path $logFile -Value $line -Encoding UTF8
    Write-Host $line
}

Write-Host ''
Write-Host '==========================================' -ForegroundColor Cyan
Write-Host '   ChatGPT 启动修复脚本' -ForegroundColor Cyan
Write-Host '==========================================' -ForegroundColor Cyan

# ---------------- 第一步: 检测 ----------------
Write-Log '[检测] 开始检测'

if (-not (Test-Path $runtimeRoot)) {
    Write-Log '[检测] 未找到 runtime 目录, 视为无问题'
    Write-Host ''
    Write-Host '>>> 当前不存在目标问题' -ForegroundColor Green
    exit 0
}

$staging = Get-ChildItem $runtimeRoot -Directory -Force -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -like '.staging-*' } |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1

if (-not $staging) {
    Write-Log '[检测] 未发现 .staging-* 目录'
    Write-Host ''
    Write-Host '>>> 当前不存在目标问题' -ForegroundColor Green
    exit 0
}

Write-Log ('[检测] 发现 staging 目录: ' + $staging.Name)

$stagingComplete = Test-Path (Join-Path $staging.FullName 'bin\node_repl.exe')

$hasValidRuntime = @(Get-ChildItem $runtimeRoot -Directory -Force -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -notlike '.staging-*' -and (Test-Path (Join-Path $_.FullName 'bin\node_repl.exe')) }).Count -gt 0

$procs     = Get-Process ChatGPT -ErrorAction SilentlyContinue
$procCount = @($procs).Count
$hasWindow = @($procs | Where-Object { $_.MainWindowHandle -ne 0 }).Count -gt 0

Write-Log ('[检测] staging 完整: ' + $stagingComplete + '；已有可用 runtime: ' + $hasValidRuntime + '；ChatGPT 进程数: ' + $procCount + '；有窗口: ' + $hasWindow)

# 情形1: staging 完整且已有可用 runtime -> 只是残留, 清理即可
if ($stagingComplete -and $hasValidRuntime) {
    Get-ChildItem $runtimeRoot -Directory -Force -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -like '.staging-*' } |
        Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
    Write-Log '[清理] 已删除残留的 staging 目录'
    Write-Host ''
    Write-Host '>>> 当前不存在目标问题（已顺手清理残留的 staging 目录）' -ForegroundColor Green
    exit 0
}

# 情形2: 应用当前运行正常(有窗口) -> 不动进程, 只清理残留
if ($hasWindow) {
    Get-ChildItem $runtimeRoot -Directory -Force -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -like '.staging-*' } |
        Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
    Write-Log '[清理] 应用正在正常运行, 已删除残留的 staging 目录'
    Write-Host ''
    Write-Host '>>> 当前不存在目标问题（应用当前运行正常，已顺手清理残留）' -ForegroundColor Green
    exit 0
}

# 情形3: 确认目标问题 -> 执行修复
Write-Host ''
Write-Log '[修复] 确认目标问题: staging 不完整, 开始修复'

# 3.1 结束无窗口的 ChatGPT 僵尸进程
if ($procCount -gt 0) {
    $procs | Stop-Process -Force -ErrorAction SilentlyContinue
    Write-Log ('[修复] 已结束 ' + $procCount + ' 个 ChatGPT 进程')
    Start-Sleep -Seconds 2
} else {
    Write-Log '[修复] 当前没有运行中的 ChatGPT 进程'
}

# 3.2 定位安装包内的 runtime 源目录
$pkg = Get-AppxPackage -Name OpenAI.Codex
if (-not $pkg) {
    Write-Log '[修复] 失败: 找不到 OpenAI.Codex 安装包'
    Write-Host '>>> 修复未成功：找不到 ChatGPT 安装包，请查看日志' -ForegroundColor Red
    exit 1
}
$src = Join-Path $pkg.InstallLocation 'app\resources\cua_node'
if (-not (Test-Path (Join-Path $src 'bin\node_repl.exe'))) {
    Write-Log ('[修复] 失败: 安装包内源目录不存在或不完整: ' + $src)
    Write-Host '>>> 修复未成功：安装包内未找到 cua_node 源文件，请查看日志' -ForegroundColor Red
    exit 1
}

# 3.3 从 staging 名字推导目标 runtime ID, 复制完整 runtime
$runtimeId = ($staging.Name -replace '^\.staging-','') -replace '-[^-]+$',''
$dst = Join-Path $runtimeRoot $runtimeId
New-Item -ItemType Directory -Path $dst -Force | Out-Null
Write-Log ('[修复] 源目录: ' + $src)
Write-Log ('[修复] 目标目录: ' + $dst)

Write-Log '[修复] 正在用 xcopy /G 完整复制 runtime（约需 1 分钟）...'
# 注: xcopy 会跳过一个路径超过 260 字符的 pnpm 缓存文件(tslib.es6.js),
#     已验证该文件缺失不影响运行(当前正常工作的部署中同样缺失),
#     因此复制结果以 node_repl.exe 校验为准, 文件总数仅供日志参考。
& cmd.exe /c "xcopy `"$src\*`" `"$dst\`" /E /H /I /Y /G /Q /C" | Out-Null
Write-Log ('[修复] xcopy 退出码: ' + $LASTEXITCODE)

# 3.4 校验复制结果
$okRepl = Test-Path (Join-Path $dst 'bin\node_repl.exe')
$okExe  = Test-Path (Join-Path $dst 'bin\node.exe')
$count  = (Get-ChildItem $dst -Recurse -File -Force -ErrorAction SilentlyContinue).Count
Write-Log ('[校验] node_repl.exe: ' + $okRepl + '；node.exe: ' + $okExe + '；文件总数: ' + $count)

if (-not $okRepl) {
    Write-Log '[修复] 校验失败: node_repl.exe 仍缺失, 已保留 staging 目录以便重试'
    Write-Host '>>> 修复未成功：复制校验失败，请查看日志' -ForegroundColor Red
    exit 1
}

# 3.5 清理所有 staging 目录
Get-ChildItem $runtimeRoot -Directory -Force -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -like '.staging-*' } |
    Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
Write-Log '[清理] 已删除所有 staging 目录'

# 3.6 重新启动 ChatGPT
Start-Sleep -Seconds 1
$launched = $false
try {
    Start-Process ("shell:AppsFolder\{0}!App" -f $pkg.PackageFamilyName)
    $launched = $true
} catch {
    Write-Log ('[修复] 启动应用失败: ' + $_.Exception.Message)
}
Write-Log ('[修复] 已重新启动 ChatGPT: ' + $launched)

Write-Host ''
Write-Host '>>> 已完成修复' -ForegroundColor Green
Write-Host ('    日志文件: ' + $logFile)
exit 0
