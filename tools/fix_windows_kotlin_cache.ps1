# Windows workaround for Kotlin "this and base files have different roots"
# when Flutter project lives on D: but PUB_CACHE lives on C:.
# Run from any working directory. Changes only the local Android Gradle
# configuration (plus disposable build caches); does not edit Laravel code.
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$android = Join-Path $root 'android'
$props = Join-Path $android 'gradle.properties'
$wrapper = Join-Path $android 'gradlew.bat'

if (-not (Test-Path -LiteralPath $props)) {
  throw "Android Gradle properties file missing: $props"
}
if (-not (Test-Path -LiteralPath $wrapper)) {
  throw "Gradle wrapper missing: $wrapper"
}

$previous = Get-Content -LiteralPath $props -Raw
$pattern = '(?m)^[ \t]*kotlin\.incremental[ \t]*=[ \t]*[^\r\n]*'
if ([regex]::IsMatch($previous, $pattern)) {
  $updated = [regex]::Replace($previous, $pattern, 'kotlin.incremental=false')
} else {
  $updated = $previous.TrimEnd() + [Environment]::NewLine +
    'kotlin.incremental=false' + [Environment]::NewLine
}
if ($updated -ne $previous) {
  Copy-Item -LiteralPath $props -Destination "$props.bak" -Force
  Set-Content -LiteralPath $props -Value $updated -Encoding utf8 -NoNewline
  Write-Host 'Configured kotlin.incremental=false in android/gradle.properties'
  Write-Host 'Original saved as android/gradle.properties.bak'
} else {
  Write-Host 'Kotlin incremental compilation is already disabled.'
}

Push-Location $android
try {
  & $wrapper --stop
} finally {
  Pop-Location
}

Push-Location $root
try {
  & flutter clean
  if ($LASTEXITCODE -ne 0) { throw "flutter clean failed" }
  & flutter pub get
  if ($LASTEXITCODE -ne 0) { throw "flutter pub get failed" }
} finally {
  Pop-Location
}
Write-Host ''
Write-Host 'Kotlin cross-drive cache workaround applied. Run flutter build apk --debug next.'
