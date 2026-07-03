---
name: creative-workspace
description: Initialize or health-check a local creative workspace for bulk ad launching. Scaffolds the folder convention (BRAND.md, assets/, campaigns/, .adup/ state), asks the one-time platform-enhancements question, and runs structural doctor checks. The workspace feeds /adup:launch, /adup:status, and /adup:creative-import.
---

# Creative Workspace (init + doctor)

A creative workspace is a local folder — one per client/brand — that is the **source of truth** for ads: markdown copy + media files. **Files can be named anything** — Claude detects each file's ratio and format from its actual pixels/duration, not its name. Claude validates, uploads, and proposes ads from it; humans approve in the ADUP portal.

**Invariant (restate to the user whenever relevant): nothing in this workspace ever reaches an ad platform directly. Launching creates PROPOSALS that must be approved in the ADUP portal, and even approved ads always land PAUSED on the platform.**

Modes:
- `/adup:creative-workspace init [folder]` — scaffold a new workspace
- `/adup:creative-workspace doctor [folder]` — structural health check (report only, never modifies content)
- `/adup:creative-workspace doctor --grouping [folder]` — grouping preview: show how assets would be grouped and mapped at launch, nothing else

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
│       ├── hero_1x1.jpg              ← naming is optional — Tara detects ratios automatically
│       ├── hero_4x5.jpg              ←   (tokens shown here purely for human readability)
│       └── hero_9x16.mp4
└── campaigns/
    └── 2026-07_summer-sale/          ← campaign folder
        ├── _campaign.md              ← objective, budget, schedule, platforms, map: (target ids)
        └── prospecting-broad/        ← ad set folder
            ├── _adset.md             ← audience notes + map: (existing adset/adgroup ids)
            └── hero-video/           ← ad folder
                └── ad.md             ← frontmatter + copy sections
```

- **Detection first — name files ANYTHING.** Each file's ratio (`1x1`, `4x5`, `9x16`, `16x9`, `191x100`) and format (image/video) are determined from its **actual pixels and duration**: locally via `scripts/inspect.sh`, and authoritatively from the server's extracted metadata after upload. The filename is never the source of truth.
- **Creative groups** (one group → one multi-placement ad) are formed in this order:
  1. An ad.md's `creative:` field lists **explicit files** or a **folder** — that IS the group.
  2. Otherwise, files in the same `assets/` subfolder group by **stem similarity**: strip extensions, separators (`-`, `_`, spaces), and resolution/ratio suffixes (`1080x1080`, `9x16`, `story`, `square`, …), then cluster near-identical stems (`Hero Final.jpg` + `hero-final-story.mp4` → one group).
  3. When ambiguity remains, Claude shows its proposed grouping table (`file → detected ratio → group → placements`) and asks ONE confirmation before proceeding — it never guesses silently on ambiguity.
- **Ratio tokens in filenames are an OPTIONAL hint.** When a token is present and matches detection: silent. When it contradicts detection: **detection wins** and a warning is shown (this is a warning, not an error — the file still launches with its detected ratio).
- Optional language suffix: `hero_9x16_nl.mp4` is used for the `nl` variant only (language cannot be detected from pixels, so this one convention stays name-based).
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

- Default platforms for new ads (e.g. `["facebook", "tiktok"]`). Creation is supported for facebook, tiktok, google (RSA text ads only — no media), and linkedin (single image/video ads); snapchat is **not yet supported for creation** — it can be listed but /adup:launch will skip it with a note.
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
                                     # Map EVERY platform the campaign may run on — even ones an ad
                                     # doesn't target yet: /adup:launch embeds all of them as
                                     # metadata.platform_targets so a portal reviewer can tick
                                     # "also launch on X" and the backend can auto-create the replica.
  facebook:
    campaign_id: "1202100000000000"  # from Ads Manager, or `create: true` (two-phase: approve campaign first)
  tiktok:
    campaign_id: "1780000000000000"
    identity_id: "7000000000000001"  # from tiktok__get_tiktok_identities; campaign-level default
                                     # (an _adset.md map.tiktok.identity_id overrides it)
  snapchat:
    adsquad_id: "aaaa1111-..."       # existing ad squad id
    brand_name: "Acme"               # optional: brand name shown on Snap ads (defaults to shop name)
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
creative: summer-sale/hero           # creative group: a folder (assets/summer-sale/), explicit file list,
                                     # or a stem prefix — ratios are DETECTED from pixels, not names
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
Carousel ads add `## Card 1` … `## Card N` sections (each with its own text + optional `link:` line) and one asset per card — list them explicitly per card (a `creative:` line inside each `## Card n` section) or name them `card1*`, `card2*`, … so the card order is unambiguous. Card ratios are detected from pixels like everything else.

### Step 6 — Offer git init

Ask: "Want version history for this workspace? I can run `git init` so every copy/creative change is tracked." If yes:

```bash
cd <workspace-root> && git init && printf '.adup/state.json\n.DS_Store\n' > .gitignore && git add -A && git commit -m "Initialize ADUP creative workspace"
```

(`state.json` is machine-owned sync state — keep it out of git; `workspace.json` IS committed.)

### Step 7 — Wrap up

Summarize: workspace path, shop, defaults, enhancements answer. Tell the user:
> Drop media into `assets/<concept>/` — **any file names work**, I detect each file's ratio and format from its actual pixels. Write ads as `ad.md` files, then run `/adup:launch`. Everything I launch becomes a **proposal** for approval in the ADUP portal, and approved ads always start **PAUSED**.

---

## Mode: doctor

Read-only structural check. **Never modify any file content — report findings and a fix list only.** (The only acceptable write is nothing; even obviously-wrong frontmatter is reported, not fixed.)

Run these checks from the workspace root:

1. **Workspace integrity** — `.adup/workspace.json` exists, parses, has `shop_slug` and `defaults`. `state.json` exists and parses.
2. **Shop reachable** — `shop_slug` appears in `list_shops` output (warn if not: key may lack access).
3. **Orphan assets** — files under `assets/` whose concept group is not referenced by any `ad.md` `creative:` field. (Informational — orphans cost nothing until uploaded.)
4. **Missing creative groups** — every `ad.md` `creative:` value resolves to ≥1 file in `assets/` (or is an https/Drive link). An ad with `status: ready|uploaded|proposed` and no files = error.
5. **Stale state entries** — `state.json` assets whose checksum matches no current local file (renamed is fine — keyed by checksum, so only report when the bytes are gone); `state.json` ads whose folder path no longer exists.
6. **Detection + optional-token hint** — for every asset file, run:
   ```bash
   bash <plugin>/skills/creative-workspace/scripts/inspect.sh <file>
   ```
   The detected `aspect_label` is authoritative. If the filename happens to contain a ratio token that **contradicts** detection, report a WARN ("filename says 4x5, actual pixels are 1080x1080 = 1x1 — detection wins at launch; consider renaming or ignore"). A token that matches, or no token at all, is silent/OK. Detected `aspect_label: "other"` = WARN (no placement on any platform will accept it).
7. **Frontmatter completeness** — every `ad.md` has `status`, `format`, `creative`, `link`, `cta`; `_campaign.md` in scope has `map:` entries for every platform its ads target; TikTok-targeting ad sets have `identity_id` in `_adset.md`.
8. **Lifecycle sanity** — `status: proposed|approved|live` ads exist in `state.json` with proposal ids (otherwise state was lost — suggest re-running /adup:launch, which is idempotent by checksum).

Output a table: `check | status (OK/WARN/ERROR) | detail`, followed by a numbered **fix list** ("1. assets/summer-sale/hero.mp4 is 3000x3000 — no accepted placement; provide a 9x16 export for TikTok…"). Offer to apply fixes only if the user explicitly asks, one confirmation per fix.

### Grouping preview (`doctor --grouping`)

A focused dry-run of launch-time grouping — the fast way to answer "how will Tara read my files?". For every `assets/` subfolder (or the one the user names), run `inspect.sh` on each file and print the exact grouping table that launch would use:

```
file                          detected      group        placements (per platform)
assets/summer-sale/
  Hero Final.jpg              1x1  image    hero         facebook: feed, carousel_card
  hero-final-story.mp4        9x16 video    hero         facebook: stories_reels · tiktok: in_feed
  IMG_4123.png                4x5  image    (ungrouped)  facebook: feed
```

Apply the same stem-similarity rules as launch; flag `(ungrouped)` files, ambiguous clusters (with the confirmation question launch would ask), and any filename-token-vs-detection contradictions (WARN, detection wins). Report-only, like the rest of doctor.
