# OpenClaw Tools

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![OpenClaw](https://img.shields.io/badge/Built%20for-OpenClaw-orange)](https://github.com/nichochar/open-claw)

Production-tested templates and scripts for autonomous AI agent workflows. Not theory — patterns extracted from a 24/7 agent system that's been running in production. They've been simplified, stress-tested, and sanitized for general use.

## What's Here

### Templates

| File | What it does |
|---|---|
| `templates/AGENTS.md` | The operating manual. CEO Mode, task lifecycle, subagent strategy, safety rules, context preservation. |
| `templates/SOUL.md` | Give your agent an identity — name, values, mission, and behavioral boundaries. |
| `templates/HEARTBEAT.md` | Structured heartbeat checks with rotation logic. Turns heartbeats from noisy acknowledgments into useful periodic work. |
| `templates/memory/MEMORY.md` | Long-term curated memory. Survives compaction. Stays under 200 lines. |
| `templates/memory/daily-note.md` | Per-session logs. Keeps context alive across restarts. |
| `templates/memory/lessons.md` | The Boris Loop — anti-pattern log for compounding improvement over time. |

### Scripts

| File | What it does |
|---|---|
| `scripts/smoke-test.sh` | Infrastructure health suite. Runs after system changes. Supports `--json` for CI integration. |
| `scripts/gateway-watchdog.sh` | Service monitor with graduated response: log → restart → config rollback → alert. Crash-loop detection + cooldown protection. |

## Key Patterns

**CEO Mode** — The main agent orchestrates; it never grinds. All implementation work goes to subagents. Result: the main session stays light, responds instantly, and compacts less often.

**The Boris Loop** — Every mistake gets logged to `lessons.md` with context and a rule. Every session starts by reading those lessons. Corrections compound. The agent gets measurably better over time.

**Task Lifecycle** — `backlog → in_progress → review → done`. Status moves *before* work starts. Self-verification happens *before* review. No skipping. This discipline is what separates agents that drift from ones that ship.

**Graduated Watchdog** — Services fail. The script handles it without drama: wait once, restart on the second failure, roll back config and alert on the third. Max rollbacks per hour prevents runaway recovery loops.

**Three-Tier Memory** — Daily notes for session context, `MEMORY.md` for curated long-term knowledge, `lessons.md` for operational corrections. Each file has a specific role; none pollute the others.

## Getting Started

```bash
# Copy templates to your agent workspace
cp -r templates/* ~/my-agent-project/

# Set up memory directory
mkdir -p ~/my-agent-project/memory
cp templates/memory/* ~/my-agent-project/memory/

# Make scripts executable
chmod +x scripts/*.sh
```

Then:
1. **Edit `SOUL.md`** — fill in your agent's name, mission, and values
2. **Edit `AGENTS.md`** — remove sections that don't apply, add your own patterns
3. **Configure `smoke-test.sh`** — replace the placeholder checks with your actual services
4. **Point your agent's startup sequence at `AGENTS.md`** — this becomes the operating manual

## Philosophy

- **Ship > perfect.** Working systems beat polished plans.
- **Log everything.** If it's not logged, it didn't happen.
- **Fail gracefully.** Graduated responses, not binary crash/success.
- **Learn from mistakes.** Systematic correction, not just apologies.
- **Context is precious.** Delegate work aggressively. Protect the orchestrator.

## Contributing

If you've built patterns that survived production, PRs are welcome. The bar is simple: did it hold up when things went sideways?

## License

MIT — see [LICENSE](LICENSE).
