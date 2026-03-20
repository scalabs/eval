import 'package:eval/src/matchers/rag_matchers.dart';
import 'package:test/test.dart';

void main() {
  group('contextPrecision', () {
    test('creates matcher with default threshold', () {
      final matcher = contextPrecision(
        contexts: ['context1', 'context2'],
        query: 'What is the answer?',
      );

      expect(matcher.threshold, equals(0.7));
    });

    test('creates matcher with custom threshold', () {
      final matcher = contextPrecision(
        contexts: ['context1'],
        query: 'query',
        threshold: 0.9,
      );

      expect(matcher.threshold, equals(0.9));
    });

    test('describe includes query and threshold', () {
      final matcher = contextPrecision(
        contexts: ['context1'],
        query: 'What is the capital of France?',
        threshold: 0.8,
      );

      final description = StringDescription();
      matcher.describe(description);

      expect(description.toString(), contains('context precision'));
      expect(description.toString(), contains('>= 0.8'));
      expect(
        description.toString(),
        contains('What is the capital of France?'),
      );
    });

    test('describeMismatch handles non-string input', () {
      final matcher = contextPrecision(contexts: ['context1'], query: 'query');

      final description = StringDescription();
      matcher.describeMismatch(123, description, {}, false);

      expect(description.toString(), equals('is not a String'));
    });

    test('describeMismatch for string indicates async needed', () {
      final matcher = contextPrecision(contexts: ['context1'], query: 'query');

      final description = StringDescription();
      matcher.describeMismatch('some answer', description, {}, false);

      expect(description.toString(), contains('async'));
    });
  });

  group('contextRecall', () {
    test('creates matcher with default threshold', () {
      final matcher = contextRecall(
        contexts: ['context1', 'context2'],
        groundTruth: 'The answer is X.',
      );

      expect(matcher.threshold, equals(0.7));
    });

    test('creates matcher with custom threshold', () {
      final matcher = contextRecall(
        contexts: ['context1'],
        groundTruth: 'truth',
        threshold: 0.85,
      );

      expect(matcher.threshold, equals(0.85));
    });

    test('describe includes threshold', () {
      final matcher = contextRecall(
        contexts: ['context1'],
        groundTruth: 'ground truth',
      );

      final description = StringDescription();
      matcher.describe(description);

      expect(description.toString(), contains('context recall'));
      expect(description.toString(), contains('>= 0.7'));
    });

    test('describeMismatch handles non-string input', () {
      final matcher = contextRecall(
        contexts: ['context1'],
        groundTruth: 'truth',
      );

      final description = StringDescription();
      matcher.describeMismatch(null, description, {}, false);

      expect(description.toString(), equals('is not a String'));
    });
  });

  group('answerGroundedness', () {
    test('creates matcher with default threshold', () {
      final matcher = answerGroundedness(contexts: ['context1', 'context2']);

      expect(matcher.threshold, equals(0.8));
    });

    test('creates matcher with custom threshold', () {
      final matcher = answerGroundedness(
        contexts: ['context1'],
        threshold: 0.95,
      );

      expect(matcher.threshold, equals(0.95));
    });

    test('describe includes threshold', () {
      final matcher = answerGroundedness(
        contexts: ['context1'],
        threshold: 0.9,
      );

      final description = StringDescription();
      matcher.describe(description);

      expect(description.toString(), contains('answer groundedness'));
      expect(description.toString(), contains('>= 0.9'));
    });

    test('describeMismatch handles non-string input', () {
      final matcher = answerGroundedness(contexts: ['context1']);

      final description = StringDescription();
      matcher.describeMismatch(['list'], description, {}, false);

      expect(description.toString(), equals('is not a String'));
    });
  });

  group('answerRelevancy', () {
    test('creates matcher with default threshold', () {
      final matcher = answerRelevancy(query: 'What is the answer?');

      expect(matcher.threshold, equals(0.7));
    });

    test('creates matcher with custom threshold', () {
      final matcher = answerRelevancy(query: 'query', threshold: 0.6);

      expect(matcher.threshold, equals(0.6));
    });

    test('describe includes query and threshold', () {
      final matcher = answerRelevancy(query: 'What is 2+2?', threshold: 0.75);

      final description = StringDescription();
      matcher.describe(description);

      expect(description.toString(), contains('answer relevancy'));
      expect(description.toString(), contains('>= 0.75'));
      expect(description.toString(), contains('What is 2+2?'));
    });

    test('describeMismatch handles non-string input', () {
      final matcher = answerRelevancy(query: 'query');

      final description = StringDescription();
      matcher.describeMismatch({'map': true}, description, {}, false);

      expect(description.toString(), equals('is not a String'));
    });
  });

  group('ragScore', () {
    test('creates matcher with default threshold', () {
      final matcher = ragScore(
        contexts: ['context1', 'context2'],
        query: 'What is the answer?',
      );

      expect(matcher.threshold, equals(0.7));
    });

    test('creates matcher with custom threshold', () {
      final matcher = ragScore(
        contexts: ['context1'],
        query: 'query',
        threshold: 0.8,
      );

      expect(matcher.threshold, equals(0.8));
    });

    test('creates matcher with ground truth', () {
      final matcher = ragScore(
        contexts: ['context1'],
        query: 'query',
        groundTruth: 'The expected answer',
      );

      expect(matcher.threshold, equals(0.7));
    });

    test('describe includes threshold', () {
      final matcher = ragScore(
        contexts: ['context1'],
        query: 'query',
        threshold: 0.85,
      );

      final description = StringDescription();
      matcher.describe(description);

      expect(description.toString(), contains('combined RAG score'));
      expect(description.toString(), contains('>= 0.85'));
    });

    test('describeMismatch handles non-string input', () {
      final matcher = ragScore(contexts: ['context1'], query: 'query');

      final description = StringDescription();
      matcher.describeMismatch(42, description, {}, false);

      expect(description.toString(), equals('is not a String'));
    });
  });

  group('edge cases', () {
    test('contextPrecision handles empty contexts', () {
      final matcher = contextPrecision(contexts: [], query: 'query');

      expect(matcher.threshold, equals(0.7));
    });

    test('contextRecall handles empty contexts', () {
      final matcher = contextRecall(contexts: [], groundTruth: 'truth');

      expect(matcher.threshold, equals(0.7));
    });

    test('answerGroundedness handles empty contexts', () {
      final matcher = answerGroundedness(contexts: []);

      expect(matcher.threshold, equals(0.8));
    });

    test('ragScore handles empty contexts', () {
      final matcher = ragScore(contexts: [], query: 'query');

      expect(matcher.threshold, equals(0.7));
    });

    test('matchers handle long context lists', () {
      final longContexts = List.generate(100, (i) => 'Context $i: Some text');

      final matcher = contextPrecision(contexts: longContexts, query: 'query');

      expect(matcher.threshold, equals(0.7));
    });

    test('matchers handle special characters in query', () {
      final matcher = answerRelevancy(query: 'What is "quoted" & <special>?');

      final description = StringDescription();
      matcher.describe(description);

      expect(description.toString(), contains('quoted'));
    });

    test('matchers handle multiline ground truth', () {
      final matcher = contextRecall(
        contexts: ['context'],
        groundTruth: '''Line 1
Line 2
Line 3''',
      );

      expect(matcher.threshold, equals(0.7));
    });
  });

  group('isUpperBoundCheck', () {
    test('contextPrecision uses lower bound (>=)', () {
      final matcher = contextPrecision(contexts: [], query: 'q');
      expect(matcher.isUpperBoundCheck, isFalse);
    });

    test('contextRecall uses lower bound (>=)', () {
      final matcher = contextRecall(contexts: [], groundTruth: 't');
      expect(matcher.isUpperBoundCheck, isFalse);
    });

    test('answerGroundedness uses lower bound (>=)', () {
      final matcher = answerGroundedness(contexts: []);
      expect(matcher.isUpperBoundCheck, isFalse);
    });

    test('answerRelevancy uses lower bound (>=)', () {
      final matcher = answerRelevancy(query: 'q');
      expect(matcher.isUpperBoundCheck, isFalse);
    });

    test('ragScore uses lower bound (>=)', () {
      final matcher = ragScore(contexts: [], query: 'q');
      expect(matcher.isUpperBoundCheck, isFalse);
    });
  });

  group('checkThreshold', () {
    test('contextPrecision passes when score >= threshold', () {
      final matcher = contextPrecision(
        contexts: [],
        query: 'q',
        threshold: 0.7,
      );
      expect(matcher.checkThreshold(0.7), isTrue);
      expect(matcher.checkThreshold(0.8), isTrue);
      expect(matcher.checkThreshold(0.6), isFalse);
    });

    test('answerGroundedness passes when score >= threshold', () {
      final matcher = answerGroundedness(contexts: [], threshold: 0.8);
      expect(matcher.checkThreshold(0.8), isTrue);
      expect(matcher.checkThreshold(0.9), isTrue);
      expect(matcher.checkThreshold(0.7), isFalse);
    });
  });

  group('answerCorrectness', () {
    test('creates matcher with default threshold', () {
      final matcher = answerCorrectness(
        groundTruth: 'Paris is the capital of France.',
      );

      expect(matcher.threshold, equals(0.7));
    });

    test('creates matcher with custom threshold', () {
      final matcher = answerCorrectness(
        groundTruth: 'Paris is the capital of France.',
        threshold: 0.9,
      );

      expect(matcher.threshold, equals(0.9));
    });

    test('describe includes threshold', () {
      final matcher = answerCorrectness(
        groundTruth: 'Paris is the capital of France.',
        threshold: 0.8,
      );

      final description = StringDescription();
      matcher.describe(description);

      expect(description.toString(), contains('answer correctness'));
      expect(description.toString(), contains('>= 0.8'));
    });

    test('describeMismatch handles non-string input', () {
      final matcher = answerCorrectness(groundTruth: 'truth');

      final description = StringDescription();
      matcher.describeMismatch(123, description, {}, false);

      expect(description.toString(), equals('is not a String'));
    });

    test('uses lower bound (>=)', () {
      final matcher = answerCorrectness(groundTruth: 'truth');
      expect(matcher.isUpperBoundCheck, isFalse);
    });

    test('checkThreshold passes when score >= threshold', () {
      final matcher = answerCorrectness(groundTruth: 'truth', threshold: 0.7);
      expect(matcher.checkThreshold(0.7), isTrue);
      expect(matcher.checkThreshold(0.8), isTrue);
      expect(matcher.checkThreshold(0.6), isFalse);
    });
  });

  group('ragScore with weights', () {
    test('creates matcher with default weights (null)', () {
      final matcher = ragScore(
        contexts: ['context1'],
        query: 'What is the answer?',
      );

      expect(matcher.threshold, equals(0.7));
    });

    test('creates matcher with custom weights', () {
      final matcher = ragScore(
        contexts: ['context1'],
        query: 'What is the answer?',
        weights: {'groundedness': 2.0, 'precision': 0.5},
      );

      expect(matcher.threshold, equals(0.7));
    });

    test('describe output is unchanged with weights', () {
      final matcher = ragScore(
        contexts: ['context1'],
        query: 'query',
        weights: {'groundedness': 2.0},
      );

      final description = StringDescription();
      matcher.describe(description);

      expect(description.toString(), contains('combined RAG score'));
      expect(description.toString(), contains('>= 0.7'));
    });
  });

  group('RagEvalResult', () {
    test('creates result with all scores', () {
      const result = RagEvalResult(
        score: 0.85,
        contextPrecision: 0.9,
        contextRecall: 0.8,
        answerGroundedness: 0.85,
        answerRelevancy: 0.85,
      );

      expect(result.score, equals(0.85));
      expect(result.contextPrecision, equals(0.9));
      expect(result.contextRecall, equals(0.8));
      expect(result.answerGroundedness, equals(0.85));
      expect(result.answerRelevancy, equals(0.85));
    });

    test('creates result with partial scores', () {
      const result = RagEvalResult(
        score: 0.8,
        contextPrecision: 0.9,
        answerGroundedness: 0.7,
      );

      expect(result.score, equals(0.8));
      expect(result.contextPrecision, equals(0.9));
      expect(result.contextRecall, isNull);
      expect(result.answerGroundedness, equals(0.7));
      expect(result.answerRelevancy, isNull);
    });

    test('toString formats all scores', () {
      const result = RagEvalResult(
        score: 0.85,
        contextPrecision: 0.9,
        contextRecall: 0.8,
        answerGroundedness: 0.85,
        answerRelevancy: 0.75,
      );

      final str = result.toString();

      expect(str, contains('RagEvalResult'));
      expect(str, contains('score: 0.85'));
      expect(str, contains('precision: 0.90'));
      expect(str, contains('recall: 0.80'));
      expect(str, contains('groundedness: 0.85'));
      expect(str, contains('relevancy: 0.75'));
    });

    test('toString omits null scores', () {
      const result = RagEvalResult(score: 0.8, contextPrecision: 0.9);

      final str = result.toString();

      expect(str, contains('score: 0.80'));
      expect(str, contains('precision: 0.90'));
      expect(str, isNot(contains('recall')));
      expect(str, isNot(contains('groundedness')));
      expect(str, isNot(contains('relevancy')));
    });

    test('can store optional metadata', () {
      const result = RagEvalResult(
        score: 0.8,
        relevantContextIndices: [0, 2, 4],
        unsupportedClaims: ['claim1', 'claim2'],
        reason: 'The answer mostly aligns with the context.',
      );

      expect(result.relevantContextIndices, equals([0, 2, 4]));
      expect(result.unsupportedClaims, equals(['claim1', 'claim2']));
      expect(result.reason, contains('mostly aligns'));
    });
  });
}
