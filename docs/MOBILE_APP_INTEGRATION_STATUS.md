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

## Consolidated mobile batch — November 3, 2026

- Fixed CRM `curly_braces_in_flow_control_structures` issues and repaired setState callback formatting after static inspection.
- Added `lib/stock_screens.dart`: stock catalogue/parties, movement search, IN/OUT filters, pagination, entry detail and aggregate report. **Backend stock balances remain global**, even when access is checked via project_id.
- Added `lib/labour_screens.dart`: labour search, active/inactive filter, attendance summary, single-worker present/absent marking with confirmation and hours validation, labour attendance report. Backend write permissions and duplicate checks remain authoritative.
- Added `lib/approval_screens.dart`: pending/approved/rejected lists, paginated records, approval detail, before/after field preview and approve/reject with explicit review acknowledgement. Read privilege = `direct-update` or admin/superadmin role. Write privilege = `direct-update` or superadmin role, per controller. Backend must validate every action.
- Wired new screens to the Flutter dashboard, retained existing CRM and auth flows.
- Added approval privilege regression tests and aligned existing `direct-update` permission test.
- **No Flutter SDK/device tests executed here**: run local `flutter analyze` and `flutter test` before the next APK build.

### Release blockers / limitations

- Native Android/pubspeс files exist only on user's PC; dependencies were added locally and main Android biometric setup was executed there.
- Live API responses, all roles and project membership have not been tested with real accounts.
- Approval actions and labour attendance can modify real dev data. Test only with approved test accounts.
- Stock IN/OUT entry submission, finance approval, bulk labour attendance, detailed reports, payroll, notifications and high-fidelity UI remain pending; do not describe the app as production complete.

## Compilation repair after Windows validation — November 3, 2026

User's Windows Flutter checks found 26 analyzer issues, primarily cascading from a malformed CRM follow-up request-map collection-if created by an automated brace rewrite. The source has been corrected to use a valid collection-if with a trailing comma. The one-line CRM confirmation conditional now uses braces, and approval/labour text-concatenation warnings were addressed. Because many errors were cascading, their count is not the number of independent root causes.

Next local gate: `git pull --ff-only origin main`, then `flutter analyze` and `flutter test`. Do not build APK until these pass. Existing saved formatting stash can remain stashed. GitHub connector does not execute the Windows Flutter SDK, so local validation is still required.

## Consolidated completion batch — November 3, 2026

Prior Windows verification at commit `6957e101`: `flutter analyze` clean and 16/16 tests passed. The changes below are **new and still require local Flutter validation**.

### New Flutter implementations
- `lib/stock_entry_form.dart`: authenticated stock IN/OUT form with server-provided active item/party selectors, date, quantity, PKR rate, optional vehicle/driver/reason, explicit high-risk accounting confirmation, and server-side stock permission/availability checks. Currently supports one item line per submission; backend supports multiple lines.
- **Currency correctness:** Laravel converts `lines.*.rate` to minor units via integer rounding. Mobile PKR entry is converted to integer paisa before posting; unit regression tests added.
- `lib/labour_bulk.dart`: multi-worker date-specific present/absent attendance with user-configurable hours, selective submission, page navigation for more than 100 workers and explicit confirmation. Server controls duplicate updates and project membership.
- `lib/labour_payment_report.dart`: date-filtered **read-only** unpaid labour payment summary; mapping to controller `data.items`.
- `lib/project_reports.dart`: per-project read-only project summary, plots, bookings, recovery totals and customers with pagination, search and appropriate filters. Child screens use Laravel role/permission checks.
- `lib/dashboard_metrics.dart`: CRM lead totals and today's follow-ups from `GET /api/v1/mobile/dashboard`. Server returns `null` for other dashboard metrics; UI does not fabricate them.
- Inventory report uses the dedicated stock report renderer; stock balances remain global per current Laravel schema.
- Approvals require successful nonempty server diff preview plus user acknowledgement before allowing approve/reject.
- `test/mobile_api_contract_test.dart`: mock HTTP request paths, headers, Sanctum token, HTTPS refusal, and server-error handling. `test/integration_forms_test.dart`: quantity, rate/currency and date validation.

### Actual server-contract caveats
- Mobile SDK tests have NOT been run in this GitHub-only environment; no actual login credentials or device connectivity were used.
- Existing Laravel stock ledger posting has financial effects, so do not use stock writes on real customer data during initial QA.
- The backend does not currently provide an exposed mobile push notification feed; creating a fake notification system would be misleading.
- CRM assignment requires a trustworthy server-provided assignable-users list; the mobile routes currently inspected do not expose that list.
- Advanced end-to-end QA for approvals, payments, role matrices, stock balances, multiple projects, and device biometrics is still required. App is **not yet certified production-ready**.
- Complete multi-line stock transactions, sophisticated charts, exports, offline workflows, notification services, richer designs and store release/signing remain separate future work.

### Local Windows verification BEFORE any APK
```powershell
cd D:\Projects\BlueMarketingEmployeeApp
git status --short
git pull --ff-only origin main
dart format lib test
flutter analyze
flutter test
```
Preserve old CRM-formatting stash. Local `pubspec.yaml`, Android native project and dependency lockfile should be committed to the standalone Flutter repo after verification. The backend Laravel repo remains untouched.

## Strict API scope — 2026-11-03

**Source of truth:** Laravel `routes/api.php`, `Route::prefix('v1/mobile')`. Do not create new Laravel routes, controllers or mobile app features that require unregistered endpoints. Existing Flutter work must only call these registered mobile API route families:

- `auth/login`, `auth/me`, `auth/logout`;
- `projects`, `dashboard`;
- `crm/summary`, `crm/leads`, `crm/leads/{lead}`, follow-up, history, assign;
- `attendance/staff/*`, `attendance/labour/*`;
- `stock/meta`, `stock/items`, `stock/parties`, `stock/entries`, `stock/entries/in`, `stock/entries/out`, `stock/finance/{kind}/{sourceId}/approve`, `stock/report`;
- `reports/inventory`, `reports/projects` and registered per-project detail/plots/bookings/recovery/customers;
- `approvals/summary`, `approvals/`, `approvals/{approval}`, `approvals/{approval}/preview`, approve and reject.

Some listed routes still lack a dedicated UI (e.g. CRM assignment and stock finance approval). Those are **not completed** and should not be represented as implemented. A mobile feature with no registered API must remain out of scope. Existing biometric device unlock is local and does not require a backend API.

### Windows analyzer failure addressed
The supplied Windows log shows a malformed Dart regular expression near the beginning of `lib/stock_entry_form.dart` (`Unterminated string literal`); this produced cascading test failures. Repaired its validator and cleaned the `live_employee_app.dart` conditional braces. These changes were pushed but Windows `flutter analyze` / `flutter test` have NOT been rerun after the fix. Do not make an APK until both checks pass.
