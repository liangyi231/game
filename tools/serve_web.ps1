$ErrorActionPreference = 'Stop'
$root = Join-Path $PSScriptRoot '..\dist\web'
if (-not (Test-Path $root)) {
    Write-Output 'dist\web not found - export the Web preset first.'
    exit 1
}
$ip = (Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
    Where-Object { $_.IPAddress -notlike '127.*' -and $_.IPAddress -notlike '169.254.*' } |
    Select-Object -First 1).IPAddress
Write-Output 'Open in browser (PC):    http://localhost:8000'
if ($ip) { Write-Output ('Open on phone (same Wi-Fi): http://' + $ip + ':8000') }
Write-Output 'Press Ctrl+C to stop.'
Set-Location $root
python -m http.server 8000
