---
name: creative-import
description: Import ads INTO a local creative workspace from two sources — a winning ad on a connected platform (import-winner, to relaunch it cross-platform) or a Google Sheets/CSV/xlsx copy matrix (import-sheet, bulk intake). Creates draft ad.md files; /adup-staging:launch does the actual proposing. One-way import — workspace folders stay the source of truth.
---

# Creative Import (/adup-staging:creative-import)

Two modes, both ending in **draft `ad.md` files** that `/adup-staging:launch` picks up:

- `winner` — "this Facebook ad is crushing it, put it on TikTok too"
- `sheet` — "here's our launch spreadsheet, build the workspace from it"

Both are **one-way**: the workspace folders remain the source of truth afterwards. Nothing is proposed or launched by this skill — and as always, anything later launched becomes a proposal that lands PAUSED after portal approval.

Requires an initialized workspace (`/adup-staging:creative-workspace init` first).

---

## Mode: import-winner

### Step 1 — Find the winner

The workspace's `.adup/workspace.json` holds the `shop_slug`. Call `set_active_shop(shop_slug="<slug>")` first — it is **required for tool discovery** (until a shop is active, an agency key sees only the six virtual tools) — then pass `shop_slug="<slug>"` explicitly on every platform call below; the ambient active shop is per API key and races with concurrent runs.

If the user named a specific ad, look it up. Otherwise find candidates with the platform's namespaced insight tools over the last 14–30 days, e.g.:

- Facebook: `facebook__get_ad_insights(shop_slug="<slug>", ...)` (CTR/CPA/ROAS per ad) + `facebook__get_ads(shop_slug="<slug>")` / `facebook__ads_creative_list(shop_slug="<slug>")` for names and creative details
- TikTok: the `tiktok__*` report tools with `shop_slug="<slug>"` — TikTok reporting **is** available via MCP
- Google/LinkedIn: `google_ads__*` and `linkedin__*` performance tools with `shop_slug="<slug>"` (creation TO them is supported too — google as RSA text ads, linkedin as single image/video ads)

Rank by the account's primary KPI (ask if unclear: ROAS, CPA, or CTR), show the top 3–5 with numbers, and let the user confirm which ad to import.

### Step 2 — Pull the copy

Read the winning ad's creative fields (primary text, headline, description, CTA, landing URL). On Facebook this is two hops: `facebook__ads_ad_get(shop_slug="<slug>", ad_id="<id>")` to get the ad and the creative id it points at, then `facebook__ads_creative_get(shop_slug="<slug>", creative_id="<id>")` to read the copy fields off that creative. Show what was extracted.

### Step 3 — Get the source creative file

Platforms serve **renditions**, not original files — a downloaded thumbnail is not launch-quality. Ask:

> I need the original media file (the one used to make this ad). Can you drop it into the workspace, point me at it, or paste a Google Drive link? Platform downloads are compressed renditions, so the original gives the best result on the new platform.

Place/copy it into `assets/<concept>/` — **any file name works**: the ratio and format are detected from the file's actual pixels/duration (run `scripts/inspect.sh` to preview what launch will detect, e.g. `aspect_label: 9x16`). A ratio token in the name (`winner-ugc_9x16.mp4`) is an optional readability hint; if it ever contradicts detection, detection wins with a warning. A Drive link can instead go directly into the ad.md `creative:` field (fetched server-side at launch, where the server's extracted metadata plays the same role). Only if the user truly has no original, accept their explicit go-ahead to use a rendition — and warn about quality.

### Step 4 — Scaffold the draft ad

Ask which campaign/ad set folder the imported ad belongs to (offer to create the folders + `_campaign.md`/`_adset.md` with empty `map:` placeholders if new). Write `ad.md`:

```markdown
---
status: draft
format: video            # match the winner's format
creative: winner-ugc     # or the Drive link
link: <winner's landing URL>
cta: <winner's CTA>
languages: [en]
platforms: [tiktok]      # the NEW platforms to launch to — not the source platform
---

## Primary text
<winner's primary text>

## Headline
<winner's headline>

## Description
<winner's description>
```

Adapt copy to the destination platform's limits only as a **suggestion** (e.g. TikTok's 100-char ad text) — show the proposed shortened variant as a `## Primary text (tiktok)` section and let the user approve it.

### Step 5 — Hand off

Summarize what was created and finish with:

> Draft ready. Review the copy, fill in `map:` target ids in `_adset.md`, then run `/adup-staging:launch <ad folder>` — that will validate, upload, and create the approval proposals (everything lands PAUSED after approval).

---

## Mode: import-sheet

Maps a spreadsheet copy matrix into `ad.md` files — one row per ad.

### Step 1 — Get the sheet

Accept any of: a local `.csv` / `.xlsx` file, a Google Sheets share link (use the CSV export URL: `https://docs.google.com/spreadsheets/d/<id>/export?format=csv&gid=<gid>`, works when shared "anyone with the link"), or a connected Google Sheets MCP. Read it with python3 (`csv` stdlib; `openpyxl` for xlsx).

### Step 2 — Map the columns

The canonical column template is:

```
campaign, adset, ad, format, creative_group_or_drive_link, primary_text, headline, description, cta, link, platforms, languages
```

Real sheets are never this clean — map loose columns **interactively**: show the header row, propose a mapping (e.g. "'Ad copy' → primary_text, 'URL' → link, 'Channel' → platforms?"), and confirm with the user before proceeding. Multi-value cells (`platforms`, `languages`) split on comma/semicolon. Ignore columns the user says are irrelevant; ask about ones you can't place.

Required per row: campaign, adset, ad, primary_text, link. Missing required values → list the offending rows and ask whether to skip them or stop.

### Step 3 — Build the workspace files

For each row:

1. Ensure `campaigns/<campaign-slug>/` exists with a `_campaign.md` (create with the row's platforms and an empty `map:` block flagged `# TODO: fill target ids before launch`).
2. Ensure the ad set folder + `_adset.md` exist the same way.
3. Write `campaigns/<campaign>/<adset>/<ad-slug>/ad.md` with `status: draft`, the mapped frontmatter (`format`, `creative`, `link`, `cta`, `languages`, row-level `platforms` if narrower than the campaign), and the copy sections (`## Primary text`, `## Headline`, `## Description`).
4. The `creative_group_or_drive_link` cell: a Drive/Dropbox/https link goes straight into `creative:` (it flows through the server-side from-url fetch at launch time); a plain name is treated as a creative group the user still needs to drop files for in `assets/` — collect these into a "missing media" list.
5. Never overwrite an existing `ad.md` without showing a diff and asking.

### Step 4 — Report

```
Imported 18 ads into 2 campaigns / 5 ad sets (from launch-plan.xlsx)
  - 12 ads reference Drive links (fetched server-side at launch)
  - 6 ads need media files in assets/: hero-a, hero-b, ...
  - TODO: fill map: target ids in 2 _campaign.md / 5 _adset.md files

Next: add the missing media, fill the map ids, then /adup-staging:launch.
```

Remind: the sheet was a one-time intake — future edits happen in the workspace files (use `/adup-staging:status --csv|--sheet` for reporting back out).

## Rules

1. **This skill never launches anything.** It only writes local draft files; `/adup-staging:launch` owns validation, upload, and proposals (which land PAUSED after approval).
2. **One-way import** — never sync workspace changes back into the sheet, and never re-import a sheet over edited ads without per-file confirmation.
3. **Ask for originals** — never silently use platform renditions as source creative.
4. **Interactive column mapping** — never guess silently on ambiguous columns.
