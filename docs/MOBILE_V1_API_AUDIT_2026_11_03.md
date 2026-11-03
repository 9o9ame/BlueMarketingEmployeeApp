# Mobile V1 API audit — 2026-11-03

Source inspected: Laravel `Bilal6230/blueMarketing`, branch `upgrade/laravel-framework`, `routes/api.php` and controllers under `app/Http/Controllers/Api/V1/Mobile/`. Flutter: `9o9ame/BlueMarketingEmployeeApp`, branch `main`.

**43 registered HTTP method+path combinations** under `/api/v1/mobile`. Registered in Git does not prove the current `https://dev.bluemarketing.com.pk` deployment contains the same code, that the database holds records, or that a specific authenticated user has permission. Public live deployment verification was not available; no login token or customer DB was accessed by this audit.

## Route inventory and Flutter status

| Family | Count | Registered endpoints | Flutter usage |
|---|---:|---|---|
| Authentication | 3 | POST auth/login, GET auth/me, POST auth/logout | Connected |
| Core | 2 | GET projects, GET dashboard | Auth response projects and dashboard used; dedicated projects GET used by API Diagnostics |
| CRM | 8 | GET crm/summary; GET/POST crm/leads; GET/PUT crm/leads/{lead}; POST crm/leads/{lead}/follow-up; GET crm/leads/{lead}/history; POST crm/leads/{lead}/assign | Lead list/create/detail/edit/followup/history and generic summary; **assignment action not finished** |
| Staff attendance | 4 | GET attendance/staff/today; POST attendance/staff/check-in; POST attendance/staff/check-out; GET attendance/staff/history | Connected |
| Labour | 4 | GET attendance/labour; POST attendance/labour/mark; GET attendance/labour/report; GET attendance/labour/payment-summary | Connected |
| Stock | 9 | GET stock/meta, GET stock/items, GET stock/parties, GET stock/entries, GET stock/entries/{entry}, POST stock/entries/in, POST stock/entries/out, POST stock/finance/{kind}/{sourceId}/approve, GET stock/report | Read/IN/OUT connected; **finance approval action not finished** |
| Reports | 7 | GET reports/inventory, GET reports/projects, GET reports/projects/{project}, GET reports/projects/{project}/plots, GET reports/projects/{project}/bookings, GET reports/projects/{project}/recovery, GET reports/projects/{project}/customers | Connected |
| Approvals | 6 | GET approvals/summary, GET approvals/, GET approvals/{approval}, GET approvals/{approval}/preview, POST approvals/{approval}/approve, POST approvals/{approval}/reject | List/details/preview/approve/reject connected; **summary endpoint not in dedicated UI** |
| **Total** | **43** | | |

No mobile `tasks`, `notifications`, or `devices` endpoints currently registered. Bell is UI-only until Task Management routes / FCM / push backend exist.

## Confirmed code-level reasons a screen could appear empty

1. **Project access scope**: `ResolvesMobileProjectAccess::allowedProjects()` gives superadmin all active projects; a non-superadmin gets *only* the project whose ID matches `users.project_id`. When `users.project_id` is empty or the project inactive, the user is assigned zero accessible projects. Laravel source contains a TODO for real multi-project assignment. Do not bypass this authorization from Flutter.
2. **CRM permissions and assignments**: `MobileCrmController` requires `read lead`. For non-admin, `scopedLeadsQuery` also filters to leads assigned to that user. Empty CRM can be correct even when records exist globally.
3. **Dashboard placeholders**: backend `MobileDashboardController` returns `attendance: null`, `stock: null`, `reports: null`, `approvals: null`; only CRM counts are available if permission and project match. Displaying invented KPI values is prohibited.
4. **Stock menu navigation defect**: Flutter's previous `HomeScreen.open` sent every stock menu link to `StockWorkspace` rather than the concrete records screen. Fixed: Stock Items / Stock Report now open their `StockRecords` live API page. Stock Workspace remains a menu for movements, parties, transactions and reports.
5. **Approvals default filter**: `ApprovalWorkspace` starts at `status=pending`. Approved/rejected historical records will not be displayed until user changes dropdown to `All`.
6. **Deployment/data differences**: The user's app points to `https://dev.bluemarketing.com.pk`, which may differ from other development/staging/production databases and deployed route versions. Code inspection alone cannot assert which.
7. **Permission fallback mismatch**: Flutter previously exposes some menus for `admin` roles broadly, but the CRM controller strictly checks `can('read lead')`. Therefore visible menu does not guarantee authorized records.

## Read-only diagnostics for actual cause

Implemented `lib/api_diagnostics_screen.dart` and a **Sidebar → API Diagnostics** shortcut. Tap **Run read-only checks** to test 13 existing GET endpoints and show statuses and record counts:

- auth/me, projects, dashboard
- CRM leads, CRM summary
- today attendance, labour records
- global stock items, stock entries, stock report
- project reports, inventory report
- approvals (all statuses)

Shows: `Connected`, `HTTP 401`, `HTTP 403`, `HTTP 404`, `HTTP 422`, `HTTP 500`, `No selected project`, or network/response errors. It never displays bearer tokens, raw customer record data or passwords. Does not write to any endpoint.

Interpretation: 401 = login session invalid; 403 = insufficient permissions or project; 404 = missing/not deployed route; 422 = invalid parameters; 500 = backend error; Connected with 0 records = empty queried result or permission-filtered zero rows.

## Local QA before APK

```powershell
cd D:\Projects\BlueMarketingEmployeeApp
git pull --ff-only origin main
flutter analyze
flutter test
```

Once tests pass, build one new APK for device QA. Take screenshot of the API Diagnostics list showing labels, statuses and counts. Do **not** share passwords, tokens or full API response bodies. Laravel backend remains untouched.
