# Pilot Rollout Plan (Sprint 7)

## Phase 1: Internal (1-2 branches)
- Enable Android app for selected counselors.
- Upload recordings to staging storage; validate playback.
- Daily checks: call log sync, notes, follow-ups.

## Phase 2: Limited pilot (3-5 branches)
- Enable production uploads and analytics rollups.
- Monitor recording upload success rate and sync retries.
- Support playbooks for call recording permissions.

## Monitoring & KPIs
- Call log sync success rate
- Recording upload success rate
- Post-call note completion rate
- Lead status update rate
- Crash-free sessions (Android)

## Rollback criteria
- >5% crash rate over 24 hours
- Recording upload failures >10% over 6 hours
- Call log sync failures >10% over 6 hours

## Rollback steps
- Disable recording capture via feature flag (if available).
- Pause call log sync schedule.
- Revert app release in Play Console (or disable rollout).
