# Run from the root of BlueMarketingEmployeeApp after flutter pub add local_auth.
$ErrorActionPreference = 'Stop'
$root = (Get-Location).Path
$activity = Join-Path $root 'android\app\src\main\kotlin\com\bluemarketing\bluemarketing_employee\MainActivity.kt'
$manifest = Join-Path $root 'android\app\src\main\AndroidManifest.xml'
if (-not (Test-Path $activity)) { throw "MainActivity not found: $activity" }
if (-not (Test-Path $manifest)) { throw "AndroidManifest not found: $manifest" }

$source = Get-Content $activity -Raw
$source = $source.Replace('import io.flutter.embedding.android.FlutterActivity', 'import io.flutter.embedding.android.FlutterFragmentActivity')
$source = $source.Replace('class MainActivity : FlutterActivity()', 'class MainActivity : FlutterFragmentActivity()')
$source = $source.Replace('class MainActivity: FlutterActivity()', 'class MainActivity: FlutterFragmentActivity()')
if (-not $source.Contains('FlutterFragmentActivity()')) { throw 'Inspect MainActivity.kt manually before proceeding.' }

$xml = Get-Content $manifest -Raw
if ($xml -notmatch '<manifest\b') { throw 'Invalid AndroidManifest.xml' }
$quote = [char]34
if ($xml -notmatch 'android.permission.USE_BIOMETRIC') {
  $permission = [Environment]::NewLine + '    <uses-permission android:name=' + $quote + 'android.permission.USE_BIOMETRIC' + $quote + ' />'
  $xml = ([regex]'(<manifest\b[^>]*>)').Replace($xml, ('$1' + $permission), 1)
}
if ($xml -notmatch 'android.permission.INTERNET') {
  $permission = [Environment]::NewLine + '    <uses-permission android:name=' + $quote + 'android.permission.INTERNET' + $quote + ' />'
  $xml = [regex]::Replace($xml, '(<manifest\b[^>]*>)', '$1' + $permission, 1)
}
Set-Content -Path $activity -Value $source -Encoding UTF8
Set-Content -Path $manifest -Value $xml -Encoding UTF8
Write-Host 'Android biometrics and internet permissions configured.'
