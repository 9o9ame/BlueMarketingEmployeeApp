# Consolidated employee mobile app implementation

Repository: `9o9ame/BlueMarketingEmployeeApp`
Backend: existing BlueMarketing Laravel API (NO Laravel changes).

## Implemented in Flutter
- Real Sanctum login against `POST /api/v1/mobile/auth/login`.
- Persistent token using `flutter_secure_storage`, current-user restoration via `GET auth/me` and logout.
- Permission-filtered module navigation and project selection.
- Staff attendance today/history, server-validated check-in/check-out with explicit confirmation.
- Read-only remote data screens: CRM leads/summary, labour, stock entries/items/report, project/inventory reports and approvals.
- Network loading, retry, and no-data states.
- No fake data or demo login in active entry point.

## Scope / release restrictions
- More comprehensive workflow UI remains outstanding: lead creation/update/follow-up, labour marking, stock in/out, approval approve/reject/preview, detailed booking/recovery charts, notifications, rich search/pagination.
- Some role permission labels are provisional; reconcile against the Laravel controllers before production rollout. The backend remains the security authority.
- Generic read-only data renderer is an initial integration screen, not the final module UI.
- Live PHP/API integration and physical-device verification have NOT run from this GitHub environment.
- A selected project is required for project-scoped screens.
- HTTPS required for API calls; do not use a production login against an untrusted server.

## One-time local dependencies
The existing `pubspec.yaml` was generated locally and has not yet been uploaded to GitHub. Before building:

```powershell
cd D:\Projects\BlueMarketingEmployeeApp
git pull --ff-only origin main
flutter pub add http flutter_secure_storage
flutter analyze
flutter test
```

## Debug build

```powershell
flutter build apk --debug --dart-define=API_BASE_URL=https://YOUR-LARAVEL-DOMAIN
& "D:\Android\Sdk\platform-tools\adb.exe" -s d2b1f972 install --no-streaming -r "build\app\outputs\flutter-apk\app-debug.apk"
```

Keep real credentials out of screenshots and Git. If the HTTPS backend is not configured, the login button remains disabled.

For signed Android release builds verify main AndroidManifest INTERNET permission, secure network policies, app signing, token lifecycle, server access rules and comprehensive integration tests.

## Test/build status
Code committed remotely. No claim of successful Flutter analysis or build until the local Windows SDK runs the commands.
