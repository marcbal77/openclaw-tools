# OpenClaw Tools

Templates, scripts, and patterns for building AI-powered agent workflows.

Born from real-world experience running autonomous AI agents in production — these are the patterns that survived contact with reality.

## What's Inside

### Templates

| File | Purpose |
|---|---|
| `templates/AGENTS.md` | Agent operating manual — workflow patterns, task lifecycle, CEO Mode, subagent strategy, safety rules |
| `templates/SOUL.md` | Agent identity template — define personality, values, boundaries, and mission |
| `templates/HEARTBEAT.md` | Heartbeat checklist — structured periodic health checks with smart rotation |
| `templates/memory/MEMORY.md` | Long-term memory template — curated knowledge that persists across sessions |
| `templates/memory/daily-note.md` | Daily note template — session logs, events, and end-of-day summaries |
| `templates/memory/lessons.md` | The Boris Loop — anti-pattern log for continuous self-improvement |

### Scripts

| File | Purpose |
|---|---|
| `scripts/smoke-test.sh` | Infrastructure smoke test suite — verify integrations after system changes |
| `scripts/gateway-watchdog.sh` | Graduated response watchdog — auto-recover services with crash-loop detection |

## Key Patterns

### CEO Mode
The main agent session acts as an orchestrator — it never does inline work. All research, code, and diagnostics are delegated to subagents. This preserves the main session's context window for decision-making and communication.

### The Boris Loop
A self-improvement pattern: every mistake gets logged to `lessons.md`, categorized, and reviewed at session startup. The agent gets better over time, not just within a session.

### Task Lifecycle
Every task follows `backlog → in_progress → review → done`. No skipping steps. Status must be set before work begins, and self-verification happens before review.

### Graduated Watchdog
The watchdog script implements a graduated response to failures:
1. **First failure:** Log and wait
2. **Second failure:** Attempt restart
3. **Third+ failure:** Rollback config, restart, alert

With cooldown protection to prevent infinite rollback loops.

### Memory System
Three-tier memory: daily notes (session context), long-term memory (curated knowledge), and lessons learned (anti-patterns). Designed to survive context compaction events.

## Getting Started

1. **Copy the templates** into your agent's project root:
   ```bash
   cp -r templates/* ~/my-agent-project/
   ```

2. **Customize `SOUL.md`** — give your agent a name, mission, and personality

3. **Set up the memory directory:**
   ```bash
   mkdir -p memory
   cp templates/memory/* memory/
   ```

4. **Configure the smoke test** — edit `scripts/smoke-test.sh` to match your infrastructure

5. **Point your agent's startup sequence** at `AGENTS.md` — this becomes the operating manual

## Philosophy

- **Ship > Perfect** — working systems over polished plans
- **Log everything** — if it's not logged, it didn't happen
- **Fail gracefully** — graduated responses, not binary crash/success
- **Learn from mistakes** — systematic correction, not just apologies
- **Context is precious** — delegate work, preserve the orchestrator

## Contributing

Issues and PRs welcome. If you've built patterns that survived production use, we'd love to see them.

## License

MIT License — see [LICENSE](LICENSE) for details.
