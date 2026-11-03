# Account History, Fingerprint Sign-In and Task Notification Bell

Updated November 3, 2026. Changes are confined to the Flutter app repository. Laravel `upgrade/laravel-framework` is untouched.

## Implemented in Flutter source

- Recent account history: successfully authenticated email addresses appear in latest-first order, maximum 10 accounts, inside an on-tap history selector for email/password fields. Passwords are **never displayed** in this selector. Email is prefilled on selection, with Android Autofill available for the password.
- Login screen always includes a visible `Sign in with fingerprint / face` action, including after explicit logout. The button displays a helpful message if the device has no enabled/saved biometric credential yet.
- Optional checkbox `Remember for fingerprint sign-in` requires device biometric verification and then stores the selected login password in encrypted Flutter secure storage. No default password saving.
- Once explicitly enabled, the biometric preference remains enabled until Settings is manually switched off, including after logout, failed/cancelled fingerprint or password sign-in.
- With a saved, biometric-protected credential, a fingerprint check can submit the **existing** `POST /api/v1/mobile/auth/login` to get a **new** Sanctum token after logout or token expiry. A revoked token is never reused. Device must remain authenticated and user must have current backend access.
- Disabling biometrics in Settings removes stored password copies, but retains recent account email history. Newly enabled biometrics do not magically recreate passwords; an explicit opt-in at the next password login is needed.
- On app cold start, the existing valid token is unlocked via biometrics, or the most recent opt-in credential can be used to obtain a fresh token after biometric verification.
- Switching a recent account only uses its saved password after biometric success; otherwise it selects that email and asks for its password. Account switching must never use a different account's bearer token.
- Navigation: colorful notification bell in dashboard and Notifications shortcut in slide-out drawer. The notification inbox is an honest empty state while Task Management APIs and FCM setup are pending.
- Added `test/remembered_accounts_test.dart` and new account-selector coverage in `test/premium_ui_test.dart`.

## Important security choices

- Saved passwords are opt-in and encrypted by `flutter_secure_storage`, but an app-level `local_auth` check is not identical to hardware-enforced, per-read key access. For a higher-assurance enterprise release, adopt Android Credential Manager / passkeys / backend refresh-token design.
- No passwords or tokens should appear in analytics, logs, notification payloads or screenshots.
- A user who does not opt in will see recent emails but must use Android Autofill or enter the password again after explicit logout.
- Password login and fingerprint re-login remain subject to the backend login throttle and user/project permissions.
- For a shared or compromised device, enable OS device lock and restrict biometric enrollment; device admins should be able to revoke sessions.
- The previous `MOBILE_PREMIUM_DESIGN_MILESTONE.md` assertion that passwords are never stored is **superseded** for users who explicitly choose opt-in storage.

## Task notifications — pending backend dependencies

The existing Laravel `routes/api.php` has no Task Management notification or device registration endpoint. Therefore the dashboard bell is **not** a functional real-time task notification delivery system yet. See `docs/TASK_NOTIFICATIONS_INTEGRATION_CONTRACT.md` for proposed FCM + Reverb architecture, per-user inbox/device routes, one-time/repeated scheduling, idempotency and security.

No Firebase dependencies or config were added because the Firebase project, `google-services.json`, device registration endpoint, Laravel task module and job integration are missing.

## Local QA gate (do not build APK before verification)

```powershell
cd D:\Projects\BlueMarketingEmployeeApp
git pull --ff-only origin main
flutter analyze
flutter test
```

After tests pass, verify login, recent-account ordering, opt-in, successful fingerprint, failure/cancel, post-logout new-token re-login, switching accounts and manual Settings OFF on Redmi. Do not test with sensitive finance data.

Remote GitHub source was inspected but Dart/Flutter tests have **not** been executed by this environment.
