# CHAIGIDA Capture10 — use existing H:\BRON_BUILD; no Android Studio or GitHub UI required.
$ErrorActionPreference = 'Stop'
$base = 'H:\BRON_BUILD'
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$srcSha = 'd70056db1b25f0307ab72b21b9572052ed9cc4a5'
$jdk = Join-Path $base 'jdk'
$sdk = Join-Path $base 'android-sdk'
$workspace = Join-Path $base 'projects\CHAIGIDA_CAPTURE10'
$cache = Join-Path $base 'gradle-cache'
$tmp = Join-Path $base 'temp\capture10'
$out = Join-Path $base 'output'
$zip = Join-Path $workspace ('AutoScreenshot-' + $srcSha + '.zip')
$dest = Join-Path $out 'CHAIGIDA_CAPTURE10_DEBUG.apk'

if (-not (Test-Path -LiteralPath $base)) { throw 'H:\BRON_BUILD not found. Check the H: drive.' }
if (-not (Test-Path -LiteralPath (Join-Path $jdk 'bin\java.exe'))) { throw 'H:\BRON_BUILD\jdk\bin\java.exe missing' }
if (-not (Test-Path -LiteralPath (Join-Path $sdk 'platforms\android-35'))) { throw 'Android SDK 35 is not present in H:\BRON_BUILD\android-sdk\platforms.' }

New-Item -ItemType Directory -Force -Path $workspace,$cache,$tmp,$out | Out-Null
$env:JAVA_HOME = $jdk
$env:ANDROID_HOME = $sdk
$env:ANDROID_SDK_ROOT = $sdk
$env:GRADLE_USER_HOME = $cache
$env:ANDROID_USER_HOME = Join-Path $base 'android-user-home'
$env:TEMP = $tmp
$env:TMP = $tmp
$env:JAVA_TOOL_OPTIONS = "-Djava.io.tmpdir=$tmp"
$env:GRADLE_OPTS = "-Djava.io.tmpdir=$tmp"
$env:PATH = (Join-Path $jdk 'bin') + ';' + $env:PATH

# Original public source is downloaded into the test folder only; never edit BR:ON.
$repoFolder = Join-Path $workspace ('Android-AutoScreenshot-' + $srcSha)
if (-not (Test-Path -LiteralPath (Join-Path $repoFolder 'gradlew.bat'))) {
    $url = 'https://codeload.github.com/SimonBaars/Android-AutoScreenshot/zip/' + $srcSha
    Write-Host 'Downloading pinned upstream source...' -ForegroundColor Cyan
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest -UseBasicParsing -Uri $url -OutFile $zip
    Expand-Archive -LiteralPath $zip -DestinationPath $workspace -Force
}
if (-not (Test-Path -LiteralPath (Join-Path $repoFolder 'gradlew.bat'))) {
    $repoFolder = (Get-ChildItem -Path $workspace -Directory | Where-Object {
        $_.Name -like 'Android-AutoScreenshot-*' -and
        (Test-Path -LiteralPath (Join-Path $_.FullName 'gradlew.bat'))
    } | Select-Object -First 1).FullName
}
if (-not $repoFolder -or -not (Test-Path -LiteralPath (Join-Path $repoFolder 'gradlew.bat'))) {
    throw 'Downloaded project does not contain gradlew.bat'
}

Write-Host 'Patching the original Android project...' -ForegroundColor Cyan
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $scriptDir 'PATCH_SOURCE.ps1') -Root $repoFolder
if ($LASTEXITCODE -ne 0) { throw "Source patch failed ($LASTEXITCODE)" }

# Gradle writes its distribution, caches, build and temporary files on H:.
Push-Location $repoFolder
try {
    Write-Host 'Compiling Android APK (debug)...' -ForegroundColor Cyan
    & (Join-Path $repoFolder 'gradlew.bat') --no-daemon --stacktrace ':app:assembleDebug'
    if ($LASTEXITCODE -ne 0) { throw "Gradle build failed ($LASTEXITCODE)" }
} finally {
    Pop-Location
}
$apk = Join-Path $repoFolder 'app\build\outputs\apk\debug\app-debug.apk'
if (-not (Test-Path -LiteralPath $apk)) { throw 'Gradle reported success but APK is missing.' }
Copy-Item -LiteralPath $apk -Destination $dest -Force
$result = Get-Item -LiteralPath $dest
if ($result.Length -lt 100000) { throw 'APK is suspiciously small.' }
Write-Host ('SUCCESS: ' + $result.FullName) -ForegroundColor Green
Write-Host ('Size: ' + $result.Length + ' bytes')
Write-Host ('SHA-256: ' + (Get-FileHash -Algorithm SHA256 -LiteralPath $dest).Hash)
Write-Host 'Transfer this APK to the Galaxy S24 Ultra to test the ten-page capture.'
