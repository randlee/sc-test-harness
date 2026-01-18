# Spike 2: Hook Observability Report

**Date**: 2026-01-16
**Author**: Agent (Spike Investigation)
**Status**: Complete

## Executive Summary

This spike investigated what Claude hook events capture and whether we can observe everything needed for testing. The findings are **highly positive** - hooks provide comprehensive observability of tool invocations, inputs, outputs, skill calls, and subagent lifecycles. However, there are some gaps that require attention.

## Current Hook Configuration

The test harness has hooks configured for all available event types:

| Event Type | Matcher | Handler |
|------------|---------|---------|
| SessionStart | `.*` | `python3 scripts/log-hook.py --event SessionStart` |
| SessionEnd | `.*` | `python3 scripts/log-hook.py --event SessionEnd` |
| UserPromptSubmit | `.*` | `python3 scripts/log-hook.py --event UserPromptSubmit` |
| PreToolUse | `.*` | `python3 scripts/log-hook.py --event PreToolUse` |
| PostToolUse | `.*` | `python3 scripts/log-hook.py --event PostToolUse` |
| SubagentStart | `.*` | `python3 scripts/log-hook.py --event SubagentStart` |
| SubagentStop | `.*` | `python3 scripts/log-hook.py --event SubagentStop` |
| Stop | `.*` | `python3 scripts/log-hook.py --event Stop` |
| Notification | `.*` | `python3 scripts/log-hook.py --event Notification` |
| PermissionRequest | `.*` | `python3 scripts/log-hook.py --event PermissionRequest` |

---

## Event Schema Documentation

### 1. SessionStart

**Fires**: At session startup before any prompts are processed.

**Payload Fields**:
| Field | Type | Description |
|-------|------|-------------|
| `session_id` | string (UUID) | Unique session identifier |
| `transcript_path` | string | Path to session transcript JSONL file |
| `cwd` | string | Current working directory |
| `hook_event_name` | string | Always "SessionStart" |
| `source` | string | Source of startup (e.g., "startup") |

**Example**:
```json
{
  "session_id": "4a69f9b0-a586-49ea-8a4a-ee356768841e",
  "transcript_path": "/Users/randlee/.claude/projects/-Users-randlee-Documents-github-sc-test-harness/4a69f9b0-a586-49ea-8a4a-ee356768841e.jsonl",
  "cwd": "/Users/randlee/Documents/github/sc-test-harness",
  "hook_event_name": "SessionStart",
  "source": "startup"
}
```

### 2. UserPromptSubmit

**Fires**: When a user prompt is submitted (before Claude processes it).

**Payload Fields**:
| Field | Type | Description |
|-------|------|-------------|
| `session_id` | string | Session identifier |
| `transcript_path` | string | Path to transcript |
| `cwd` | string | Current working directory |
| `permission_mode` | string | Permission mode (e.g., "bypassPermissions") |
| `hook_event_name` | string | Always "UserPromptSubmit" |
| `prompt` | string | **The full user prompt text** |

**Example**:
```json
{
  "session_id": "4a69f9b0-a586-49ea-8a4a-ee356768841e",
  "prompt": "list the files in the current directory using ls -la",
  "permission_mode": "bypassPermissions",
  "hook_event_name": "UserPromptSubmit"
}
```

### 3. PreToolUse

**Fires**: Before a tool is executed.

**Payload Fields**:
| Field | Type | Description |
|-------|------|-------------|
| `session_id` | string | Session identifier |
| `transcript_path` | string | Path to transcript |
| `cwd` | string | Current working directory |
| `permission_mode` | string | Permission mode |
| `hook_event_name` | string | Always "PreToolUse" |
| `tool_name` | string | Name of tool being invoked |
| `tool_input` | object | **Complete tool input parameters** |
| `tool_use_id` | string | Unique identifier for this tool invocation |

**Example (Bash)**:
```json
{
  "tool_name": "Bash",
  "tool_input": {
    "command": "ls -la",
    "description": "List all files and directories with details"
  },
  "tool_use_id": "toolu_016tu1oYHSRV37rwRkTNgGaA"
}
```

**Example (Read)**:
```json
{
  "tool_name": "Read",
  "tool_input": {
    "file_path": "/Users/randlee/Documents/github/sc-test-harness/pm/ARCH-SC.md"
  },
  "tool_use_id": "toolu_019o3YcUnD24hEyUrQwudjz7"
}
```

**Example (Skill)**:
```json
{
  "tool_name": "Skill",
  "tool_input": {
    "skill": "sc-startup",
    "args": "--readonly"
  },
  "tool_use_id": "toolu_01Bx67QzRabANFxJpLpsTeTf"
}
```

**Example (Task - Subagent)**:
```json
{
  "tool_name": "Task",
  "tool_input": {
    "description": "Search for TODO comments in repo",
    "prompt": "Search the entire repository for TODO comments...",
    "subagent_type": "Explore"
  },
  "tool_use_id": "toolu_01WuwM3F8GEL3MzNS8Zzz4PK"
}
```

### 4. PostToolUse

**Fires**: After a tool completes execution.

**Payload Fields**:
| Field | Type | Description |
|-------|------|-------------|
| `session_id` | string | Session identifier |
| `transcript_path` | string | Path to transcript |
| `cwd` | string | Current working directory |
| `permission_mode` | string | Permission mode |
| `hook_event_name` | string | Always "PostToolUse" |
| `tool_name` | string | Name of tool that was invoked |
| `tool_input` | object | Tool input parameters (same as PreToolUse) |
| `tool_response` | object | **Complete tool response** |
| `tool_use_id` | string | Matches the PreToolUse tool_use_id |

**Example (Bash - tool_response structure)**:
```json
{
  "tool_response": {
    "stdout": "total 24\ndrwxr-xr-x@ 12 randlee  staff   384 Jan 15 23:02 .\n...",
    "stderr": "",
    "interrupted": false,
    "isImage": false
  }
}
```

**Example (Read - tool_response structure)**:
```json
{
  "tool_response": {
    "type": "text",
    "file": {
      "filePath": "/Users/randlee/Documents/github/sc-test-harness/pm/ARCH-SC.md",
      "content": "# ARCH-SC Test Prompt\n\nThis is a test prompt...",
      "numLines": 4,
      "startLine": 1,
      "totalLines": 4
    }
  }
}
```

**Example (Skill - tool_response structure)**:
```json
{
  "tool_response": {
    "success": true,
    "commandName": "sc-startup"
  }
}
```

**Example (Task/Subagent - tool_response structure)**:
```json
{
  "tool_response": {
    "status": "completed",
    "prompt": "Search the entire repository for TODO comments...",
    "agentId": "a41d2ca",
    "content": [
      {
        "type": "text",
        "text": "Found all TODO comments in the repository..."
      }
    ],
    "totalDurationMs": 6497,
    "totalTokens": 11861,
    "totalToolUseCount": 1,
    "usage": { ... }
  }
}
```

### 5. SubagentStart

**Fires**: When a subagent (Task tool) is spawned.

**Payload Fields**:
| Field | Type | Description |
|-------|------|-------------|
| `session_id` | string | Parent session identifier |
| `transcript_path` | string | Parent transcript path |
| `cwd` | string | Working directory |
| `hook_event_name` | string | Always "SubagentStart" |
| `agent_id` | string | **Unique subagent identifier** (e.g., "a41d2ca") |
| `agent_type` | string | **Type of subagent** (e.g., "Explore", "sc-startup:sc-checklist-status") |

**Example**:
```json
{
  "session_id": "a063eb63-fcf1-4ddd-8ad4-78b76c8ad667",
  "hook_event_name": "SubagentStart",
  "agent_id": "a41d2ca",
  "agent_type": "Explore"
}
```

### 6. SubagentStop

**Fires**: When a subagent completes.

**Payload Fields**:
| Field | Type | Description |
|-------|------|-------------|
| `session_id` | string | Parent session identifier |
| `transcript_path` | string | Parent transcript path |
| `cwd` | string | Working directory |
| `permission_mode` | string | Permission mode |
| `hook_event_name` | string | Always "SubagentStop" |
| `stop_hook_active` | boolean | Whether stop hook is active |
| `agent_id` | string | Subagent identifier (matches SubagentStart) |
| `agent_transcript_path` | string | **Path to subagent's own transcript** |

**Example**:
```json
{
  "session_id": "a063eb63-fcf1-4ddd-8ad4-78b76c8ad667",
  "hook_event_name": "SubagentStop",
  "agent_id": "a41d2ca",
  "agent_transcript_path": "/Users/randlee/.claude/projects/-Users-randlee-Documents-github-sc-test-harness/a063eb63-fcf1-4ddd-8ad4-78b76c8ad667/subagents/agent-a41d2ca.jsonl"
}
```

### 7. Stop

**Fires**: When Claude stops responding (before SessionEnd).

**Payload Fields**:
| Field | Type | Description |
|-------|------|-------------|
| `session_id` | string | Session identifier |
| `transcript_path` | string | Transcript path |
| `cwd` | string | Working directory |
| `permission_mode` | string | Permission mode |
| `hook_event_name` | string | Always "Stop" |
| `stop_hook_active` | boolean | Whether stop hook is active |

### 8. SessionEnd

**Fires**: At the end of a session.

**Payload Fields**:
| Field | Type | Description |
|-------|------|-------------|
| `session_id` | string | Session identifier |
| `transcript_path` | string | Transcript path |
| `cwd` | string | Working directory |
| `hook_event_name` | string | Always "SessionEnd" |
| `reason` | string | Reason for ending (e.g., "other") |

---

## Coverage Matrix

| What We Need to Observe | Can We Observe It? | How? |
|------------------------|-------------------|------|
| Tool invocations | **YES** | PreToolUse event |
| Tool inputs (command/params) | **YES** | `tool_input` in PreToolUse/PostToolUse |
| Tool outputs (stdout/stderr) | **YES** | `tool_response` in PostToolUse |
| Tool errors | **PARTIAL** | PostToolUse may not fire; use transcript |
| Skill invocations | **YES** | PreToolUse with `tool_name: "Skill"` |
| Subagent lifecycle | **YES** | SubagentStart/SubagentStop events |
| Subagent internals | **YES** | `agent_transcript_path` in SubagentStop |
| User prompt | **YES** | `prompt` field in UserPromptSubmit |
| Claude response | **NO via hooks** | Must read transcript file |
| Session correlation | **YES** | `session_id` in all events |
| Tool correlation | **YES** | `tool_use_id` in Pre/PostToolUse |
| File contents read | **YES** | `tool_response.file.content` |
| File contents written | **YES** | `tool_input` for Write/Edit tools |

---

## Gap Analysis

### Gap 1: PostToolUse Not Always Firing

**Finding**: In experiment 5, when `exit 1` was run or `ls /nonexistent/path` failed, the PostToolUse hook did NOT fire, but PreToolUse did.

**Impact**: Cannot capture tool errors solely via hooks.

**Workaround**: The transcript file DOES contain the error with `"is_error": true`:
```json
{
  "type": "tool_result",
  "content": "Exit code 1\nls: /nonexistent/directory/path: No such file or directory",
  "is_error": true,
  "tool_use_id": "toolu_01LG2zWV4GUKozxX5tSNEcYw"
}
```

**Recommendation**: Always read the transcript file as a backup/supplement to hooks for complete error capture.

### Gap 2: No Direct Claude Response in Hooks

**Finding**: Hooks do not directly capture Claude's text responses to the user.

**Impact**: Cannot assert on Claude's explanatory text via hooks alone.

**Workaround**: Transcript files contain full Claude responses:
```json
{
  "type": "assistant",
  "message": {
    "role": "assistant",
    "content": [
      {
        "type": "text",
        "text": "Here are the files and directories..."
      }
    ]
  }
}
```

**Recommendation**: Parse transcript for response assertions.

### Gap 3: Environment Variables Not Populated

**Finding**: The `env` section captured by log-hook.py was always empty `{}`. Environment variables like `CLAUDE_AGENT_ID` were not set in the hook execution context.

**Impact**: Cannot use env vars to correlate subagent context.

**Workaround**: Use `agent_id` from SubagentStart/SubagentStop events instead.

---

## Experiment Results Summary

### Experiment 1: Basic Tool Capture (Bash ls -la)
- **Events fired**: SessionStart -> UserPromptSubmit -> PreToolUse(Bash) -> PostToolUse(Bash) -> Stop -> SessionEnd
- **PreToolUse captured**: Full command (`ls -la`), description
- **PostToolUse captured**: Full stdout, empty stderr, interrupted=false
- **Verdict**: COMPLETE OBSERVABILITY

### Experiment 2: Read Tool Capture
- **Events fired**: Same sequence with Read tool
- **tool_response structure different**: Contains `type`, `file.filePath`, `file.content`, `file.numLines`
- **File content**: FULLY CAPTURED in tool_response
- **Verdict**: COMPLETE OBSERVABILITY

### Experiment 3: Skill/Command Invocation
- **Events fired**: SessionStart -> UserPromptSubmit -> PreToolUse(Skill) -> PostToolUse(Skill) -> [inner tools] -> SubagentStart -> [subagent tools] -> SubagentStop -> PostToolUse(Task) -> ... -> Stop -> SessionEnd
- **Skill tool**: Captured with `skill` and `args` in tool_input
- **Inner skill tools**: ALL captured with PreToolUse/PostToolUse
- **Subagent transcript**: Path provided in SubagentStop for deep inspection
- **Verdict**: COMPLETE OBSERVABILITY (including nested calls)

### Experiment 4: Subagent/Task Detection
- **SubagentStart fired**: YES with `agent_id` and `agent_type`
- **SubagentStop fired**: YES with `agent_id` and `agent_transcript_path`
- **Subagent tools captured**: YES - Grep call inside Task visible
- **Verdict**: COMPLETE OBSERVABILITY

### Experiment 5: Error Capture
- **PreToolUse fired**: YES
- **PostToolUse fired**: NO (for error cases)
- **Transcript captured**: YES with `is_error: true`
- **Verdict**: PARTIAL - must supplement with transcript

---

## Recommendations for Test Harness

### 1. Dual-Source Data Collection

Use BOTH hooks AND transcript parsing:
```
trace.jsonl (hooks) -> Real-time capture, good for tool events
transcript.jsonl    -> Complete record including errors and responses
```

### 2. Correlation Strategy

Use these IDs for correlation:
- `session_id`: Correlate all events in a session
- `tool_use_id`: Match PreToolUse to PostToolUse to transcript tool_result
- `agent_id`: Track subagent lifecycle

### 3. Assertion Framework Design

```python
class HookAssertions:
    def assert_tool_called(self, tool_name: str, input_contains: dict = None)
    def assert_tool_output_contains(self, tool_use_id: str, content: str)
    def assert_no_errors(self)
    def assert_skill_invoked(self, skill_name: str, args: str = None)
    def assert_subagent_spawned(self, agent_type: str = None)
    def assert_subagent_completed(self, agent_id: str)

class TranscriptAssertions:
    def assert_response_contains(self, text: str)
    def assert_tool_error(self, tool_use_id: str, error_contains: str)
    def get_full_conversation(self) -> List[dict]
```

### 4. Event Flow Validation

Create expected event flow patterns:
```python
EXPECTED_SIMPLE_TOOL_FLOW = [
    "SessionStart",
    "UserPromptSubmit",
    "PreToolUse",
    "PostToolUse",
    "Stop",
    "SessionEnd"
]

EXPECTED_SUBAGENT_FLOW = [
    "SessionStart",
    "UserPromptSubmit",
    "PreToolUse(Task)",
    "SubagentStart",
    "PreToolUse(*)",  # subagent tools
    "PostToolUse(*)",
    "SubagentStop",
    "PostToolUse(Task)",
    "Stop",
    "SessionEnd"
]
```

### 5. Hook Logger Enhancements

Enhance `log-hook.py` to:
1. Parse the JSON stdin payload and extract key fields
2. Store in a more queryable format
3. Add indexes for fast lookup by tool_use_id, session_id
4. Consider SQLite instead of JSONL for complex queries

---

## Appendix: Data Locations

| Data Type | Location |
|-----------|----------|
| Hook events | `/path/to/repo/reports/trace.jsonl` |
| Session transcript | `~/.claude/projects/<encoded-path>/<session-id>.jsonl` |
| Subagent transcript | `~/.claude/projects/<encoded-path>/<session-id>/subagents/agent-<id>.jsonl` |

---

## Conclusion

Claude hooks provide **excellent observability** for test harness purposes:

1. **Full tool input/output capture** via PreToolUse/PostToolUse
2. **Complete skill invocation tracking** including nested tool calls
3. **Subagent lifecycle visibility** with dedicated SubagentStart/SubagentStop events
4. **User prompt capture** via UserPromptSubmit

The main gaps (error capture, Claude responses) are fully addressed by also parsing the transcript files, which Claude provides paths to in the hook payloads.

**Recommendation**: Proceed with implementing the test harness using hooks as the primary real-time capture mechanism, supplemented by transcript parsing for complete coverage.
