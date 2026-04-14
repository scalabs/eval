import 'dart:async';
import 'dart:math' as math;

import 'package:eval/src/services/service.dart';
import 'package:test/test.dart' as test;

import 'matchers/llm_matchers.dart';
import 'statistics.dart';

/// A function that generates an output given an API service.
typedef VariantFunction = FutureOr<String> Function(APICallService apiService);

/// Results from a comparative evaluation.
class CompareResult {
  /// Scores indexed by [variantName][modelName][runIndex].
  final Map<String, Map<String, List<double>>> scores;

  /// Statistics by variant.
  final Map<String, EvalStatistics> byVariant;

  /// Statistics by variant and model.
  final Map<String, Map<String, EvalStatistics>> byVariantAndModel;

  /// The winning variant (highest mean score), or null if no clear winner.
  final String? winner;

  /// P-value for statistical significance (if applicable).
  final double? pValue;

  const CompareResult({
    required this.scores,
    required this.byVariant,
    required this.byVariantAndModel,
    this.winner,
    this.pValue,
  });

  /// Formats the comparison results for display.
  String format({bool verbose = false}) {
    final buffer = StringBuffer();

    // Header
    buffer.writeln('=== Comparative Eval Results ===\n');

    // Table header
    final models = byVariantAndModel.values
        .expand((m) => m.keys)
        .toSet()
        .toList();
    final colWidth = 18;

    buffer.write('Variant'.padRight(colWidth));
    for (final model in models) {
      buffer.write(model.padRight(colWidth));
    }
    buffer.writeln('Overall'.padRight(colWidth));

    buffer.writeln('-' * (colWidth * (models.length + 2)));

    // Table rows
    for (final variant in byVariant.keys) {
      buffer.write(variant.padRight(colWidth));

      for (final model in models) {
        final stats = byVariantAndModel[variant]?[model];
        if (stats != null && stats.sampleSize > 0) {
          final cell =
              '${stats.mean.toStringAsFixed(2)} ± ${stats.standardDeviation.toStringAsFixed(2)}';
          buffer.write(cell.padRight(colWidth));
        } else {
          buffer.write('-'.padRight(colWidth));
        }
      }

      final overallStats = byVariant[variant]!;
      final overall =
          '${overallStats.mean.toStringAsFixed(2)} ± ${overallStats.standardDeviation.toStringAsFixed(2)}';
      if (variant == winner) {
        buffer.writeln('$overall  ← Winner');
      } else {
        buffer.writeln(overall);
      }
    }

    buffer.writeln();

    // Statistical significance
    if (pValue != null) {
      final significance = pValue! < 0.05
          ? 'statistically significant'
          : 'not statistically significant';
      buffer.writeln(
        'Statistical significance: p=${pValue!.toStringAsFixed(3)} ($significance)',
      );
    }

    if (verbose) {
      buffer.writeln('\nDetailed Scores:');
      for (final variant in scores.keys) {
        buffer.writeln('  $variant:');
        for (final model in scores[variant]!.keys) {
          final modelScores = scores[variant]![model]!;
          buffer.writeln('    $model: $modelScores');
        }
      }
    }

    return buffer.toString();
  }

  @override
  String toString() => format();
}

/// Runs a comparative evaluation of multiple variants.
///
/// Each variant is a function that generates an output given an API service.
/// The outputs are evaluated against the provided matchers, and statistics
/// are computed to determine the winning variant.
///
/// [apiServices] are the generation services under test.
///
/// If your [matchers] use LLM-as-judge scoring and you do not want to rely on
/// the global `llmMatcherService`, pass an explicit judge service to each
/// matcher with `apiService:`. That judge can be the same as or different from
/// the generation services.
///
/// Example:
/// ```dart
/// final judgeService = MyJudgeService(apiKey: '...');
///
/// await evalCompare(
///   'Summarization prompts',
///   variants: {
///     'promptA': (apiService) => apiService.sendRequest(
///       'Summarize: ...',
///       systemPrompt: promptA,
///     ),
///     'promptB': (apiService) => apiService.sendRequest(
///       'Summarize: ...',
///       systemPrompt: promptB,
///     ),
///   },
///   apiServices: [claudeService, openaiService],
///   matchers: [
///     semanticallySimilarTo(reference, apiService: judgeService),
///   ],
///   numberOfRuns: 5,
/// );
/// ```
Future<void> evalCompare(
  String description, {
  required Map<String, VariantFunction> variants,
  required List<APICallService> apiServices,
  required List<AsyncLlmMatcher> matchers,
  int numberOfRuns = 5,
  double passThreshold = 0.5,
}) async {
  assert(variants.isNotEmpty, 'variants cannot be empty');
  assert(apiServices.isNotEmpty, 'apiServices cannot be empty');
  assert(matchers.isNotEmpty, 'matchers must have at least one matcher');
  assert(numberOfRuns > 0, 'numberOfRuns must be positive');

  test.group('Compare: $description', () {
    // Store all scores: variant -> model -> scores
    final allScores = <String, Map<String, List<double>>>{};

    for (final variantEntry in variants.entries) {
      final variantName = variantEntry.key;
      final variantFn = variantEntry.value;
      allScores[variantName] = {};

      test.group(variantName, () {
        for (final apiService in apiServices) {
          final modelName =
              '${apiService.runtimeType} ${apiService.defaultModel.name}';
          allScores[variantName]![modelName] = [];

          test.group(modelName, () {
            for (var i = 0; i < numberOfRuns; i++) {
              test.test('run ${i + 1}', () async {
                final output = await variantFn(apiService);

                // Evaluate with all matchers
                var totalScore = 0.0;
                for (final matcher in matchers) {
                  final score = await matcher.evaluateAsync(output);
                  totalScore += score;
                }
                final avgScore = totalScore / matchers.length;
                allScores[variantName]![modelName]!.add(avgScore);
              });
            }
          });
        }
      });
    }

    test.tearDownAll(() {
      final result = computeCompareResult(
        allScores,
        passThreshold: passThreshold,
      );
      print('\n${result.format()}');
    });
  });
}

/// Computes comparison results from collected scores.
/// @visibleForTesting
CompareResult computeCompareResult(
  Map<String, Map<String, List<double>>> scores, {
  double passThreshold = 0.5,
}) {
  final byVariant = <String, EvalStatistics>{};
  final byVariantAndModel = <String, Map<String, EvalStatistics>>{};

  for (final variant in scores.keys) {
    final allVariantScores = <double>[];
    byVariantAndModel[variant] = {};

    for (final model in scores[variant]!.keys) {
      final modelScores = scores[variant]![model]!;
      allVariantScores.addAll(modelScores);

      byVariantAndModel[variant]![model] = EvalStatistics.compute(
        modelScores,
        passed: modelScores.where((s) => s >= passThreshold).length,
        failed: modelScores.where((s) => s < passThreshold).length,
      );
    }

    byVariant[variant] = EvalStatistics.compute(
      allVariantScores,
      passed: allVariantScores.where((s) => s >= passThreshold).length,
      failed: allVariantScores.where((s) => s < passThreshold).length,
    );
  }

  // Determine winner
  String? winner;
  double highestMean = double.negativeInfinity;
  for (final entry in byVariant.entries) {
    if (entry.value.mean > highestMean) {
      highestMean = entry.value.mean;
      winner = entry.key;
    }
  }

  // Compute p-value using Welch's t-test (for two variants)
  double? pValue;
  if (byVariant.length == 2) {
    final variants = byVariant.keys.toList();
    final scores1 = scores[variants[0]]!.values.expand((s) => s).toList();
    final scores2 = scores[variants[1]]!.values.expand((s) => s).toList();
    pValue = welchTTest(scores1, scores2);
  }

  return CompareResult(
    scores: scores,
    byVariant: byVariant,
    byVariantAndModel: byVariantAndModel,
    winner: winner,
    pValue: pValue,
  );
}

/// Performs Welch's t-test and returns the p-value.
/// @visibleForTesting
double welchTTest(List<double> sample1, List<double> sample2) {
  if (sample1.isEmpty || sample2.isEmpty) return 1.0;

  final n1 = sample1.length;
  final n2 = sample2.length;

  final mean1 = sample1.reduce((a, b) => a + b) / n1;
  final mean2 = sample2.reduce((a, b) => a + b) / n2;

  final var1 =
      sample1.map((x) => math.pow(x - mean1, 2)).reduce((a, b) => a + b) / n1;
  final var2 =
      sample2.map((x) => math.pow(x - mean2, 2)).reduce((a, b) => a + b) / n2;

  if (var1 == 0 && var2 == 0) return mean1 == mean2 ? 1.0 : 0.0;

  final se1 = var1 / n1;
  final se2 = var2 / n2;
  final se = math.sqrt(se1 + se2);

  if (se == 0) return 1.0;

  final t = (mean1 - mean2).abs() / se;

  // Approximate degrees of freedom (Welch-Satterthwaite)
  final df =
      math.pow(se1 + se2, 2) /
      (math.pow(se1, 2) / (n1 - 1) + math.pow(se2, 2) / (n2 - 1));

  // Approximate p-value using Student's t-distribution
  // Using a simple approximation for the CDF
  return _tDistributionPValue(t, df);
}

/// Approximates the p-value from Student's t-distribution.
double _tDistributionPValue(double t, double df) {
  // Using the approximation from Abramowitz and Stegun
  // This is a simple approximation; for production use, consider a proper stats library
  if (df <= 0) return 1.0;

  final x = df / (df + t * t);
  final beta = _incompleteBeta(df / 2, 0.5, x);
  return beta;
}

/// Approximates the incomplete beta function.
double _incompleteBeta(double a, double b, double x) {
  // Simple approximation using continued fraction
  // For production, use a proper implementation
  if (x == 0) return 0;
  if (x == 1) return 1;

  // Use symmetry relation if needed
  if (x > (a + 1) / (a + b + 2)) {
    return 1 - _incompleteBeta(b, a, 1 - x);
  }

  // Continued fraction approximation
  const maxIterations = 100;
  const epsilon = 1e-10;

  var result = 0.0;
  var term = 1.0;

  for (var n = 0; n < maxIterations; n++) {
    final an = (n == 0)
        ? 1.0
        : (n.isOdd
              ? -(a + (n - 1) / 2) *
                    (a + b + (n - 1) / 2) *
                    x /
                    ((a + n - 1) * (a + n))
              : (n / 2) * (b - n / 2) * x / ((a + n - 1) * (a + n)));

    term *= an;
    result += term;

    if (term.abs() < epsilon) break;
  }

  // Apply beta function normalization
  final logBeta = _logGamma(a) + _logGamma(b) - _logGamma(a + b);
  final factor = math.exp(a * math.log(x) + b * math.log(1 - x) - logBeta) / a;

  return (factor * result).clamp(0.0, 1.0);
}

/// Approximates the log gamma function using Stirling's approximation.
double _logGamma(double x) {
  if (x <= 0) return double.infinity;

  // Stirling's approximation
  const c = [
    76.18009172947146,
    -86.50532032941677,
    24.01409824083091,
    -1.231739572450155,
    0.1208650973866179e-2,
    -0.5395239384953e-5,
  ];

  var y = x;
  var tmp = x + 5.5;
  tmp -= (x + 0.5) * math.log(tmp);
  var ser = 1.000000000190015;

  for (var j = 0; j < 6; j++) {
    ser += c[j] / ++y;
  }

  return -tmp + math.log(2.5066282746310005 * ser / x);
}

/// Runs a comparative evaluation synchronously (for simpler use cases).
///
/// Returns the comparison result after all evaluations complete.
Future<CompareResult> runCompare({
  required Map<String, VariantFunction> variants,
  required List<APICallService> apiServices,
  required List<AsyncLlmMatcher> matchers,
  int numberOfRuns = 5,
  double passThreshold = 0.5,
}) async {
  final allScores = <String, Map<String, List<double>>>{};

  for (final variantEntry in variants.entries) {
    final variantName = variantEntry.key;
    final variantFn = variantEntry.value;
    allScores[variantName] = {};

    for (final apiService in apiServices) {
      final modelName =
          '${apiService.runtimeType} ${apiService.defaultModel.name}';
      allScores[variantName]![modelName] = [];

      for (var i = 0; i < numberOfRuns; i++) {
        final output = await variantFn(apiService);

        var totalScore = 0.0;
        for (final matcher in matchers) {
          final score = await matcher.evaluateAsync(output);
          totalScore += score;
        }
        final avgScore = totalScore / matchers.length;
        allScores[variantName]![modelName]!.add(avgScore);
      }
    }
  }

  return computeCompareResult(allScores, passThreshold: passThreshold);
}
