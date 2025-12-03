/// Configuration for Gemini CLI adapter.
class GeminiConfig {
  const GeminiConfig({
    this.executable = 'gemini',
    this.workingDirectory,
    this.model,
    this.approvalMode,
    this.yolo = false,
    this.autoEdit = false,
    this.sandbox = false,
    this.sandboxImage,
    this.allowedTools,
    this.debug = false,
    this.environment,
  });

  /// Path to the gemini executable.
  final String executable;

  /// Working directory for the session.
  final String? workingDirectory;

  /// Model to use.
  final String? model;

  /// Approval mode: 'default', 'auto_edit', or 'yolo'.
  final String? approvalMode;

  /// Auto-approve all operations (YOLO mode).
  final bool yolo;

  /// Auto-approve file edits only.
  final bool autoEdit;

  /// Enable Docker sandbox.
  final bool sandbox;

  /// Custom sandbox image.
  final String? sandboxImage;

  /// Tool allowlist.
  final List<String>? allowedTools;

  /// Enable debug output.
  final bool debug;

  /// Additional environment variables.
  final Map<String, String>? environment;

  /// Build CLI arguments from this config.
  List<String> buildArgs({
    required String prompt,
    String? sessionId,
  }) {
    final args = <String>[
      '-p',
      prompt,
      '--output-format',
      'stream-json',
    ];

    if (sessionId != null) {
      args.addAll(['--resume', sessionId]);
    }

    if (model != null) {
      args.addAll(['-m', model!]);
    }

    if (approvalMode != null) {
      args.addAll(['--approval-mode', approvalMode!]);
    }

    if (yolo) {
      args.add('-y');
    }

    if (autoEdit) {
      args.add('--auto-edit');
    }

    if (sandbox) {
      args.add('--sandbox');
    }

    if (sandboxImage != null) {
      args.addAll(['--sandbox-image', sandboxImage!]);
    }

    if (allowedTools != null && allowedTools!.isNotEmpty) {
      args.addAll(['--allowed-tools', allowedTools!.join(',')]);
    }

    if (debug) {
      args.add('-d');
    }

    return args;
  }

  /// Create a copy with modified values.
  GeminiConfig copyWith({
    String? executable,
    String? workingDirectory,
    String? model,
    String? approvalMode,
    bool? yolo,
    bool? autoEdit,
    bool? sandbox,
    String? sandboxImage,
    List<String>? allowedTools,
    bool? debug,
    Map<String, String>? environment,
  }) {
    return GeminiConfig(
      executable: executable ?? this.executable,
      workingDirectory: workingDirectory ?? this.workingDirectory,
      model: model ?? this.model,
      approvalMode: approvalMode ?? this.approvalMode,
      yolo: yolo ?? this.yolo,
      autoEdit: autoEdit ?? this.autoEdit,
      sandbox: sandbox ?? this.sandbox,
      sandboxImage: sandboxImage ?? this.sandboxImage,
      allowedTools: allowedTools ?? this.allowedTools,
      debug: debug ?? this.debug,
      environment: environment ?? this.environment,
    );
  }
}
