import 'dart:async';

/// Configuration for Claude Code CLI adapter.
class ClaudeConfig {
  const ClaudeConfig({
    this.executable = 'claude',
    this.workingDirectory,
    this.model,
    this.systemPrompt,
    this.appendSystemPrompt,
    this.maxTurns,
    this.allowedTools,
    this.disallowedTools,
    this.permissionMode,
    this.dangerouslySkipPermissions = false,
    this.includePartialMessages = false,
    this.verbose = false,
    this.jsonSchema,
    this.environment,
    this.permissionCallback,
  });

  /// Path to the claude executable.
  final String executable;

  /// Working directory for the session.
  final String? workingDirectory;

  /// Model to use.
  final String? model;

  /// Custom system prompt (replaces default).
  final String? systemPrompt;

  /// Text to append to system prompt.
  final String? appendSystemPrompt;

  /// Maximum agentic turns.
  final int? maxTurns;

  /// Tools to auto-approve.
  final List<String>? allowedTools;

  /// Tools to block.
  final List<String>? disallowedTools;

  /// Permission mode (e.g., 'plan').
  final String? permissionMode;

  /// Auto-approve all tools (YOLO mode).
  final bool dangerouslySkipPermissions;

  /// Include partial/streaming messages.
  final bool includePartialMessages;

  /// Enable verbose output with stream events.
  final bool verbose;

  /// JSON schema for structured output validation.
  final String? jsonSchema;

  /// Additional environment variables.
  final Map<String, String>? environment;

  /// Callback for handling permission requests.
  ///
  /// When provided, this callback is invoked for each tool permission request.
  /// Return a [ClaudePermissionResponse] to allow or deny the tool execution.
  ///
  /// This is used internally when setting up an MCP server for
  /// `--permission-prompt-tool` delegation.
  final FutureOr<ClaudePermissionResponse> Function(
    ClaudePermissionRequest request,
  )? permissionCallback;

  /// Build CLI arguments from this config.
  List<String> buildArgs({String? sessionId}) {
    final args = <String>[
      '--output-format',
      'stream-json',
      '--input-format',
      'stream-json',
    ];

    if (sessionId != null) {
      args.addAll(['--resume', sessionId]);
    }

    if (model != null) {
      args.addAll(['--model', model!]);
    }

    if (systemPrompt != null) {
      args.addAll(['--system-prompt', systemPrompt!]);
    }

    if (appendSystemPrompt != null) {
      args.addAll(['--append-system-prompt', appendSystemPrompt!]);
    }

    if (maxTurns != null) {
      args.addAll(['--max-turns', maxTurns.toString()]);
    }

    if (allowedTools != null && allowedTools!.isNotEmpty) {
      args.addAll(['--allowedTools', ...allowedTools!]);
    }

    if (disallowedTools != null && disallowedTools!.isNotEmpty) {
      args.addAll(['--disallowedTools', ...disallowedTools!]);
    }

    if (permissionMode != null) {
      args.addAll(['--permission-mode', permissionMode!]);
    }

    if (dangerouslySkipPermissions) {
      args.add('--dangerously-skip-permissions');
    }

    if (includePartialMessages) {
      args.add('--include-partial-messages');
    }

    if (verbose) {
      args.add('--verbose');
    }

    if (jsonSchema != null) {
      args.addAll(['--json-schema', jsonSchema!]);
    }

    return args;
  }

  /// Create a copy with modified values.
  ClaudeConfig copyWith({
    String? executable,
    String? workingDirectory,
    String? model,
    String? systemPrompt,
    String? appendSystemPrompt,
    int? maxTurns,
    List<String>? allowedTools,
    List<String>? disallowedTools,
    String? permissionMode,
    bool? dangerouslySkipPermissions,
    bool? includePartialMessages,
    bool? verbose,
    String? jsonSchema,
    Map<String, String>? environment,
    FutureOr<ClaudePermissionResponse> Function(ClaudePermissionRequest)?
        permissionCallback,
  }) {
    return ClaudeConfig(
      executable: executable ?? this.executable,
      workingDirectory: workingDirectory ?? this.workingDirectory,
      model: model ?? this.model,
      systemPrompt: systemPrompt ?? this.systemPrompt,
      appendSystemPrompt: appendSystemPrompt ?? this.appendSystemPrompt,
      maxTurns: maxTurns ?? this.maxTurns,
      allowedTools: allowedTools ?? this.allowedTools,
      disallowedTools: disallowedTools ?? this.disallowedTools,
      permissionMode: permissionMode ?? this.permissionMode,
      dangerouslySkipPermissions:
          dangerouslySkipPermissions ?? this.dangerouslySkipPermissions,
      includePartialMessages:
          includePartialMessages ?? this.includePartialMessages,
      verbose: verbose ?? this.verbose,
      jsonSchema: jsonSchema ?? this.jsonSchema,
      environment: environment ?? this.environment,
      permissionCallback: permissionCallback ?? this.permissionCallback,
    );
  }
}

/// Permission request sent to the permission callback.
class ClaudePermissionRequest {
  const ClaudePermissionRequest({
    required this.toolName,
    required this.toolInput,
    this.sessionId,
    this.turnNumber,
    this.workingDirectory,
  });

  /// Name of the tool requesting permission.
  final String toolName;

  /// Input arguments for the tool.
  final Map<String, dynamic> toolInput;

  /// Current session ID.
  final String? sessionId;

  /// Current turn number.
  final int? turnNumber;

  /// Working directory of the session.
  final String? workingDirectory;

  factory ClaudePermissionRequest.fromJson(Map<String, dynamic> json) {
    final context = json['context'] as Map<String, dynamic>?;
    return ClaudePermissionRequest(
      toolName: json['tool_name'] as String,
      toolInput: json['tool_input'] as Map<String, dynamic>,
      sessionId: context?['session_id'] as String?,
      turnNumber: context?['turn_number'] as int?,
      workingDirectory: context?['working_directory'] as String?,
    );
  }
}

/// Permission response returned from the permission callback.
class ClaudePermissionResponse {
  const ClaudePermissionResponse._({
    required this.behavior,
    this.message,
    this.updatedInput,
  });

  /// Allow the tool execution.
  const ClaudePermissionResponse.allow({Map<String, dynamic>? updatedInput})
      : this._(
          behavior: ClaudePermissionBehavior.allow,
          updatedInput: updatedInput,
        );

  /// Deny the tool execution.
  const ClaudePermissionResponse.deny({String? message})
      : this._(
          behavior: ClaudePermissionBehavior.deny,
          message: message,
        );

  /// Allow this tool for the remainder of the session.
  const ClaudePermissionResponse.allowAlways({Map<String, dynamic>? updatedInput})
      : this._(
          behavior: ClaudePermissionBehavior.allowAlways,
          updatedInput: updatedInput,
        );

  /// Deny this tool for the remainder of the session.
  const ClaudePermissionResponse.denyAlways({String? message})
      : this._(
          behavior: ClaudePermissionBehavior.denyAlways,
          message: message,
        );

  final ClaudePermissionBehavior behavior;
  final String? message;
  final Map<String, dynamic>? updatedInput;

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'behavior': behavior.value,
    };
    if (message != null) {
      json['message'] = message;
    }
    if (updatedInput != null) {
      json['updatedInput'] = updatedInput;
    }
    return json;
  }
}

/// Permission behavior values.
enum ClaudePermissionBehavior {
  allow('allow'),
  deny('deny'),
  allowAlways('allowAlways'),
  denyAlways('denyAlways');

  const ClaudePermissionBehavior(this.value);
  final String value;
}
