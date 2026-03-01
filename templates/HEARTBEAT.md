# HEARTBEAT.md

A heartbeat checklist for your OpenClaw agent. Edit this file to define what
your agent checks on each heartbeat poll. Keep it small to limit token burn.

## Infrastructure
- [ ] Run smoke test if system change detected: `./scripts/smoke-test.sh --json` — alert human on any FAIL results
- [ ] Check your task tracker health endpoint — if down, restart service

## Communication Checks (rotate — pick 1-2 per heartbeat)
- [ ] Scan inbox channel for unevaluated items
- [ ] Check daily brief channel — did I post today?
- [ ] Check main channel for unanswered human messages

## Smart Rotation (check state file, skip if checked <4h ago)
- [ ] Social media mentions
- [ ] Task tracker: any in-progress tasks stalled?

## Weekly (rotate through — one per day)
- [ ] Review workspace setup — any improvements?
- [ ] Check memory files — anything to consolidate to MEMORY.md?
- [ ] Review backlog — any stale items?

## State File
Track last checks in `memory/heartbeat-state.json`
Update timestamps after EACH check so you don't repeat within 4h.
