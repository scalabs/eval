import 'dart:convert';
import 'dart:io';
import 'package:test/test.dart';

void main() {
  test(
    'decision and chat runners share statistics without double counting',
    () async {
      final result = await Process.run(
        Platform.resolvedExecutable,
        ['test', 'test/fixtures/decision_runner.dart', '--reporter=expanded'],
        environment: {'CI': 'true'},
      );
      expect(
        result.exitCode,
        1,
        reason: result.stdout.toString() + result.stderr.toString(),
      );
      final line = result.stdout
          .toString()
          .split('\n')
          .firstWhere((line) => line.contains('EVAL_RUNNER_STATS:'));
      final json =
          jsonDecode(line.substring(line.indexOf('EVAL_RUNNER_STATS:') + 18))
              as Map;
      final counts = Map<String, dynamic>.from(json['counts'] as Map);
      expect(counts.length, 7);
      expect(counts.keys.where((k) => k.startsWith('typed three')).length, 3);
      expect(counts.keys.where((k) => k.startsWith('typed one')).length, 1);
      for (final entry in counts.entries) {
        expect(
          entry.value,
          entry.key.contains('failure') ? [0, 1, 1] : [1, 0, 1],
        );
        if (entry.key.contains('failure')) {
          expect(json['scores'][entry.key], [0.0]);
        }
        if (entry.key.startsWith('typed')) {
          expect(json['scores'][entry.key], [1.0]);
        }
      }
      expect(result.stdout, contains('=== Eval Results ==='));
    },
  );
}
