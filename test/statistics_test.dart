import 'package:eval/src/statistics.dart';
import 'package:test/test.dart';

void main() {
  group('EvalStatistics', () {
    test('computes statistics for simple score list', () {
      final stats = EvalStatistics.compute(
        [0.8, 0.9, 0.7, 0.85, 0.95],
        passed: 4,
        failed: 1,
      );

      expect(stats.mean, closeTo(0.84, 0.001));
      expect(stats.min, equals(0.7));
      expect(stats.max, equals(0.95));
      expect(stats.sampleSize, equals(5));
      expect(stats.passed, equals(4));
      expect(stats.failed, equals(1));
      expect(stats.passRate, closeTo(0.8, 0.001));
    });

    test('computes correct standard deviation', () {
      // Known values: [2, 4, 4, 4, 5, 5, 7, 9] has mean = 5.0
      // Sample std dev (Bessel's correction, n-1) = sqrt(36/7) ≈ 2.138
      final scores = [2.0, 4.0, 4.0, 4.0, 5.0, 5.0, 7.0, 9.0];
      final stats = EvalStatistics.compute(scores, passed: 8, failed: 0);

      expect(stats.mean, equals(5.0));
      expect(stats.standardDeviation, closeTo(2.138, 0.001));
    });

    test('handles single score with zero std dev', () {
      final stats = EvalStatistics.compute([0.75], passed: 1, failed: 0);

      expect(stats.mean, equals(0.75));
      expect(stats.standardDeviation, equals(0.0)); // n=1 gives 0 std dev
      expect(stats.sampleSize, equals(1));
    });

    test('computes percentiles correctly', () {
      // 0.0 to 1.0 in 0.1 increments
      final scores = List.generate(11, (i) => i / 10.0);
      final stats = EvalStatistics.compute(scores, passed: 11, failed: 0);

      expect(stats.p50, closeTo(0.5, 0.001));
      expect(stats.p90, closeTo(0.9, 0.001));
      expect(stats.p95, closeTo(0.95, 0.001));
    });

    test('handles empty scores list', () {
      final stats = EvalStatistics.compute([], passed: 0, failed: 0);

      expect(stats.mean, equals(0));
      expect(stats.standardDeviation, equals(0));
      expect(stats.min, equals(0));
      expect(stats.max, equals(0));
      expect(stats.sampleSize, equals(0));
      expect(stats.passRate, equals(0));
    });

    test('handles single score', () {
      final stats = EvalStatistics.compute([0.75], passed: 1, failed: 0);

      expect(stats.mean, equals(0.75));
      expect(stats.standardDeviation, equals(0.0));
      expect(stats.min, equals(0.75));
      expect(stats.max, equals(0.75));
      expect(stats.p50, equals(0.75));
      expect(stats.p90, equals(0.75));
      expect(stats.p95, equals(0.75));
    });

    test('format produces readable output', () {
      final stats = EvalStatistics.compute(
        [0.8, 0.9, 0.85],
        passed: 3,
        failed: 0,
      );

      final output = stats.format();
      expect(output, contains('Pass Rate: 100%'));
      expect(output, contains('mean='));
      expect(output, contains('std='));
    });

    test('format verbose includes percentiles', () {
      final stats = EvalStatistics.compute(
        [0.8, 0.9, 0.85],
        passed: 3,
        failed: 0,
      );

      final output = stats.format(verbose: true);
      expect(output, contains('p50='));
      expect(output, contains('p90='));
      expect(output, contains('p95='));
    });

    test('toString calls format', () {
      final stats = EvalStatistics.compute([0.8], passed: 1, failed: 0);
      expect(stats.toString(), equals(stats.format()));
    });
  });

  group('AggregateStatistics', () {
    test('computes aggregate from test runs', () {
      final testRuns = {
        'test with ClaudeService claude-sonnet 1': (3, 1, 4),
        'test with ClaudeService claude-sonnet 2': (4, 0, 4),
        'test with OpenAIService gpt-4 1': (2, 2, 4),
        'test with OpenAIService gpt-4 2': (3, 1, 4),
      };

      final testScores = {
        'test with ClaudeService claude-sonnet 1': [0.8, 0.9, 0.7, 0.6],
        'test with ClaudeService claude-sonnet 2': [0.85, 0.95, 0.9, 0.88],
        'test with OpenAIService gpt-4 1': [0.7, 0.5, 0.6, 0.55],
        'test with OpenAIService gpt-4 2': [0.75, 0.8, 0.65, 0.7],
      };

      final aggregate = AggregateStatistics.compute(
        testRuns: testRuns,
        testScores: testScores,
      );

      // Check overall stats
      expect(aggregate.overall.sampleSize, equals(16));
      expect(aggregate.overall.passed, equals(12));
      expect(aggregate.overall.failed, equals(4));
      expect(aggregate.overall.passRate, closeTo(0.75, 0.001));

      // Check by-model aggregation
      expect(aggregate.byModel.length, equals(2));
      expect(
        aggregate.byModel.containsKey('ClaudeService claude-sonnet'),
        isTrue,
      );
      expect(aggregate.byModel.containsKey('OpenAIService gpt-4'), isTrue);

      // Claude should have better stats
      final claudeStats = aggregate.byModel['ClaudeService claude-sonnet']!;
      final openaiStats = aggregate.byModel['OpenAIService gpt-4']!;
      expect(claudeStats.mean, greaterThan(openaiStats.mean));
    });

    test('handles empty test runs', () {
      final aggregate = AggregateStatistics.compute(
        testRuns: {},
        testScores: {},
      );

      expect(aggregate.overall.sampleSize, equals(0));
      expect(aggregate.byModel.isEmpty, isTrue);
      expect(aggregate.byTestRun.isEmpty, isTrue);
    });

    test('format produces structured output', () {
      final testRuns = {'test with ClaudeService claude-sonnet 1': (3, 1, 4)};
      final testScores = {
        'test with ClaudeService claude-sonnet 1': [0.8, 0.9, 0.7, 0.85],
      };

      final aggregate = AggregateStatistics.compute(
        testRuns: testRuns,
        testScores: testScores,
      );

      final output = aggregate.format();
      expect(output, contains('=== Eval Results ==='));
      expect(output, contains('By Model:'));
      expect(output, contains('Overall:'));
    });

    test('format verbose includes detailed runs', () {
      final testRuns = {'test with ClaudeService claude-sonnet 1': (3, 1, 4)};
      final testScores = {
        'test with ClaudeService claude-sonnet 1': [0.8, 0.9, 0.7, 0.85],
      };

      final aggregate = AggregateStatistics.compute(
        testRuns: testRuns,
        testScores: testScores,
      );

      final output = aggregate.format(verbose: true);
      expect(output, contains('Detailed by Run:'));
    });

    test('toString calls format', () {
      final aggregate = AggregateStatistics.compute(
        testRuns: {'test with ClaudeService model 1': (1, 0, 1)},
        testScores: {
          'test with ClaudeService model 1': [0.8],
        },
      );
      expect(aggregate.toString(), equals(aggregate.format()));
    });

    test('handles test runs without matching scores', () {
      final testRuns = {'test with ClaudeService model 1': (2, 1, 3)};
      final testScores = <String, List<double>>{}; // No scores

      final aggregate = AggregateStatistics.compute(
        testRuns: testRuns,
        testScores: testScores,
      );

      expect(aggregate.overall.passed, equals(2));
      expect(aggregate.overall.failed, equals(1));
      expect(aggregate.overall.sampleSize, equals(0)); // No scores tracked
    });

    test('handles malformed test run keys', () {
      final testRuns = {'invalid key format': (1, 0, 1)};
      final testScores = {
        'invalid key format': [0.8],
      };

      final aggregate = AggregateStatistics.compute(
        testRuns: testRuns,
        testScores: testScores,
      );

      // Should still compute overall stats even if model extraction fails
      expect(aggregate.overall.sampleSize, equals(1));
      expect(aggregate.byModel.isEmpty, isTrue);
    });
  });
}
