# CLI Agent Streaming Protocol Specification

**Version:** 1.0.0
**Date:** December 3, 2025
**Purpose:** Comprehensive specification of headless streaming protocols for Claude Code, Codex CLI, and Gemini CLI with a unified abstraction layer for Dart client library implementation.

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [Transport Layer](#2-transport-layer)
3. [Claude Code Protocol](#3-claude-code-protocol)
4. [Codex CLI Protocol](#4-codex-cli-protocol)
5. [Gemini CLI Protocol](#5-gemini-cli-protocol)
6. [Semantic Comparison](#6-semantic-comparison)
7. [Unified Protocol Specification](#7-unified-protocol-specification)
8. [JSON Schema Definitions](#8-json-schema-definitions)
9. [Implementation Notes](#9-implementation-notes)

---

## 1. Executive Summary

This specification documents the streaming protocols used by the three major AI coding assistants:

| CLI | Primary Transport | Message Format | Session ID Format |
|-----|-------------------|----------------|-------------------|
| **Claude Code** | REST + WebSocket | JSON events | UUID v4 |
| **Codex CLI** | Stdio pipes | JSONL (newline-delimited) | `sess_` + alphanumeric |
| **Gemini CLI** | Stdio/SSE/HTTP | JSONL (newline-delimited) | UUID + timestamp |

### Key Findings

1. **All three use JSON-based streaming** - Claude uses discrete JSON objects over WebSocket; Codex and Gemini use JSONL over stdio
2. **Session management varies significantly** - Claude uses server-managed sessions; Codex/Gemini use file-based persistence
3. **Permission models are semantically equivalent** - All three have "ask", "auto-approve", and "YOLO" modes with different names
4. **Tool call patterns are similar** - All emit start/update/complete lifecycle events for tools

---

## 2. Transport Layer

### 2.1 Transport Comparison Matrix

| Aspect | Claude Code | Codex CLI | Gemini CLI |
|--------|-------------|-----------|------------|
| **Primary Transport** | HTTP REST + WebSocket | Stdio (pipes) | Stdio/SSE/HTTP (configurable) |
| **Headless Mode** | Native (REST API) | `codex exec` command | `-p/--prompt` flag |
| **Streaming Method** | WebSocket push | Async readline on stdout | Async readline on stdout |
| **Message Framing** | Complete JSON objects | Newline delimiter (`\n`) | Newline delimiter (`\n`) |
| **Bidirectional** | Yes (WebSocket) | Yes (stdin/stdout) | Yes (stdin/stdout) |
| **Connection State** | Persistent HTTP connection | Process lifetime | Process lifetime |

### 2.2 Claude Code Transport

```
Client                     Server (Dart Backend)              Agent Process
  │                              │                                  │
  │──POST /api/sessions─────────>│                                  │
  │<─────────{"id":"..."}────────│                                  │
  │                              │──spawn claude-code-acp──────────>│
  │──WS /ws/sessions/<id>───────>│                                  │
  │<────historical events────────│                                  │
  │<────live events──────────────│<─────NDJSON events───────────────│
  │                              │                                  │
```

**Endpoints:**
- `POST /api/sessions` - Create session
- `GET /api/sessions/<id>` - Get session state
- `GET /api/sessions/<id>/events?offset=N&limit=M` - Paginated history
- `POST /api/sessions/<id>/cancel` - Cancel session
- `WS /ws/sessions/<id>` - Real-time event stream

### 2.3 Codex CLI Transport

```
SDK/Client                        Codex Process
    │                                  │
    │──spawn codex exec [args]────────>│
    │──write prompt to stdin──────────>│
    │──close stdin────────────────────>│
    │                                  │
    │<───JSONL events on stdout────────│
    │<───JSONL events on stdout────────│
    │<───process exit─────────────────│
    │                                  │
```

**CLI Invocation:**
```bash
codex exec --output-jsonl "prompt text"
codex exec --output-jsonl --resume <session_id> "continue prompt"
```

### 2.4 Gemini CLI Transport

```
Client                           Gemini Process
  │                                  │
  │──spawn gemini -p [args]─────────>│
  │                                  │
  │<───JSONL events on stdout────────│
  │<───JSONL events on stdout────────│
  │<───process exit─────────────────│
  │                                  │
```

**CLI Invocation:**
```bash
gemini -p "prompt" --output-format stream-json
gemini -p "prompt" --output-format stream-json --resume <session_id>
```

---

## 3. Claude Code Protocol

### 3.1 Session Lifecycle

#### Create Session

**Request:**
```http
POST /api/sessions
Content-Type: application/json

{
  "agentId": "claude",
  "projectId": "my-project",
  "prompt": "Refactor the authentication module"
}
```

**Response:**
```json
{
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "state": "running"
}
```

#### Session States

```typescript
enum SessionState {
  running   = "running",    // Active, accepting events
  done      = "done",       // Completed successfully
  failed    = "failed",     // Error occurred
  cancelled = "cancelled"   // User cancelled
}
```

### 3.2 Event Types

```typescript
enum SessionEventType {
  plan       = "plan",       // Planning phase output
  log        = "log",        // Log messages
  diff       = "diff",       // File changes
  action     = "action",     // Tool action initiated
  toolResult = "toolResult", // Tool execution result
  error      = "error",      // Error occurred
  cancelled  = "cancelled"   // Cancellation confirmed
}
```

### 3.3 Event Message Format

```json
{
  "id": "evt-550e8400-e29b-41d4-a716-446655440001",
  "sessionId": "550e8400-e29b-41d4-a716-446655440000",
  "type": "log",
  "payload": {
    "line": "Analyzing project structure..."
  },
  "timestamp": "2025-12-03T10:00:01.234Z"
}
```

### 3.4 Event Payload Schemas

#### Plan Event
```json
{
  "type": "plan",
  "payload": {
    "message": "Planning edits for: Refactor authentication"
  }
}
```

#### Log Event
```json
{
  "type": "log",
  "payload": {
    "line": "Reading file: src/auth.ts"
  }
}
```

#### Diff Event
```json
{
  "type": "diff",
  "payload": {
    "file": "src/auth.ts",
    "diff": "@@ -10,5 +10,8 @@\n-old line\n+new line"
  }
}
```

#### Action Event
```json
{
  "type": "action",
  "payload": {
    "tool": "Edit",
    "args": {
      "file_path": "/src/auth.ts",
      "old_string": "function login()",
      "new_string": "async function login()"
    }
  }
}
```

#### Tool Result Event
```json
{
  "type": "toolResult",
  "payload": {
    "tool": "Edit",
    "success": true,
    "output": "File updated successfully"
  }
}
```

#### Error Event
```json
{
  "type": "error",
  "payload": {
    "message": "Session failed: Permission denied"
  }
}
```

### 3.5 WebSocket Protocol

**Connection URL:** `ws://host:port/ws/sessions/<sessionId>`

**Connection Flow:**
1. Client connects to WebSocket endpoint
2. Server validates session exists
3. Server sends all historical events immediately (replay)
4. Server streams new events in real-time
5. Stream closes when session ends (done/failed/cancelled)

**Message Format:** Each WebSocket message is a JSON-encoded `SessionEvent` object.

### 3.6 CLI Arguments

| Argument | Description |
|----------|-------------|
| `--resume <session-id>` | Resume existing session |
| `--dangerously-skip-permissions` | Auto-approve all tool calls |
| `--allowedTools <list>` | Comma-separated tool allowlist |
| `--model <model>` | Specify model |
| `--max-turns <n>` | Limit conversation turns |

### 3.7 Permission Control

**Modes:**
- **Default (ask):** Prompt user for each tool execution
- **dangerouslySkipPermissions:** Auto-approve everything (YOLO equivalent)
- **Allowlist:** Auto-approve only specific tools

**Configuration (hooks):**
```json
{
  "hooks": {
    "beforeToolCall": "./scripts/approve-tool.sh"
  }
}
```

---

## 4. Codex CLI Protocol

### 4.1 Session Lifecycle

#### Start Session

```bash
codex exec --output-jsonl "Your prompt here"
```

**First Event:**
```json
{"type":"thread.started","thread_id":"sess_abc123xyz"}
```

#### Resume Session

```bash
codex exec --output-jsonl --resume sess_abc123xyz "Continue with..."
# OR
codex resume sess_abc123xyz
```

### 4.2 Event Types

```typescript
// Session events
type ThreadStartedEvent = {
  type: "thread.started";
  thread_id: string;
};

// Turn lifecycle
type TurnStartedEvent = {
  type: "turn.started";
};

type TurnCompletedEvent = {
  type: "turn.completed";
  usage: {
    input_tokens: number;
    cached_input_tokens?: number;
    output_tokens: number;
  };
};

type TurnFailedEvent = {
  type: "turn.failed";
  error: { message: string };
};

// Item lifecycle
type ItemStartedEvent = {
  type: "item.started";
  item_type: string;
};

type ItemUpdatedEvent = {
  type: "item.updated";
  item_type: string;
  // Item-specific fields
};

type ItemCompletedEvent = {
  type: "item.completed";
  item_type: string;
  status: "success" | "failed";
};

// Errors
type ThreadErrorEvent = {
  type: "error";
  message: string;
};
```

### 4.3 Item Types

```typescript
type ItemType =
  | "agent_message"      // Model text response
  | "reasoning"          // Internal reasoning (if supported)
  | "command_execution"  // Shell command
  | "file_change"        // File modification
  | "mcp_tool_call"      // MCP tool invocation
  | "web_search"         // Web search
  | "todo_list"          // Task planning
  | "error";             // Error item
```

### 4.4 Item Payload Examples

#### Agent Message
```json
{"type":"item.started","item_type":"agent_message"}
{"type":"item.updated","item_type":"agent_message","content":"I'll help you refactor..."}
{"type":"item.updated","item_type":"agent_message","content":"I'll help you refactor the auth module..."}
{"type":"item.completed","item_type":"agent_message","status":"success"}
```

#### Command Execution
```json
{"type":"item.started","item_type":"command_execution"}
{"type":"item.updated","item_type":"command_execution","command_line":"npm test","aggregated_output":""}
{"type":"item.updated","item_type":"command_execution","command_line":"npm test","aggregated_output":"[PASS] auth.test.js\n"}
{"type":"item.completed","item_type":"command_execution","status":"success","exit_code":0}
```

#### File Change
```json
{"type":"item.started","item_type":"file_change"}
{"type":"item.updated","item_type":"file_change","changes":[{"path":"src/auth.ts","before":"...","after":"..."}]}
{"type":"item.completed","item_type":"file_change","status":"success"}
```

#### MCP Tool Call
```json
{"type":"item.started","item_type":"mcp_tool_call"}
{"type":"item.updated","item_type":"mcp_tool_call","tool_name":"database_query","tool_input":{"sql":"SELECT * FROM users"},"tool_result":""}
{"type":"item.updated","item_type":"mcp_tool_call","tool_name":"database_query","tool_result":"[{id:1,name:'Alice'}]"}
{"type":"item.completed","item_type":"mcp_tool_call","status":"success"}
```

### 4.5 CLI Arguments

| Argument | Short | Description |
|----------|-------|-------------|
| `exec` | | Non-interactive mode |
| `--output-jsonl` | | Enable JSONL streaming output |
| `--output-last-message` | | Output only final message |
| `--output-schema <file>` | | JSON schema for structured output |
| `--ask-for-approval` | `-a` | Require approval for actions |
| `--model <name>` | | Specify model |
| `--cd <path>` | | Working directory |
| `--full-auto` | | danger-full-access mode |
| `--env KEY=val` | | Set environment variable |
| `resume` | | Resume session subcommand |
| `resume --last` | | Resume most recent session |

### 4.6 Permission Control

**Approval Policies:**

| Mode | CLI Flag | Behavior |
|------|----------|----------|
| `never` | `--full-auto` | No prompts, full autonomy |
| `on-request` | (default) | Prompt on escalation |
| `on-failure` | | Prompt if sandbox blocks |
| `untrusted` | `-a` | Prompt before sensitive commands |

**Sandbox Modes:**

| Mode | Write Access | Network | Use Case |
|------|--------------|---------|----------|
| `read-only` | No | No | Inspection only |
| `workspace-write` | CWD + tmp | No | Safe development |
| `danger-full-access` | All | Yes | Unrestricted |

**Configuration (~/.codex/config.toml):**
```toml
[core]
approval_policy = "on-request"
sandbox_mode = "workspace-write"

[sandbox_workspace_write]
network_access = false
writable_roots = ["/extra/path"]
```

---

## 5. Gemini CLI Protocol

### 5.1 Session Lifecycle

#### Start Session

```bash
gemini -p "Your prompt here" --output-format stream-json
```

#### Resume Session

```bash
gemini --resume "Continue with..."
gemini --resume 1 "Continue..."  # By index
gemini --resume <uuid> "Continue..."  # By ID
```

### 5.2 Event Types

```typescript
type StreamEventType =
  | "content"        // Text content from model
  | "tool_call"      // Tool invocation
  | "result"         // Completion with stats
  | "error"          // Error event
  | "retry";         // Retry signal
```

### 5.3 Event Message Format

#### Content Event
```json
{"type":"content","value":"Analyzing the codebase structure..."}
```

#### Tool Call Event
```json
{
  "type": "tool_call",
  "name": "write_file",
  "args": {
    "file_path": "./src/auth.ts",
    "content": "export async function login() { ... }"
  }
}
```

#### Result Event
```json
{
  "type": "result",
  "status": "success",
  "stats": {
    "total_tokens": 350,
    "input_tokens": 100,
    "output_tokens": 250,
    "thought_tokens": 0,
    "cache_tokens": 0,
    "tool_tokens": 0,
    "duration_ms": 5000,
    "tool_calls": 2
  },
  "timestamp": "2025-12-03T10:30:00Z"
}
```

#### Error Event
```json
{
  "type": "error",
  "status": "error",
  "error": {
    "code": "INVALID_CHUNK",
    "message": "Stream ended with invalid chunk"
  }
}
```

### 5.4 CLI Arguments

| Argument | Short | Description |
|----------|-------|-------------|
| `--prompt <text>` | `-p` | Headless mode with prompt |
| `--output-format <fmt>` | | text, json, or stream-json |
| `--approval-mode <mode>` | | default, auto_edit, or yolo |
| `--yolo` | `-y` | Auto-approve all (legacy) |
| `--auto-edit` | | Auto-approve file edits only |
| `--sandbox` | | Enable Docker sandbox |
| `--sandbox-image <img>` | | Custom sandbox image |
| `--model <name>` | `-m` | Specify model |
| `--resume` | | Resume session |
| `--allowed-tools <list>` | | Tool allowlist |

### 5.5 Permission Control

**Approval Modes:**

| Mode | CLI Flag | Behavior |
|------|----------|----------|
| `default` | (none) | Prompt for each tool |
| `auto_edit` | `--auto-edit` | Auto-approve file edits only |
| `yolo` | `-y` / `--yolo` | Auto-approve everything |

**Per-Server Trust (settings.json):**
```json
{
  "mcpServers": {
    "trustedServer": {
      "command": "server",
      "trust": true
    }
  }
}
```

**Tool Filtering:**
```json
{
  "mcpServers": {
    "myServer": {
      "includeTools": ["safe_tool"],
      "excludeTools": ["dangerous_tool"]
    }
  }
}
```

### 5.6 Session Storage

**Locations:**
```
~/.gemini/tmp/<project_hash>/chats/       # Session files
~/.gemini/tmp/<project_hash>/checkpoints/ # Checkpoints
~/.gemini/history/<project_hash>/         # Shadow Git repo
```

**Checkpointing (Git-based):**
```json
{
  "general": {
    "checkpointing": {
      "enabled": true
    }
  }
}
```

---

## 6. Semantic Comparison

### 6.1 Terminology Mapping

| Concept | Claude Code | Codex CLI | Gemini CLI |
|---------|-------------|-----------|------------|
| **Session ID** | UUID v4 | `sess_` + alphanumeric | UUID |
| **Full Auto Mode** | `dangerouslySkipPermissions` | `danger-full-access` / `--full-auto` | `yolo` / `-y` |
| **Ask Mode** | Default | `untrusted` / `-a` | `default` |
| **Semi-Auto Mode** | (via hooks) | `on-request` | `auto_edit` |
| **Session State: Active** | `running` | (implicit, streaming) | (implicit, streaming) |
| **Session State: Done** | `done` | `turn.completed` | `result.status: "success"` |
| **Session State: Error** | `failed` | `turn.failed` | `result.status: "error"` |
| **Session State: Cancelled** | `cancelled` | (AbortSignal) | (AbortSignal) |
| **Tool Start** | `action` event | `item.started` | `tool_call` event |
| **Tool Progress** | (N/A) | `item.updated` | (N/A - atomic) |
| **Tool Complete** | `toolResult` event | `item.completed` | (next content event) |
| **File Change** | `diff` event | `file_change` item | `write_file` tool_call |
| **Text Output** | `log` event | `agent_message` item | `content` event |
| **Planning** | `plan` event | `reasoning` item | (embedded in content) |
| **Token Usage** | (in result event) | `turn.completed.usage` | `result.stats` |

### 6.2 Feature Comparison

| Feature | Claude Code | Codex CLI | Gemini CLI |
|---------|-------------|-----------|------------|
| **WebSocket Streaming** | Yes | No | No |
| **HTTP Polling** | Yes (events endpoint) | No | No |
| **Stdio Streaming** | Via ACP | Yes (primary) | Yes (primary) |
| **SSE Transport** | No | No | Yes (MCP servers) |
| **Session Persistence** | Server-side | File-based | File + Git |
| **Partial Text Streaming** | Per-event | `item.updated` | Per-line |
| **Tool Call Lifecycle** | 2-phase (start/result) | 3-phase (start/update/complete) | 1-phase (atomic) |
| **Structured Output Schema** | No | Yes (`--output-schema`) | Partial (proposed) |
| **MCP Integration** | Planned | Yes (as server) | Yes (client) |
| **Sandbox Mode** | No | Yes (3 levels) | Yes (Docker/Podman) |
| **Git Checkpointing** | No | No | Yes |
| **Token Tracking** | Limited | Full | Full |
| **Hook System** | Yes | Via policy files | Proposed |

### 6.3 Event Flow Comparison

**Claude Code:**
```
plan → log* → action → toolResult → log* → (done|failed|cancelled)
```

**Codex CLI:**
```
thread.started → turn.started →
  (item.started → item.updated* → item.completed)* →
turn.completed
```

**Gemini CLI:**
```
content* → tool_call → content* → result
```

### 6.4 Permission Mode Mapping

| Behavior | Claude Code | Codex CLI | Gemini CLI |
|----------|-------------|-----------|------------|
| Ask for everything | Default | `untrusted` | `default` |
| Ask for dangerous only | (hooks) | `on-request` | - |
| Auto-approve file edits | (hooks) | - | `auto_edit` |
| Auto-approve all | `dangerouslySkipPermissions` | `never` / `--full-auto` | `yolo` |
| Sandbox execution | - | `workspace-write` | `--sandbox` |
| Full system access | - | `danger-full-access` | `--sandbox` disabled |

---

## 7. Unified Protocol Specification

### 7.1 Design Goals

1. **Transport Agnostic:** Support WebSocket, stdio, and HTTP polling
2. **Event-Driven:** Consistent event lifecycle across all backends
3. **Type-Safe:** Strong typing for Dart implementation
4. **Lossless:** No information loss when translating from native protocols
5. **Extensible:** Support for future CLIs and features

### 7.2 Unified Event Model

```dart
/// Base event type
sealed class AgentEvent {
  final String id;
  final String sessionId;
  final DateTime timestamp;
  final AgentEventType type;
}

/// Event types
enum AgentEventType {
  // Session lifecycle
  sessionStarted,
  sessionEnded,

  // Turn lifecycle
  turnStarted,
  turnCompleted,
  turnFailed,

  // Content streaming
  textChunk,

  // Tool lifecycle
  toolStarted,
  toolProgress,
  toolCompleted,
  toolFailed,

  // File operations
  fileChanged,

  // Errors
  error,
}
```

### 7.3 Unified Session Model

```dart
/// Session configuration
class SessionConfig {
  final String agentType;        // "claude" | "codex" | "gemini"
  final String? projectId;
  final String? workingDirectory;
  final String? model;
  final ApprovalMode approvalMode;
  final SandboxMode sandboxMode;
  final List<String>? allowedTools;
  final List<String>? blockedTools;
  final int? maxTurns;
}

/// Approval modes (normalized)
enum ApprovalMode {
  ask,          // Prompt for every tool
  askDangerous, // Prompt only for dangerous tools
  autoEdit,     // Auto-approve file operations
  autoAll,      // Auto-approve everything (YOLO)
}

/// Sandbox modes (normalized)
enum SandboxMode {
  none,           // No sandboxing
  readOnly,       // Read-only access
  workspaceWrite, // Write to workspace only
  fullAccess,     // Unrestricted (danger mode)
}
```

### 7.4 Unified Event Types

#### Session Started
```dart
class SessionStartedEvent extends AgentEvent {
  final String sessionId;
  final String agentType;
  final SessionConfig config;
}
```

**Wire format:**
```json
{
  "id": "evt_001",
  "sessionId": "sess_abc123",
  "timestamp": "2025-12-03T10:00:00.000Z",
  "type": "sessionStarted",
  "agentType": "codex",
  "config": {
    "model": "gpt-4",
    "approvalMode": "ask",
    "sandboxMode": "workspaceWrite"
  }
}
```

#### Turn Started
```dart
class TurnStartedEvent extends AgentEvent {
  final int turnNumber;
  final String prompt;
}
```

#### Text Chunk
```dart
class TextChunkEvent extends AgentEvent {
  final String content;
  final bool isComplete;
}
```

#### Tool Started
```dart
class ToolStartedEvent extends AgentEvent {
  final String toolId;
  final String toolName;
  final Map<String, dynamic> arguments;
}
```

#### Tool Progress
```dart
class ToolProgressEvent extends AgentEvent {
  final String toolId;
  final String? output;
  final double? progress; // 0.0 to 1.0
}
```

#### Tool Completed
```dart
class ToolCompletedEvent extends AgentEvent {
  final String toolId;
  final bool success;
  final dynamic result;
  final String? error;
}
```

#### File Changed
```dart
class FileChangedEvent extends AgentEvent {
  final String filePath;
  final FileChangeType changeType;
  final String? diff;
  final String? before;
  final String? after;
}

enum FileChangeType { created, modified, deleted }
```

#### Turn Completed
```dart
class TurnCompletedEvent extends AgentEvent {
  final int turnNumber;
  final TokenUsage usage;
  final Duration duration;
}

class TokenUsage {
  final int inputTokens;
  final int outputTokens;
  final int? cachedTokens;
  final int? reasoningTokens;
  final int totalTokens;
}
```

#### Session Ended
```dart
class SessionEndedEvent extends AgentEvent {
  final SessionEndReason reason;
  final String? error;
}

enum SessionEndReason {
  completed,
  failed,
  cancelled,
  timeout,
}
```

### 7.5 Protocol Adapters

Each CLI requires an adapter to translate native events:

```dart
abstract class ProtocolAdapter {
  Stream<AgentEvent> adaptEvents(Stream<dynamic> nativeEvents);
  dynamic translateRequest(AgentRequest request);
  SessionConfig translateConfig(Map<String, dynamic> nativeConfig);
}

class ClaudeAdapter implements ProtocolAdapter { ... }
class CodexAdapter implements ProtocolAdapter { ... }
class GeminiAdapter implements ProtocolAdapter { ... }
```

### 7.6 Event Translation Rules

#### From Claude Code
| Native Event | Unified Event |
|--------------|---------------|
| (WebSocket connect) | `SessionStartedEvent` |
| `type: "plan"` | `TextChunkEvent` (isComplete: true) |
| `type: "log"` | `TextChunkEvent` (isComplete: true) |
| `type: "action"` | `ToolStartedEvent` |
| `type: "toolResult"` | `ToolCompletedEvent` |
| `type: "diff"` | `FileChangedEvent` |
| `type: "error"` | `SessionEndedEvent` (reason: failed) |
| `type: "cancelled"` | `SessionEndedEvent` (reason: cancelled) |
| (WebSocket close, state: done) | `SessionEndedEvent` (reason: completed) |

#### From Codex CLI
| Native Event | Unified Event |
|--------------|---------------|
| `type: "thread.started"` | `SessionStartedEvent` |
| `type: "turn.started"` | `TurnStartedEvent` |
| `type: "item.started"` (agent_message) | (prepare for TextChunk) |
| `type: "item.updated"` (agent_message) | `TextChunkEvent` |
| `type: "item.completed"` (agent_message) | `TextChunkEvent` (isComplete: true) |
| `type: "item.started"` (command_execution) | `ToolStartedEvent` |
| `type: "item.updated"` (command_execution) | `ToolProgressEvent` |
| `type: "item.completed"` (command_execution) | `ToolCompletedEvent` |
| `type: "item.*"` (file_change) | `FileChangedEvent` |
| `type: "turn.completed"` | `TurnCompletedEvent` |
| `type: "turn.failed"` | `SessionEndedEvent` (reason: failed) |
| `type: "error"` | `SessionEndedEvent` (reason: failed) |

#### From Gemini CLI
| Native Event | Unified Event |
|--------------|---------------|
| (first event) | `SessionStartedEvent` |
| `type: "content"` | `TextChunkEvent` |
| `type: "tool_call"` | `ToolStartedEvent` + `ToolCompletedEvent` |
| `type: "result"` (success) | `TurnCompletedEvent` + `SessionEndedEvent` |
| `type: "result"` (error) | `SessionEndedEvent` (reason: failed) |
| `type: "error"` | `SessionEndedEvent` (reason: failed) |

---

## 8. JSON Schema Definitions

### 8.1 Unified Event Schema

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "$id": "https://agent-board.dev/schemas/unified-event.json",
  "title": "UnifiedAgentEvent",
  "type": "object",
  "required": ["id", "sessionId", "timestamp", "type"],
  "properties": {
    "id": {
      "type": "string",
      "description": "Unique event identifier"
    },
    "sessionId": {
      "type": "string",
      "description": "Session this event belongs to"
    },
    "timestamp": {
      "type": "string",
      "format": "date-time",
      "description": "ISO 8601 timestamp"
    },
    "type": {
      "type": "string",
      "enum": [
        "sessionStarted",
        "sessionEnded",
        "turnStarted",
        "turnCompleted",
        "turnFailed",
        "textChunk",
        "toolStarted",
        "toolProgress",
        "toolCompleted",
        "toolFailed",
        "fileChanged",
        "error"
      ]
    }
  },
  "allOf": [
    {
      "if": { "properties": { "type": { "const": "sessionStarted" } } },
      "then": {
        "properties": {
          "agentType": { "type": "string", "enum": ["claude", "codex", "gemini"] },
          "config": { "$ref": "#/$defs/SessionConfig" }
        },
        "required": ["agentType"]
      }
    },
    {
      "if": { "properties": { "type": { "const": "textChunk" } } },
      "then": {
        "properties": {
          "content": { "type": "string" },
          "isComplete": { "type": "boolean", "default": false }
        },
        "required": ["content"]
      }
    },
    {
      "if": { "properties": { "type": { "const": "toolStarted" } } },
      "then": {
        "properties": {
          "toolId": { "type": "string" },
          "toolName": { "type": "string" },
          "arguments": { "type": "object" }
        },
        "required": ["toolId", "toolName"]
      }
    },
    {
      "if": { "properties": { "type": { "const": "toolProgress" } } },
      "then": {
        "properties": {
          "toolId": { "type": "string" },
          "output": { "type": "string" },
          "progress": { "type": "number", "minimum": 0, "maximum": 1 }
        },
        "required": ["toolId"]
      }
    },
    {
      "if": { "properties": { "type": { "const": "toolCompleted" } } },
      "then": {
        "properties": {
          "toolId": { "type": "string" },
          "success": { "type": "boolean" },
          "result": {},
          "error": { "type": "string" }
        },
        "required": ["toolId", "success"]
      }
    },
    {
      "if": { "properties": { "type": { "const": "fileChanged" } } },
      "then": {
        "properties": {
          "filePath": { "type": "string" },
          "changeType": { "type": "string", "enum": ["created", "modified", "deleted"] },
          "diff": { "type": "string" },
          "before": { "type": "string" },
          "after": { "type": "string" }
        },
        "required": ["filePath", "changeType"]
      }
    },
    {
      "if": { "properties": { "type": { "const": "turnCompleted" } } },
      "then": {
        "properties": {
          "turnNumber": { "type": "integer" },
          "usage": { "$ref": "#/$defs/TokenUsage" },
          "durationMs": { "type": "integer" }
        },
        "required": ["turnNumber", "usage"]
      }
    },
    {
      "if": { "properties": { "type": { "const": "sessionEnded" } } },
      "then": {
        "properties": {
          "reason": { "type": "string", "enum": ["completed", "failed", "cancelled", "timeout"] },
          "error": { "type": "string" }
        },
        "required": ["reason"]
      }
    }
  ],
  "$defs": {
    "SessionConfig": {
      "type": "object",
      "properties": {
        "agentType": { "type": "string" },
        "projectId": { "type": "string" },
        "workingDirectory": { "type": "string" },
        "model": { "type": "string" },
        "approvalMode": { "type": "string", "enum": ["ask", "askDangerous", "autoEdit", "autoAll"] },
        "sandboxMode": { "type": "string", "enum": ["none", "readOnly", "workspaceWrite", "fullAccess"] },
        "allowedTools": { "type": "array", "items": { "type": "string" } },
        "blockedTools": { "type": "array", "items": { "type": "string" } },
        "maxTurns": { "type": "integer" }
      }
    },
    "TokenUsage": {
      "type": "object",
      "properties": {
        "inputTokens": { "type": "integer" },
        "outputTokens": { "type": "integer" },
        "cachedTokens": { "type": "integer" },
        "reasoningTokens": { "type": "integer" },
        "totalTokens": { "type": "integer" }
      },
      "required": ["inputTokens", "outputTokens", "totalTokens"]
    }
  }
}
```

### 8.2 Session Request Schema

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "$id": "https://agent-board.dev/schemas/session-request.json",
  "title": "SessionRequest",
  "type": "object",
  "required": ["agentType", "prompt"],
  "properties": {
    "agentType": {
      "type": "string",
      "enum": ["claude", "codex", "gemini"],
      "description": "Target agent CLI"
    },
    "prompt": {
      "type": "string",
      "maxLength": 100000,
      "description": "User prompt"
    },
    "sessionId": {
      "type": "string",
      "description": "Optional session ID to resume"
    },
    "config": {
      "$ref": "#/$defs/SessionConfig"
    }
  },
  "$defs": {
    "SessionConfig": {
      "type": "object",
      "properties": {
        "projectId": { "type": "string" },
        "workingDirectory": { "type": "string" },
        "model": { "type": "string" },
        "approvalMode": {
          "type": "string",
          "enum": ["ask", "askDangerous", "autoEdit", "autoAll"],
          "default": "ask"
        },
        "sandboxMode": {
          "type": "string",
          "enum": ["none", "readOnly", "workspaceWrite", "fullAccess"],
          "default": "none"
        },
        "allowedTools": {
          "type": "array",
          "items": { "type": "string" }
        },
        "blockedTools": {
          "type": "array",
          "items": { "type": "string" }
        },
        "maxTurns": {
          "type": "integer",
          "minimum": 1,
          "maximum": 1000
        }
      }
    }
  }
}
```

### 8.3 Native Protocol Schemas

#### Claude Code Session Event
```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "$id": "https://agent-board.dev/schemas/claude/session-event.json",
  "title": "ClaudeSessionEvent",
  "type": "object",
  "required": ["id", "sessionId", "type", "payload", "timestamp"],
  "properties": {
    "id": { "type": "string", "format": "uuid" },
    "sessionId": { "type": "string", "format": "uuid" },
    "type": {
      "type": "string",
      "enum": ["plan", "log", "diff", "action", "toolResult", "error", "cancelled"]
    },
    "payload": { "type": "object" },
    "timestamp": { "type": "string", "format": "date-time" }
  }
}
```

#### Codex CLI Thread Event
```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "$id": "https://agent-board.dev/schemas/codex/thread-event.json",
  "title": "CodexThreadEvent",
  "oneOf": [
    {
      "type": "object",
      "properties": {
        "type": { "const": "thread.started" },
        "thread_id": { "type": "string" }
      },
      "required": ["type", "thread_id"]
    },
    {
      "type": "object",
      "properties": {
        "type": { "const": "turn.started" }
      },
      "required": ["type"]
    },
    {
      "type": "object",
      "properties": {
        "type": { "const": "turn.completed" },
        "usage": {
          "type": "object",
          "properties": {
            "input_tokens": { "type": "integer" },
            "cached_input_tokens": { "type": "integer" },
            "output_tokens": { "type": "integer" }
          },
          "required": ["input_tokens", "output_tokens"]
        }
      },
      "required": ["type", "usage"]
    },
    {
      "type": "object",
      "properties": {
        "type": { "const": "turn.failed" },
        "error": {
          "type": "object",
          "properties": {
            "message": { "type": "string" }
          },
          "required": ["message"]
        }
      },
      "required": ["type", "error"]
    },
    {
      "type": "object",
      "properties": {
        "type": { "const": "item.started" },
        "item_type": { "type": "string" }
      },
      "required": ["type", "item_type"]
    },
    {
      "type": "object",
      "properties": {
        "type": { "const": "item.updated" },
        "item_type": { "type": "string" }
      },
      "required": ["type", "item_type"]
    },
    {
      "type": "object",
      "properties": {
        "type": { "const": "item.completed" },
        "item_type": { "type": "string" },
        "status": { "type": "string", "enum": ["success", "failed"] }
      },
      "required": ["type", "item_type", "status"]
    },
    {
      "type": "object",
      "properties": {
        "type": { "const": "error" },
        "message": { "type": "string" }
      },
      "required": ["type", "message"]
    }
  ]
}
```

#### Gemini CLI Stream Event
```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "$id": "https://agent-board.dev/schemas/gemini/stream-event.json",
  "title": "GeminiStreamEvent",
  "oneOf": [
    {
      "type": "object",
      "properties": {
        "type": { "const": "content" },
        "value": { "type": "string" }
      },
      "required": ["type", "value"]
    },
    {
      "type": "object",
      "properties": {
        "type": { "const": "tool_call" },
        "name": { "type": "string" },
        "args": { "type": "object" }
      },
      "required": ["type", "name", "args"]
    },
    {
      "type": "object",
      "properties": {
        "type": { "const": "result" },
        "status": { "type": "string", "enum": ["success", "error", "cancelled"] },
        "stats": {
          "type": "object",
          "properties": {
            "total_tokens": { "type": "integer" },
            "input_tokens": { "type": "integer" },
            "output_tokens": { "type": "integer" },
            "thought_tokens": { "type": "integer" },
            "cache_tokens": { "type": "integer" },
            "tool_tokens": { "type": "integer" },
            "duration_ms": { "type": "integer" },
            "tool_calls": { "type": "integer" }
          }
        },
        "timestamp": { "type": "string", "format": "date-time" },
        "error": { "type": "object" }
      },
      "required": ["type", "status"]
    },
    {
      "type": "object",
      "properties": {
        "type": { "const": "error" },
        "status": { "const": "error" },
        "error": {
          "type": "object",
          "properties": {
            "code": { "type": "string" },
            "message": { "type": "string" }
          }
        }
      },
      "required": ["type", "error"]
    }
  ]
}
```

---

## 9. Implementation Notes

### 9.1 Dart Client Library Architecture

```
lib/
├── src/
│   ├── core/
│   │   ├── agent_client.dart        # Main client class
│   │   ├── session.dart             # Session management
│   │   └── event_stream.dart        # Event streaming
│   ├── events/
│   │   ├── agent_event.dart         # Base event class
│   │   ├── session_events.dart      # Session lifecycle events
│   │   ├── turn_events.dart         # Turn lifecycle events
│   │   ├── tool_events.dart         # Tool execution events
│   │   └── content_events.dart      # Content/text events
│   ├── config/
│   │   ├── session_config.dart      # Configuration models
│   │   ├── approval_mode.dart       # Permission enums
│   │   └── sandbox_mode.dart        # Sandbox enums
│   ├── adapters/
│   │   ├── protocol_adapter.dart    # Base adapter interface
│   │   ├── claude_adapter.dart      # Claude Code translation
│   │   ├── codex_adapter.dart       # Codex CLI translation
│   │   └── gemini_adapter.dart      # Gemini CLI translation
│   ├── transport/
│   │   ├── transport.dart           # Base transport interface
│   │   ├── websocket_transport.dart # WebSocket (Claude)
│   │   ├── stdio_transport.dart     # Stdio (Codex, Gemini)
│   │   └── http_transport.dart      # HTTP polling fallback
│   └── utils/
│       ├── jsonl_parser.dart        # JSONL parsing
│       └── event_buffer.dart        # Event buffering
└── agent_protocol.dart              # Library exports
```

### 9.2 Usage Example

```dart
import 'package:agent_protocol/agent_protocol.dart';

void main() async {
  // Create client for specific agent
  final client = AgentClient(
    agentType: AgentType.codex,
    config: ClientConfig(
      workingDirectory: '/path/to/project',
    ),
  );

  // Start session
  final session = await client.createSession(
    prompt: 'Refactor the authentication module',
    config: SessionConfig(
      approvalMode: ApprovalMode.ask,
      sandboxMode: SandboxMode.workspaceWrite,
      model: 'gpt-4',
    ),
  );

  // Stream events
  await for (final event in session.events) {
    switch (event) {
      case TextChunkEvent(:final content):
        stdout.write(content);
      case ToolStartedEvent(:final toolName, :final arguments):
        print('Tool: $toolName');
        print('Args: $arguments');
      case ToolCompletedEvent(:final success, :final result):
        print('Result: $result (success: $success)');
      case FileChangedEvent(:final filePath, :final changeType):
        print('File $changeType: $filePath');
      case SessionEndedEvent(:final reason):
        print('Session ended: $reason');
        break;
      default:
        // Handle other events
    }
  }

  // Resume later
  final resumedSession = await client.resumeSession(
    sessionId: session.id,
    prompt: 'Continue with error handling',
  );
}
```

### 9.3 Transport Selection

```dart
Transport selectTransport(AgentType agentType, {String? baseUrl}) {
  switch (agentType) {
    case AgentType.claude:
      return WebSocketTransport(
        baseUrl: baseUrl ?? 'ws://localhost:8080',
      );
    case AgentType.codex:
      return StdioTransport(
        command: 'codex',
        args: ['exec', '--output-jsonl'],
      );
    case AgentType.gemini:
      return StdioTransport(
        command: 'gemini',
        args: ['-p', '--output-format', 'stream-json'],
      );
  }
}
```

### 9.4 Error Handling Strategy

```dart
/// Unified error types
enum AgentErrorType {
  connectionFailed,
  authenticationFailed,
  sessionNotFound,
  permissionDenied,
  toolExecutionFailed,
  timeout,
  protocolError,
  unknown,
}

class AgentError implements Exception {
  final AgentErrorType type;
  final String message;
  final String? nativeError;
  final String? agentType;

  AgentError(this.type, this.message, {this.nativeError, this.agentType});
}

/// Error translation
AgentError translateError(dynamic nativeError, AgentType agentType) {
  // Map native errors to unified types
}
```

### 9.5 Backpressure and Flow Control

```dart
/// Buffered event stream with backpressure
class EventBuffer {
  final int maxBufferSize;
  final Duration flushInterval;

  Stream<AgentEvent> buffer(Stream<AgentEvent> source) async* {
    // Implement buffering with overflow handling
  }
}

/// Cancellation support
class CancellableSession {
  final Session session;
  final CancelToken cancelToken;

  Future<void> cancel() async {
    await cancelToken.cancel();
    // Send cancellation to native protocol
  }
}
```

### 9.6 Testing Strategy

```dart
/// Mock transport for testing
class MockTransport implements Transport {
  final List<String> events;
  int _index = 0;

  @override
  Stream<String> get events async* {
    for (final event in events) {
      yield event;
      await Future.delayed(Duration(milliseconds: 10));
    }
  }
}

/// Test with mock events
void testCodexAdapter() {
  final adapter = CodexAdapter();
  final mockEvents = [
    '{"type":"thread.started","thread_id":"sess_123"}',
    '{"type":"turn.started"}',
    '{"type":"item.started","item_type":"agent_message"}',
    '{"type":"item.completed","item_type":"agent_message","status":"success"}',
    '{"type":"turn.completed","usage":{"input_tokens":100,"output_tokens":50}}',
  ];

  final unified = adapter.adaptEvents(Stream.fromIterable(mockEvents));
  // Assert expected unified events
}
```

---

## Appendix A: CLI Installation Commands

```bash
# Claude Code (via npm)
npm install -g @anthropic-ai/claude-code

# Codex CLI (via npm or direct download)
npm install -g @openai/codex
# OR
curl -fsSL https://codex.openai.com/install.sh | sh

# Gemini CLI (via npm)
npm install -g @anthropic/gemini-cli
# OR
npx @anthropic/gemini-cli
```

---

## Appendix B: Environment Variables

| Variable | Claude Code | Codex CLI | Gemini CLI |
|----------|-------------|-----------|------------|
| API Key | `ANTHROPIC_API_KEY` | `OPENAI_API_KEY` or `CODEX_API_KEY` | `GEMINI_API_KEY` or `GOOGLE_API_KEY` |
| Model | `CLAUDE_MODEL` | (config only) | `GEMINI_MODEL` |
| Debug | `CLAUDE_DEBUG` | (config only) | `--debug` flag |

---

## Appendix C: References

### Official Repositories
- Claude Code: https://github.com/anthropics/claude-code
- Codex CLI: https://github.com/openai/codex
- Gemini CLI: https://github.com/google-gemini/gemini-cli

### Documentation
- Claude Agent SDK: https://docs.anthropic.com/claude-code
- Codex CLI Docs: https://github.com/openai/codex/tree/main/docs
- Gemini CLI Docs: https://geminicli.com/docs/

---

*End of Specification*
