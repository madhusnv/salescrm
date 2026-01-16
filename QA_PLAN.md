# QA Plan (Sprint 7)

## Scope
- Web (Phoenix LiveView): lead import, assignment rules, lead lifecycle, recordings playback.
- Android: login, lead list/detail, post-call notes, call log sync, recordings capture/upload, consent.
- Backend APIs: auth, leads, call logs, recordings, analytics.

## Environments
- Local dev: daily smoke.
- Staging: full regression before pilot.
- Pilot: limited production rollout.

## Test cycles
1) Smoke (per build)
2) Feature regression (per sprint)
3) Pilot readiness (full end-to-end + device matrix)

## Critical flows (must pass)
- Auth: login, token refresh, session persistence.
- Lead list/detail: filters, pagination, notes, status updates, follow-ups.
- Call log sync: paging, retries, dedupe; last sync stats update.
- Post-call note overlay: call ends -> note appears -> save note.
- Recording pipeline: consent toggle -> record -> upload -> playback.
- RBAC: correct access to lead data and recordings.

## Non-functional checks
- App startup time.
- Foreground service stability.
- Background sync reliability (WorkManager).
- Storage growth and retention job (1 year).
- Crash-free session during calls and uploads.

## Regression checklist
- CSV import + mapping.
- Assignment rules: create/update/delete.
- Lead lifecycle: status, notes, follow-ups.
- Android: lead list, lead detail tabs, call log list filters, recordings tab.
- Web: dashboard metrics, lead detail playback.

## Exit criteria
- All critical flows pass on device matrix.
- No P0/P1 bugs open; P2 only with approved workaround.
- Pilot readiness sign-off from QA + Product.
