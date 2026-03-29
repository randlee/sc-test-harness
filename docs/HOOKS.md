# Hooks

## Location

Project hooks live in `.claude/settings.json` under the `hooks` key.

Plugin hooks live in a plugin root at `hooks/hooks.json`.

Local agent markdown files in `.claude/agents/*.md` may also contain frontmatter
`hooks: PreToolUse` entries. In this repo those are exercised via the local
`ai_cli` runner for Codex/local-agent emulation, not by the baseline
`log-hook.py` harness wiring.

## Events

Current events wired:
- `SessionStart`
- `SessionEnd`
- `UserPromptSubmit`
- `Notification`
- `Stop`
- `SubagentStart`
- `SubagentStop`
- `PermissionRequest`
- `PreToolUse`
- `PostToolUse`

The baseline settings hooks each run:

```
python3 scripts/log-hook.py --event <EventName>
```

`PreCompact` is not currently wired in this repo's baseline `.claude/settings.json`.

## Output

Events are appended to `reports/trace.jsonl` as JSON lines.
See `docs/TRACE.md` for the record format.
