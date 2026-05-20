# Notes for AI tooling (Claude Code, opencode, etc.)

This is a **template repo**. When you see it in this state (with `rapidnative-coach`, `agni`, `/Users/agni/Documents/rapidclaw` etc. placeholders still present in files), it has not been instantiated yet — run `./bot-init.sh` to walk through the setup wizard. Don't try to operate the bot until the wizard has run and all placeholders are substituted.

After `bot-init.sh` completes:
- The project gains a real identity (`profile.md`, `CLAUDE.md` — both populated from the wizard answers)
- Slack tokens live at `~/.config/claude/<slug>-slack-{bot,app}-token` (mode 600)
- launchd plists at `~/Library/LaunchAgents/com.<owner>.<slug>-*.plist` keep the listener + crons alive
- All `__PLACEHOLDER__` markers have been replaced with real values

To resume an interrupted setup, just run `./bot-init.sh` again — it reads `.bot-setup-state.json` and skips completed steps.

To inspect / operate after setup, use `accountability/routines/coach.sh status` (and the other subcommands).
