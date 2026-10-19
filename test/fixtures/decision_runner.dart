import 'dart:convert';
import 'package:eval/eval.dart';
import 'package:http/testing.dart';
import '../decision_service_test.dart' show Model, Service;

class ChatService extends APICallService<Model> {
  ChatService()
    : super(
        baseUrl: '',
        apiKey: '',
        defaultModel: Model.first,
        timeout: Duration.zero,
        stateful: false,
      );
  @override
  Future<String> sendRequest(
    String prompt, {
    String? systemPrompt,
    Model? modelName,
  }) async => 'ok';
}

void main() {
  final service = Service(
    MockClient((_) async => throw StateError('No HTTP expected')),
  );
  decisionEval(
    'typed three',
    (s) async {
      expect(s, isA<DecisionModelService>());
    },
    apiServices: [service],
    numberOfRuns: 3,
  );
  decisionEval(
    'typed one',
    (s) async {
      expect(true, isTrue);
    },
    apiServices: [service],
    numberOfRuns: 1,
  );
  decisionEval(
    'assertion failure',
    (s) async {
      expect(false, isTrue);
    },
    apiServices: [service],
    numberOfRuns: 1,
  );
  decisionEval(
    'transport failure',
    (s) async {
      throw StateError('Unavailable');
    },
    apiServices: [service],
    numberOfRuns: 1,
  );
  eval(
    'legacy chat',
    (s) async {
      expect(await s.sendRequest('hello'), 'ok');
    },
    apiServices: [ChatService()],
    numberOfRunsPerLLM: 1,
  );
  tearDownAll(
    () => print(
      'EVAL_RUNNER_STATS:${jsonEncode({
            'counts': testRuns.map(
              (key, v) => MapEntry(key, [v.$1, v.$2, v.$3]),
            ),
            'scores': testScores,
          })}',
    ),
  );
}
