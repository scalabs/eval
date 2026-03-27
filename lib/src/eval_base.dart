// ignore_for_file: implementation_imports

import 'dart:async';

import 'package:eval/src/services/service.dart';
import 'package:test/test.dart' as test;

import 'matchers/llm_matchers.dart';
import 'statistics.dart';

export 'package:test/test.dart' hide expect, expectAsync;

typedef TestFunction = FutureOr<void> Function(APICallService apiService);

/// Pass/fail counts per test run key.
Map<String, (int passed, int failed, int total)> testRuns = {};

/// Individual scores per test run key (for statistical analysis).
Map<String, List<double>> testScores = {};

String currentTestRunKey = '';

Future<void> eval(
  String description,
  TestFunction testFunction, {
  required List<APICallService> apiServices,
  required int numberOfRunsPerLLM,
  bool verbose = false,
}) async {
  assert(apiServices.isNotEmpty, 'apiServices cannot be empty');

  test.group(description, () {
    print(description);
    for (final apiService in apiServices) {
      test.group(
        'with ${apiService.runtimeType} ${apiService.defaultModel.name}',
        () {
          print('with ${apiService.runtimeType}');
          for (var i = 0; i < numberOfRunsPerLLM; i++) {
            print('run ${i + 1}');

            final testRunKey =
                '$description with ${apiService.runtimeType} ${apiService.defaultModel.name} ${i + 1}';
            testRuns[testRunKey] = (0, 0, 0);
            testScores[testRunKey] = [];
            test.test('run ${i + 1}', () async {
              currentTestRunKey = testRunKey;
              try {
                await testFunction(apiService);
              } catch (e) {
                // Mark any exception as a failed expectation
                final current = testRuns[testRunKey]!;
                testRuns[testRunKey] = (
                  current.$1,
                  current.$2 + 1,
                  current.$3 + 1,
                );
                rethrow;
              }
            });
          }
        },
      );
    }

    test.tearDownAll(() {
      final stats = AggregateStatistics.compute(
        testRuns: testRuns,
        testScores: testScores,
      );
      print('\n${stats.format(verbose: verbose)}');
    });
  });
}

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
/// Example:
/// ```dart
/// await expectAsync(response, semanticallySimilarTo('expected answer'));
/// await expectAsync(response, isNotToxic());
/// await expectAsync(response, answersQuestion('What is 2+2?'));
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
