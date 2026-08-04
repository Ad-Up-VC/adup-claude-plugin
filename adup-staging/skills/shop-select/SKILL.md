---
name: shop-select
description: Set the active client for an agency account. Use when a user mentions a client name and you need to resolve which shop to query, or when switching between clients mid-session.
---

# Shop Selection

Resolve a natural-language client name to the correct shop slug for subsequent queries.

## When to use this skill

- User mentions a client by name ("show me Nike data", "for Adidas this month")
- Need to switch clients mid-session
- Previous query returned a shop-not-found error

## Tool sequence

1. Call `list_shops` to get all available shops with names, slugs and connected platforms
2. Match the user's client name to a shop (case-insensitive, partial match)
3. Call `set_active_shop(shop_slug="<slug>")` with the matched slug
4. Pass that slug as `shop_slug` on every subsequent platform tool call

**Do not skip step 3, even when you plan to pass `shop_slug` everywhere.**
`set_active_shop` is what makes the platform tools *appear*: the `adup` connector
only lists a shop's `facebook__*` / `google_ads__*` / `ga4__*` tools once that shop
is active (or when the API key has exactly one shop). Until then an agency key sees
only the gateway's own virtual tools — `list_shops`, `set_active_shop` and friends.
So "the Facebook tools aren't available" nearly always means "no active shop yet".
Passing `shop_slug` on a call does not change what is listed; it only changes where
an already-listed tool reads from. The tool list also changes when you switch shops,
so reload / reconnect the connector after `set_active_shop`.

## Concurrency: pass shop_slug per call

`set_active_shop` sets a single ambient shop **per API key**. It is fine for one
interactive session, but it is NOT safe when several runs share the same
`ADUP_STAGING_API_KEY` at once (e.g. multiple scheduled automations) — one run's
`set_active_shop` overwrites another's, so a data call can silently hit the wrong
client. Every platform tool accepts an optional `shop_slug` argument that targets
that client for THAT call only. The gateway resolves the shop per call as:
explicit `shop_slug` argument → otherwise the ambient active shop (or the sole shop
on a single-shop key).

- **Interactive, one client at a time:** `set_active_shop` once, then call normally
  — but passing `shop_slug` anyway costs nothing and is never wrong.
- **Multiple clients in one session, or parallel work:** pass `shop_slug="<slug>"`
  on every data call, e.g.
  `google_ads__get_google_ads_campaign_performance(shop_slug="nike", ...)`.
- **Scheduled automations and loops over clients:** same rule — `set_active_shop`
  for the shop you're on so its tools are listed, then pass `shop_slug` on every
  single call. Never let a call in a loop or a background run fall back to the
  ambient shop; that is exactly where the race bites.

## Matching rules

- "Nike" → matches "Nike Netherlands", "Nike Global", "Nike NL 2024" (prefer most recent if multiple)
- Exact slug match takes priority over name match
- If ambiguous (2+ matches), show options and ask user to clarify

## Output

```
Now working with: Nike Netherlands
Connected platforms: Facebook Ads, Google Ads, GA4

What would you like to analyse for Nike?
```

## Solo user behaviour

Solo users never need shop selection — their shop is auto-selected. If a solo user triggers this, just confirm their active shop.
