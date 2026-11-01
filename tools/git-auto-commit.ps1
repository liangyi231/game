param(
    [string]$Message = ""
)

# Auto-commit at the end of each iteration.
# Usage: powershell -NoProfile -ExecutionPolicy Bypass -File tools/git-auto-commit.ps1 "feat: summary"
#        powershell -NoProfile -ExecutionPolicy Bypass -File tools/git-auto-commit.ps1   (timestamp message)
#
# Note: messages are ASCII on purpose. This machine only has Windows PowerShell 5.1,
# which decodes BOM-less UTF-8 scripts as ANSI; keep the script body ASCII-safe.
# Chinese commit messages still work when passed from the command line.

$ErrorActionPreference = "Stop"
Set-Location (Split-Path $PSScriptRoot -Parent)

$status = git status --porcelain
if (-not $status) {
    Write-Output "No changes to commit."
    exit 0
}

git add -A
if ([string]::IsNullOrWhiteSpace($Message)) {
    $stamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $Message = "chore: auto commit $stamp"
}

git commit -q -m $Message
$hash = git rev-parse --short HEAD
Write-Output ("Committed " + $hash + " - " + $Message)
