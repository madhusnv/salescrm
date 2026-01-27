# Sales CRM API Documentation

> **Last Updated**: January 25, 2026  
> **Backend**: Phoenix/Elixir v1.8  
> **Android App**: Kotlin + OkHttp  
> **Base URL**: Configured via `ApiConfig.BASE_URL`

---

## Table of Contents

1. [Authentication](#1-authentication)
2. [Leads](#2-leads)
3. [Call Logs](#3-call-logs)
4. [Recordings](#4-recordings)
5. [Assignment Rules](#5-assignment-rules)
6. [Universities](#6-universities)
7. [Counselor Stats](#7-counselor-stats)
8. [LiveView Routes](#8-liveview-routes)
9. [Android Clients](#9-android-clients)
10. [Backend Contexts](#10-backend-contexts)

---

## Authentication

**Header**: `Authorization: Bearer <access_token>`

### Rate Limits
| Endpoint | Limit | Window |
|----------|-------|--------|
| Login | 5 req | 60s |
| Refresh | 10 req | 60s |

---

## 1. Authentication

### POST `/api/auth/login`

**Request:**
```json
{
  "email": "string",
  "password": "string"
}
```

**Response (200):**
```json
{
  "access_token": "string",
  "refresh_token": "string",
  "token_type": "bearer",
  "expires_in": 3600,
  "user_id": 123,
  "user": {
    "id": 123,
    "email": "user@example.com",
    "full_name": "John Doe"
  }
}
```

### POST `/api/auth/refresh`

**Request:**
```json
{
  "refresh_token": "string"
}
```

---

## 2. Leads

> **Permissions**: `leads.read` (GET), `leads.update` (POST)

### GET `/api/leads`

| Param | Type | Default | Description |
|-------|------|---------|-------------|
| `page` | int | 1 | Page number |
| `page_size` | int | 20 | Items per page |
| `status` | string | - | Filter by status |
| `search` | string | - | Search name/phone |
| `counselor_id` | int | - | Filter by counselor |

**Response:**
```json
{
  "data": [{ "id": 1, "student_name": "...", "status": "..." }],
  "meta": { "page": 1, "page_size": 20, "total_count": 150 }
}
```

### POST `/api/leads`

**Request:**
```json
{
  "student_name": "string",
  "phone_number": "string",
  "university_id": 1
}
```

### GET `/api/leads/:id`

Returns lead with activities, followups, call_logs, recordings.

### POST `/api/leads/:id/status`

```json
{ "status": "contacted" }
```

### POST `/api/leads/:id/notes`

```json
{ "body": "Note text" }
```

### POST `/api/leads/:id/followups`

```json
{
  "due_at": "2026-01-26T10:00:00Z",
  "note": "optional"
}
```

---

## 3. Call Logs

### POST `/api/call-logs`

**Request:**
```json
{
  "phone_number": "+919876543210",
  "call_type": "outgoing",
  "device_call_id": "unique_id",
  "started_at": 1737800000,
  "ended_at": 1737800300,
  "duration_seconds": 300,
  "consent_granted": true
}
```

**Response:**
```json
{
  "data": { "id": 1, "call_type": "outgoing", ... },
  "status": "created"
}
```

### GET `/api/call-logs?lead_id=1`

Returns call logs for specified lead.

---

## 4. Recordings

> **Max Size**: 50MB  
> **Formats**: m4a, mp4, mpeg, wav, amr, ogg, 3gpp, aac

### POST `/api/recordings/init`

```json
{
  "lead_id": 1,
  "call_log_id": 1,
  "content_type": "audio/m4a",
  "consent_granted": true,
  "recorded_at": "2026-01-25T11:00:00Z"
}
```

**Response:**
```json
{
  "data": {
    "id": 1,
    "upload_url": "/api/recordings/1/upload",
    "storage_key": "recordings/5/uuid.m4a"
  }
}
```

### PUT `/api/recordings/:id/upload`

Binary body or multipart `file` field.

### POST `/api/recordings/:id/complete`

```json
{
  "status": "uploaded",
  "file_url": "/uploads/...",
  "file_size_bytes": 1024000,
  "duration_seconds": 300
}
```

### GET `/api/recordings?lead_id=1`

---

## 5. Assignment Rules

### GET `/api/assignment-rules`
### POST `/api/assignment-rules`

```json
{
  "assignment_rule": {
    "branch_id": 1,
    "university_id": 1,
    "counselor_id": 5,
    "is_active": true,
    "priority": 1,
    "daily_cap": 50
  }
}
```

### PUT `/api/assignment-rules/:id`
### DELETE `/api/assignment-rules/:id`

---

## 6. Universities

### GET `/api/universities`

```json
{
  "data": [
    { "id": 1, "name": "Example University" }
  ]
}
```

---

## 7. Counselor Stats

### GET `/api/counselor-stats?filter=today`

```json
{
  "data": {
    "total_calls": 25,
    "outgoing_calls": 15,
    "incoming_calls": 8,
    "missed_calls": 2,
    "total_duration_seconds": 7200,
    "leads_assigned": 10
  }
}
```

---

## 8. LiveView Routes

### Authenticated Routes
| Path | Description |
|------|-------------|
| `/dashboard` | Main dashboard |
| `/leads` | Lead list |
| `/leads/:id` | Lead details |
| `/imports/leads` | CSV import |
| `/assignments/rules` | Assignment rules |

### Admin Routes (`/admin`)
| Path | Description |
|------|-------------|
| `/admin/users` | User management |
| `/admin/branches` | Branch management |
| `/admin/universities` | University management |
| `/admin/recordings` | Recording management |
| `/admin/audit` | Audit logs |
| `/admin/counselor-reports` | Reports |

---

## 9. Android Clients

| Class | Endpoints |
|-------|-----------|
| `AuthApi` | `/api/auth/*` |
| `LeadApi` | `/api/leads/*`, `/api/universities` |
| `CallLogApi` | `/api/call-logs` |
| `RecordingApi` | `/api/recordings/*` |
| `StatsApi` | `/api/counselor-stats` |

---

## 10. Backend Contexts

| Context | Responsibility |
|---------|---------------|
| `Accounts` | User auth, tokens |
| `Leads` | Lead CRUD, activities |
| `Calls` | Call log management |
| `Recordings` | Recording uploads |
| `Assignments` | Lead assignment rules |
| `Organizations` | Multi-tenancy |
| `Reports` | Counselor reports |
| `Audit` | Audit logging |
