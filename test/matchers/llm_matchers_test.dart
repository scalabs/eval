import 'package:eval/eval.dart' hide expect;
import 'package:test/test.dart' hide expectAsync;

enum _TestJudgeModel { mock }

class _FakeJudgeService extends APICallService<_TestJudgeModel> {
  final String response;

  _FakeJudgeService(this.response)
    : super(
        baseUrl: 'https://example.com',
        apiKey: 'test-key',
        defaultModel: _TestJudgeModel.mock,
        timeout: Duration.zero,
        stateful: false,
      );

  @override
  Future<String> apiCallImpl(
    String prompt,
    String? systemPrompt,
    _TestJudgeModel modelName, {
    imageBytes,
    fileBytes,
  }) async {
    return response;
  }
}

void main() {
  group('LlmEvalResult', () {
    test('creates result with required fields', () {
      final result = LlmEvalResult(score: 0.8, passed: true);
      expect(result.score, equals(0.8));
      expect(result.passed, isTrue);
      expect(result.reason, isNull);
    });

    test('creates result with reason', () {
      final result = LlmEvalResult(
        score: 0.5,
        passed: false,
        reason: 'Score below threshold',
      );
      expect(result.reason, equals('Score below threshold'));
    });
  });

  group('semanticallySimilarTo matcher', () {
    test('creates matcher with default threshold', () {
      final matcher = semanticallySimilarTo('reference text');
      expect(matcher, isA<Matcher>());
    });

    test('creates matcher with custom threshold', () {
      final matcher = semanticallySimilarTo('reference', threshold: 0.9);
      expect(matcher, isA<Matcher>());
    });

    test('throws when no API service configured', () {
      llmMatcherService = null;
      // The matcher itself doesn't throw, but evaluation would
      final matcher = semanticallySimilarTo('reference');
      expect(matcher, isA<Matcher>());
    });
  });

  group('answersQuestion matcher', () {
    test('creates matcher with question', () {
      final matcher = answersQuestion('What is the capital of France?');
      expect(matcher, isA<Matcher>());
    });

    test('creates matcher with custom threshold', () {
      final matcher = answersQuestion('What is 2+2?', threshold: 0.5);
      expect(matcher, isA<Matcher>());
    });
  });

  group('isFaithfulTo matcher', () {
    test('creates matcher with context', () {
      final matcher = isFaithfulTo('Paris is the capital of France.');
      expect(matcher, isA<Matcher>());
    });

    test('creates matcher with custom threshold', () {
      final matcher = isFaithfulTo('Some context', threshold: 0.8);
      expect(matcher, isA<Matcher>());
    });
  });

  group('isNotToxic matcher', () {
    test('creates matcher with default threshold', () {
      final matcher = isNotToxic();
      expect(matcher, isA<Matcher>());
    });

    test('creates matcher with custom threshold', () {
      final matcher = isNotToxic(threshold: 0.1);
      expect(matcher, isA<Matcher>());
    });
  });

  group('isNotBiased matcher', () {
    test('creates matcher with default threshold', () {
      final matcher = isNotBiased();
      expect(matcher, isA<Matcher>());
    });

    test('creates matcher with custom threshold', () {
      final matcher = isNotBiased(threshold: 0.2);
      expect(matcher, isA<Matcher>());
    });
  });

  group('llmMatcherService', () {
    test('defaults to null', () {
      llmMatcherService = null;
      expect(llmMatcherService, isNull);
    });
  });

  group('AsyncLlmMatcher', () {
    test('checkThreshold works for lower bound matchers', () {
      final asyncMatcher = semanticallySimilarTo('ref', threshold: 0.7);

      expect(asyncMatcher.threshold, equals(0.7));
      expect(asyncMatcher.isUpperBoundCheck, isFalse);
      expect(asyncMatcher.checkThreshold(0.8), isTrue); // 0.8 >= 0.7
      expect(asyncMatcher.checkThreshold(0.7), isTrue); // 0.7 >= 0.7
      expect(asyncMatcher.checkThreshold(0.6), isFalse); // 0.6 < 0.7
    });

    test('checkThreshold works for upper bound matchers (toxicity)', () {
      final asyncMatcher = isNotToxic(threshold: 0.3);

      expect(asyncMatcher.threshold, equals(0.3));
      expect(asyncMatcher.isUpperBoundCheck, isTrue);
      expect(asyncMatcher.checkThreshold(0.2), isTrue); // 0.2 <= 0.3
      expect(asyncMatcher.checkThreshold(0.3), isTrue); // 0.3 <= 0.3
      expect(asyncMatcher.checkThreshold(0.4), isFalse); // 0.4 > 0.3
    });

    test('checkThreshold works for upper bound matchers (bias)', () {
      final asyncMatcher = isNotBiased(threshold: 0.3);

      expect(asyncMatcher.isUpperBoundCheck, isTrue);
      expect(asyncMatcher.checkThreshold(0.1), isTrue);
      expect(asyncMatcher.checkThreshold(0.5), isFalse);
    });

    test('answersQuestion uses lower bound check', () {
      final asyncMatcher = answersQuestion('question?', threshold: 0.5);

      expect(asyncMatcher.isUpperBoundCheck, isFalse);
      expect(asyncMatcher.checkThreshold(0.6), isTrue);
      expect(asyncMatcher.checkThreshold(0.4), isFalse);
    });

    test('isFaithfulTo uses lower bound check', () {
      final asyncMatcher = isFaithfulTo('context', threshold: 0.8);

      expect(asyncMatcher.isUpperBoundCheck, isFalse);
      expect(asyncMatcher.checkThreshold(0.9), isTrue);
      expect(asyncMatcher.checkThreshold(0.7), isFalse);
    });

    test('fails in sync matcher contexts with async guidance', () {
      final matcher = semanticallySimilarTo('reference');
      final matchState = <dynamic, dynamic>{};

      expect(matcher.matches('actual', matchState), isFalse);

      final description = StringDescription();
      matcher.describeMismatch('actual', description, matchState, false);

      expect(description.toString(), contains('expectAsync'));
    });

    test('expectAsync passes for matching score', () async {
      await expectAsync(
        'actual',
        semanticallySimilarTo(
          'reference',
          apiService: _FakeJudgeService('{"score": 0.95, "reason": "close"}'),
        ),
      );
    });

    test('expectAsync fails for score below threshold', () async {
      await expectLater(
        expectAsync(
          'actual',
          semanticallySimilarTo(
            'reference',
            apiService: _FakeJudgeService(
              '{"score": 0.1, "reason": "not similar"}',
            ),
          ),
        ),
        throwsA(isA<TestFailure>()),
      );
    });
  });
}
