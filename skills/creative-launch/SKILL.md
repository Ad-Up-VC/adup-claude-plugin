---
name: launch
description: Launch ads from a local creative workspace — validate copy and media against platform specs, upload assets to ADUP, and fan out ad-creation PROPOSALS per ad x platform x language in one batch. Nothing touches an ad platform until each proposal is approved in the ADUP portal, and approved ads always land PAUSED.
---

# Creative Launch (/adup:launch)

Turns `ad.md` files in a creative workspace into ad-creation proposals: **VALIDATE → UPLOAD → BATCH → PROPOSE → WRITE BACK**.

**Invariant — say this to the user in every launch summary: launching creates PROPOSALS in the ADUP approval queue. Nothing is uploaded to or created on any ad platform until a human approves each proposal in the portal — and even then, every ad lands PAUSED.**

Usage: `/adup:launch [path]` — path may be a workspace root, a campaign folder, an ad set folder, or a single ad folder. No path = current directory's workspace, all campaigns.

Environment: `ADUP_API_KEY` (personal employee key), API base `${ADUP_API_BASE:-https://centralapi.adup.io}`.

---

## Step 1 — Resolve context

1. Find the workspace root: walk up from the given path until a directory containing `.adup/workspace.json` is found. Missing → tell the user to run `/adup:creative-workspace init` first and stop.
2. Read `.adup/workspace.json` (shop_slug, defaults) and `.adup/state.json`. Call `set_active_shop(shop_slug="<slug>")`.
3. Collect every `ad.md` in scope. For each, resolve its full context:
   - `_campaign.md` and `_adset.md` frontmatter from the enclosing folders.
   - Effective **platforms**: ad frontmatter → campaign frontmatter → workspace default (first one that sets it wins).
   - Effective **languages**: ad frontmatter → campaign frontmatter → `[workspace default language]`.
   - **Creative group**: `creative:` field → files matching `assets/<group>_*` / `assets/<group>/<basename>_*`, or an https/Google Drive/Dropbox share link.
4. Skip ads with `status: proposed | approved | live` whose content is unchanged (compare sha256 of `ad.md` against `state.json` `content_hash`) — the launch is idempotent. Changed ads and `draft`/`ready`/`changes_requested` ads are in scope.
5. Platform support gate: only **facebook** and **tiktok** support creation today. If an ad targets google, linkedin, or snapchat, keep the ad but mark that platform "not yet supported for creation — skipped" in the report. Never fail the launch over an unsupported platform.

## Step 2 — VALIDATE (report first, fix only with permission)

For every referenced **local** media file, run:

```bash
bash <plugin>/skills/creative-workspace/scripts/inspect.sh "<file>"
```

Load `<plugin>/skills/creative-workspace/specs/platform-specs.json` and check, per ad x target platform:

- **Ratio token vs pixels**: filename token must equal `aspect_label`.
- **Placement fit**: the group must contain at least one file whose ratio is accepted by the platform (e.g. TikTok in_feed wants 9x16; Meta feed wants 1x1/4x5). Files whose ratio a platform doesn't accept are simply filtered out for that platform — only an EMPTY result after filtering is an error.
- **min_px / max_mb / duration_s / mime** per the spec file.
- **Text limits** per section: `soft` exceeded = WARN (truncation), `hard` exceeded = ERROR. Check the copy variant actually used per platform/language (see fan-out rules).
- **Frontmatter**: `link` is a valid URL, `cta` is a known value, `format` matches the assets (carousel needs `card1_*`… files or `## Card n` sections; 2–10 cards).
- **Targets**: `map:` provides the platform's campaign/adset (facebook) or campaign/adgroup + `identity_id` (tiktok). If TikTok `identity_id` is missing, call `tiktok__get_tiktok_identities`, show the options, ask the user to pick, and (with their OK) record it in `_adset.md` — this is the one file edit allowed during validation.
- Drive/https creatives can't be probed locally: mark them "server will validate on fetch" (WARN, not ERROR).

Present ONE consolidated report table: `ad | platform | check | severity | detail`.

**Auto-fix policy — strict:**
- The ONLY permitted auto-fix is an image **downscale/re-export** (too-large file or oversize pixels), e.g. `sips -Z 1080 in.jpg --out out.jpg` or a JPEG re-export to get under max_mb. Always show the exact command and **ask for confirmation first**; write the fixed file next to the original (never overwrite silently).
- **NEVER auto-truncate or rewrite copy.** For text over a limit, propose a shorter version as a suggested `ad.md` edit (show old → new) and let the user accept the edit or write their own. The file is only changed after they agree.
- Anything else (wrong ratio, missing files, bad video duration) = user must fix.

**Hard stop:** if any ERROR remains, stop and show the fix list. Only continue with the unaffected ads if the user explicitly says to **launch the valid ones**.

## Step 3 — UPLOAD (to ADUP infrastructure only — inert until approval)

For each unique local file used by in-scope ads:

1. Compute `shasum -a 256`. If the checksum already exists in `state.json` `assets`, reuse the recorded `asset_id` — no upload.
2. Otherwise run:
   ```bash
   bash <plugin>/skills/creative-workspace/scripts/upload.sh "${ADUP_API_BASE:-https://centralapi.adup.io}" <shop_slug> "<file>" "<campaign-slug>,<concept>"
   ```
   The script itself GETs `?checksum=` first and skips re-upload on a hit (returns the existing asset with `"deduplicated": true`). 422 = bad mime or over the 100MB multipart cap — report it, don't retry.
3. Record in `state.json` under `assets["<sha256>"]`: `asset_id`, `filename`, `kind`, `mime_type`, `width`, `height`, `duration_ms`, `aspect_ratio`, `uploaded_at`.

**Drive/Dropbox/https links** in `creative:` never touch local disk — call instead:

```bash
curl -s -X POST -H "Authorization: Bearer $ADUP_API_KEY" -H "Content-Type: application/json" -H "Accept: application/json" \
  -d '{"url": "<share-link>", "filename": "<concept>_<ratio>.<ext>", "tags": ["<campaign-slug>"]}' \
  "${ADUP_API_BASE:-https://centralapi.adup.io}/api/v1/shops/<shop_slug>/creative-assets/from-url"
```

(Google Drive links work when shared "anyone with the link".) Record the returned asset the same way, keyed by its `checksum_sha256`.

Set each ad's `status: uploaded` once its assets are in.

## Step 4 — BATCH + count confirmation (mandatory stop-and-ask)

Generate ONE batch id for the whole launch:

```bash
uuidgen | tr '[:upper:]' '[:lower:]'
```

Compute the fan-out (see rules below) and **ask before proposing anything**:

> This launch creates **N proposals** (X ads × platforms × languages: 12 facebook, 12 tiktok; 2 platforms skipped as not yet supported). All of them go to the approval queue in the ADUP portal — nothing goes live, and approved ads land PAUSED. Continue?

Do not proceed without an explicit yes. If N is surprisingly large (language × platform cartesian), point that out.

## Step 5 — PROPOSE (fan out per ad × platform × language)

**Fan-out rules:**
- **Copy resolution** (most specific wins): `## Primary text (tiktok, nl)` → `## Primary text (nl)` → `## Primary text (tiktok)` → `## Primary text`. Same for `## Headline` / `## Description`. TikTok uses only primary text (no headline/description fields).
- **Creative group filtered per platform** using platform-specs.json: Meta gets all accepted ratios of the group (1x1 + 4x5 + 9x16 for multi-placement), TikTok gets the 9x16 (or other accepted) file. Language-suffixed files (`hero_9x16_nl.mp4`) are used only for that language variant.
- **Targets pinned by `map:`** — no magic mirroring: facebook ads go to `map.facebook.adset_id`, tiktok ads to `map.tiktok.adgroup_id`.
- **`map.<platform>.create: true`** (new campaign/ad set) is **two-phase** in v1: propose the campaign/ad set creation first (`facebook__ads_campaign_create` / `facebook__ads_adset_create` / `tiktok__propose_create_campaign` / `tiktok__propose_create_adgroup`, each with `batch_id`), then tell the user to approve those in the portal and run `/adup:status` to capture the created ids into `map:` — THEN re-run `/adup:launch` for the ads. Do not chain unresolved parent ids in one batch.
- **Enhancements**: read `defaults.enhancements` from workspace.json — `off` → pass `enhancements_opt_out: true` on every Meta creative; `on` → `false`; `ask` → ask once per launch. Never re-ask when it's `off`/`on`.

**Facebook** (per ad × language) — call `facebook__ads_ad_create` with:
- `adset_id` (from map), `name` (`<ad-folder> | <lang>` or the account's convention),
- the creative spec inline: `asset_id`(s) from state.json, resolved primary text/headline/description, `link`, `cta`, `enhancements_opt_out`, and for `format: carousel` the `child_attachments` array (per card: asset_id, copy, link),
- `batch_id`, and `reasoning` (one sentence: campaign + why).
Use `facebook__ads_creative_create` (same creative params + `batch_id`) only when the user explicitly wants a reusable creative in the account library without an ad.

**TikTok** (per ad × language) — call `tiktok__propose_create_ad` with:
- `adgroup_id` + `identity_id` (from map), ad name,
- `asset_id` of the platform-filtered video, ad text (the resolved primary text, hard 100 chars), landing page URL, CTA,
- `batch_id`, `reasoning`.

Each call returns `Proposal created. ID: …`. Collect every proposal id. If a call fails, keep going, and list failures at the end (those ads stay `uploaded`).

## Step 6 — WRITE BACK + summary

1. `state.json` per ad path: `content_hash` (sha256 of ad.md), `batch_id`, and `targets` keyed `"<platform>:<lang>"` → `{proposal_id, status: "proposed", proposed_at}`.
2. Each launched `ad.md`: `status: proposed`.
3. Print the summary:

```
Launch complete — 24 proposals created (batch 3f2a…)

  campaign            ad            platforms          proposals
  2026-07_summer-sale hero-video    facebook, tiktok   4 (2 langs)
  ...

Review & approve: https://tara.adup.io/proposals?batch=<batch_id>
Skipped: linkedin (not yet supported for creation), 1 unchanged ad.

Nothing has touched any ad platform yet. After approval in the portal,
ads are created on the platform in PAUSED state — activate them from
Ads Manager / TikTok Ads Manager when you're ready to spend.
```

## Rules

1. **Approval middleware is never bypassed.** Every create goes through a proposal. If a tool ever appears to create directly, stop and report it.
2. **PAUSED always** — restate it in the summary every time.
3. **One batch id per launch** — makes the whole launch one reviewable unit in the portal.
4. **Idempotent** — unchanged ads and already-uploaded checksums are skipped; re-running a launch never duplicates uploads or proposals.
5. **Stop-and-ask points**: image auto-fix, copy rewrite suggestions, TikTok identity pick, the proposal-count confirmation, and launching-only-the-valid-ones. Never assume.
6. **Never auto-truncate copy.** Ever.
