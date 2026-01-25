# Database Optimizations

This document summarizes the database optimizations implemented to improve query performance at scale.

## Migration Applied

`20260121023706_add_database_optimizations.exs`

## Summary of Changes

### 1. Composite Partial Indexes on Leads

| Index | Purpose | Columns |
|-------|---------|---------|
| `leads_org_branch_status_activity_partial_idx` | Main list screen queries | `organization_id, branch_id, status, last_activity_at` (WHERE merged IS NULL) |
| `leads_org_counselor_activity_partial_idx` | "My leads" view | `organization_id, assigned_counselor_id, last_activity_at` (WHERE merged IS NULL) |
| `leads_org_phone_partial_idx` | Phone lookup for dedupe | `organization_id, normalized_phone_number` (WHERE merged IS NULL) |
| `leads_org_branch_phone_partial_idx` | Branch-scoped phone lookup | `organization_id, branch_id, normalized_phone_number` (WHERE merged IS NULL) |

### 2. Trigram Indexes for ILIKE Search

Enabled `pg_trgm` extension and created GIN indexes:

- `leads_student_name_trgm_idx` - Fast `ILIKE '%search%'` on student names
- `leads_phone_number_trgm_idx` - Fast `ILIKE '%search%'` on phone numbers

### 3. Call Logs Index Fix

- **Dropped**: `call_logs_organization_id_device_call_id_index` (mismatched with lookup pattern)
- **Added**: `call_logs_org_counselor_device_unique_idx` (matches `get_call_log_by_device_id/3`)
- **Added**: `call_logs_lead_started_idx` - Lead call history
- **Added**: `call_logs_counselor_started_idx` - Counselor call history

### 4. Analytics Indexes

- `analytics_events_org_branch_occurred_idx` - Branch-scoped dashboard queries
- `analytics_events_org_occurred_type_idx` - Aggregation queries
- `analytics_daily_stats_org_branch_date_idx` - Daily stats lookup

### 5. Import Processing Indexes

- `import_rows_job_status_row_idx` - Main filter queries
- `import_rows_job_dedupe_assign_idx` - Dedupe/assignment filtering
- `import_rows_job_lead_idx` - Lead creation lookup
- `import_jobs_org_inserted_idx` - Job list queries
- `import_jobs_org_status_inserted_idx` - Filtered job lists

### 6. Activity/Followup Indexes

- `lead_activities_lead_occurred_idx` - Timeline queries
- `lead_followups_lead_status_due_idx` - Pending followups
- `lead_followups_user_status_due_idx` - Counselor followup dashboard

### 7. Call Recordings Indexes

- `call_recordings_counselor_status_recorded_idx` - Reports queries
- `call_recordings_call_status_idx` - Recording lookup by call

### 8. Users Index

- `users_org_branch_active_idx` - Counselor list queries

---

## Code Optimizations

### N+1 Query Fixes

#### `Reports.list_counselor_stats/2`

**Before**: 3 queries per counselor (N+1 pattern)
```elixir
Enum.map(counselors, fn counselor ->
  get_counselor_stats(counselor, ...)  # 3 queries each!
end)
```

**After**: 3 batch queries total using `GROUP BY`
```elixir
call_stats = fetch_call_stats_batch(counselor_ids, ...)      # 1 query
leads_counts = fetch_leads_counts_batch(counselor_ids, ...)  # 1 query
recordings_counts = fetch_recordings_counts_batch(...)        # 1 query
```

**Impact**: 50 counselors: 150 queries → 3 queries

#### `Reports.list_lead_calls_with_recordings/1`

**Before**: 1 query per call (N+1 pattern)
```elixir
Enum.map(calls, fn call ->
  recording = Repo.one(...)  # N+1!
end)
```

**After**: 2 queries total
```elixir
calls = Repo.all(...)
recordings = Repo.all(...) |> Map.new(...)  # batch fetch
```

**Impact**: 20 calls: 21 queries → 2 queries

### Analytics Fallback Fix

**Before**: Loaded all events into memory, counted in Elixir
```elixir
events = Repo.all(...)
Enum.count(events, &(&1.event_type == metric))
```

**After**: SQL aggregation
```elixir
|> group_by([e], e.event_type)
|> select([e], {e.event_type, count(e.id)})
|> Repo.all()
|> Map.new()
```

**Impact**: Memory usage reduced, faster execution

### Order By Optimization

**Before**: Using `coalesce()` prevents index usage
```elixir
order_by([l], desc: coalesce(l.last_activity_at, l.inserted_at))
```

**After**: Direct column ordering (with backfill migration)
```elixir
order_by([l], [desc: l.last_activity_at, desc: l.id])
```

**Impact**: Indexes can now be used for sorting

---

## Performance Expectations

| Query Type | Before | After |
|------------|--------|-------|
| Lead list (10k leads) | ~500ms | ~50ms |
| Counselor stats (50 counselors) | ~2s (150 queries) | ~100ms (3 queries) |
| Lead search (ILIKE) | Full scan | Index scan |
| Phone dedupe lookup | Seq scan | Index scan |
| Analytics dashboard | Memory-heavy | SQL aggregation |

---

## Monitoring Recommendations

Add these queries to your monitoring:

```sql
-- Check index usage
SELECT schemaname, tablename, indexname, idx_scan, idx_tup_read
FROM pg_stat_user_indexes
WHERE schemaname = 'public'
ORDER BY idx_scan DESC;

-- Find slow queries
SELECT query, calls, mean_time, total_time
FROM pg_stat_statements
ORDER BY mean_time DESC
LIMIT 20;

-- Check for sequential scans on large tables
SELECT relname, seq_scan, seq_tup_read, idx_scan, idx_tup_fetch
FROM pg_stat_user_tables
WHERE relname IN ('leads', 'call_logs', 'analytics_events')
ORDER BY seq_scan DESC;
```

---

## Future Improvements

1. **Keyset pagination** - Replace offset pagination for leads list when >100k rows
2. **Read replicas** - Route analytics/reporting queries to read replicas
3. **Table partitioning** - Partition `analytics_events` by month for faster queries
4. **Materialized views** - Pre-compute daily/weekly rollups for dashboards
