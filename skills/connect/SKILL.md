---
name: connect
description: Connect your ADUP account and verify which platforms are active. Run this first to confirm the integration is working and see your role, accessible shops, and connected platforms.
---

# Connect to ADUP

Verify the ADUP connection, show the user their role and accessible shops, and confirm which platforms are connected per shop.

## Where the key comes from

The connector reads the key from the plugin's own **Employee API key** field, filled in when the
plugin was enabled. It is not a shell variable any more: `ADUP_API_KEY` only ever expanded in the
Claude Code CLI, so every GUI install authenticated with the literal string `${ADUP_API_KEY}` and
got a 401 nobody could fix from the UI.

The connector is pinned to production (`https://gateway.adup.io/mcp`). A key is issued by ONE
environment and authenticates only against that one, so a staging or dev key returns
`invalid_token` here while being perfectly valid where it came from.

`ADUP_API_BASE` still applies to the skills that call central-api directly over bash (reports,
proposals, creative uploads) and still defaults to production — it does **not** move the connector.

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

## Your agency's managed agents

The agency's skills run inside Tara's **managed agents** (Reporting Skill, Spreadsheet Skill,
Assistant) — server-side, per brand, on their own schedule. Nothing is synced down any more. Run
`/adup:agents` to see each brand's agents, open or download their drafts, start a run, or publish a
house-style skill up to them. `/adup:sync-skills` is deprecated and only cleans up what it used to
write.

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

**Auth error (`-32001`, `invalid_token`).** The gateway now says what to do in the error's `data`:
`reason: credential_rejected`, `action: reauthenticate`, and an `authorize_url`. Read it rather than
guessing, then tell the user:

> Your ADUP key was rejected. It may have been regenerated, revoked, or issued by a different
> environment. Get a current key from Tara → **My MCP setup**, then update the plugin's
> **Employee API key** field (see `/adup:reset`).

Offer to open the key page for them — `open https://tara.adup.io/my-mcp-setup` on macOS. Do not tell
them to `export ADUP_API_KEY=…`; that no longer feeds the connector.

**A rejected key cannot fix itself.** Claude Code disables OAuth fallback whenever a connector
carries a static Authorization header, so nothing will prompt the user to re-authenticate — the
field has to be updated by hand. Say so plainly instead of suggesting they restart and retry.

**Transient failure (`-32603`).** Not an auth problem. Central-api is briefly unavailable and the
gateway already retried. Say so and suggest retrying in a moment — do NOT send the user to check
their key, and do not offer to re-enter it.

**No active plan (`-32003`).** The key is valid; the organisation has no active plan, so the gateway
serves no tools. This is a billing answer — point at the portal, never at the key.

**Server unreachable (connection refused or timeout).**
"Cannot reach the ADUP gateway at `https://gateway.adup.io/mcp`. Check whether the service is up."

**No shops returned (empty `accessible_shops`).**
"Your ADUP account is connected, but no shops have been assigned to you yet. Ask your agency owner
to assign you to a client in the portal Team page."
