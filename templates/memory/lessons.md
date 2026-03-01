# lessons.md — The Boris Loop

> Anti-patterns and corrections. Reviewed every session.
> When you make a mistake or receive a correction, log it here.
> Categorize by type. Include context so future sessions understand WHY.

---

## Workflow Lessons

- **Always follow the task lifecycle** — set status to `in_progress` BEFORE spawning
  work. Don't skip steps. (Context: tasks moved to done without going through review
  caused missed issues)

- **Stop when asked to present a plan** — present the plan, wait for approval, THEN
  build. Don't present and start building simultaneously.

- **Questions = FULL STOP** — when the human asks a question, answer it first.
  Don't continue working while they're waiting for a response.

- **Research before building** — don't skip the research phase. Understanding the
  problem space prevents wasted effort on wrong approaches.

- **Multi-phase plans: complete ALL phases** — don't stop after phase 1 and call it done.
  If you can't finish, explicitly check in before stopping.

---

## Communication Lessons

- **Production code changes = always ask** — branch → PR → human reviews.
  Never push directly to main for production code.

- **When given edited text, USE IT EXACTLY** — don't rewrite, rephrase, or "improve"
  text the human has already edited. They chose those words deliberately.

- **If you ask a question, WAIT for the answer** — don't ask a question and then
  proceed as if you already know the answer.

- **When a tool fails, try alternatives** — don't immediately escalate to the human.
  Try the next tool in the chain first.

---

## Technical Lessons

- **Validate config before writing** — never write unvalidated keys to config files.
  Invalid config can cause crash-loops.

- **Run upgrade scripts after version changes** — dependency version changes often
  require post-upgrade scripts. Don't skip them.

- **Use correct HTTP methods** — PATCH for partial updates, not PUT. Check the API
  documentation first.

- **Never move tasks directly to done** — ALWAYS go through review first:
  `backlog → in_progress → review → done`

---

## Template Entry

> Copy this when adding a new lesson:

```
- **<LESSON_TITLE>** — <DESCRIPTION_OF_WHAT_WENT_WRONG>.
  (Context: <WHAT_HAPPENED_AND_WHY_THIS_MATTERS>)
```
