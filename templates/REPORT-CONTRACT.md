# ADUP Report Contract (HTML)

**THE authoritative spec for platform-delivered HTML reports.** Every HTML report submitted
via the `create_report` MCP tool MUST comply with every MUST/NEVER rule below. The platform
sanitizes server-side on ingest: non-compliant markup is stripped (not rejected), and the
sanitizer report is returned to you and shown to reviewers. Build compliant HTML the first
time — stripped content means a degraded report in the review queue.

Tone, narrative structure, and content quality are governed by `REPORT-DESIGN-GUIDE.md`.
This file governs only the HTML/CSS mechanics.

---

## 1. Document

- **MUST** be a single, fully self-contained `<!doctype html>` document: `<html lang="…">`,
  `<head>` with `<meta charset="utf-8">`, `<meta name="viewport" content="width=device-width,initial-scale=1">`,
  a `<title>`, exactly ONE `<style>` block — then `<body>`.
- **MUST NOT** contain `<script>` anywhere, in any form. The server strips it; interactivity
  is declarative only (section 5).
- **MUST NOT** reference ANY external resource: no CDN fonts, no `@import`, no external
  stylesheets, no remote images, no external `url()` in CSS. The sanitizer removes them all.
- Fonts: the platform viewer provides the font files. Declare font *stacks* via the CSS
  variables in section 3 — never `@font-face`, never a fonts CDN.
- Charts and graphics: **inline SVG** (the full `svg` subtree is allowed). Prefer SVG over
  raster for anything drawable — bars, lines, donuts, gauges, sparklines, logos.
- Raster images are allowed as data URIs, but avoid base64 blobs where SVG works. Large
  embedded images (>8KB base64) are automatically extracted and re-hosted by the server —
  they still count against your pre-strip size, so keep them rare and small.
- Also stripped by the sanitizer (never emit): `<iframe>`, `<object>`, `<embed>`, `<form>`,
  `<link>`, `<meta http-equiv>`, all `on*` attributes, `javascript:` URLs, and in CSS:
  `@import`, `expression()`, external `url()`.

## 2. Structure — slides

```html
<body>
  <main class="report">
    <section class="slide cover"   data-slide="1"> … </section>
    <section class="slide"         data-slide="2"> … </section>
    …
    <section class="slide closing" data-slide="N"> … </section>
  </main>
</body>
```

- Exactly one `<main class="report">` wrapping all content.
- Each page is one `<section class="slide" data-slide="n">` with `data-slide` numbered
  sequentially from 1 with no gaps.
- First slide **MUST** be the cover: `class="slide cover"`. Last slide **MUST** be the
  closing/next-steps slide: `class="slide closing"`.
- Maximum **~18 slides**. If content wants more, condense — move detail into
  `data-expandable` deep-dives (section 5).
- Each slide must be self-sufficient at one full viewport height and its content must fit a
  **16:9-ish viewport** without inner scrolling. Do not let tables or charts overflow a slide;
  split or condense instead.

## 3. Theming — the `:root` variable contract

`:root` in the `<style>` block **MUST** define ALL of:

```css
:root {
  --r-bg: …;            /* page background */
  --r-panel: …;         /* card/panel surfaces */
  --r-accent: …;        /* primary accent */
  --r-accent-2: …;      /* secondary accent */
  --r-text: …;          /* primary text */
  --r-text-muted: …;    /* secondary/muted text */
  --r-font-heading: …;  /* heading font stack */
  --r-font-body: …;     /* body font stack */
}
```

- **Every** color and font-family in the document — including inside inline SVG (use
  `fill="var(--r-accent)"` etc.) — MUST reference these variables, directly or via derived
  values (`color-mix(...)` over a var is acceptable, plain vars preferred). No hardcoded
  hex/rgb outside `:root`.
- The platform re-skins reports by overriding these eight variables — a report that hardcodes
  colors elsewhere breaks agency whitelabeling.
- Values come from agency branding via the `get_report_branding` tool. Until that tool is
  available (later phase), use tasteful defaults consistent with `REPORT-DESIGN-GUIDE.md`.

## 4. Print

The `<style>` block **MUST** include:

```css
@page { size: A4 landscape; margin: 0; }
.slide { page-break-after: always; }
```

- Do NOT size slides with `height: 100vh` alone — viewport units collapse or misbehave in
  print. Use `min-height: 100vh` **plus** a fixed fallback, e.g.:

```css
.slide { min-height: 100vh; min-height: 210mm; /* print fallback */ }
@media print { .slide { min-height: 0; height: 210mm; } }
```

  (Any equivalent that guarantees one slide per A4-landscape page is acceptable; the rule is:
  never rely on `100vh` as the only sizing mechanism.)

## 5. Interactivity — declarative only, NEVER your own JS

The platform viewer injects its own runtime. You only annotate:

- **Deep-dive / expandable block** (hidden until the viewer enables it):

```html
<div data-expandable data-expand-label="How this is calculated">
  … extended methodology, extra tables, footnotes …
</div>
```

- **Tabs** (optional):

```html
<div data-tabs>
  <div data-tab-panel="Facebook & Instagram"> … </div>
  <div data-tab-panel="Google Ads"> … </div>
</div>
```

- **NEVER** implement toggles, accordions, tabs, tooltips, or animation with JS — there is no
  JS. CSS-only hover/transition effects are fine but must not hide primary content.
- Content inside `data-expandable` must be supplementary: the slide must read complete when
  the block is hidden (deep-dives are off until the platform enables them).

## 6. Size

- Keep the final HTML **under 1.5 MB**.
- The gateway **hard-rejects over 8 MB** before ingest.
- Biggest offenders: base64 images and copy-pasted data. Use SVG, round your numbers, and let
  the server re-host any unavoidable large image.

## 7. Pre-submit checklist

- [ ] One `<style>` block in `<head>`; zero `<script>`; zero external URLs
- [ ] `<main class="report">` → `<section class="slide" data-slide="1..N">`, cover first, closing last, ≤ ~18 slides
- [ ] All 8 `--r-*` variables defined in `:root`; no colors/fonts outside them
- [ ] Charts are inline SVG using the variables
- [ ] `@page A4 landscape` + `.slide { page-break-after: always }` + non-`100vh`-only sizing
- [ ] Interactivity only via `data-expandable` / `data-tabs` attributes
- [ ] Under 1.5 MB

---

## Complete minimal example (3-slide report, valid per this contract)

```html
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Acme Store — Monthly Report June 2026</title>
<style>
:root {
  --r-bg: #0e1116;
  --r-panel: #1a1f28;
  --r-accent: #4fd1a5;
  --r-accent-2: #f0a848;
  --r-text: #f2f4f7;
  --r-text-muted: #9aa3b0;
  --r-font-heading: Georgia, 'Times New Roman', serif;
  --r-font-body: -apple-system, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif;
}
* { margin: 0; padding: 0; box-sizing: border-box; }
body { background: var(--r-bg); color: var(--r-text); font-family: var(--r-font-body); }
h1, h2, h3 { font-family: var(--r-font-heading); }
.slide {
  min-height: 100vh;
  min-height: 210mm;
  padding: 6vh 7vw;
  display: flex;
  flex-direction: column;
  justify-content: center;
  gap: 2rem;
}
.slide.cover, .slide.closing { align-items: center; text-align: center; }
.kicker { color: var(--r-accent); text-transform: uppercase; letter-spacing: .18em; font-size: .8rem; }
.panel { background: var(--r-panel); border-radius: 12px; padding: 1.5rem; }
table { width: 100%; border-collapse: collapse; }
th, td { padding: .6rem .8rem; text-align: right; border-bottom: 1px solid var(--r-panel); }
th:first-child, td:first-child { text-align: left; }
th { color: var(--r-text-muted); font-weight: 600; }
tr.blended td { font-weight: 700; color: var(--r-accent); }
.muted { color: var(--r-text-muted); }
@page { size: A4 landscape; margin: 0; }
.slide { page-break-after: always; }
@media print { .slide { min-height: 0; height: 210mm; } }
</style>
</head>
<body>
<main class="report">

  <section class="slide cover" data-slide="1">
    <p class="kicker">Monthly Performance Report</p>
    <h1>Acme Store</h1>
    <p class="muted">June 2026 · compared to May 2026</p>
    <p>A strong month: €12,400 spend returned €43,900 in revenue — a blended return of 3.5x, up 9% on May.</p>
  </section>

  <section class="slide" data-slide="2">
    <p class="kicker">Performance Overview</p>
    <h2>All channels, one view</h2>
    <div class="panel">
      <table>
        <thead><tr><th>Platform</th><th>Spend</th><th>Revenue</th><th>Return</th><th>vs May</th></tr></thead>
        <tbody>
          <tr><td>Facebook &amp; Instagram</td><td>€7,100</td><td>€24,200</td><td>3.4x</td><td>+6% return</td></tr>
          <tr><td>Google Ads</td><td>€5,300</td><td>€19,700</td><td>3.7x</td><td>+12% return</td></tr>
          <tr class="blended"><td>All Channels (Blended)</td><td>€12,400</td><td>€43,900</td><td>3.5x</td><td>+9% return</td></tr>
        </tbody>
      </table>
    </div>
    <svg viewBox="0 0 600 160" role="img" aria-label="Revenue by channel" xmlns="http://www.w3.org/2000/svg">
      <rect x="40"  y="55" width="220" height="40" rx="6" fill="var(--r-accent)"/>
      <rect x="40" y="105" width="180" height="40" rx="6" fill="var(--r-accent-2)"/>
      <text x="46" y="45"  fill="var(--r-text-muted)" font-size="14" font-family="var(--r-font-body)">Revenue by channel (€K)</text>
      <text x="270" y="81"  fill="var(--r-text)" font-size="14" font-family="var(--r-font-body)">Facebook &amp; Instagram — 24.2</text>
      <text x="230" y="131" fill="var(--r-text)" font-size="14" font-family="var(--r-font-body)">Google Ads — 19.7</text>
    </svg>
    <div data-expandable data-expand-label="How we measure">
      <p class="muted">Google Analytics 4 (last-click) is the source of truth for revenue. Platform-reported
      conversions run 15–25% higher by design; we use them only for in-channel optimization.</p>
    </div>
  </section>

  <section class="slide closing" data-slide="3">
    <p class="kicker">Next Steps</p>
    <h2>Where we go from here</h2>
    <div class="panel" style="text-align:left; max-width: 60ch;">
      <p><strong>1.</strong> Scale Google Shopping budget by 15% — projected ~90 additional customers at €8.50 each.</p>
      <p><strong>2.</strong> Refresh Facebook prospecting creative to counter early fatigue signals.</p>
    </div>
    <p class="muted">Prepared by your ADUP team · June 2026</p>
  </section>

</main>
</body>
</html>
```
