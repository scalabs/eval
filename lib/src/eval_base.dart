// ignore_for_file: implementation_imports

import 'dart:async';

import 'package:eval/src/services/service.dart';
import 'package:test/test.dart' as test;

import 'matchers/llm_matchers.dart';
import 'statistics.dart';

export 'package:test/test.dart' hide expect, expectAsync;

/// Body of an [eval] run.
///
/// The callback receives the API service for the current model/run so the same
/// evaluation logic can be reused across all configured services.
typedef TestFunction = FutureOr<void> Function(APICallService apiService);

/// Pass/fail counts per test run key.
Map<String, (int passed, int failed, int total)> testRuns = {};

/// Individual scores per test run key (for statistical analysis).
Map<String, List<double>> testScores = {};

String currentTestRunKey = '';

/// Registers an LLM evaluation on top of `package:test`.
///
/// [eval] wraps normal Dart test groups/tests and runs [testFunction] once for
/// each service in [apiServices] and once for each repetition in
/// [numberOfRunsPerLLM].
///
/// Inside [testFunction]:
/// - use [expect] for synchronous assertions
/// - use [expectAsync] for LLM-as-judge and RAG matchers
///
/// Both wrappers still perform normal assertions. The difference is that inside
/// [eval], they also record pass/fail counts. [expectAsync] additionally records
/// numeric scores, which are summarized as aggregate statistics when the group
/// finishes.
///
/// Example:
/// ```dart
/// await eval(
///   'answers a simple question',
///   (apiService) async {
///     final answer = await apiService.sendRequest(
///       'What is the capital of France?',
///     );
///
///     expect(answer, containsIgnoreCase('paris'));
///     await expectAsync(
///       answer,
///       answersQuestion(
///         'What is the capital of France?',
///         apiService: apiService,
///       ),
///     );
///   },
///   apiServices: [myService],
///   numberOfRunsPerLLM: 3,
/// );
/// ```
Future<void> eval(
  String description,
  TestFunction testFunction, {
  required List<APICallService> apiServices,
  required int numberOfRunsPerLLM,
  bool verbose = false,
  Duration timeout = const Duration(minutes: 10),
}) async {
  _registerEval<APICallService>(
    description,
    testFunction,
    services: apiServices,
    numberOfRuns: numberOfRunsPerLLM,
    modelName: (service) => service.defaultModel.name,
    verbose: verbose,
    timeout: timeout,
  );
}

/// Body of a typed decision evaluation.
typedef DecisionTestFunction =
    FutureOr<void> Function(DecisionModelService service);

/// Evaluates decision models using the same assertions and statistics as [eval].
/// Every repetition is scored independently; there is no best-of-run selection.
Future<void> decisionEval(
  String description,
  DecisionTestFunction testFunction, {
  required List<DecisionModelService> apiServices,
  required int numberOfRuns,
  bool verbose = false,
  Duration timeout = const Duration(minutes: 2),
}) async {
  _registerEval<DecisionModelService>(
    description,
    testFunction,
    services: apiServices,
    numberOfRuns: numberOfRuns,
    modelName: (service) => service.defaultModel.name,
    verbose: verbose,
    timeout: timeout,
    binaryScores: true,
  );
}

void _registerEval<S>(
  String description,
  FutureOr<void> Function(S) body, {
  required List<S> services,
  required int numberOfRuns,
  required String Function(S) modelName,
  required bool verbose,
  required Duration timeout,
  bool binaryScores = false,
}) {
  if (services.isEmpty) throw ArgumentError('apiServices cannot be empty');
  if (numberOfRuns < 1) throw ArgumentError('numberOfRuns must be positive');
  final keys = <String>[];
  test.group(description, () {
    for (final service in services) {
      final identity = 'with ${service.runtimeType} ${modelName(service)}';
      test.group(identity, () {
        for (var i = 0; i < numberOfRuns; i++) {
          final key = '$description $identity ${i + 1}';
          keys.add(key);
          testRuns[key] = (0, 0, 0);
          testScores[key] = [];
          test.test('run ${i + 1}', () async {
            currentTestRunKey = key;
            try {
              await body(service);
            } catch (_) {
              final current = testRuns[key]!;
              // expect/expectAsync already record failed assertions. Only add
              // a failure for an otherwise unrecorded exception.
              if (current.$2 == 0) {
                testRuns[key] = (current.$1, 1, current.$3 + 1);
              }
              if (testScores[key]!.isEmpty) testScores[key]!.add(0);
              rethrow;
            } finally {
              if (binaryScores && testScores[key]!.isEmpty) {
                final counts = testRuns[key]!;
                if (counts.$3 > 0) {
                  testScores[key]!.add(counts.$2 == 0 ? 1 : 0);
                }
              }
              currentTestRunKey = '';
            }
          }, timeout: test.Timeout(timeout));
        }
      });
    }
    test.tearDownAll(() {
      final stats = AggregateStatistics.compute(
        testRuns: {for (final key in keys) key: testRuns[key]!},
        testScores: {for (final key in keys) key: testScores[key]!},
      );
      print('\n${stats.format(verbose: verbose)}');
    });
  });
}

/// Wrapper around `package:test`'s `expect(...)`.
///
/// Inside [eval], this delegates to the underlying test matcher while also
/// recording pass/fail counts for the current eval run.
///
/// Outside [eval], it behaves like a normal `test.expect(...)`.
void expect(dynamic actual, dynamic matcher, {String? reason, Object? skip}) {
  if (currentTestRunKey.isEmpty) {
    test.expect(actual, matcher, reason: reason, skip: skip);
    return;
  }

  final current = testRuns[currentTestRunKey]!;
  final (passed, failed, total) = current;

  try {
    test.expect(actual, matcher, reason: reason, skip: skip);
    testRuns[currentTestRunKey] = (passed + 1, failed, total + 1);
  } catch (e) {
    testRuns[currentTestRunKey] = (passed, failed + 1, total + 1);
    rethrow;
  }
}

/// Async expect for LLM matchers.
///
/// Evaluates the [matcher] asynchronously against [actual] and records
/// the result in the eval scoring system.
///
/// Use this for [AsyncLlmMatcher] implementations such as LLM-as-judge and RAG
/// matchers. Inside [eval], it records both pass/fail counts and numeric scores.
/// Those scores are later summarized by [AggregateStatistics].
///
/// Example:
/// ```dart
/// await expectAsync(
///   response,
///   semanticallySimilarTo(
///     'expected answer',
///     apiService: apiService,
///   ),
/// );
/// await expectAsync(response, isNotToxic(apiService: apiService));
/// await expectAsync(
///   response,
///   answersQuestion('What is 2+2?', apiService: apiService),
/// );
/// ```
Future<void> expectAsync(
  String actual,
  AsyncLlmMatcher matcher, {
  String? reason,
}) async {
  final score = await matcher.evaluateAsync(actual);
  final passed = matcher.checkThreshold(score);

  if (currentTestRunKey.isNotEmpty) {
    final current = testRuns[currentTestRunKey]!;
    final (p, f, t) = current;
    if (passed) {
      testRuns[currentTestRunKey] = (p + 1, f, t + 1);
    } else {
      testRuns[currentTestRunKey] = (p, f + 1, t + 1);
    }
    // Record score for statistical analysis
    testScores[currentTestRunKey]?.add(score);
  }

  if (!passed) {
    final msg =
        reason ??
        'Expected: ${matcher.describe(test.StringDescription())}\n'
            '  Actual: "$actual"\n'
            '   Score: ${score.toStringAsFixed(3)} '
            '(threshold: ${matcher.threshold}, ${matcher.isUpperBoundCheck ? "<=" : ">="})';
    throw test.TestFailure(msg);
  }
}
