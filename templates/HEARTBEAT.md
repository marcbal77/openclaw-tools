# HEARTBEAT.md — Heartbeat Checklist Template

> This file defines what your agent checks on every heartbeat poll.
> Heartbeats are periodic check-ins — use them productively, not just as acknowledgments.

---

## Infrastructure (EVERY heartbeat — do first)

These checks run on every single heartbeat. Infrastructure health is always priority #1.

- [ ] **Subagent Status** — Check all recent subagents (last 60 min)
  - Deliver completed results immediately
  - Alert on stuck subagents (running >20 min without output)
  - Alert on failed subagents
- [ ] **Core Service Health** — Ping your primary service health endpoint
  ```bash
  curl -s https://<YOUR_SERVICE_URL>/api/health
  ```
  - If down: attempt rebuild/restart, then alert the human operator
- [ ] **Smoke Test** (only after system changes)
  ```bash
  ./scripts/smoke-test.sh --json
  ```

---

## Communication Checks (rotate 1-2 per heartbeat)

Don't check everything every time — rotate through these:

- [ ] **Primary Channel** — Check for new messages requiring response
- [ ] **Inbox / Notifications** — Check for mentions, DMs, or alerts
- [ ] **Task Queue** — Check for new assigned tasks

---

## Smart Rotation (skip if checked recently)

These checks have cooldown periods. Skip if last checked less than N hours ago.

| Check | Cooldown | Description |
|---|---|---|
| Social mentions | 4 hours | Check social media mentions/replies |
| Task board review | 4 hours | Review in-progress tasks for blockers |
| System metrics | 6 hours | Check resource usage, error rates |

---

## Weekly Checks (one per day, spread across the week)

| Day | Check |
|---|---|
| Monday | Stack/dependency update review |
| Tuesday | Communication workspace review |
| Wednesday | Memory consolidation |
| Thursday | Project backlog grooming |
| Friday | Cost/usage review |
| Saturday | Toolbox & integration watchlist |
| Sunday | Weekly retrospective |

---

## State Tracking

Track when each check was last performed to avoid redundant work.

**State file:** `memory/heartbeat-state.json`

```json
{
  "lastChecked": {
    "coreServiceHealth": 0,
    "socialMentions": 0,
    "primaryChannel": 0,
    "taskBoard": 0,
    "smokeTest": 0,
    "weeklyReview": 0,
    "memoryConsolidation": 0,
    "toolboxWatchlist": 0
  },
  "notes": ""
}
```

Update timestamps (Unix epoch) after each check. Read this file at heartbeat start
to determine which checks to run this cycle.

---

## Heartbeat vs Cron

| Use Heartbeats For | Use Crons For |
|---|---|
| Reactive checks (is X healthy?) | Scheduled deliverables (daily brief) |
| Status monitoring | Reports and summaries |
| Quick rotational checks | Time-specific tasks |
| Subagent management | Autonomous background work |

---

## Anti-Patterns

- **Don't just reply "OK"** — every heartbeat should accomplish something
- **Don't check everything every time** — use rotation and cooldowns
- **Don't skip infrastructure** — always check subagents and core health first
- **Don't forget to update state** — stale timestamps lead to redundant work
