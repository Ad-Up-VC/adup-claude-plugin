---
description: Propose creating new Facebook ads within existing ad sets through the action middleware. Guides creative specification, references creative playbook data, and ensures new ads are created in PAUSED status for review.
---

# Ad Creation

## Pre-flight
- Confirm shop context for agency accounts (use `set_active_shop` if not already set)
- New ads are always created in **PAUSED** status — they must be manually activated after review
- This skill creates ads within **existing ad sets only** — no campaign or ad set creation

---

## Step 1 — Identify the Target Ad Set

Determine which ad set the new ad should be created in:

### Pull ad set information:
- Use `get_adsets` to list ad sets in the target campaign
- Check ad set status: only create ads in ACTIVE ad sets (not paused, deleted, or archived)
- Check learning phase: creating a new ad in a Learning ad set may reset the learning clock — flag this risk

### Verify targeting and budget:
- Confirm the ad set's audience and targeting are appropriate for the new creative
- Confirm the ad set has sufficient budget to support an additional ad

---

## Step 2 — Define Creative Specification

### Option A: Use an Existing Creative
If the user has an existing creative ID:
- Call `propose_create_ad` with `creative_id`
- This reuses an already-uploaded creative

### Option B: Define New Creative Details
Provide the creative elements:
- **page_id** (required): The Facebook Page ID the ad will be published from
- **message** (required): Primary text / ad body
- **link** (required): Landing page URL
- **image_hash** (optional): Hash of a previously uploaded image
- **headline** (optional): Ad headline text
- **call_to_action** (optional): CTA type — LEARN_MORE, SHOP_NOW, SIGN_UP, BOOK_TRAVEL, CONTACT_US

### Creative Best Practices (reference):
- Primary text: 125 characters for mobile display without truncation
- Headline: 40 characters max for full display
- Image: 1080×1080 or 1200×628 recommended
- CTA should match the landing page intent (SHOP_NOW for product pages, LEARN_MORE for content)

---

## Step 3 — Propose Ad Creation

Call `propose_create_ad` with:
- `adset_id`: Target ad set
- `ad_name`: Descriptive name following the account's naming convention
- Creative specification (either `creative_id` OR `page_id` + `message` + `link` + optional fields)
- `reasoning`: Why this ad should be created — reference performance data, creative gaps, or fatigue signals

**Example reasoning:**
> "Ad set 'Retargeting - Website Visitors' currently has 2 active ads, both with frequency >3.5 and declining CTR. Creating a new ad with a testimonial-based creative to combat fatigue. The creative playbook shows testimonial formats achieve 45% lower CPA for this client."

---

## Step 4 — Summary

Present:
- Ad name and target ad set
- Creative specification summary
- Status: PAUSED (will need manual activation)
- Reasoning recap
- Next steps: "Review the ad in Facebook Ads Manager, then activate when ready"

---

## Rules

1. **Always create as PAUSED.** New ads default to PAUSED status. This ensures the user can review creative rendering in Ads Manager before spending money.

2. **Existing ad sets only.** This skill does not create campaigns or ad sets. If the user needs a new ad set or campaign, instruct them to create it in Ads Manager first.

3. **Learning phase warning.** If the target ad set is in Learning phase, warn that adding a new ad may reset the learning clock. Recommend waiting until learning exits unless there's an urgent reason.

4. **Name consistently.** Follow the account's existing naming convention for ad names. If no convention is apparent, use: "[Creative Type] - [Key Message] - [Date]" (e.g., "Testimonial - Customer Review - Mar 2026").

5. **One ad at a time.** Propose one ad creation per call. For multiple ads, make separate proposals — each goes through middleware approval independently.

6. **All proposals go through middleware.** Ad creation is an irreversible, high-risk action. It will likely require manual approval in the dashboard unless auto-approval rules are configured for ad creation.
