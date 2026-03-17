# Claude Notifier

Native macOS notifications with the Claude logo for [Claude Code](https://claude.ai/claude-code).

macOS requires a `.app` bundle to post notifications — bare CLI binaries can't do it. Claude Notifier is a minimal `.app` that runs as an invisible background process (no Dock icon), posts a notification via `UNUserNotificationCenter`, and exits. It natively parses Claude Code's hook JSON, so setup is a single line.

## Install

### Homebrew

```bash
brew install ebarti/tap/claude-notifier
```

### From source

```bash
git clone https://github.com/ebarti/claude-notifier.git
cd claude-notifier
make install
```

## Claude Code Integration

Add this to `~/.claude/settings.json`:

```json
{
  "hooks": {
    "Notification": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "claude-notifier"
          }
        ]
      }
    ]
  }
}
```

That's it. Claude Code pipes JSON to stdin with `title`, `message`, and `notification_type` fields. The app parses it automatically and applies per-type sounds and grouping:

| Notification Type | Title | Sound | Group |
|---|---|---|---|
| `permission_prompt` | Permission Needed | Funk | `claude-permission_prompt` |
| `idle_prompt` | Claude Code | default | `claude-idle_prompt` |
| `auth_success` | Authentication | Glass | `claude-auth_success` |
| `elicitation_dialog` | Input Required | Blow | `claude-elicitation_dialog` |

## CLI Usage

The app also works standalone with CLI flags:

```bash
# Basic notification
claude-notifier -message "Task complete"

# With title and sound
claude-notifier -title "Claude Code" -message "Build finished" -sound Glass

# Pipe plain text
echo "Deployment done" | claude-notifier

# Pipe JSON (Claude Code hook format)
echo '{"message":"Hello","notification_type":"idle_prompt"}' | claude-notifier

# Click to open URL
claude-notifier -message "PR ready" -open "https://github.com/..."

# Replace previous notification in same group
claude-notifier -message "Step 1/3..." -group progress
claude-notifier -message "Step 2/3..." -group progress
```

### Flags

| Flag | Description | Default |
|---|---|---|
| `-message VALUE` | Notification body | *(stdin)* |
| `-title VALUE` | Notification title | `Claude Code` |
| `-subtitle VALUE` | Secondary line | — |
| `-sound NAME` | Sound from `/System/Library/Sounds` | `default` |
| `-group ID` | Group ID (replaces previous in group) | — |
| `-open URL` | URL or path to open on click | — |
| `-execute CMD` | Shell command to run on click | — |
| `-timeout SECS` | Auto-dismiss after N seconds | `0` |
| `-help` | Print usage | — |
| `-version` | Print version | — |

## Troubleshooting

- **Notifications not showing?** Check System Settings > Notifications > Claude Notifier
- **Permission prompt not appearing?** Run `claude-notifier -message "test"` once manually to trigger the macOS permission dialog
- **Icon not updating?** Run `killall NotificationCenter` to clear the cached icon

## Requirements

- macOS 11+
- Xcode Command Line Tools (`xcode-select --install`)

## License

MIT
