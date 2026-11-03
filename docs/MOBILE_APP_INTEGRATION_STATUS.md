# Employee Mobile — November 3 integrated fixes

Repository: 9o9ame/BlueMarketingEmployeeApp (Flutter only)
Laravel backend: unchanged.

## Implemented
- Fixed widget-test timeout by rendering LoginScreen directly, without invoking an asynchronous secure-storage platform call inside the test.
- Added a two-project selector widget test.
- Cleaned up reported string concatenation / conditional-braces lints.
- Default API host: https://dev.bluemarketing.com.pk (overridable using --dart-define=API_BASE_URL=https://...).
- Login screen asks for **email and password only**.
- Single-project user enters dashboard directly; multi-project users always select a project before opening modules; available options come from the server's authenticated login response.
- Added local_auth biometric opt-in switch inside dashboard; biometric unlock is checked on the next launch before reusing stored Sanctum token. Biometrics do not replace the server token or account permissions. Failed unlock requires sign-in again.
- New-login account clears prior biometric opt-in. Logout clears token and biometric opt-in.
- Kept existing attendance / CRM / project / stock / reports read APIs. Backend remains source of truth.

## Android-native setup (required once on existing locally generated Android project)

The Android project and pubspec.yaml currently exist locally on the user's Windows PC and are not in the GitHub repo. This repository includes tools/configure_android_biometrics.ps1 to edit the local MainActivity to FlutterFragmentActivity and add USE_BIOMETRIC and INTERNET permissions.

Run on Windows PowerShell from D:\Projects\BlueMarketingEmployeeApp:

```powershell
git pull --ff-only origin main
flutter pub add local_auth
.\tools\configure_android_biometrics.ps1
flutter analyze
flutter test
```

Review the generated AndroidManifest and Kotlin diff before building. If a widget test still fails, share the complete output before creating another APK.

## Single consolidated debug APK (after tests pass)
```powershell
flutter build apk --debug --dart-define=API_BASE_URL=https://dev.bluemarketing.com.pk
& "D:\Android\Sdk\platform-tools\adb.exe" -s d2b1f972 install --no-streaming -r "build\app\outputs\flutter-apk\app-debug.apk"
```

The generated `pubspec.yaml`, platform folders and dependencies should be committed to this standalone repository after validation. Do not commit credentials or production tokens.

## Unverified
- Flutter analyze/test/device build were not executed in this GitHub-only environment.
- Live API availability and user login have not been confirmed with real credentials. The public dev URL is configured, not verified by authenticated smoke tests.
- Which Android face biometric types are usable depends on device biometric enrollment and security classification. Android may offer fingerprint only.
- Detailed role permission labels, project membership and module workflows require a server-connected QA pass; advanced CRM/stock/approvals writes are not complete.


## CRM milestone — November 3, 2026

Implemented in standalone Flutter repository:
- Searchable, status-filtered, paginated CRM leads list.
- CRM lead detail, masked NIC as returned by server, and activity history.
- New lead form with first/last name, phone, optional 11-digit mobile number, remarks, follow-up date.
- Edit lead and record follow-up with explicit user confirmation.
- Create/update controls require relevant server-issued permission; Laravel retains all authorization.
- Requests follow exact MobileCrmController endpoint and field names; no hardcoded CRM status IDs or arbitrary user assignments.

API dependencies: GET crm/leads, GET crm/leads/{id}, POST crm/leads, PUT crm/leads/{id}, POST crm/leads/{id}/follow-up, GET crm/leads/{id}/history.

Not included: lead assignment (server requires a valid assignable user and privilege checks), status selection (canonical statuses not confirmed), booking writes, finance/stock writes.

Testing: unit tests added; no local Flutter SDK available to run tests in GitHub tool environment. Run `flutter analyze` and `flutter test` locally before APK build. No claim of production API end-to-end test.
