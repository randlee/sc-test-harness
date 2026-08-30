# Codex Parity

The test harness can run fixture/eval prompts against OpenAI Codex models
(`gpt-5.6-luna`/`sol`/`terra`, aliased as `luna`/`sol`/`terra`) with the same
isolation, tracing, and reporting guarantees as Claude. This document is the
model for that parity: what maps to what, and where the two paths genuinely
differ.

The implementation lives in `synaptic-canvas`'s `test-packages/harness/`
(`environment.py`, `runner.py`, `collector.py`); this repo (`sc-test-harness`)
is just the project under test, used by both paths identically.

## Routing

A test's `execution.model` selects the path. `harness.environment.MODEL_ALIASES`
(`luna`/`sol`/`terra` -> `gpt-5.6-*`) and `is_codex_model()` decide: anything
resolving to a `gpt-*` id runs via `codex exec`; everything else (haiku,
sonnet, opus, ...) runs via `claude -p`, completely unchanged. The two paths
never mix within one test.

## Invocation

```
codex exec --yolo --model <resolved-model> --json \
  --output-last-message <file> --skip-git-repo-check \
  -c 'shell_environment_policy.inherit="all"' <prompt>
```

`--json` emits one JSON object per line on stdout. That stream is captured
verbatim to `reports/{test_id}-codex-events.jsonl` — see "No hooks: JSONL is
the trace" below.

## Equivalence table

| Concern | Claude | Codex |
|---|---|---|
| Isolated config/home | `HOME` override (`isolated_home`) | `CODEX_HOME` override, set alongside `HOME` inside the same isolated dir (`isolated_home/.codex`) |
| Auth in isolation | Claude session auth lives under isolated `HOME` | `auth.json` copied from the real `~/.codex` into isolated `CODEX_HOME` (`copy_codex_auth` / `setup_codex_home`) |
| Trace mechanism | Hooks write `PreToolUse`/`PostToolUse`/... events to `trace.jsonl` | No hook system exists for Codex — the `--json` event stream on stdout *is* the trace, saved as `{test_id}-codex-events.jsonl` |
| Session record | Separate transcript JSONL under `~/.claude/projects/...` | None — the event stream also carries the final message (plus `--output-last-message` as a belt-and-suspenders authoritative copy) |
| Tool-permission control | `--allowedTools` / `--dangerously-skip-permissions` | `--yolo` (sandbox/approval bypass is the ecosystem convention for eval runs; there is no allowlist flag) |
| Skill loading | `Skill` tool invocation, tool-call visible in trace | No `Skill` tool. Codex reads `AGENTS.md` in the working directory automatically. The harness generates one pointing at every installed `.claude/skills/*/SKILL.md`, skipped if the fixture already ships its own `AGENTS.md`. Same skill content, each model's idiomatic loading path. |
| PATH control for stubbed binaries | Subprocess `env=` override is honored directly | Codex runs shell commands via `zsh -lc`, a **login shell** that re-sources the user's profile and rebuilds `PATH`, silently defeating a stub-PATH set only via the subprocess environment. Fixed by pointing `ZDOTDIR` at a workspace-owned directory whose `.zshenv` unconditionally prepends the stub bin dir, with empty `.zprofile`/`.zshrc` so nothing re-clobbers `PATH` afterward. |

## No hooks: JSONL is the trace

Claude's trace is built from hook events fired during the session. Codex has
no hook system, so there is nothing to log independently — the `--json`
event stream Codex prints to stdout *is* the complete record of what
happened. The harness treats `{test_id}-codex-events.jsonl` as a first-class
artifact, exactly parallel to `trace.jsonl`:

- Claude: `trace.jsonl` (hooks) + `<session>.jsonl` (transcript) -> `DataCollector.collect()`
- Codex: `{test_id}-codex-events.jsonl` (the `--json` stream) -> `DataCollector.collect_from_codex_events()`

Both produce the same `CollectedData` shape, so every existing expectation
evaluator (`tool_call`, `tool_not_called`, `tool_order`, `output_contains`,
`llm_judge`, `file_contains`, ...) works unchanged against a Codex run.

### Event mapping

| Codex event | `CollectedData` field |
|---|---|
| `item.completed` / `item.type == "command_execution"` | `CorrelatedToolCall(tool_name="Bash", tool_input={"command": item.command}, tool_response={"stdout": item.aggregated_output, "exit_code": item.exit_code}, is_error=exit_code not in (0, None))` |
| `item.completed` / `item.type == "agent_message"` | `ClaudeResponseText(text=item.text)` |
| `turn.completed` (`usage`) | `TokenUsage(input_tokens, output_tokens, cache_creation_tokens)`, aggregated across turns |

Every Codex tool call surfaces as tool `"Bash"` — Codex's `command_execution`
items don't distinguish tool identity the way Claude's tool-call blocks do,
so file edits, reads, and shell commands all arrive as shell commands. This
is faithful to what Codex actually did (it always shells out), not a lossy
approximation.

## CODEX_HOME isolation

`CODEX_HOME` is Codex's analogue of `HOME`: it holds config and `auth.json`,
the way `~/.claude` holds Claude's. `setup_test_environment()` provisions it
inside the same isolated directory used for `HOME` isolation
(`isolated_home/.codex`), and copies `auth.json` from the real `~/.codex` if
present (`copy_codex_auth`), so isolated Codex runs can still authenticate
without ever touching the real `~/.codex`. Setting `CODEX_HOME` in the
environment is inert on the Claude path — Claude never reads it.

## ZDOTDIR / PATH control

Ground truth, verified empirically: Codex executes shell commands via
`/bin/zsh -lc "<command>"`. `-l` makes it a **login shell**, which re-sources
`.zprofile`/`.zshrc`/etc. from the user's actual dotfiles and rebuilds `PATH`
from scratch — even when the parent process passed a carefully constructed
stub-PATH via `env=`. The fix is `ZDOTDIR`: pointing it at a workspace-owned
directory whose `.zshenv` unconditionally does
`export PATH="<stub-bin-dir>:$PATH"`, with empty `.zprofile`/`.zshrc` so no
later dotfile stage overwrites it. `.zshenv` is sourced by *every* zsh
invocation, interactive or not, login or not — so it wins regardless of what
`-l` does afterward. `environment.provision_codex_zdot()` implements this;
`IsolatedSession.run_codex_command()` calls it automatically before invoking
`codex exec`.

## AGENTS.md / Skill-tool parity

Codex has no `Skill` tool. Its native instruction-loading channel is
`AGENTS.md` in the working directory, which it reads automatically on
`codex exec`. To exercise the same skill content across both models, the
harness generates an `AGENTS.md` listing every installed
`.claude/skills/*/SKILL.md`, with the instruction "read the relevant skill
and follow it before acting" — before invoking Codex
(`environment.write_codex_agents_md()`, called from
`run_codex_command()`). If the fixture already ships its own `AGENTS.md`,
generation is skipped entirely so fixture-authored instructions are never
clobbered. This means a skill's actual instructions are identical between
runs — only the loading mechanism differs, matching each model's own idiom
(a tool call for Claude, a file Codex reads on startup).

Because `AGENTS.md` (and the harness's `.codex-zdot`/`bin` scratch dirs) are
untracked, `scripts/reset-test-repo.sh` / `reset_test_repo.py`'s
`git clean -fdx` removes them along with everything else — no Codex-specific
reset logic is needed. Reset in this repo remains model-agnostic.

## Deliberately out of scope

- Codex sandbox/approval modes beyond `--yolo` (no per-tool allowlist
  equivalent to `--allowedTools` exists in `codex exec`).
- Subagent-equivalent tracking: Codex has no `Task`/subagent concept, so
  `SubagentLifecycle` stays empty on the Codex path.
- Backfilling Claude-side `token_usage` from transcript `usage` fields
  (the field now exists on `CollectedData` for both paths, but wiring it up
  for Claude was a pre-existing TODO in `reporter.py`, unrelated to Codex
  parity, and was left alone).
