import 'dart:async';
import 'dart:convert';

import 'package:eval/eval.dart' hide expect;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

enum Model { first, second }

class Service extends DecisionModelService<Model> {
  Service(
    http.Client client, {
    super.requestTimeout = const Duration(seconds: 1),
    super.rateLimitDelay,
  }) : super(
         baseUrl: 'https://example.test/api/alpha/decisions',
         apiKey: 'test-key',
         defaultModel: Model.first,
         client: client,
       );
  @override
  String modelId(Model model) => 'test/${model.name}';
}

DecisionRequest request() => DecisionRequest(
  state: {'title': 'Grüße 世界'},
  questions: {
    'include': NoulQuestion(instructions: 'Include?'),
    'category': ChoiceQuestion(
      instructions: 'Category?',
      criteria: {'a': 'A', 'b': 'B'},
    ),
    'priority': ScoreQuestion(
      instructions: 'Priority?',
      criteria: ['Low', 'High'],
    ),
  },
);

Map<String, dynamic> response() => {
  'id': 'decision-1',
  'model': 'test/first-version',
  'provider': 'Test',
  'answers': {
    'include': {'type': 'noul', 'noul': 0.8},
    'category': {
      'type': 'choice',
      'choice': 'a',
      'probabilities': {'a': 0.7, 'b': 0.3},
      'confidence': 0.4,
    },
    'priority': {
      'type': 'score',
      'score': 0.9,
      'probabilities': {'0': 0.1, '1': 0.9},
      'legend': {'0': 'Low', '1': 'High'},
      'confidence': 0.8,
    },
  },
  'usage': {'input_tokens': 100, 'output_tokens': 0, 'cost': 0.001},
};

void main() {
  test(
    'sends state/questions and parses all typed answers and metadata',
    () async {
      final service = Service(
        MockClient((r) async {
          expect(r.method, 'POST');
          expect(r.url.path, '/api/alpha/decisions');
          expect(r.headers['Authorization'], 'Bearer test-key');
          final body = jsonDecode(r.body) as Map;
          expect(body['model'], 'test/second');
          expect(body['state'], {'title': 'Grüße 世界'});
          expect(body.keys, unorderedEquals(['model', 'state', 'questions']));
          expect(body['questions']['include']['type'], 'noul');
          return http.Response(jsonEncode(response()), 200);
        }),
      );
      final result = await service.decide(request(), modelName: Model.second);
      expect((result.answers['include'] as NoulAnswer).probability, 0.8);
      expect((result.answers['category'] as ChoiceAnswer).choice, 'a');
      expect((result.answers['category'] as ChoiceAnswer).confidence, 0.4);
      expect((result.answers['priority'] as ScoreAnswer).score, 0.9);
      expect(result.model, 'test/first-version');
      expect(result.provider, 'Test');
      expect(result.usage.inputTokens, 100);
      expect(result.usage.outputTokens, 0);
      expect(result.usage.cost, 0.001);
    },
  );

  test('optional confidence/distributions/cost remain absent', () {
    final json = response();
    (json['answers']['category'] as Map)
      ..remove('confidence')
      ..remove('probabilities');
    (json['answers']['priority'] as Map)
      ..remove('confidence')
      ..remove('probabilities')
      ..remove('legend');
    (json['usage'] as Map).remove('cost');
    final result = DecisionResponse.fromJson(json, request: request());
    expect(result.usage.cost, isNull);
    expect((result.answers['category'] as ChoiceAnswer).confidence, isNull);
    expect((result.answers['priority'] as ScoreAnswer).probabilities, isNull);
  });

  final invalid = <String, void Function(Map<String, dynamic>)>{
    'missing answer': (j) => (j['answers'] as Map).remove('include'),
    'extra answer': (j) => j['answers']['extra'] = {'type': 'noul', 'noul': 1},
    'wrong type': (j) => j['answers']['include']['type'] = 'choice',
    'boolean probability': (j) => j['answers']['include']['noul'] = true,
    'negative probability': (j) => j['answers']['include']['noul'] = -0.01,
    'probability above one': (j) => j['answers']['include']['noul'] = 1.01,
    'nonfinite probability': (j) =>
        j['answers']['include']['noul'] = double.nan,
    'unknown choice': (j) => j['answers']['category']['choice'] = 'c',
    'wrong probability keys': (j) =>
        j['answers']['category']['probabilities'] = {'a': 1.0},
    'bad distribution sum': (j) =>
        j['answers']['category']['probabilities'] = {'a': 0.8, 'b': 0.8},
    'score outside rubric': (j) => j['answers']['priority']['score'] = 2,
    'incorrect legend': (j) => j['answers']['priority']['legend']['0'] = 'High',
    'missing model': (j) => j.remove('model'),
    'missing usage': (j) => j.remove('usage'),
    'negative cost': (j) => j['usage']['cost'] = -1,
    'invalid tokens': (j) => j['usage']['input_tokens'] = 0.5,
  };
  for (final entry in invalid.entries) {
    test('rejects ${entry.key}', () {
      final json = response();
      entry.value(json);
      expect(
        () => DecisionResponse.fromJson(json, request: request()),
        throwsA(isA<ApiInvalidDecisionResponseException>()),
      );
    });
  }
  for (final status in [
    400,
    401,
    402,
    404,
    413,
    429,
    500,
    502,
    503,
    524,
    529,
  ]) {
    test('preserves HTTP status $status without retry', () async {
      var calls = 0;
      final service = Service(
        MockClient((r) async {
          calls++;
          return http.Response('{"error":{"message":"unavailable"}}', status);
        }),
      );
      await expectLater(
        service.decide(request()),
        throwsA(
          isA<ApiException>().having((e) => e.statusCode, 'status', status),
        ),
      );
      expect(calls, 1);
    });
  }
  for (final body in ['not JSON', '[]', '{"model":"x"}']) {
    test('rejects malformed body $body', () async {
      final service = Service(
        MockClient((r) async => http.Response(body, 200)),
      );
      await expectLater(
        service.decide(request()),
        throwsA(isA<ApiInvalidDecisionResponseException>()),
      );
    });
  }
  test('timeout aborts transport', () async {
    final client = AbortClient();
    await expectLater(
      Service(
        client,
        requestTimeout: const Duration(milliseconds: 10),
      ).decide(request()),
      throwsA(isA<TimeoutException>()),
    );
    await client.aborted.future;
  });
  test('typed queue recovers after failed request', () async {
    var calls = 0;
    final service = Service(
      MockClient(
        (r) async => ++calls == 1
            ? http.Response('unavailable', 503)
            : http.Response(jsonEncode(response()), 200),
      ),
      rateLimitDelay: const Duration(milliseconds: 1),
    );
    await expectLater(
      service.decide(request()),
      throwsA(isA<ApiHttpException>()),
    );
    expect((await service.decide(request())).model, 'test/first-version');
  });
  test('request snapshots state and validates criteria', () {
    final state = {
      'list': ['original'],
    };
    final req = DecisionRequest(
      state: state,
      questions: {'x': NoulQuestion(instructions: 'X?')},
    );
    state['list']!.add('changed');
    expect(req.state, {
      'list': ['original'],
    });
    expect(
      () => ChoiceQuestion(instructions: 'X?', criteria: {'a': 'A'}),
      throwsArgumentError,
    );
    expect(
      () => ScoreQuestion(instructions: 'X?', criteria: ['A']),
      throwsArgumentError,
    );
    expect(
      () => NoulQuestion(instructions: 'X?', criteria: {'yes': 'A'}),
      throwsArgumentError,
    );
    expect(
      () => DecisionRequest(state: 'text', questions: {}),
      throwsArgumentError,
    );
    expect(
      () => DecisionRequest(
        state: 4,
        questions: {'x': NoulQuestion(instructions: 'X?')},
      ),
      throwsArgumentError,
    );
  });
}

class AbortClient extends http.BaseClient {
  final aborted = Completer<void>();
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final abortable = request as http.AbortableRequest;
    await abortable.abortTrigger;
    aborted.complete();
    throw http.RequestAbortedException(request.url);
  }
}
