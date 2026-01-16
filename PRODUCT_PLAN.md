1. PRD
1.1 Overview
Multi-branch educational consultancy platform with a web app for admin and branch managers, and an Android app for counselors that mirrors Callyzer-style call tracking and recording. Leads are imported via CSV, assigned by rules, and managed end-to-end (call, follow-up, close).
Launch region: India only.

1.2 Goals
1.2.1 Reduce time-to-first-contact and improve conversion rate.
1.2.2 Provide branch-level accountability and HQ-wide visibility.
1.2.3 Capture complete call history, recordings, and counselor actions per lead.
1.2.4 Ensure compliant call recording and secure data handling.

1.3 Non-goals
1.3.1 No iOS app in initial phases.
1.3.2 No in-house VoIP or custom dialer beyond Android dialer integration for MVP.
1.3.3 No marketing automation or payments in MVP.

1.4 User roles and access
1.4.1 Super Admin (HQ): full multi-branch access, global settings, analytics.
1.4.2 Branch Manager: manage counselors, lead assignment, branch analytics.
1.4.3 Counselor: assigned leads, calls, notes, follow-ups, status updates.
1.4.4 Compliance/Audit (optional): restricted access to recordings and audit logs.

1.5 Core user flows
1.5.1 Lead import: upload CSV, map fields, validate, dedupe, apply assignment rules, import job tracking.
1.5.2 Lead assignment: rule-driven distribution by branch, counselor, and university (round-robin, capacity, priority).
1.5.3 Counselor workflow (Android): lead list -> click to call -> call state tracked -> recording captured -> post-call note popup -> follow-up scheduled -> status updated.
1.5.4 Manager workflow (Web): view pipeline, reassign leads, monitor counselor activity and SLAs.
1.5.5 Admin analytics: cross-branch funnel, call KPIs, counselor performance.

1.6 Functional requirements
1.6.1 Web
- Multi-branch RBAC, branch and counselor management.
- Email/password login for admin and branch manager.
- CSV import (student_name, phone_number) and assignment rules UI.
- University selection per CSV import (single university per file).
- Lead list, detail view, status updates, notes, follow-ups.
- Call history and recording playback (admin and branch manager only).
- Analytics dashboards for admin and branch managers.
1.6.2 Android (Callyzer-like)
- Email/password login and offline lead access.
- Call tracking with Telephony state + CallLog observer.
- Call sync: map CallLog entries to leads by phone_number; incremental sync with WorkManager retries.
- Call recording pipeline with foreground service, compression, upload, and retry.
- Recording status and failure reason captured per call (best-effort recording).
- Post-call notes popup and lead status updates.
- Default Android dialer for MVP.
- Background sync with WorkManager.
1.6.3 Android permissions and consent (MVP)
- Required runtime permissions: READ_PHONE_STATE, READ_CALL_LOG, RECORD_AUDIO, POST_NOTIFICATIONS (33+).
- Required manifest permissions: FOREGROUND_SERVICE, INTERNET, ACCESS_NETWORK_STATE.
- Foreground service types: microphone + dataSync; Android 14 requires FOREGROUND_SERVICE_MICROPHONE when targeting 34.
- Optional (only if needed): READ_PHONE_NUMBERS (line number), RECEIVE_BOOT_COMPLETED (reschedule sync).
- Storage permissions: not required for app-private storage; READ_MEDIA_AUDIO/READ_EXTERNAL_STORAGE only if accessing shared storage or SAF.
- Avoided in MVP: SYSTEM_ALERT_WINDOW, CALL_PHONE, READ_CONTACTS.
- Consent: explicit in-app consent and recording notice; store consent flag per call.
- Recording: foreground service with persistent notification; best-effort recording with clear "recording unavailable" status when blocked.
- Storage: record into app-private storage for MVP (no SAF required). If external recorder folder access is needed later, add SAF folder picker and persist URI permissions.
- Android 13/14 compliance: use correct foreground service types and permission gating for microphone recording.
1.6.4 Backend (Phoenix)
- Email/password auth (all roles), RBAC, multi-branch scoping, password reset.
- Lead import pipeline and assignment rules engine.
- Lead import sets university from import selection.
- Lead statuses (MVP): New, Follow-up, Applied, Not Interested.
- Call log and recording metadata ingestion.
- Analytics aggregation and dashboard APIs.
- Audit logs, retention, and consent tracking.

1.7 Success metrics
1.7.1 Time-to-first-contact (median, p90).
1.7.2 Call connect rate and call-to-appointment rate.
1.7.3 Lead-to-close conversion by branch and counselor.
1.7.4 Recording coverage rate and follow-up adherence.

2. Architecture overview
2.1 Web
Phoenix LiveView for the web app; no separate React frontend in scope. Web consumes JSON APIs and shows dashboards, assignments, and recordings.

2.2 Android
Kotlin app with foreground service for call tracking, WorkManager for background sync, local Room cache for offline usage, and a recording pipeline similar to Callyzer (capture -> compress -> upload -> metadata sync).

2.3 Backend (Phoenix)
Phoenix JSON API + Ecto/Postgres. Oban for background jobs (imports, assignment batches, analytics rollups, retention). Amazon S3 for recordings.

2.4 Data
Postgres for transactional data, Amazon S3 for recordings, optional Redis for queues or caching. Analytics rollups stored in Postgres tables for dashboards. S3 bucket: `koncallcrm` (Hyderabad, ap-south-2) with encryption and 1-year lifecycle policy.

2.5 Security and observability
JWT auth with role claims, branch scoping in policy layer, audit logs for sensitive actions, and structured logs + metrics for ops.
S3 encryption default: SSE-S3 (recommended for MVP); upgrade to SSE-KMS if compliance requires customer-managed keys.

2.6 Testing strategy
2.6.1 Backend: ExUnit unit tests for validators, normalization, assignment rules; DataCase for DB; ConnCase for API; LiveView tests for key flows.
2.6.2 Property-based tests (StreamData): CSV parsing idempotency, dedupe invariants, assignment constraints, pagination consistency.
2.6.3 Jobs: Oban job tests for imports, retention, and analytics rollups.
2.6.4 Storage: S3 integration tests using MinIO or a mocked client to validate upload flow and metadata persistence.
2.6.5 Android: unit tests for call state, permissions gating, sync logic; instrumentation tests for WorkManager and recording pipeline.

3. Backend data model and APIs
3.1 Proposed DB schema (key tables)
- organizations, branches
- users, roles, permissions, counselor_profiles
- universities, counselor_university_assignments
- leads, lead_assignments, lead_statuses
- lead_activities (calls, notes, status changes)
- follow_ups
- call_logs, call_recordings (file_url, duration, size, consent_flag)
- import_jobs, import_rows
- assignment_rules
- device_sessions (Android devices, FCM token)
- analytics_events, analytics_rollups
- audit_logs

3.2 API surface (high level)
- Auth: POST /auth/login, POST /auth/refresh
- Users/branches: GET/POST /branches, GET/POST /counselors, POST /counselors/:id/universities
- Leads: GET/POST /leads, GET/PUT /leads/:id, POST /leads/:id/assign, POST /leads/:id/status
- Activities: POST /leads/:id/notes, POST /leads/:id/followups
- CSV import: POST /imports/leads (upload), GET /imports/:id/status
- Assignment rules: GET/POST /assignment-rules
- Calls: POST /calls/logs, GET /calls?lead_id=
- Recordings: POST /recordings/init (signed URL), POST /recordings/complete, GET /recordings/:id
- Analytics: GET /analytics/admin, GET /analytics/branches/:id, GET /analytics/counselors/:id

4. Milestones, dependencies, and task tracker
4.1 Milestones with rough estimates
4.1.1 M1 Discovery, UX, compliance baseline (10 days)
4.1.2 M2 Backend foundations, schema, CSV import, assignment rules (15 days)
4.1.3 M3 Web admin and branch manager MVP (15 days)
4.1.4 M4 Android counselor MVP with call tracking + recording (20 days)
4.1.5 M5 Analytics, hardening, QA, pilot (10 days)
Total estimate: ~70 days (14 to 15 weeks).

4.2 Task tracker table

| Epic | Story | Task | Owner Role | Est (days) | Dependencies |
| --- | --- | --- | --- | --- | --- |
| Foundations and RBAC | Access model | Define role matrix and branch scoping rules | Product | 1 | None |
| Foundations and RBAC | Access model | Ecto schemas for org, branch, user, role, permission | Backend Eng | 2 | Role matrix |
| Foundations and RBAC | Access model | JWT auth and refresh endpoints | Backend Eng | 2 | Core schemas |
| Foundations and RBAC | Access model | RBAC policy middleware and branch scoping | Backend Eng | 2 | Auth endpoints |
| Foundations and RBAC | Access model | Web app shell and login | Web Eng | 2 | Auth endpoints |
| Foundations and RBAC | Access model | Android login and session persistence | Android Eng | 2 | Auth endpoints |
| Lead intake and assignment | CSV import | CSV template and mapping UI (student_name, phone_number) + university selection | Web Eng/Design | 2 | Web shell |
| Lead intake and assignment | CSV import | Import job pipeline with validation + set university | Backend Eng | 2 | Lead schema |
| Lead intake and assignment | CSV import | Dedupe rules and merge strategy | Backend Eng | 2 | Import pipeline |
| Lead intake and assignment | CSV import | Import status and error UI | Web Eng | 1 | Import pipeline |
| Lead intake and assignment | Assignment rules | Assignment rule model and CRUD API | Backend Eng | 2 | Lead schema |
| Lead intake and assignment | Assignment rules | Rule engine (round-robin, capacity, university) | Backend Eng | 2 | Rule model |
| Lead intake and assignment | Assignment rules | Assignment UI and bulk assign | Web Eng | 2 | Rule engine |
| Lead intake and assignment | Assignment rules | Lead aging and auto-reassignment job | Backend Eng | 1 | Rule engine |
| Lead lifecycle and CRM | Lead management | Lead CRUD and status transitions API | Backend Eng | 2 | Core schemas |
| Lead lifecycle and CRM | Lead management | Lead activity log and notes API | Backend Eng | 2 | Lead CRUD |
| Lead lifecycle and CRM | Follow-ups | Follow-up scheduling and reminders | Backend Eng | 2 | Activity API |
| Lead lifecycle and CRM | Lead views | Web lead list and filters | Web Eng | 2 | Lead CRUD |
| Lead lifecycle and CRM | Lead views | Web lead detail and timeline | Web Eng | 2 | Activity API |
| Lead lifecycle and CRM | Counselor UX | Android lead list and detail | Android Eng | 2 | Lead API |
| Lead lifecycle and CRM | Counselor UX | Android status update, notes, follow-ups | Android Eng | 2 | Activity API |
| Android call tracking | Call state | Call state detection and CallLog sync module | Android Eng | 2 | Android login |
| Android call tracking | Call state | Call log ingestion API | Backend Eng | 2 | Lead CRUD |
| Android call tracking | Call state | Post-call note popup UX | Android Eng | 1 | Call state module |
| Android recording pipeline | Recording capture | Recording capture with OEM fallback matrix | Android Eng | 2 | Call state module |
| Android recording pipeline | Recording pipeline | Local file management and compression worker | Android Eng | 2 | Recording capture |
| Android recording pipeline | Storage | Object storage bucket, IAM, signed URL config (S3 encryption + lifecycle) | DevOps | 1 | None |
| Android recording pipeline | Storage access | Recording storage strategy + permission gating (app-private vs SAF) | Android Eng | 1 | Recording capture |
| Android recording pipeline | Storage access | SAF folder picker + persisted URI (optional) | Android Eng | 2 | Recording storage strategy |
| Android recording pipeline | FGS compliance | Foreground service types + Android 13/14 permission gating | Android Eng | 1 | Call state module |
| Android recording pipeline | Upload | Signed upload endpoints | Backend Eng | 2 | Storage setup |
| Android recording pipeline | Upload | Upload manager, retry, metadata sync | Android Eng | 2 | Signed upload endpoints |
| Web and reporting | Recording access | Recording playback with access checks (admin, branch manager) | Web Eng/Backend Eng | 2 | Recording metadata |
| Analytics and dashboards | KPIs | Event schema and aggregation jobs | Backend Eng/Data | 2 | Lead and call logs |
| Analytics and dashboards | KPIs | Admin dashboard widgets | Web Eng/Design | 2 | Aggregation API |
| Analytics and dashboards | KPIs | Branch manager dashboard | Web Eng | 1 | Aggregation API |
| Branch and university mgmt | Org setup | Branch and counselor management API | Backend Eng | 2 | Core schemas |
| Branch and university mgmt | Org setup | Branch and counselor management UI | Web Eng | 2 | Management API |
| Branch and university mgmt | University | University model and counselor mapping UI | Web Eng/Backend Eng | 2 | Management API |
| Compliance and security | Consent | Consent capture flow and policy settings | Product/Backend Eng | 2 | Role matrix |
| Compliance and security | Retention | Recording retention (1 year) and deletion jobs | Backend Eng | 2 | Storage setup |
| Compliance and security | Audit | Audit log for sensitive actions | Backend Eng | 1 | RBAC policies |
| DevOps and QA | Release | CI/CD pipelines and env secrets | DevOps | 2 | None |
| DevOps and QA | Release | QA plan and device matrix for recording | QA | 2 | Recording capture |
| DevOps and QA | Release | Pilot rollout and monitoring dashboards | Product/DevOps | 2 | Analytics |
| Testing and QA automation | Backend tests | Unit/integration tests for contexts and validators | Backend Eng | 2 | Core schemas |
| Testing and QA automation | Property-based tests | StreamData tests for CSV, dedupe, assignment | Backend Eng | 2 | Import pipeline, rule engine |
| Testing and QA automation | LiveView tests | LiveView tests for import, assignment, lead flows | Web Eng | 2 | Lead views, assignment UI |
| Testing and QA automation | Android tests | Unit tests for call state and permission gating | Android Eng | 1 | Call state module |
| Testing and QA automation | Android tests | Instrumentation tests for WorkManager and recording | Android Eng/QA | 2 | Recording pipeline |
| Testing and QA automation | Storage tests | S3 upload integration tests (MinIO or mock) | Backend Eng/DevOps | 1 | Signed upload endpoints |

5. Risks and compliance notes
5.1 Product and tech risks
5.1.1 Android call recording restrictions vary by OS and OEM; fallback strategies and device matrix testing are mandatory.
5.1.2 Permissions fatigue may reduce adoption; onboarding must explain why and capture consent cleanly.
5.1.3 CSV data quality and duplicates can corrupt assignments; validation and preview are critical.
5.1.4 Multi-branch data isolation must be enforced in every query and API path.
5.1.5 Offline mobile flows risk data conflicts; need idempotent APIs and conflict strategy.

5.2 Call recording compliance (India only)
5.2.1 Capture consent and clear notice before recording; store consent flag per call/lead.
5.2.2 Retention period: 1 year for recordings and lead data (configurable).
5.2.3 Access limited to admin and branch manager; log access in audit logs.

6. MVP vs Phase 2/3
6.1 MVP
6.1.1 Multi-branch RBAC, branch and counselor management.
6.1.2 CSV import with validation, dedupe, assignment rules.
6.1.3 Lead lifecycle tracking, notes, follow-ups.
6.1.4 Android call tracking + basic recording + upload + post-call notes.
6.1.5 Admin and branch dashboards (core KPIs).

6.2 Phase 2
6.2.1 Advanced assignment rules (SLA, priority queues, lead aging).
6.2.2 Enhanced analytics (cohort, funnel, per-university performance).
6.2.3 In-app dialer enhancements, call outcome tagging templates.
6.2.4 Quality review workflows for recordings and coaching.

6.3 Phase 3
6.3.1 AI call summaries, sentiment scoring, auto follow-up suggestions.
6.3.2 Omnichannel support (WhatsApp, email, SMS).
6.3.3 iOS counselor app and optional VoIP integration.

7. Decisions and open questions
7.1 Decisions (confirmed)
7.1.1 Launch region: India only.
7.1.2 MVP uses default Android dialer.
7.1.3 CSV required fields: student_name, phone_number.
7.1.4 Leads assigned by university.
7.1.5 Recording and lead data retention: 1 year (initial).
7.1.6 No CRM integration in MVP.
7.1.7 No data residency requirement.
7.1.8 Recording access limited to admin and branch manager.
7.1.9 Web app built in Phoenix LiveView (no React).
7.1.10 Email/password auth for all roles.
7.1.11 Password policy: min 8 characters.
7.1.12 Password reset via email link.
7.1.13 Token TTLs: access 30 minutes, refresh 30 days.
7.1.14 Auth scaffold: Phoenix `phx.gen.auth` (email/password).
7.1.15 Android package name: com.koncrm.counselor (existing project).
7.1.16 Lead statuses (MVP): New, Follow-up, Applied, Not Interested.
7.1.17 S3 bucket: koncallcrm (Hyderabad, ap-south-2), encryption + 1-year lifecycle policy.
7.1.18 KPIs/SLA targets deferred.
7.1.19 University selection per CSV import (single university per file).

7.2 Open questions
7.2.1 Target KPIs and SLA thresholds for dashboards.
7.2.2 Consent/recording notice copy for India (deferred).
7.2.3 Confirm S3 encryption choice (recommend SSE-S3; SSE-KMS if compliance requires).

7.3 Dedupe strategy (confirmed)
7.3.1 Hybrid: hard dedupe on phone_number + student_name (normalized), soft-flag phone-only matches for review/merge.
