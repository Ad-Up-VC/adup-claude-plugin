---
name: reset
description: Change the ADUP employee API key, or clear a stale one. Use when the key was regenerated, when a different employee takes over this machine, when the connector reports invalid_token, or when switching between ADUP environments.
---

# Reset the ADUP key

The key lives in the plugin's **Employee API key** config field, filled in when the plugin was
enabled. Older installs also left copies in three environment stores; those no longer feed the
connector, but a stale copy still reaches the skills that call central-api directly, so a proper
reset clears them too.

## 1. Replace the key in the plugin config

The field is masked and stored in the OS keychain, so it cannot be read back or rewritten from a
script — the user has to retype it.

Tell them, in this order:

1. Get a current key: Tara → **My MCP setup** (`https://tara.adup.io/my-mcp-setup`). Offer to open
   it: `open https://tara.adup.io/my-mcp-setup`. **Regenerate** there issues a new key and kills the
   old one — only do that if the current key is compromised or lost, because every other machine
   using it stops working immediately.
2. Open the plugin's settings and use **Customize** on the ADUP plugin, if the surface offers it.
3. If it does not, disable and re-enable the plugin — the config field is prompted at enable time.

Do not invent a path you have not seen; ask what the screen shows and work from that.

## 2. Clear stale environment copies

Only for installs that ran `/adup:setup` before v1.7.0. Harmless to run either way.

```bash
# LaunchAgent plists (macOS GUI apps read env from launchctl, not from a shell profile)
for OLD in "$HOME/Library/LaunchAgents"/io.adup.env.*.plist; do
  [ -e "$OLD" ] || continue
  VAR="$(basename "$OLD" .plist)"; VAR="${VAR#io.adup.env.}"
  launchctl unload "$OLD" 2>/dev/null || true
  launchctl unsetenv "$VAR" 2>/dev/null || true
  rm -f "$OLD"
done

# Claude Code settings
python3 - "$HOME/.claude/settings.json" <<'PY'
import json, sys
path = sys.argv[1]
try:
    settings = json.load(open(path))
except (FileNotFoundError, json.JSONDecodeError):
    sys.exit(0)
env = settings.get("env", {})
for stale in ("ADUP_API_KEY", "ADUP_GATEWAY_BASE", "ADUP_API_BASE"):
    env.pop(stale, None)
json.dump(settings, open(path, "w"), indent=2)
PY

# Shell profile
for PROFILE_FILE in "$HOME/.zshrc" "$HOME/.bashrc"; do
  [ -f "$PROFILE_FILE" ] || continue
  grep -vE '^export (ADUP_API_KEY|ADUP_GATEWAY_BASE|ADUP_API_BASE)=' "$PROFILE_FILE" \
    > "$PROFILE_FILE.tmp" && mv "$PROFILE_FILE.tmp" "$PROFILE_FILE"
done
```

**`ADUP_GATEWAY_BASE` no longer does anything** and is removed rather than rewritten. The connector
URL is a literal now; a leftover value used to look like an environment override while having no
effect, which is a confusing thing to leave behind.

If the user still needs the direct-HTTP skills (client reports, proposals, creative uploads), have
them re-run `/adup:setup` afterwards to write the new key back into the environment. That step is
optional — the connector itself does not need it.

## 3. Verify

Run `/adup:connect`. A successful reset reports the role and accessible shops. If it still returns
`invalid_token`, the key is wrong or belongs to another environment — do not clear anything a second
time, get a fresh key from the portal instead.

## Switching environments

The connector is pinned to `https://gateway.adup.io/mcp`, so a staging or dev key cannot be made to
work by setting a variable. Testing another environment needs a variant build of the plugin or a
hand-added custom connector pointing at that gateway.
