# ZeroExplorer Web Bootstrapper & Auto-Updater
try { Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force -ErrorAction SilentlyContinue } catch {}
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls11 -bor [Net.SecurityProtocolType]::Tls

$localDir = Join-Path $env:LOCALAPPDATA "ZeroExplorer"
$localScript = Join-Path $localDir "ZeroExplore.ps1"
$localBat = Join-Path $localDir "ZeroExplore.bat"
$localVbs = Join-Path $localDir "ZeroExplore.vbs"
$localAssetsDir = Join-Path $localDir "assets"

if (-not (Test-Path $localDir)) {
    New-Item -ItemType Directory -Path $localDir -Force | Out-Null
}
if (-not (Test-Path $localAssetsDir)) {
    New-Item -ItemType Directory -Path $localAssetsDir -Force | Out-Null
}

$ts = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
$downloadUrl = "https://raw.githubusercontent.com/ZeroIQs/ZeroExplorer/main/ZeroExplore.ps1?nocache=$ts"
$scriptText = $null

$isOnline = $false
try {
    $isOnline = [System.Net.NetworkInformation.NetworkInterface]::GetIsNetworkAvailable()
} catch {}

if ($isOnline) {
    try {
        $wc = New-Object System.Net.WebClient
        $wc.Headers.Add('User-Agent', 'ZeroExplorer-Launcher')
        $wc.Headers.Add('Cache-Control', 'no-cache, no-store, must-revalidate')
        $wc.Headers.Add('Pragma', 'no-cache')

        try {
            $commit = Invoke-RestMethod -Uri "https://api.github.com/repos/ZeroIQs/ZeroExplorer/commits/main?t=$ts" -Headers @{ "Cache-Control" = "no-cache"; "User-Agent" = "ZeroExplorer" } -TimeoutSec 3
            if ($commit -and $commit.sha) {
                $downloadUrl = "https://raw.githubusercontent.com/ZeroIQs/ZeroExplorer/$($commit.sha)/ZeroExplore.ps1"
            }
        } catch {}

        $b = $wc.DownloadData($downloadUrl)
        $scriptText = [System.Text.Encoding]::UTF8.GetString($b).TrimStart([char]0xFEFF)

        # Cache locally with UTF-8 BOM so offline startup works forever
        [System.IO.File]::WriteAllText($localScript, $scriptText, [System.Text.Encoding]::UTF8)

        $batContent = "@echo off`r`nstart `"`" powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -STA -File `"%~dp0ZeroExplore.ps1`"`r`nexit"
        [System.IO.File]::WriteAllText($localBat, $batContent, [System.Text.Encoding]::ASCII)

        $vbsContent = "Set WshShell = CreateObject(`"WScript.Shell`")`r`nSet fso = CreateObject(`"Scripting.FileSystemObject`")`r`ncurrentDir = fso.GetParentFolderName(WScript.ScriptFullName)`r`nps1Path = currentDir & `"\ZeroExplore.ps1`"`r`nWshShell.CurrentDirectory = currentDir`r`nWshShell.Run `"powershell.exe -WindowStyle Hidden -NoProfile -ExecutionPolicy Bypass -STA -File `"`"`" & ps1Path & `"`"`"`, 0, False"
        [System.IO.File]::WriteAllText($localVbs, $vbsContent, [System.Text.Encoding]::ASCII)

        try {
            $icoUrl = "https://raw.githubusercontent.com/ZeroIQs/ZeroExplorer/main/assets/app_logo.ico"
            $localIco = Join-Path $localAssetsDir "app_logo.ico"
            if (-not (Test-Path $localIco)) {
                $wc.DownloadFile($icoUrl, $localIco)
            }
        } catch {}
    } catch {}
}

# If offline or GitHub request failed, run the cached local copy
if (-not $scriptText -and (Test-Path $localScript)) {
    $scriptText = [System.IO.File]::ReadAllText($localScript, [System.Text.Encoding]::UTF8)
}

if ($scriptText) {
    try { Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force -ErrorAction SilentlyContinue } catch {}
    if (Test-Path $localScript) {
        try {
            & "$localScript"
        } catch {
            Invoke-Expression $scriptText
        }
    } else {
        Invoke-Expression $scriptText
    }
} else {
    Write-Host "ZeroExplorer: Unable to connect to GitHub and no local copy found. Please check your internet connection for the first run." -ForegroundColor Red
}
