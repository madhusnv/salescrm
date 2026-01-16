# Role matrix and branch scoping

## Scoping rules
- Organization-scoped: all data belongs to a single organization.
- Branch-scoped: branch managers and counselors can only access data for their branch.
- Cross-branch: super admin can access all branches.
- Recording access: limited to super admin and branch manager.

## Permissions (seed list)
- org.manage
- branch.manage
- user.manage
- role.manage
- permission.manage
- lead.import
- lead.assign
- lead.read
- lead.update
- call.read
- call.write
- recording.read
- recording.review
- analytics.read

## Role to permission mapping
| Role | Scope | Key permissions |
| --- | --- | --- |
| Super Admin | All branches | org.manage, branch.manage, user.manage, role.manage, permission.manage, lead.import, lead.assign, lead.read, lead.update, call.read, call.write, recording.read, recording.review, analytics.read |
| Branch Manager | Own branch | branch.manage, user.manage, lead.import, lead.assign, lead.read, lead.update, call.read, call.write, recording.read, recording.review, analytics.read |
| Counselor | Own branch + assigned universities | lead.read, lead.update, call.write |
| Compliance/Audit | All branches (read-only) | call.read, recording.read, analytics.read |
