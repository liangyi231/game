$ErrorActionPreference = 'Stop'
# 前提：网页版本地服务已经在 8080 端口运行（tools\打开网页版.bat 或 serve_web.ps1）
$root = Join-Path $PSScriptRoot '..\dist\web'
if (-not (Test-Path $root)) { Write-Output 'dist\web not found'; exit 1 }
try {
    $r = Invoke-WebRequest -Uri 'http://127.0.0.1:8080/index.html' -Method Head -TimeoutSec 5 -UseBasicParsing
    Write-Output ('local server OK: ' + $r.StatusCode)
} catch {
    Write-Output 'local server not running on 8080. Start it first: tools\打开网页版.bat'
    exit 1
}
Write-Output 'Opening public tunnel via localhost.run (no account needed)...'
Write-Output 'Look for a line like: https://xxxx.lhr.life tunneled with tls termination'
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=NUL -o ExitOnForwardFailure=yes -R 80:localhost:8080 nokey@localhost.run
