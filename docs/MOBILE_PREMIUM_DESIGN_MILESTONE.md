# BlueMarketing Employee App — Premium UI & Persistent Biometrics

**Scope:** Flutter presentation, navigation and device-local biometric unlock only. Existing `routes/api.php` mobile endpoints remain the source of truth. Laravel backend untouched.

## Implemented in current GitHub branch

- `lib/premium_design.dart`: unified design tokens (navy/blue/cyan/teal/purple), 3D-depth/shadow cards, branded logo, gradient buttons, colorful KPI widgets, animated side drawer, bottom quick navigation, animated module headings, security settings and slide/fade route transitions.
- Branded login with email + password only. **No Google/Microsoft social login buttons**.
- Searchable project selection with actual assigned projects from server and softly animated project cards. Single assigned project continues automatically.
- Dashboard with real project count, server-provided CRM leads/today's follow-ups, number of permitted modules, attendance status, quick navigation and expandable drawer. The static design reference includes revenue, trends, stock valuation, notifications and social auth; these are **not invented** because backend does not expose the required data/workflows.
- CRM, stock, labour, approvals and project reports share premium module header, colors and card styling. Staff attendance now has a dedicated status/clock-in/clock-out card layout.
- `test/premium_ui_test.dart`: new widget tests covering biometric retry, social-login absence, project search, dashboard drawer, manual setting toggle and source-level flag persistence.
- Global ThemeData: rounded form controls, elevated cards, themed buttons, platform page transitions and accent colors.

## Remembered device login and fingerprint/face behavior

- Login is via existing Laravel Sanctum `auth/login`, `auth/me` and `auth/logout` only.
- Only the **session token and last-used email** are kept in `flutter_secure_storage`, not the password.
- Enabling biometric unlock requires successful biometric verification once; the stored preference remains enabled until the user manually disables it in Settings.
- Each cold app launch with a remembered token and enabled biometric setting immediately requests device biometric verification before fetching `auth/me`.
- If the biometric prompt is cancelled/unavailable, show email/password screen with a **Sign in with fingerprint / face** button to retry against the *same previously stored token*. Failed fingerprint unlock does **not** erase the token or change the user's setting.
- On app background → foreground resume, close the open module route and require biometric unlock again before sensitive data is displayed. Successful unlock restores a previously selected project if still permitted.
- Explicit Logout invalidates the session token but **does not change the biometric preference**. After logout or token expiry, password login is needed to obtain a new server token; fingerprint cannot create a new token or bypass Laravel authentication.
- Expired token (401) is deleted locally. Biometric preference remains enabled. Device must have enrolled and supported fingerprint/face biometrics.

## Release verification needed

The updated Flutter source was written and structurally inspected via GitHub integration. The remote environment does not have this app's Flutter/Android SDK or its local `pubspec.yaml` / `android/` folder. **Do not claim Flutter analyzer, tests, APK or real API integration passed for this new UI batch until Windows execution results are received.**

Run on Windows in the local Flutter project:

```powershell
cd D:\Projects\BlueMarketingEmployeeApp
git status --short
git pull --ff-only origin main
dart format lib test
flutter analyze
flutter test
```

Only when checks pass and local Android Kotlin cache workaround remains applied, build debug APK:

```powershell
flutter build apk --debug --dart-define=API_BASE_URL=https://dev.bluemarketing.com.pk
& "D:\Android\Sdk\platform-tools\adb.exe" -s d2b1f972 install --no-streaming -r "build\app\outputs\flutter-apk\app-debug.apk"
```

Do not submit real stock, labour, or approval writes as part of first-time UI verification.
