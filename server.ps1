param([int]$Port = 8777, [switch]$NoBrowser)
# 血夜：吸血鬼之影 - 本機遊戲伺服器（不需安裝任何套件）
$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath((Split-Path -Parent $MyInvocation.MyCommand.Path)).TrimEnd('\') + '\'

function Test-Port([int]$p) {
    try { $l = [System.Net.Sockets.TcpListener]::new([Net.IPAddress]::Any, $p); $l.Start(); $l.Stop(); return $true } catch { return $false }
}
while (-not (Test-Port $Port)) { $Port++ }

$ips = @()
try {
    $ips = [System.Net.NetworkInformation.NetworkInterface]::GetAllNetworkInterfaces() |
        Where-Object { $_.OperationalStatus -eq 'Up' -and $_.NetworkInterfaceType -ne 'Loopback' } |
        ForEach-Object { $_.GetIPProperties().UnicastAddresses } |
        Where-Object { $_.Address.AddressFamily -eq 'InterNetwork' -and -not $_.Address.ToString().StartsWith('169.254') } |
        ForEach-Object { $_.Address.ToString() }
} catch {}
$urls = @($ips | ForEach-Object { "http://${_}:$Port/" })

$listener = [System.Net.Sockets.TcpListener]::new([Net.IPAddress]::Any, $Port)
$listener.Start()

Write-Host ''
Write-Host '  ========================================' -ForegroundColor DarkRed
Write-Host '     血夜：吸血鬼之影  伺服器已啟動' -ForegroundColor Red
Write-Host '  ========================================' -ForegroundColor DarkRed
Write-Host ''
Write-Host "  電腦遊玩： http://localhost:$Port/" -ForegroundColor Yellow
if ($urls.Count) {
    Write-Host '  手機遊玩（需連同一個 Wi-Fi）：' -ForegroundColor Cyan
    $urls | ForEach-Object { Write-Host "     $_" -ForegroundColor Cyan }
    Write-Host '  （若 Windows 防火牆詢問，請允許「私人網路」）' -ForegroundColor DarkGray
}
Write-Host ''
Write-Host '  關閉此視窗即可結束伺服器' -ForegroundColor DarkGray
Write-Host ''

if (-not $NoBrowser) { Start-Process "http://localhost:$Port/" }

$mime = @{ '.html'='text/html; charset=utf-8'; '.js'='application/javascript; charset=utf-8'; '.css'='text/css; charset=utf-8';
           '.json'='application/json; charset=utf-8'; '.png'='image/png'; '.jpg'='image/jpeg'; '.svg'='image/svg+xml';
           '.ico'='image/x-icon'; '.mp3'='audio/mpeg'; '.ogg'='audio/ogg'; '.wav'='audio/wav' }
$lanJson = [Text.Encoding]::UTF8.GetBytes((@{ port = $Port; urls = $urls } | ConvertTo-Json -Compress))

function Send([System.Net.Sockets.NetworkStream]$s, [string]$status, [string]$type, [byte[]]$body) {
    $head = "HTTP/1.1 $status`r`nContent-Type: $type`r`nContent-Length: $($body.Length)`r`nCache-Control: no-cache`r`nConnection: close`r`n`r`n"
    $hb = [Text.Encoding]::ASCII.GetBytes($head)
    $s.Write($hb, 0, $hb.Length); if ($body.Length) { $s.Write($body, 0, $body.Length) }; $s.Flush()
}

try {
    while ($true) {
        $client = $listener.AcceptTcpClient()
        try {
            $stream = $client.GetStream(); $stream.ReadTimeout = 3000
            $reader = New-Object IO.StreamReader($stream, [Text.Encoding]::ASCII)
            $line = $reader.ReadLine()
            while ($true) { $h = $reader.ReadLine(); if ($null -eq $h -or $h -eq '') { break } }
            if (-not $line) { continue }
            $path = '/'
            if ($line -match '^\w+\s+(\S+)') { $path = $Matches[1] }
            $path = [Uri]::UnescapeDataString(($path -split '\?')[0])
            if ($path -eq '/') { $path = '/index.html' }
            if ($path -eq '/lan.json') { Send $stream '200 OK' $mime['.json'] $lanJson; continue }
            $full = [IO.Path]::GetFullPath((Join-Path $root ($path.TrimStart('/').Replace('/', '\'))))
            if ($full.StartsWith($root, [StringComparison]::OrdinalIgnoreCase) -and (Test-Path -LiteralPath $full -PathType Leaf)) {
                $ext = [IO.Path]::GetExtension($full).ToLower()
                $type = if ($mime.ContainsKey($ext)) { $mime[$ext] } else { 'application/octet-stream' }
                Send $stream '200 OK' $type ([IO.File]::ReadAllBytes($full))
            } else {
                Send $stream '404 Not Found' 'text/plain; charset=utf-8' ([Text.Encoding]::UTF8.GetBytes('404'))
            }
        } catch {
        } finally { $client.Close() }
    }
} finally { $listener.Stop() }
