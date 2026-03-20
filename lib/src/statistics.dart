import 'dart:math' as math;

/// Statistical summary of evaluation scores.
class EvalStatistics {
  /// Arithmetic mean of scores.
  final double mean;

  /// Standard deviation of scores.
  final double standardDeviation;

  /// Minimum score.
  final double min;

  /// Maximum score.
  final double max;

  /// 50th percentile (median).
  final double p50;

  /// 90th percentile.
  final double p90;

  /// 95th percentile.
  final double p95;

  /// Number of samples.
  final int sampleSize;

  /// Pass rate as a fraction (0.0 to 1.0).
  final double passRate;

  /// Number of passed tests.
  final int passed;

  /// Number of failed tests.
  final int failed;

  const EvalStatistics({
    required this.mean,
    required this.standardDeviation,
    required this.min,
    required this.max,
    required this.p50,
    required this.p90,
    required this.p95,
    required this.sampleSize,
    required this.passRate,
    required this.passed,
    required this.failed,
  });

  /// Creates statistics from a list of scores and pass/fail counts.
  factory EvalStatistics.compute(
    List<double> scores, {
    required int passed,
    required int failed,
  }) {
    final total = passed + failed;
    final passRate = total > 0 ? passed.toDouble() / total : 0.0;

    if (scores.isEmpty) {
      return EvalStatistics(
        mean: 0,
        standardDeviation: 0,
        min: 0,
        max: 0,
        p50: 0,
        p90: 0,
        p95: 0,
        sampleSize: 0,
        passRate: passRate,
        passed: passed,
        failed: failed,
      );
    }

    final sorted = List<double>.from(scores)..sort();
    final n = scores.length;

    // Mean
    final sum = scores.fold<double>(0, (a, b) => a + b);
    final mean = sum / n;

    // Standard deviation (sample, using Bessel's correction)
    final squaredDiffs = scores.map((s) => math.pow(s - mean, 2));
    final sumSquaredDiffs = squaredDiffs.fold<double>(0, (a, b) => a + b);
    // Use n-1 for sample std dev (Bessel's correction), but handle n=1 case
    final variance = n > 1 ? sumSquaredDiffs / (n - 1) : 0.0;
    final std = math.sqrt(variance);

    return EvalStatistics(
      mean: mean,
      standardDeviation: std,
      min: sorted.first,
      max: sorted.last,
      p50: _percentile(sorted, 0.50),
      p90: _percentile(sorted, 0.90),
      p95: _percentile(sorted, 0.95),
      sampleSize: n,
      passRate: passRate,
      passed: passed,
      failed: failed,
    );
  }

  static double _percentile(List<double> sorted, double p) {
    if (sorted.isEmpty) return 0;
    if (sorted.length == 1) return sorted.first;

    final index = p * (sorted.length - 1);
    final lower = index.floor();
    final upper = index.ceil();

    if (lower == upper) return sorted[lower];

    final fraction = index - lower;
    return sorted[lower] * (1 - fraction) + sorted[upper] * fraction;
  }

  /// Formats the statistics for display.
  String format({bool verbose = false}) {
    final buffer = StringBuffer();
    final total = passed + failed;

    buffer.writeln(
      '  Pass Rate: ${(passRate * 100).toStringAsFixed(0)}% ($passed/$total)',
    );

    if (sampleSize > 0) {
      buffer.write(
        '  Score: mean=${mean.toStringAsFixed(2)}, std=${standardDeviation.toStringAsFixed(2)}',
      );

      if (verbose) {
        buffer.writeln(
          ', min=${min.toStringAsFixed(2)}, max=${max.toStringAsFixed(2)}',
        );
        buffer.write(
          '  Percentiles: p50=${p50.toStringAsFixed(2)}, p90=${p90.toStringAsFixed(2)}, p95=${p95.toStringAsFixed(2)}',
        );
      }
    }

    return buffer.toString();
  }

  @override
  String toString() => format();
}

/// Aggregates statistics across multiple test runs.
class AggregateStatistics {
  final Map<String, EvalStatistics> byTestRun;
  final Map<String, EvalStatistics> byModel;
  final EvalStatistics overall;

  const AggregateStatistics({
    required this.byTestRun,
    required this.byModel,
    required this.overall,
  });

  /// Computes aggregate statistics from test run data.
  factory AggregateStatistics.compute({
    required Map<String, (int passed, int failed, int total)> testRuns,
    required Map<String, List<double>> testScores,
  }) {
    final byTestRun = <String, EvalStatistics>{};
    final modelScores = <String, List<double>>{};
    final modelPassed = <String, int>{};
    final modelFailed = <String, int>{};
    final allScores = <double>[];
    var totalPassed = 0;
    var totalFailed = 0;

    for (final entry in testRuns.entries) {
      final key = entry.key;
      final (passed, failed, _) = entry.value;
      final scores = testScores[key] ?? [];

      byTestRun[key] = EvalStatistics.compute(
        scores,
        passed: passed,
        failed: failed,
      );

      // Extract model name from key (format: "description with ModelType modelName runNumber")
      final modelMatch = RegExp(r'with (\w+) ([\w\-\.]+) \d+$').firstMatch(key);
      if (modelMatch != null) {
        final modelKey = '${modelMatch.group(1)} ${modelMatch.group(2)}';
        modelScores.putIfAbsent(modelKey, () => []).addAll(scores);
        modelPassed[modelKey] = (modelPassed[modelKey] ?? 0) + passed;
        modelFailed[modelKey] = (modelFailed[modelKey] ?? 0) + failed;
      }

      allScores.addAll(scores);
      totalPassed += passed;
      totalFailed += failed;
    }

    final byModel = <String, EvalStatistics>{};
    for (final modelKey in modelScores.keys) {
      byModel[modelKey] = EvalStatistics.compute(
        modelScores[modelKey]!,
        passed: modelPassed[modelKey]!,
        failed: modelFailed[modelKey]!,
      );
    }

    return AggregateStatistics(
      byTestRun: byTestRun,
      byModel: byModel,
      overall: EvalStatistics.compute(
        allScores,
        passed: totalPassed,
        failed: totalFailed,
      ),
    );
  }

  /// Formats the aggregate statistics for display.
  String format({bool verbose = false}) {
    final buffer = StringBuffer();

    buffer.writeln('=== Eval Results ===\n');

    // By model summary
    if (byModel.isNotEmpty) {
      buffer.writeln('By Model:');
      for (final entry in byModel.entries) {
        buffer.writeln('  ${entry.key}:');
        buffer.writeln('  ${entry.value.format(verbose: verbose)}');
      }
      buffer.writeln();
    }

    // Overall
    buffer.writeln('Overall:');
    buffer.writeln(overall.format(verbose: verbose));

    if (verbose && byTestRun.isNotEmpty) {
      buffer.writeln('\nDetailed by Run:');
      for (final entry in byTestRun.entries) {
        buffer.writeln('  ${entry.key}:');
        buffer.writeln('  ${entry.value.format()}');
      }
    }

    return buffer.toString();
  }

  @override
  String toString() => format();
}
