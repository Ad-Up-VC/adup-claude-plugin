---
description: Connect your ADUP account and verify which platforms are active. Run this first to confirm the integration is working and see your available shops/clients.
---

# Connect to ADUP

Verify the ADUP connection and show the user what data sources are available.

## Steps

1. Call `list_shops` to confirm connection and get account structure
2. Present the results clearly

## Output format

For a **solo account** (one shop):
```
Connected to ADUP.

Active shop: [Shop Name]
Connected platforms: Facebook Ads, Google Ads, GA4

What would you like to analyse?
```

For an **agency account** (multiple shops):
```
Connected to ADUP.

You manage [N] client shops:
  • Nike Netherlands  (nike-nl)   — Facebook Ads, Google Ads, GA4
  • Adidas EU        (adidas-eu) — Facebook Ads, LinkedIn Ads
  • Puma Global      (puma)      — All platforms

Mention a client name in your next query to start working with their data.
```

## Error handling

If `list_shops` fails with an auth error:
"The ADUP connection needs authentication. Set your API key: export ADUP_API_KEY=your_key_here, then restart Claude Code."

If the MCP server itself is unreachable (connection refused or timeout):
"Cannot reach the ADUP gateway at https://tara-gateway-vc-v2wpc.ondigitalocean.app/mcp. Check that your ADUP_API_KEY is set correctly and the service is running."

If no shops are returned:
"Your ADUP account is connected but no shops are configured yet. Visit https://tara-vc.adup.io to connect your first advertising account."
