# Codex Sound Guard

Menu bar utility for macOS that watches Codex Desktop session logs and plays local sounds when a Codex turn completes.

## Behavior

- Watches `~/.codex/sessions/**/*.jsonl`.
- Plays a completion sound when Codex writes `task_complete`.
- Plays a failure sound when the turn has a failure event or the final assistant message looks like a failure/blocker.
- Does not depend on macOS notification sound permissions.

Command failure detection is optional because Codex often runs exploratory commands that exit non-zero without meaning the whole task failed.

## Run

```bash
./script/build_and_run.sh
```

Use the menu bar bell icon to enable/disable monitoring, choose sounds, and test playback.
