# GA4 Metrics & Dimensions Reference

Use this reference to select the correct `dimensions` and `metrics` API names when calling GA4 tools. Always pass explicit values — the tools do not auto-select.

---

## Scope Compatibility Rules

GA4 dimensions and metrics have scopes. You MUST match scopes within a query.

| Scope | Dimensions | Metrics |
|-------|-----------|---------|
| **Session** | sessionSource, sessionMedium, sessionCampaignName, sessionDefaultChannelGroup, sessionManualAdContent | sessions, engagementRate, bounceRate, averageSessionDuration, engagedSessions |
| **User** | country, city, region, deviceCategory, platform, operatingSystem, browser, language, newVsReturning | activeUsers, newUsers, totalUsers, userEngagementDuration |
| **Event** | eventName, linkUrl, outbound, linkDomain | eventCount, eventValue, conversions, eventsPerSession |
| **Item** | itemName, itemId, itemCategory, itemCategory2, itemBrand | itemRevenue, itemsPurchased, itemsViewed, cartToViewRate, purchaseToViewRate |
| **Page** | pagePath, pageTitle, landingPage, landingPagePlusQueryString, pageReferrer | screenPageViews, entrances, exits |

**Safe dimensions** (work with most metrics from any scope):
`date`, `dateHour`, `year`, `month`, `dayOfWeek`, `deviceCategory`, `platform`, `operatingSystem`, `country`, `city`, `region`

---

## Use-Case Mapping

### Traffic by source/channel
```
dimensions: ["sessionDefaultChannelGroup", "sessionSource", "sessionMedium"]
metrics:    ["sessions", "activeUsers", "engagementRate", "bounceRate"]
```

### Revenue by channel (e-commerce)
```
dimensions: ["sessionDefaultChannelGroup", "date"]
metrics:    ["purchaseRevenue", "transactions", "activeUsers", "engagementRate"]
```

### Revenue by source
```
dimensions: ["sessionSource", "sessionMedium", "date"]
metrics:    ["purchaseRevenue", "transactions"]
```

### Content/page performance
```
dimensions: ["pagePath", "pageTitle"]
metrics:    ["screenPageViews", "averageSessionDuration", "engagementRate", "userEngagementDuration"]
```

### E-commerce product performance
```
dimensions: ["itemName", "itemCategory"]
metrics:    ["itemRevenue", "itemsPurchased", "itemsViewed", "cartToViewRate"]
```

### Event analysis
```
dimensions: ["eventName"]
metrics:    ["eventCount", "eventValue", "conversions"]
```

### User demographics
```
dimensions: ["deviceCategory", "country", "city"]
metrics:    ["activeUsers", "newUsers", "totalUsers"]
```

### Conversion event details
```
dimensions: ["date"]   (or "sessionSource", "deviceCategory", "country", "pagePath")
metrics:    ["eventCount", "conversions", "activeUsers", "eventValue", "eventsPerSession"]
```

### Conversion funnel
```
dimensions: ["eventName"]
metrics:    ["eventCount", "activeUsers"]
```

### User acquisition
```
dimensions: ["sessionSource", "sessionMedium"]
metrics:    ["sessions", "activeUsers", "newUsers", "engagementRate", "bounceRate"]
```

### User journey (base set, tool adds sub-report dimensions)
```
dimensions: ["date"]
metrics:    ["sessions", "bounceRate", "eventCount", "totalUsers"]
```

### Active users over time
```
dimensions: ["date"]
metrics:    ["activeUsers", "newUsers", "totalUsers", "engagementRate"]
```

### Realtime monitoring
```
dimensions: ["country"]  (or "deviceCategory", "unifiedScreenName")
metrics:    ["activeUsers", "screenPageViews", "eventCount"]
```

---

## Incompatible Combinations (avoid these)

- Event-scoped dimensions + session-only metrics: `eventName` + `sessions`
- Session-scoped dimensions + event-only metrics: `sessionSource` + `eventCount`
- Item-scoped dimensions + user metrics: `itemName` + `activeUsers`
- Mixing too many different scopes in one query
- Advertising metrics (`advertiserAdClicks`, `advertiserAdCost`) require Google Ads linking

---

## Tool Auto-Appended Dimensions

Some tools auto-append dimensions. Do NOT duplicate these in your call:

| Tool | Auto-appends |
|------|-------------|
| `get_ecommerce_performance` | `date` always; `itemName`, `itemCategory` when `include_items=True` |
| `get_user_acquisition` | `sessionSource` if missing |
| `get_conversion_funnel` | `date` when `include_date_breakdown=True` |
| `get_user_journey` | Internally creates 3 sub-reports with `landingPage`, `eventName+pagePath`, `pagePath` |
