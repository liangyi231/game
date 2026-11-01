param(
    [string]$Message = ""
)

# 每轮迭代结束后调用：把当前改动全部暂存并提交。
# 用法：pwsh -File tools/git-auto-commit.ps1 "feat: 本轮做了什么"
#       pwsh -File tools/git-auto-commit.ps1        （自动生成时间戳信息）

$ErrorActionPreference = "Stop"
Set-Location (Split-Path $PSScriptRoot -Parent)

$status = git status --porcelain
if (-not $status) {
    Write-Output "没有未提交的改动，跳过。"
    exit 0
}

git add -A
if ([string]::IsNullOrWhiteSpace($Message)) {
    $stamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $Message = "chore: 自动提交 $stamp"
}

git commit -q -m $Message
$hash = git rev-parse --short HEAD
$files = (git ls-files --modified --others --exclude-standard | Measure-Object).Count
Write-Output "已提交 $hash —— $Message"
