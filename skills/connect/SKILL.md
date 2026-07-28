---
name: connect
description: Connect your ADUP account and verify which platforms are active. Run this first to confirm the integration is working and see your role, accessible shops, and connected platforms.
---

# Connect to ADUP

Verify the ADUP connection, show the user their role and accessible shops, and confirm which platforms are connected per shop.

## Steps

1. Call `list_shops` on the `adup` base connector. The gateway resolves your identity via Central API `/api/v1/me`, returning:
   - `role` (`owner` / `team_lead` / `manager` / `analyst` / `read_only`)
   - `accessible_shops` — only the shops you've been assigned to (or all shops if you're an owner)
   - Per-shop connected platforms
2. Present the results clearly with role context.

## Output format

For a **solo account** (one shop, owner role typically):
```
Connected to ADUP.

Role: owner
Active shop: [Shop Name]
Connected platforms: Facebook Ads, Google Ads, GA4

What would you like to analyse?
```

For an **agency or enterprise account** (multiple shops):
```
Connected to ADUP.

Role: <your role>
You can access [N] client shops:
  • Nike Netherlands  (nike-nl)   — Facebook Ads, Google Ads, GA4
  • Adidas EU        (adidas-eu) — Facebook Ads, LinkedIn Ads
  • Puma Global      (puma)      — All platforms

Mention a client name to switch to it, or run /adup:shop-select.
```

## Role-specific guidance

After listing shops, briefly remind the user what their role allows:

- **owner**: full access to all shops, can approve all changes, can manage team.
- **team_lead**: can see their group's shops, approve changes within group, onboard new analysts/managers.
- **manager**: can see assigned shops, propose changes, approve up to rule thresholds.
- **analyst**: can see assigned shops, propose changes — every change goes to `pending_review` and requires approval by a team_lead/manager/owner.
- **read_only**: can see assigned shops and read data, but cannot propose any change.

## New skills from your agency

If your agency owner has installed additional skills (e.g., "LinkedIn Engagement Analysis") in the ADUP portal, run `/adup:sync-skills` to pull them into your local Claude. They'll be available after a Claude restart.

## Switching shops — refresh the tool list

All tools are served by the single `adup` connector, namespaced per platform
(e.g. `facebook__get_ad_insights`, `google_ads__execute_google_ads_gaql_query`,
`ga4__get_ecommerce_performance`). Note the Google Ads prefix is `google_ads__`,
never `google__`.

**The tool list is gated on the active shop.** Until you call `set_active_shop`
(or your key has exactly one shop), only the gateway's own virtual tools are
listed — `list_shops`, `set_active_shop` and friends — and no platform tools at
all. After `set_active_shop`, the available tools change to that shop's connected
platforms. The gateway emits a `notifications/tools/list_changed`, but most MCP
clients don't act on it automatically — so **reload tools / reconnect the
connector** to pick up the newly-active shop's tools.

Only connected platforms appear: if a shop has just Facebook Ads + GA4 connected,
you'll see only `facebook__*` and `ga4__*` tools.

Passing `shop_slug` on a call does **not** change what is listed — it only changes
which client an already-listed tool reads from. You still need the right shop
active for its tools to exist, and you should still pass `shop_slug` explicitly on
every data call (the active shop is shared per API key and parallel runs race).

## Error handling

If `list_shops` fails with an auth error:
"The ADUP connection needs authentication. Set your personal API key: `export ADUP_API_KEY=your_key_here`, then restart Claude Code. If you don't have a key, ask your agency owner to invite you in the portal."

If the MCP server itself is unreachable (connection refused or timeout):
"Cannot reach the ADUP gateway at https://gateway.adup.io/mcp. Check that your ADUP_API_KEY is set correctly and the service is running."

If no shops are returned (empty `accessible_shops`):
"Your ADUP account is connected, but no shops have been assigned to you yet. Ask your agency owner to assign you to a client in the portal Team page."
