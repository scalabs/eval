# Eval

Pure Dart LLM evaluation helpers for tests, including judge-based matchers, RAG scoring, and statistics.

## Install

```yaml
dependencies:
  eval: ^0.0.2
```

## What It Includes

- String, JSON, schema, and frontmatter matchers
- Distance metrics such as Levenshtein and Jaro-Winkler
- LLM-as-judge matchers for semantic similarity, faithfulness, toxicity, bias, and answer quality
- RAG helpers for context precision, context recall, groundedness, relevancy, correctness, and combined scoring
- Aggregate statistics and prompt comparison helpers

## Quick Start

Use regular `expect(...)` for synchronous matchers:

```dart
import 'package:eval/eval.dart';
import 'package:test/test.dart';

void main() {
  test('sync matchers', () {
    const output = '{"message":"Hello"}';

    expect(output, isValidJson);
    expect(output, hasJsonPathValue('message', 'Hello'));
    expect('The quick brown fox', containsAllWords(['quick', 'fox']));
  });
}
```

Use `await expectAsync(...)` for judge-based matchers:

```dart
import 'package:eval/eval.dart';
import 'package:test/test.dart';

void main() {
  test('llm judge matchers', () async {
    llmMatcherService = MyLlmService(apiKey: 'your-api-key');

    await expectAsync(
      'Paris is the capital of France.',
      semanticallySimilarTo('France has Paris as its capital'),
    );

    await expectAsync(
      'Paris is the capital of France.',
      answersQuestion('What is the capital of France?'),
    );
  });
}
```

## Matcher Overview

### String

```dart
expect(text, containsIgnoreCase('hello'));
expect(text, matchesPattern(r'\d{3}-\d{4}'));
expect(text, containsAllWords(['important', 'keywords']));
expect(text, containsAnyOf(['error', 'warning']));
expect(text, containsNoneOf(['forbidden']));
expect(text, wordCountBetween(50, 100));
expect(text, sentenceCountBetween(3, 5));
```

### JSON

```dart
expect(jsonString, isValidJson);
expect(jsonString, isJsonObject);
expect(jsonString, hasJsonKey('status'));
expect(jsonString, hasJsonPath('user.address.city'));
expect(jsonString, hasJsonPathValue('status', 'active'));
```

### Schema

```dart
expect(jsonString, matchesSchema({
  'type': 'object',
  'required': ['name', 'email'],
  'properties': {
    'name': {'type': 'string', 'minLength': 1},
    'email': {'type': 'string'},
    'age': {'type': 'integer', 'minimum': 0},
  },
}));

expect(jsonString, hasRequiredFields({
  'id': int,
  'name': String,
  'active': bool,
}));

expect(jsonString, fieldOneOf('status', ['pending', 'active', 'done']));
expect(jsonString, fieldHasType('age', int));
```

### Frontmatter

```dart
expect(markdown, hasValidFrontmatter);
expect(markdown, hasFrontmatterKey('title'));
expect(markdown, hasFrontmatterValue('draft', false));
expect(markdown, hasMarkdownBody);
expect(markdown, bodyContains('# Heading'));

expect(markdown, frontmatterMatchesSchema({
  'type': 'object',
  'required': ['title'],
  'properties': {
    'title': {'type': 'string'},
    'tags': {'type': 'array', 'items': {'type': 'string'}},
  },
}));
```

### Distance

```dart
expect(text, editDistanceLessThan('expected', 3));
expect(text, editDistanceRatio('expected', 0.2));
expect(text, jaroWinklerSimilarity('expected', 0.9));
```

## LLM-As-Judge Matchers

Judge matchers return `AsyncLlmMatcher`, so use them with `await expectAsync(...)`.

```dart
await expectAsync(
  answer,
  semanticallySimilarTo('Expected meaning', threshold: 0.8),
);

await expectAsync(
  answer,
  isFaithfulTo(sourceDocument, threshold: 0.9),
);

await expectAsync(answer, isNotToxic());
await expectAsync(answer, isNotBiased());
```

If you prefer not to set a global service, pass one directly:

```dart
await expectAsync(
  answer,
  answersQuestion(
    'What is machine learning?',
    apiService: myService,
  ),
);
```

## RAG Evaluation

### Individual Metrics

```dart
await expectAsync(
  answer,
  contextPrecision(
    contexts: retrievedDocs,
    query: 'What causes climate change?',
    threshold: 0.7,
    apiService: myService,
  ),
);

await expectAsync(
  answer,
  answerGroundedness(
    contexts: retrievedDocs,
    threshold: 0.8,
    apiService: myService,
  ),
);

await expectAsync(
  answer,
  answerCorrectness(
    groundTruth: 'The expected factual answer',
    threshold: 0.8,
    apiService: myService,
  ),
);
```

### Detailed RAG Result

```dart
final result = await evaluateRag(
  answer: generatedAnswer,
  contexts: retrievedDocs,
  query: 'What is quantum computing?',
  groundTruth: 'Quantum computing uses quantum mechanics...',
  apiService: myService,
);

print(result.score);
print(result.contextPrecision);
print(result.contextRecall);
print(result.answerGroundedness);
print(result.answerRelevancy);
print(result.relevantContextIndices);
print(result.unsupportedClaims);
print(result.reason);
```

## Statistics

### Basic Statistics

```dart
final scores = [0.85, 0.72, 0.91, 0.68, 0.79];

final stats = EvalStatistics.compute(
  scores,
  passed: scores.where((s) => s >= 0.7).length,
  failed: scores.where((s) => s < 0.7).length,
);

print(stats.format(verbose: true));
```

### Aggregate Statistics

```dart
final aggregate = AggregateStatistics.compute(
  testRuns: {
    'summary with ClaudeService sonnet 1': (3, 1, 4),
    'summary with ClaudeService sonnet 2': (4, 0, 4),
  },
  testScores: {
    'summary with ClaudeService sonnet 1': [0.8, 0.9, 0.7, 0.6],
    'summary with ClaudeService sonnet 2': [0.85, 0.95, 0.9, 0.88],
  },
);

print(aggregate.format(verbose: true));
```

## Compare Prompt Variants

```dart
await evalCompare(
  'Compare prompt strategies',
  variants: {
    'concise': (service) => service.sendRequest('Be brief: $question'),
    'detailed': (service) => service.sendRequest('Explain thoroughly: $question'),
  },
  apiServices: [claudeService, gptService],
  matchers: [
    answersQuestion(question),
    isNotToxic(),
  ],
  numberOfRuns: 10,
  passThreshold: 0.7,
);
```

## Implementing A Custom API Service

```dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:eval/eval.dart';
import 'package:http/http.dart' as http;

enum MyModel {
  small('my-model-small');

  final String modelId;
  const MyModel(this.modelId);
}

class MyLlmService extends APICallService<MyModel> {
  MyLlmService({required String apiKey})
      : super(
          baseUrl: 'https://api.example.com/v1/chat',
          apiKey: apiKey,
          defaultModel: MyModel.small,
          timeout: Duration.zero,
          stateful: false,
        );

  @override
  Future<String> apiCallImpl(
    String prompt,
    String? systemPrompt,
    MyModel modelName, {
    Uint8List? imageBytes,
    Uint8List? fileBytes,
  }) async {
    final response = await http.post(
      Uri.parse(baseUrl),
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': modelName.modelId,
        'messages': [
          if (systemPrompt != null)
            {'role': 'system', 'content': systemPrompt},
          {'role': 'user', 'content': prompt},
        ],
      }),
    );

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return json['content'] as String;
  }
}
```

## Run The Package Checks

```bash
dart analyze
dart test
dart pub publish --dry-run
```

## License

MIT
