$ErrorActionPreference = 'Continue'
Set-Location (Join-Path $PSScriptRoot '..')
$repo = 'https://github.com/liangyi231/game'

Write-Output '=============================================='
Write-Output '  Push 大肥鱼传说 to GitHub'
Write-Output '  A Git Credential Manager window may open.'
Write-Output '  Sign in with your browser once, then it pushes.'
Write-Output '=============================================='
Write-Output ''

$branch = (git rev-parse --abbrev-ref HEAD).Trim()
$ahead = (git rev-list --count "origin/$branch..$branch").Trim()
Write-Output ("Current branch: " + $branch + "  commits to push: " + $ahead)
Write-Output ''

git push origin $branch
$code = $LASTEXITCODE

if ($code -eq 0) {
    Write-Output ''
    Write-Output 'Push OK.'
    Write-Output ('Repo: ' + $repo)
    Start-Process $repo
} else {
    Write-Output ''
    Write-Output ("Push failed (exit " + $code + ").")
    Write-Output 'Try one of these:'
    Write-Output '  1) Run this script again and finish the sign-in in the popup window.'
    Write-Output '  2) Use GitHub Desktop: Add existing repository -> Push origin.'
    Write-Output '  3) Install GitHub CLI, then: gh auth login ; gh auth setup-git ; git push origin main'
    Write-Output ''
    Write-Output 'Note: a Personal Access Token also works, but keep it private'
    Write-Output '(do not paste it in chats / commit it into files).'
}
Write-Output ''
Read-Host 'Press Enter to close'
