import 'package:eval/src/eval_compare.dart';
import 'package:eval/src/statistics.dart';
import 'package:test/test.dart';

void main() {
  group('CompareResult', () {
    test('formats basic comparison results', () {
      final result = CompareResult(
        scores: {
          'promptA': {
            'ClaudeService claude-sonnet': [0.8, 0.85, 0.9],
          },
          'promptB': {
            'ClaudeService claude-sonnet': [0.75, 0.78, 0.82],
          },
        },
        byVariant: {
          'promptA': EvalStatistics.compute(
            [0.8, 0.85, 0.9],
            passed: 3,
            failed: 0,
          ),
          'promptB': EvalStatistics.compute(
            [0.75, 0.78, 0.82],
            passed: 3,
            failed: 0,
          ),
        },
        byVariantAndModel: {
          'promptA': {
            'ClaudeService claude-sonnet': EvalStatistics.compute(
              [0.8, 0.85, 0.9],
              passed: 3,
              failed: 0,
            ),
          },
          'promptB': {
            'ClaudeService claude-sonnet': EvalStatistics.compute(
              [0.75, 0.78, 0.82],
              passed: 3,
              failed: 0,
            ),
          },
        },
        winner: 'promptA',
        pValue: 0.03,
      );

      final output = result.format();
      expect(output, contains('=== Comparative Eval Results ==='));
      expect(output, contains('promptA'));
      expect(output, contains('promptB'));
      expect(output, contains('Winner'));
      expect(output, contains('p=0.030'));
    });

    test('formats verbose output with detailed scores', () {
      final result = CompareResult(
        scores: {
          'promptA': {
            'Model1': [0.8, 0.9],
          },
        },
        byVariant: {
          'promptA': EvalStatistics.compute([0.8, 0.9], passed: 2, failed: 0),
        },
        byVariantAndModel: {
          'promptA': {
            'Model1': EvalStatistics.compute([0.8, 0.9], passed: 2, failed: 0),
          },
        },
      );

      final output = result.format(verbose: true);
      expect(output, contains('Detailed Scores:'));
      expect(output, contains('promptA'));
      expect(output, contains('Model1'));
    });

    test('handles multiple models', () {
      final result = CompareResult(
        scores: {
          'variant1': {
            'Model1': [0.8],
            'Model2': [0.7],
          },
        },
        byVariant: {
          'variant1': EvalStatistics.compute([0.8, 0.7], passed: 2, failed: 0),
        },
        byVariantAndModel: {
          'variant1': {
            'Model1': EvalStatistics.compute([0.8], passed: 1, failed: 0),
            'Model2': EvalStatistics.compute([0.7], passed: 1, failed: 0),
          },
        },
      );

      final output = result.format();
      expect(output, contains('Model1'));
      expect(output, contains('Model2'));
    });

    test('handles no statistical significance', () {
      final result = CompareResult(
        scores: {'a': {}},
        byVariant: {'a': EvalStatistics.compute([], passed: 0, failed: 0)},
        byVariantAndModel: {'a': {}},
        pValue: 0.15,
      );

      final output = result.format();
      expect(output, contains('not statistically significant'));
    });

    test('handles statistically significant result', () {
      final result = CompareResult(
        scores: {'a': {}},
        byVariant: {'a': EvalStatistics.compute([], passed: 0, failed: 0)},
        byVariantAndModel: {'a': {}},
        pValue: 0.02,
      );

      final output = result.format();
      expect(output, contains('statistically significant'));
      expect(output, isNot(contains('not statistically significant')));
    });

    test('handles no pValue', () {
      final result = CompareResult(
        scores: {'a': {}, 'b': {}, 'c': {}},
        byVariant: {
          'a': EvalStatistics.compute([], passed: 0, failed: 0),
          'b': EvalStatistics.compute([], passed: 0, failed: 0),
          'c': EvalStatistics.compute([], passed: 0, failed: 0),
        },
        byVariantAndModel: {'a': {}, 'b': {}, 'c': {}},
        pValue: null,
      );

      final output = result.format();
      expect(output, isNot(contains('Statistical significance')));
    });

    test('handles missing model stats gracefully', () {
      final result = CompareResult(
        scores: {
          'variant1': {
            'Model1': [0.8],
          },
          'variant2': {
            'Model2': [0.7],
          },
        },
        byVariant: {
          'variant1': EvalStatistics.compute([0.8], passed: 1, failed: 0),
          'variant2': EvalStatistics.compute([0.7], passed: 1, failed: 0),
        },
        byVariantAndModel: {
          'variant1': {
            'Model1': EvalStatistics.compute([0.8], passed: 1, failed: 0),
          },
          'variant2': {
            'Model2': EvalStatistics.compute([0.7], passed: 1, failed: 0),
          },
        },
      );

      final output = result.format();
      expect(output, contains('-')); // Missing model shows as dash
    });

    test('toString calls format', () {
      final result = CompareResult(
        scores: {'a': {}},
        byVariant: {'a': EvalStatistics.compute([], passed: 0, failed: 0)},
        byVariantAndModel: {'a': {}},
      );

      expect(result.toString(), equals(result.format()));
    });
  });

  group('computeCompareResult', () {
    test('computes statistics from scores', () {
      final scores = {
        'variantA': {
          'Model1': [0.8, 0.85, 0.9],
          'Model2': [0.75, 0.8, 0.85],
        },
        'variantB': {
          'Model1': [0.6, 0.65, 0.7],
          'Model2': [0.55, 0.6, 0.65],
        },
      };

      final result = computeCompareResult(scores);

      expect(result.byVariant.length, equals(2));
      expect(result.byVariantAndModel['variantA']!.length, equals(2));
      expect(result.winner, equals('variantA'));
    });

    test('determines correct winner', () {
      final scores = {
        'low': {
          'M': [0.3, 0.4, 0.35],
        },
        'high': {
          'M': [0.9, 0.95, 0.92],
        },
        'mid': {
          'M': [0.6, 0.65, 0.62],
        },
      };

      final result = computeCompareResult(scores);
      expect(result.winner, equals('high'));
    });

    test('computes pValue for two variants', () {
      final scores = {
        'A': {
          'M': [0.8, 0.85, 0.9, 0.82, 0.88],
        },
        'B': {
          'M': [0.5, 0.55, 0.6, 0.52, 0.58],
        },
      };

      final result = computeCompareResult(scores);
      expect(result.pValue, isNotNull);
      expect(result.pValue, lessThan(0.05)); // Should be significant
    });

    test('does not compute pValue for more than two variants', () {
      final scores = {
        'A': {
          'M': [0.8],
        },
        'B': {
          'M': [0.5],
        },
        'C': {
          'M': [0.6],
        },
      };

      final result = computeCompareResult(scores);
      expect(result.pValue, isNull);
    });

    test('handles empty scores', () {
      final scores = <String, Map<String, List<double>>>{};

      final result = computeCompareResult(scores);
      expect(result.byVariant.isEmpty, isTrue);
      expect(result.winner, isNull);
    });

    test('handles single variant', () {
      final scores = {
        'only': {
          'M': [0.8, 0.85],
        },
      };

      final result = computeCompareResult(scores);
      expect(result.winner, equals('only'));
      expect(result.pValue, isNull);
    });

    test('computes pass/fail based on default 0.5 threshold', () {
      final scores = {
        'variant': {
          'M': [0.6, 0.4, 0.7, 0.3],
        }, // 2 pass, 2 fail
      };

      final result = computeCompareResult(scores);
      expect(result.byVariant['variant']!.passed, equals(2));
      expect(result.byVariant['variant']!.failed, equals(2));
    });

    test('computes pass/fail based on custom passThreshold', () {
      final scores = {
        'variant': {
          'M': [0.6, 0.4, 0.7, 0.3],
        }, // With threshold 0.65: 1 pass, 3 fail
      };

      final result = computeCompareResult(scores, passThreshold: 0.65);
      expect(result.byVariant['variant']!.passed, equals(1)); // Only 0.7 passes
      expect(result.byVariant['variant']!.failed, equals(3));
    });

    test('uses custom passThreshold for model-level stats', () {
      final scores = {
        'variant': {
          'Model1': [0.8, 0.9, 0.6], // With 0.75: 2 pass, 1 fail
          'Model2': [0.7, 0.5, 0.4], // With 0.75: 0 pass, 3 fail
        },
      };

      final result = computeCompareResult(scores, passThreshold: 0.75);
      expect(result.byVariantAndModel['variant']!['Model1']!.passed, equals(2));
      expect(result.byVariantAndModel['variant']!['Model1']!.failed, equals(1));
      expect(result.byVariantAndModel['variant']!['Model2']!.passed, equals(0));
      expect(result.byVariantAndModel['variant']!['Model2']!.failed, equals(3));
    });

    test('aggregates scores across models', () {
      final scores = {
        'variant': {
          'Model1': [0.8, 0.9],
          'Model2': [0.7, 0.75],
        },
      };

      final result = computeCompareResult(scores);
      expect(result.byVariant['variant']!.sampleSize, equals(4));
    });
  });

  group('welchTTest', () {
    test('returns 1.0 for empty samples', () {
      expect(welchTTest([], [1.0, 2.0]), equals(1.0));
      expect(welchTTest([1.0, 2.0], []), equals(1.0));
      expect(welchTTest([], []), equals(1.0));
    });

    test('returns 1.0 for identical samples', () {
      final sample = [0.5, 0.5, 0.5, 0.5];
      final pValue = welchTTest(sample, sample);
      expect(pValue, closeTo(1.0, 0.1));
    });

    test('returns low p-value for very different samples', () {
      final sample1 = [0.9, 0.95, 0.92, 0.88, 0.91];
      final sample2 = [0.1, 0.15, 0.12, 0.08, 0.11];

      final pValue = welchTTest(sample1, sample2);
      expect(pValue, lessThan(0.01));
    });

    test('returns high p-value for similar samples', () {
      final sample1 = [0.5, 0.52, 0.48, 0.51, 0.49];
      final sample2 = [0.51, 0.49, 0.5, 0.52, 0.48];

      final pValue = welchTTest(sample1, sample2);
      expect(pValue, greaterThan(0.3));
    });

    test('handles samples with zero variance', () {
      final constant = [0.5, 0.5, 0.5, 0.5];
      final varied = [0.4, 0.5, 0.6, 0.5];

      // Should not throw
      final pValue = welchTTest(constant, varied);
      expect(pValue, isA<double>());
      expect(pValue, greaterThanOrEqualTo(0.0));
      expect(pValue, lessThanOrEqualTo(1.0));
    });

    test('handles both samples with zero variance and same mean', () {
      final sample1 = [0.5, 0.5, 0.5];
      final sample2 = [0.5, 0.5, 0.5];

      final pValue = welchTTest(sample1, sample2);
      expect(pValue, equals(1.0));
    });

    test('handles both samples with zero variance and different means', () {
      final sample1 = [0.3, 0.3, 0.3];
      final sample2 = [0.7, 0.7, 0.7];

      final pValue = welchTTest(sample1, sample2);
      expect(pValue, closeTo(0.0, 1e-10)); // Very close to 0
    });

    test('handles single element samples', () {
      final pValue = welchTTest([0.5], [0.8]);
      expect(pValue, isA<double>());
      // With single elements, variance calc may produce NaN/Inf, but should handle gracefully
    });

    test('is symmetric', () {
      final sample1 = [0.8, 0.85, 0.9];
      final sample2 = [0.5, 0.55, 0.6];

      final pValue1 = welchTTest(sample1, sample2);
      final pValue2 = welchTTest(sample2, sample1);

      expect(pValue1, closeTo(pValue2, 0.001));
    });

    test('handles unequal sample sizes', () {
      final sample1 = [0.8, 0.85, 0.9, 0.82, 0.88, 0.91, 0.87];
      final sample2 = [0.5, 0.55, 0.6];

      final pValue = welchTTest(sample1, sample2);
      expect(pValue, isA<double>());
      expect(pValue, greaterThanOrEqualTo(0.0));
      expect(pValue, lessThanOrEqualTo(1.0));
    });
  });

  group('EvalStatistics for compare', () {
    test('computes statistics for comparison', () {
      final scores = [0.8, 0.85, 0.9, 0.75, 0.82];
      final stats = EvalStatistics.compute(scores, passed: 5, failed: 0);

      expect(stats.mean, closeTo(0.824, 0.001));
      expect(stats.sampleSize, equals(5));
      expect(stats.passRate, equals(1.0));
    });

    test('computes standard deviation for variance comparison', () {
      // High variance
      final highVar = EvalStatistics.compute(
        [0.1, 0.9, 0.2, 0.8],
        passed: 2,
        failed: 2,
      );

      // Low variance
      final lowVar = EvalStatistics.compute(
        [0.5, 0.55, 0.45, 0.5],
        passed: 4,
        failed: 0,
      );

      expect(highVar.standardDeviation, greaterThan(lowVar.standardDeviation));
    });

    test('toString calls format', () {
      final stats = EvalStatistics.compute([0.8], passed: 1, failed: 0);
      expect(stats.toString(), equals(stats.format()));
    });
  });
}
