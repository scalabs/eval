/// Pure Dart helpers for evaluating LLM outputs on top of `package:test`.
///
/// Import this library to get:
/// - [eval], which wraps normal Dart tests with multi-model/multi-run execution
/// - [expect] and [expectAsync], which record evaluation statistics
/// - matcher libraries for strings, JSON, schemas, frontmatter, distance, LLM
///   judges, and RAG
/// - most of `package:test/test.dart` re-exported for convenience
///
/// The typical flow is:
/// 1. Register an evaluation with [eval].
/// 2. Use [expect] for sync assertions inside the eval body.
/// 3. Use [expectAsync] for judge-based or RAG matchers that return scores.
library;

export 'src/eval_base.dart';
export 'src/eval_compare.dart';
export 'src/matchers/matchers.dart';
export 'src/md_file.dart';
export 'src/services/example_claude_service.dart';
export 'src/services/service.dart';
export 'src/statistics.dart';
