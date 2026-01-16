1. Assumptions
1.1 Team: Product, Backend, Web (LiveView), Android, DevOps, QA.
1.2 Sprint cadence: 2-week sprints.
1.3 Region: India only.
1.4 Android: default dialer in MVP.
1.5 Dedupe: hybrid (hard dedupe on phone_number + student_name; soft-flag phone-only matches).
1.6 Recording retention: 1 year.
1.7 Storage: Amazon S3 for recordings.
1.8 KPIs/SLA targets: to be finalized later.
1.9 Auth: email/password for all roles.
1.10 Password policy: min 8 characters; reset via email link.
1.11 Token TTLs: access 30 minutes, refresh 30 days.
1.12 Auth scaffold: Phoenix `phx.gen.auth` (email/password).
1.13 S3 bucket: koncallcrm (Hyderabad, ap-south-2), encryption + 1-year lifecycle policy.
1.14 Lead statuses (MVP): New, Follow-up, Applied, Not Interested.
1.15 CSV import: university selected per file (single university per CSV).

2. Epic and story tracker
2.1 E1 Foundations and RBAC
2.1.1 S1.1 Role matrix and branch scoping rules (Product) -> depends on none.
2.1.2 S1.2 Core schemas for org/branch/user/role/permission (Backend) -> S1.1.
2.1.3 S1.3 Auth endpoints (Backend) -> S1.2.
2.1.4 S1.4 RBAC middleware and branch scoping (Backend) -> S1.3.
2.1.5 S1.5 Web login and shell (Web) -> S1.3.
2.1.6 S1.6 Android login and session persistence (Android) -> S1.3.

2.2 E2 Lead intake and assignment
2.2.1 S2.1 CSV template and mapping UI (student_name, phone_number) + university selection (Web/Design) -> S1.5.
2.2.2 S2.2 Import job pipeline with validation + set university (Backend) -> S1.2.
2.2.3 S2.3 Dedupe rules + possible-duplicate flagging (Backend) -> S2.2.
2.2.4 S2.4 Import status and error UI (Web) -> S2.2.
2.2.5 S2.5 Assignment rule model and CRUD (Backend) -> S1.2.
2.2.6 S2.6 Assignment rule engine (university-based) (Backend) -> S2.5.
2.2.7 S2.7 Assignment UI + bulk assign (Web) -> S2.6.

2.3 E3 Lead lifecycle and CRM
2.3.1 S3.1 Lead CRUD and status transitions (Backend) -> S1.2.
2.3.2 S3.2 Lead activity log + notes (Backend) -> S3.1.
2.3.3 S3.3 Follow-ups and reminders (Backend) -> S3.2.
2.3.4 S3.4 Web lead list and filters (Web) -> S3.1.
2.3.5 S3.5 Web lead detail and timeline (Web) -> S3.2.
2.3.6 S3.6 Android lead list/detail (Android) -> S3.1.
2.3.7 S3.7 Android notes/status/follow-ups (Android) -> S3.2.

2.4 E4 Android call tracking
2.4.1 S4.1 Call state detection + CallLog sync (Android) -> S1.6.
2.4.2 S4.2 Call log ingestion API (Backend) -> S3.1.
2.4.3 S4.3 Post-call note popup (Android) -> S4.1.

2.5 E5 Recording pipeline
2.5.1 S5.1 Recording capture with OEM fallbacks (Android) -> S4.1.
2.5.2 S5.2 Compression worker (Android) -> S5.1.
2.5.3 S5.3 Object storage + signed upload endpoints (S3 encryption + lifecycle) (DevOps/Backend) -> S1.2.
2.5.4 S5.4 Upload manager + metadata sync (Android) -> S5.3.
2.5.5 S5.5 Recording playback with RBAC (Web/Backend) -> S5.4.
2.5.6 S5.6 Recording storage strategy + permission gating (app-private vs SAF) (Android) -> S5.1.
2.5.7 S5.7 SAF folder picker + persisted URI (optional) (Android) -> S5.6.
2.5.8 S5.8 Foreground service types + Android 13/14 permission gating (Android) -> S4.1.

2.6 E6 Analytics and dashboards
2.6.1 S6.1 Event schema + aggregation jobs (Backend/Data) -> S3.1, S4.2.
2.6.2 S6.2 Admin dashboard widgets (Web) -> S6.1.
2.6.3 S6.3 Branch manager dashboard (Web) -> S6.1.

2.7 E7 Compliance and security
2.7.1 S7.1 Consent capture + flags (Backend/Android) -> S4.1.
2.7.2 S7.2 Retention jobs (1 year) (Backend/DevOps) -> S5.3.
2.7.3 S7.3 Audit logging for recordings/access (Backend) -> S5.5.

2.8 E8 DevOps and QA
2.8.1 S8.1 CI/CD and environments (DevOps) -> None.
2.8.2 S8.2 QA plan + device matrix for recording (QA) -> S5.1.
2.8.3 S8.3 Pilot rollout + monitoring (Product/DevOps) -> S6.2, S6.3.

2.9 E9 Testing and QA automation
2.9.1 S9.1 Backend unit/integration tests for contexts and validators (Backend) -> S1.2.
2.9.2 S9.2 Property-based tests for CSV, dedupe, assignment (Backend) -> S2.2, S2.6.
2.9.3 S9.3 LiveView tests for import, assignment, lead flows (Web) -> S2.1, S3.4, S3.5.
2.9.4 S9.4 Android unit tests for call state and permission gating (Android) -> S4.1.
2.9.5 S9.5 Android instrumentation tests for WorkManager and recording (Android/QA) -> S5.2.
2.9.6 S9.6 S3 upload integration tests (Backend/DevOps) -> S5.3.

3. Sprint plan (2-week sprints)
3.1 Sprint 0: setup and foundations
- S1.1, S1.2, S8.1.

3.2 Sprint 1: auth, RBAC, and app shells
- S1.3, S1.4, S1.5, S1.6.

3.3 Sprint 2: CSV import and assignment rules
- S2.1, S2.2, S2.4, S2.5, S2.6.

3.4 Sprint 3: lead lifecycle (backend + web) + tests
- S3.1, S3.2, S3.3, S3.4, S3.5, S9.1.

3.5 Sprint 4: Android lead UX + call tracking
- S3.6, S3.7, S4.1, S4.2, S4.3.

3.6 Sprint 5: recording pipeline
- S5.1, S5.2, S5.3, S5.4, S5.5, S5.6, S5.7, S5.8.

3.7 Sprint 6: analytics + compliance + audit + testing
- S6.1, S6.2, S6.3, S7.1, S7.2, S7.3, S9.2, S9.3, S9.6.

3.8 Sprint 7: QA + pilot + testing
- S8.2, S8.3, S9.4, S9.5, bug fixes and hardening.
