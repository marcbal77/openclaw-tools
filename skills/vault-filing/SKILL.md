---
name: vault-filing
description: Auto-file documents uploaded to any channel into a local vault directory. Use when ANY message contains file attachments (images, PDFs, scans, documents). Handles OCR, content analysis, naming, smart routing, dedup, and confirmation. Works across all channels.
---

# Vault Auto-Filing

## Vault Location

Configure your vault root path:

```
VAULT_PATH=~/vault/   # or ~/documents/vault/, ~/clawd/vault/, etc.
```

## Suggested Structure

```
vault/
├── <project-a>/           ← project-specific documents
├── <project-b>/
├── personal/
│   ├── health/            ← labs, medical, prescriptions, health receipts
│   ├── finance/           ← tax docs, W-2s, statements, invoices
│   ├── legal/             ← contracts, leases, court documents
│   ├── identity/          ← IDs, passports (manual only — never auto-file)
│   └── receipts/          ← general receipts (not covered above)
└── archive/
    ├── 2024/
    └── 2025/
```

Adapt the folder structure to your life. Add new top-level categories freely.

## Smart Routing

Route based on **content analysis**, with channel context as a hint only:

| Content Type | Vault Path | Channel Hints |
|---|---|---|
| Medical/lab/pharmacy/prescriptions | personal/health/ | #health |
| Tax/financial/bank/crypto/invoices | personal/finance/ | #finance |
| Legal/court/contracts | personal/legal/ | — |
| Project documents | `<project-folder>/` | project-specific channels |
| General receipts | personal/receipts/ | — |
| Identity docs (IDs, passports) | **ASK FIRST** | — |
| Ambiguous | **ASK USER** | — |

**Priority: content > channel.** A medical receipt dropped in any channel still goes to `personal/health/`.

## Procedure

When a message has file attachment(s):

1. **Locate** the file in `media/inbound/<file>` (workspace-relative)
2. **Analyze** content:
   - PDFs: extract text with `python3 -c "import pdfplumber; ..."` or `strings`
   - Images: use the `image` tool for OCR/vision analysis
3. **Route** using smart routing table above
   - Use channel as a hint but always verify via content
   - If ambiguous → ask user before filing
4. **Dedup** (BEFORE saving):
   - Hash: `md5 -q <file>` (macOS) or `md5sum <file>` (Linux)
   - Compare target folder: `find $VAULT_PATH/<path> -type f -exec md5 -q {} \;`
   - Match → **skip**, reply: "⚠️ Duplicate — already exists as `vault/<path>/<name>`"
5. **Rename** using convention: `YYYY-MM-DD_Source_Description.ext`
6. **Save:** `cp media/inbound/<file> $VAULT_PATH/<path>/<renamed>`
7. **Confirm:** "📁 Filed → `vault/<path>/<filename>`"
8. **Summarize** key content if useful (amounts, dates, key details)
9. **Continue discussion** normally — filing is additive, not a replacement for conversation

## Configuration Notes

- Adjust vault root and category folders to match your project structure
- Health receipts → `personal/health/` (keep with medical context)
- Project-specific receipts → project folder (keep with project context)
- General receipts only → `personal/receipts/`
- Identity documents: never auto-file, require explicit user instruction
- Create new vault subdirectories freely as new categories emerge

## Why This Pattern Works

- **Content-first routing** means the right document ends up in the right place regardless of which channel it was dropped in
- **Dedup before save** prevents archive bloat from duplicate uploads
- **Consistent naming** (`YYYY-MM-DD_Source_Description`) makes files instantly findable without search
- **Ask before filing ambiguous docs** preserves user trust — never silently misfile something important
