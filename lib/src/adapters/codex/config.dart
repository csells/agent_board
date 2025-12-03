/// Configuration for Codex CLI adapter.
class CodexConfig {
  const CodexConfig({
    this.executable = 'codex',
    this.workingDirectory,
    this.model,
    this.fullAuto = false,
    this.askForApproval = false,
    this.outputSchema,
    this.environment,
  });

  /// Path to the codex executable.
  final String executable;

  /// Working directory for the session.
  final String? workingDirectory;

  /// Model to use.
  final String? model;

  /// Auto-approve all operations (danger mode).
  final bool fullAuto;

  /// Require approval for all operations (untrusted mode).
  final bool askForApproval;

  /// JSON schema file for structured output.
  final String? outputSchema;

  /// Additional environment variables.
  final Map<String, String>? environment;

  /// Build CLI arguments from this config.
  List<String> buildArgs({
    required String prompt,
    String? threadId,
  }) {
    final args = <String>['exec', '--output-jsonl'];

    if (threadId != null) {
      args.addAll(['--resume', threadId]);
    }

    if (model != null) {
      args.addAll(['--model', model!]);
    }

    if (fullAuto) {
      args.add('--full-auto');
    }

    if (askForApproval) {
      args.add('--ask-for-approval');
    }

    if (outputSchema != null) {
      args.addAll(['--output-schema', outputSchema!]);
    }

    if (workingDirectory != null) {
      args.addAll(['--cd', workingDirectory!]);
    }

    // Prompt goes last
    args.add(prompt);

    return args;
  }

  /// Create a copy with modified values.
  CodexConfig copyWith({
    String? executable,
    String? workingDirectory,
    String? model,
    bool? fullAuto,
    bool? askForApproval,
    String? outputSchema,
    Map<String, String>? environment,
  }) {
    return CodexConfig(
      executable: executable ?? this.executable,
      workingDirectory: workingDirectory ?? this.workingDirectory,
      model: model ?? this.model,
      fullAuto: fullAuto ?? this.fullAuto,
      askForApproval: askForApproval ?? this.askForApproval,
      outputSchema: outputSchema ?? this.outputSchema,
      environment: environment ?? this.environment,
    );
  }
}
