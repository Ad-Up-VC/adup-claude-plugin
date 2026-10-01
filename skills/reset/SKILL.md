---
name: reset
description: Sign out of ADUP on this machine or switch to another Tara account, and remove credentials left by key-based installs. Use when Claude should stop acting as you here, when another employee takes over the machine, or when the connector keeps reporting invalid_token after you were signed out from Tara.
---

# Reset the ADUP sign-in

The `adup` connector signs in with OAuth 2.0 — there is no key in the plugin any more. "Reset"
therefore means: sign this machine out, and optionally sign in again as someone else.

## 1. Sign out on this machine

| surface | how |
|---|---|
| any terminal | `claude mcp logout plugin:adup:adup` — removes the tokens from the keychain |
| Claude Code CLI | `/mcp` → **adup** → the clear/sign-out option when it is offered; otherwise the terminal command |
| Cowork / Claude desktop app | the terminal command above, once, on this Mac |

Then make the sign-out stick server-side as well: Tara → **My MCP setup** → **Connected devices** →
**Sign out** on the device (`https://tara.adup.io/my-mcp-setup`; offer
`open https://tara.adup.io/my-mcp-setup` on macOS). Signing out there revokes the session within a
minute even when the local tokens were not cleared — it is the backstop for a lost laptop.

## 2. Sign in again, optionally as someone else

`claude mcp login plugin:adup:adup`, or `/mcp` → **adup** → **Authenticate** in the CLI. The browser
opens Tara. To switch accounts, click **Not you? Sign in as someone else** on the consent screen,
log in with the other account, and approve.

## 3. Remove leftovers from key-based installs (plugin ≤ 1.9)

Older versions wrote the employee key in cleartext to three per-user places. Run the same
list → confirm → remove block as `/adup:setup` Step 2 (LaunchAgent plists
`~/Library/LaunchAgents/io.adup.env.*.plist`, the `ADUP_*` keys under `env` in
`~/.claude/settings.json`, `export ADUP_*` lines in `~/.zshrc` / `~/.bashrc`, and
`~/.claude/skills/adup-*/`). Harmless on a clean machine.

## 4. Verify

Run `/adup:connect`. It reports who you are signed in as, the role and the brands. If it still
answers `invalid_token`, sign in again (Step 2). If the browser shows "This sign-in request can't
be completed", the request expired — start again from Claude.

## Automation keys

A machine that cannot open a browser uses the employee API key through a **second, hand-added
connector**, never through this plugin's own connector (see `/adup:setup` → **Automation
machines**). To rotate that key: Tara → My MCP setup → **Regenerate key** (it kills the old key
everywhere immediately), then on the automation machine:

```bash
claude mcp remove adup-automation
claude mcp add --transport http --scope user adup-automation https://gateway.adup.io/mcp \
  --header "Authorization: Bearer emp_…"
```

## Switching environments

The connector is pinned to `https://gateway.adup.io/mcp` and signs in there. Testing against
staging or dev is a hand-added connector against that gateway (`claude mcp add --transport http
adup-staging https://gateway-staging.adup.io/mcp`), which runs its own OAuth sign-in against that
environment's portal.
