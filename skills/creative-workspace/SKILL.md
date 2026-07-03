---
name: creative-workspace
description: Initialize or health-check a local creative workspace for bulk ad launching. Scaffolds the folder convention (BRAND.md, assets/, campaigns/, .adup/ state), asks the one-time platform-enhancements question, and runs structural doctor checks. The workspace feeds /adup:launch, /adup:status, and /adup:creative-import.
---

# Creative Workspace (init + doctor)

A creative workspace is a local folder — one per client/brand — that is the **source of truth** for ads: markdown copy + ratio-named media files. Claude validates, uploads, and proposes ads from it; humans approve in the ADUP portal.

**Invariant (restate to the user whenever relevant): nothing in this workspace ever reaches an ad platform directly. Launching creates PROPOSALS that must be approved in the ADUP portal, and even approved ads always land PAUSED on the platform.**

Modes:
- `/adup:creative-workspace init [folder]` — scaffold a new workspace
- `/adup:creative-workspace doctor [folder]` — structural health check (report only, never modifies content)

---

## Workspace convention (reference)

```
acme-nl/                              ← workspace root = ONE shop (agency: sibling folders per client)
├── BRAND.md                          ← tone of voice, do/don'ts (Claude reads this when writing copy)
├── .adup/                            ← machine-owned; do not hand-edit
│   ├── workspace.json                ← shop_slug + defaults (platforms, language, enhancements)
│   └── state.json                    ← sync ledger (asset checksums → asset_ids; ads → proposal ids)
├── assets/                           ← SHARED creative library (one video reused by 10 ads = stored once)
│   └── summer-sale/                  ← concept folder
│       ├── hero_1x1.jpg              ← {concept}_{ratio}[_{lang}].{ext}
│       ├── hero_4x5.jpg
│       └── hero_9x16.mp4
└── campaigns/
    └── 2026-07_summer-sale/          ← campaign folder
        ├── _campaign.md              ← objective, budget, schedule, platforms, map: (target ids)
        └── prospecting-broad/        ← ad set folder
            ├── _adset.md             ← audience notes + map: (existing adset/adgroup ids)
            └── hero-video/           ← ad folder
                └── ad.md             ← frontmatter + copy sections
```

- **Ratio tokens** in filenames: `1x1`, `4x5`, `9x16`, `16x9`, `191x100`. All files sharing a concept prefix (`hero_*`) form one **creative group** → one multi-placement ad. The token must match the file's actual pixels (validated by `scripts/inspect.sh`; mismatch = validation error at launch).
- Optional language suffix: `hero_9x16_nl.mp4` is used for the `nl` variant only.
- **Ad lifecycle** (`status:` in ad.md): `draft` → `ready` → `uploaded` → `proposed` → `approved` → `live` (still PAUSED on-platform). Side exits: `changes_requested` (denial notes written into `## Review feedback`), `rejected`.

---

## Mode: init

### Step 1 — Pick the shop

Call `list_shops` on the adup connector. Show the list and ask which client this workspace is for (skip the question for solo accounts with one shop). Then call `set_active_shop(shop_slug="<slug>")`.

### Step 2 — Pick the folder

Ask where to create the workspace if no folder was given. Suggest `~/Documents/ADUP-Creatives/<shop-slug>/`. Never scaffold inside an existing non-empty folder without confirmation.

### Step 3 — Ask the enhancements question (ONCE, at init only)

Ask exactly once:

> Ad platforms can automatically "enhance" your creatives (Meta Advantage+ features: auto-translation, image animation, added music, visual touch-ups, format changes; TikTok has similar Smart Creative options). Many brands block these to keep full control of how their creative renders. How should this workspace handle them?
>
> - **off** (recommended, default) — block all automatic enhancements on every ad we create
> - **ask** — ask at each launch
> - **on** — allow the platform's enhancements

Store the answer in `workspace.json` under `defaults.enhancements`. Default to `off` if the user has no preference. Never ask this again for this workspace (the doctor and launch skills read it from `workspace.json`).

### Step 4 — Ask for defaults

- Default platforms for new ads (e.g. `["facebook", "tiktok"]`). Only facebook and tiktok support creation today; google, linkedin, and snapchat are **not yet supported for creation** — they can be listed but /adup:launch will skip them with a note.
- Default language (e.g. `"en"`).

### Step 5 — Scaffold

Create the tree exactly as below (substitute the real slug/answers):

**`.adup/workspace.json`**
```json
{
  "version": 1,
  "shop_slug": "acme-nl",
  "defaults": {
    "platforms": ["facebook", "tiktok"],
    "language": "en",
    "enhancements": "off"
  }
}
```

**`.adup/state.json`**
```json
{
  "version": 1,
  "assets": {},
  "ads": {}
}
```

**`BRAND.md`**
```markdown
# Brand: Acme NL

## Tone of voice
<!-- e.g. Confident but warm. Short sentences. No exclamation marks. -->

## Do
<!-- e.g. Lead with the customer benefit. Always mention free shipping. -->

## Don't
<!-- e.g. Never use discount percentages above 30%. No emoji in headlines. -->
```

**`assets/`** — empty folder (add a `.gitkeep`).

**`campaigns/_example/_campaign.md`** — commented example campaign:
```markdown
---
# EXAMPLE CAMPAIGN — copy this folder, rename it (e.g. 2026-07_summer-sale), delete this comment block.
name: Summer Sale 2026
objective: conversions
platforms: [facebook, tiktok]        # overrides workspace default; ads can narrow further
languages: [en]                      # copy variants to produce
budget:
  daily: 100
  currency: EUR
schedule:
  start: 2026-07-10
  end: 2026-08-10
map:                                 # WHERE ads land, per platform. v1: use EXISTING ids.
  facebook:
    campaign_id: "1202100000000000"  # from Ads Manager, or `create: true` (two-phase: approve campaign first)
  tiktok:
    campaign_id: "1780000000000000"
---

Free-form campaign notes for context (audience insights, promo details, deadlines).
```

**`campaigns/_example/prospecting-broad/_adset.md`**:
```markdown
---
name: Prospecting Broad
map:
  facebook:
    adset_id: "1202100000000001"     # existing ad set id
  tiktok:
    adgroup_id: "1780000000000001"   # existing ad group id
    identity_id: "7000000000000001"  # from tiktok__get_tiktok_identities (required for TikTok ads)
---

Audience / placement notes.
```

**`campaigns/_example/prospecting-broad/hero-video/ad.md`**:
```markdown
---
status: draft                        # draft → ready → uploaded → proposed → approved → live
format: single                       # single | video | carousel
creative: summer-sale/hero           # creative group: matches assets/summer-sale/hero_*.{jpg,mp4}
                                     # (a Google Drive/Dropbox share link also works here)
link: https://acme.nl/summer-sale
cta: SHOP_NOW                        # SHOP_NOW | LEARN_MORE | SIGN_UP | CONTACT_US | BOOK_TRAVEL
languages: [en]                      # overrides campaign languages for this ad
---

## Primary text
Summer's best deals are live. Up to 30% off the whole collection — free shipping, always.

## Primary text (tiktok)
Up to 30% off everything. Free shipping. Go.

## Headline
Summer Sale — up to 30% off

## Description
Free shipping on every order.
```

Per-platform and per-language copy variants use qualified section headings, most specific wins:
`## Primary text (tiktok, nl)` > `## Primary text (nl)` / `## Primary text (tiktok)` > `## Primary text`.
Carousel ads add `## Card 1` … `## Card N` sections (each with its own text + optional `link:` line) and card assets named `card1_1x1.jpg`, `card2_1x1.jpg`, …

### Step 6 — Offer git init

Ask: "Want version history for this workspace? I can run `git init` so every copy/creative change is tracked." If yes:

```bash
cd <workspace-root> && git init && printf '.adup/state.json\n.DS_Store\n' > .gitignore && git add -A && git commit -m "Initialize ADUP creative workspace"
```

(`state.json` is machine-owned sync state — keep it out of git; `workspace.json` IS committed.)

### Step 7 — Wrap up

Summarize: workspace path, shop, defaults, enhancements answer. Tell the user:
> Drop media into `assets/<concept>/` using ratio names (`hero_1x1.jpg`, `hero_9x16.mp4`), write ads as `ad.md` files, then run `/adup:launch`. Everything I launch becomes a **proposal** for approval in the ADUP portal, and approved ads always start **PAUSED**.

---

## Mode: doctor

Read-only structural check. **Never modify any file content — report findings and a fix list only.** (The only acceptable write is nothing; even obviously-wrong frontmatter is reported, not fixed.)

Run these checks from the workspace root:

1. **Workspace integrity** — `.adup/workspace.json` exists, parses, has `shop_slug` and `defaults`. `state.json` exists and parses.
2. **Shop reachable** — `shop_slug` appears in `list_shops` output (warn if not: key may lack access).
3. **Orphan assets** — files under `assets/` whose concept group is not referenced by any `ad.md` `creative:` field. (Informational — orphans cost nothing until uploaded.)
4. **Missing creative groups** — every `ad.md` `creative:` value resolves to ≥1 file in `assets/` (or is an https/Drive link). An ad with `status: ready|uploaded|proposed` and no files = error.
5. **Stale state entries** — `state.json` assets whose checksum matches no current local file (renamed is fine — keyed by checksum, so only report when the bytes are gone); `state.json` ads whose folder path no longer exists.
6. **Ratio-token vs pixels** — for each asset file with a ratio token, run:
   ```bash
   bash <plugin>/skills/creative-workspace/scripts/inspect.sh <file>
   ```
   and compare `aspect_label` to the filename token. Mismatch = error (would fail at launch).
7. **Frontmatter completeness** — every `ad.md` has `status`, `format`, `creative`, `link`, `cta`; `_campaign.md` in scope has `map:` entries for every platform its ads target; TikTok-targeting ad sets have `identity_id` in `_adset.md`.
8. **Lifecycle sanity** — `status: proposed|approved|live` ads exist in `state.json` with proposal ids (otherwise state was lost — suggest re-running /adup:launch, which is idempotent by checksum).

Output a table: `check | status (OK/WARN/ERROR) | detail`, followed by a numbered **fix list** ("1. Rename assets/summer-sale/hero_4x5.jpg — actual pixels are 1080x1080 (1x1)…"). Offer to apply fixes only if the user explicitly asks, one confirmation per fix.
