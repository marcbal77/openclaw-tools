# openclaw-tools

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![OpenClaw](https://img.shields.io/badge/OpenClaw-Agent%20Tools-orange)](https://github.com/nichochar/open-claw)

Production-tested templates, scripts, and patterns for building autonomous AI agent workflows on [OpenClaw](https://github.com/nichochar/open-claw).

Born from months of running a 24/7 AI agent system — these are the patterns that survived production. Sanitized for public use.

## Who This Is For

- **OpenClaw users** who want a proven starting point for agent configuration
- **AI agent builders** looking for battle-tested operational patterns
- **Anyone** running persistent AI agents who needs memory, self-improvement, and reliability systems

## What's Included

### Templates (`templates/`)

| File | Purpose |
|---|---|
| **AGENTS.md** | Complete agent workspace configuration — session startup, memory, CEO Mode, Boris Loop, heartbeats, group chat behavior, task lifecycle |
| **SOUL.md** | Agent identity template — define personality, values, mission, boundaries |
| **HEARTBEAT.md** | Proactive heartbeat checklist — what to check, when to speak, when to stay quiet |
| **MEMORY.md** | Long-term memory template — curated knowledge that persists across sessions |
| **daily-note.md** | Daily log template (`memory/YYYY-MM-DD.md`) — raw session notes |
| **lessons.md** | Boris Loop anti-pattern tracker — capture corrections, never repeat mistakes |
| **heartbeat-state.json** | State tracking for heartbeat rotation — avoid redundant checks |

### Scripts (`scripts/`)

| File | Purpose |
|---|---|
| **smoke-test.sh** | Infrastructure smoke test framework with `run_test`/`run_warn` runners, `--json` output, colored terminal output, fix hints, and exit codes |
| **gateway-watchdog.sh** | Gateway health monitor with graduated response: wait → restart → rollback config to last-known-good. Includes webhook alerting, log rotation, and crash-loop detection |

## Key Patterns

### The Boris Loop (Self-Improvement)
After any correction or mistake:
1. Add the pattern to `memory/lessons.md` (Date | Trigger | Lesson | Rule)
2. Review lessons.md at every session start
3. If the same mistake appears twice, escalate to AGENTS.md as a permanent rule

Every correction compounds into permanent improvement.

### CEO Mode (Context Preservation)
Main session = CEO. It plans, delegates, and responds — it does NOT do work.
- All research, coding, and deep work → spawn subagents
- Main session stays light → fewer compactions → better continuity
- Instant response time = trust

### Graduated Watchdog Response
1. **1st failure** → log, wait (could be transient)
2. **2nd failure** → attempt restart
3. **3rd+ failure** → rollback config + restart + alert
4. **Max rollbacks exceeded** → back off + manual intervention alert

### Memory Architecture
```
MEMORY.md           → curated long-term memory (loaded in main session only)
memory/
  YYYY-MM-DD.md     → raw daily logs
  lessons.md        → Boris Loop anti-patterns
  heartbeat-state.json → check rotation state
```

## Quick Start

1. **Copy templates** to your OpenClaw workspace:
   ```bash
   cp templates/AGENTS.md ~/your-workspace/AGENTS.md
   cp templates/SOUL.md ~/your-workspace/SOUL.md
   cp templates/HEARTBEAT.md ~/your-workspace/HEARTBEAT.md
   mkdir -p ~/your-workspace/memory
   cp templates/MEMORY.md ~/your-workspace/MEMORY.md
   cp templates/lessons.md ~/your-workspace/memory/lessons.md
   cp templates/heartbeat-state.json ~/your-workspace/memory/heartbeat-state.json
   ```

2. **Customize SOUL.md** with your agent's identity and values.

3. **Edit AGENTS.md** to match your workflow — add/remove sections as needed.

4. **Set up scripts** (optional):
   ```bash
   cp scripts/smoke-test.sh ~/your-workspace/scripts/
   cp scripts/gateway-watchdog.sh ~/your-workspace/scripts/
   chmod +x ~/your-workspace/scripts/*.sh
   ```

5. **Customize smoke tests** — replace placeholder checks with your actual services and APIs.

6. **Configure watchdog alerts** — create a webhook env file with your alert URL:
   ```bash
   echo "ALERT_WEBHOOK_URL=https://your-webhook-url-here" > ~/.secrets/alert-webhook.env
   ```

## Contributing

Issues and PRs welcome. If you've built patterns that survived production use with OpenClaw agents, share them.

## License

MIT — see [LICENSE](LICENSE).
