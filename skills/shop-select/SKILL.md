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

1. Call `list_shops` to get all available shops with names and slugs
2. Match the user's client name to a shop (case-insensitive, partial match)
3. Call `set_active_shop(shop_slug="<slug>")` with the matched slug
4. The returned `shop_slug` is what to use in all subsequent platform tool calls

## Concurrency: pass shop_slug per call

`set_active_shop` sets a single ambient shop **per API key**. It is fine for one
interactive session, but it is NOT safe when several runs share the same
`ADUP_API_KEY` at once (e.g. multiple scheduled automations) — one run's
`set_active_shop` overwrites another's, so a data call can silently hit the wrong
client. Every platform tool accepts an optional `shop_slug` argument that targets
that client for THAT call only, ignoring the ambient shop:

- **Interactive, one client at a time:** `set_active_shop` once, then call normally.
- **Multiple clients in one session, or parallel work:** pass `shop_slug="<slug>"`
  on every data call (e.g. `google_ads__get_campaigns(shop_slug="nike", ...)`).
- **Scheduled automations (one run per client):** pin the client on the connector
  via the `X-Shop-Slug` header (see the plugin README) — no `set_active_shop` needed
  and fully race-free.

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
