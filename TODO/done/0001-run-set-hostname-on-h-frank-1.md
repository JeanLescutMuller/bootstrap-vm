---
# ── What
id: bootstrap-vm#1
type: one-off
title: Run set_hostname.sh on H-Frank-1 (needs your sudo password)
category: ops
# ── Who
owner: Jean
autonomy:
# ── Urgency
priority: 7 days
estimated_work_duration: 2 min
# ── When
not_before:
planned_at: 2026-10-11[Europe/Zurich]
not_after:
# ── Status and claim
status: todo
claimed_since:
claimed_by:
# ── Links
depends_on: []
todoist_id: 6hjCx2xx524xjjvV
# ── Origin
created_at: 2026-10-10T18:52+02:00[Europe/Zurich]
created_by: chan-lescut-macbook-pro, claude, ee3c8ee2-75f8-4935-9858-034a4100e230
---
## Context

The VM's name `H-Frank-1` is right today, but cloud-init has `preserve_hostname: false`, so the provider's metadata could reset it at a boot, and every project keys its data by this name. `01_unix_helpers/set_hostname.sh` (`bc824f8`) sets it for good. It needs root, and the VM's sudo asks for a password. From the Mac:

```bash
scp ~/dev/bootstrap-vm/01_unix_helpers/set_hostname.sh H-Frank-1:/tmp/ && ssh -t H-Frank-1 'sudo bash /tmp/set_hostname.sh H-Frank-1 && cat /etc/cloud/cloud.cfg.d/99-preserve-hostname.cfg'
```

## Done when

The command ends without error and prints `preserve_hostname: true`.

## History

- 2026-10-10: created

## Links

- bootstrap-home `files/home_AGENTS.md` "Machine name"

## Result
