# Eval

Pure Dart helpers for LLM evaluations built on top of `package:test`.

`eval(...)` is the center of the package. It wraps normal Dart tests so you can
run the same evaluation across multiple models and multiple runs while collecting
pass/fail counts and score statistics.

## Install

```yaml
dependencies:
  eval: ^0.0.2
```

## Mental Model

- `eval(...)` wraps normal `package:test` groups/tests.
- It runs one evaluation body for every service in `apiServices` and every run in
  `numberOfRunsPerLLM`.
- `expect(...)` is the sync assertion wrapper. It still behaves like a normal
  Dart test expectation, but inside `eval(...)` it also tracks pass/fail counts.
- `expectAsync(...)` is for `AsyncLlmMatcher` matchers such as LLM-as-judge and
  RAG metrics. It tracks pass/fail counts and records numeric scores, which power
  the final statistics output.
- `evalCompare(...)` is for comparing multiple prompt or generation variants.

If you only want ordinary Dart tests, you can still use `test(...)`. This package
just gives you a better default wrapper for LLM evaluations.

## Import

Most users only need:

```dart
import 'package:eval/eval.dart';
```

`package:eval/eval.dart` re-exports most of `package:test/test.dart`, so common
matchers such as `equals`, `contains`, `isA`, and `isNot` are already available.

If you also import `package:test/test.dart` directly, hide `expect` to avoid a
name collision with `eval`'s statistics-aware `expect(...)`:

```dart
import 'package:test/test.dart' hide expect;
```

## Quick Start

```dart
import 'dart:io';

import 'package:eval/eval.dart';

Future<void> main() async {
  final apiKey = Platform.environment['ANTHROPIC_API_KEY'] ?? '';
  if (apiKey.isEmpty) {
    throw StateError('Set ANTHROPIC_API_KEY before running this eval.');
  }

  await eval(
    'answers geography questions',
    (apiService) async {
      final answer = await apiService.sendRequest(
        'Answer in one short sentence: What is the capital of France?',
      );

      expect(answer, containsIgnoreCase('paris'));
      expect(answer, sentenceCountBetween(1, 2));

      await expectAsync(
        answer,
        answersQuestion(
          'What is the capital of France?',
          apiService: apiService,
        ),
      );

      await expectAsync(
        answer,
        isNotToxic(apiService: apiService),
      );
    },
    apiServices: [
      ExampleClaudeService(
        defaultModel: ExampleClaudeModel.haiku45,
        apiKey: apiKey,
      ),
      ExampleClaudeService(
        defaultModel: ExampleClaudeModel.sonnet45,
        apiKey: apiKey,
      ),
    ],
    numberOfRunsPerLLM: 3,
    verbose: true,
  );
}
```

That gives you a normal test run plus eval-specific output:

- one grouped run per model
- repeated runs per model
- pass/fail tracking for every `expect(...)` and `expectAsync(...)`
- score summaries for async judge-based assertions

## Why Use `eval(...)` Instead Of `test(...)`?

Use raw `test(...)` when you want a normal unit test. Use `eval(...)` when you
want LLM evaluation behavior:

- fan out the same eval across multiple services/models
- repeat each eval multiple times
- keep using familiar matcher-style assertions
- collect aggregate statistics such as pass rates and judge score summaries
- print a final report at the end of the run

In other words: `eval(...)` is a wrapper around normal Dart tests, not a different
testing model.

## Sync Matchers

Use regular `expect(...)` for deterministic matchers.

The sections below intentionally list every public sync matcher exported by the
package.

### String

Available string matchers:

- `containsIgnoreCase(...)`: substring check without case sensitivity
- `matchesPattern(...)`: regex or pattern match
- `containsAllWords(...)`: all words must appear as whole words
- `containsAnyOf(...)`: at least one candidate substring must appear
- `containsNoneOf(...)`: none of the candidate substrings may appear
- `wordCountBetween(...)`: inclusive word-count bounds
- `sentenceCountBetween(...)`: inclusive sentence-count bounds

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

Available JSON matchers:

- `isValidJson`: any valid JSON value
- `isJsonObject`: JSON that decodes to an object / `Map`
- `isJsonArray`: JSON that decodes to an array / `List`
- `hasJsonKey(...)`: top-level key exists
- `hasJsonPath(...)`: dot-notation path exists, including array indices
- `hasJsonPathValue(...)`: dot-notation path equals a specific value

```dart
expect(jsonString, isValidJson);
expect(jsonString, isJsonObject);
expect('[{"id":1},{"id":2}]', isJsonArray);
expect(jsonString, hasJsonKey('status'));
expect(jsonString, hasJsonPath('user.address.city'));
expect(jsonString, hasJsonPathValue('status', 'active'));
```

### Schema

Available JSON schema/data-shape matchers:

- `matchesSchema(...)`: validate against the supported JSON Schema subset
- `hasRequiredFields(...)`: require named fields with expected Dart types
- `jsonArrayLengthBetween(...)`: require an array path length within bounds
- `fieldOneOf(...)`: require a field/path value to be in an allowed set
- `fieldHasType(...)`: require a field/path value to have a specific type

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

expect(jsonString, jsonArrayLengthBetween('items', 1, 5));
expect(jsonString, fieldOneOf('status', ['pending', 'active', 'done']));
expect(jsonString, fieldHasType('age', int));
```

### Frontmatter

Available frontmatter/body matchers:

- `hasValidFrontmatter`: valid YAML frontmatter is present
- `hasFrontmatterTitle`: frontmatter contains a non-empty `title`
- `hasFrontmatterKey(...)`: key exists in frontmatter
- `hasFrontmatterValue(...)`: key has an exact value
- `frontmatterKeyMatches(...)`: key value satisfies another matcher
- `hasMarkdownBody`: non-empty body content exists after frontmatter
- `bodyContains(...)`: body contains a substring
- `bodyMatches(...)`: body satisfies another matcher

```dart
expect(markdown, hasValidFrontmatter);
expect(markdown, hasFrontmatterTitle);
expect(markdown, hasFrontmatterKey('title'));
expect(markdown, hasFrontmatterValue('draft', false));
expect(markdown, frontmatterKeyMatches('tags', contains('dart')));
expect(markdown, hasMarkdownBody);
expect(markdown, bodyContains('# Heading'));
expect(markdown, bodyMatches(contains('Introduction')));
```

### Frontmatter Schema

Available frontmatter schema/type helpers:

- `frontmatterMatchesSchema(...)`: validate frontmatter against the supported JSON Schema subset
- `frontmatterHasRequiredFields(...)`: require frontmatter fields with expected Dart types
- `frontmatterArrayLengthBetween(...)`: require a frontmatter array length within bounds
- `frontmatterFieldOneOf(...)`: require a frontmatter field to be in an allowed set
- `frontmatterFieldHasType(...)`: require a frontmatter field to have a specific type

```dart
expect(markdown, frontmatterMatchesSchema({
  'type': 'object',
  'required': ['title'],
  'properties': {
    'title': {'type': 'string'},
    'tags': {'type': 'array', 'items': {'type': 'string'}},
  },
}));

expect(markdown, frontmatterHasRequiredFields({
  'title': String,
  'draft': bool,
}));

expect(markdown, frontmatterArrayLengthBetween('tags', 1, 5));
expect(markdown, frontmatterFieldOneOf('status', ['draft', 'published']));
expect(markdown, frontmatterFieldHasType('count', int));
```

### Distance

Available distance/similarity matchers:

- `editDistanceLessThan(...)`: raw Levenshtein distance must be below a threshold
- `editDistanceRatio(...)`: normalized edit-distance ratio must be below a threshold
- `jaroWinklerSimilarity(...)`: Jaro-Winkler similarity must be at least a threshold

```dart
expect(text, editDistanceLessThan('expected', 3));
expect(text, editDistanceRatio('expected', 0.2));
expect(text, jaroWinklerSimilarity('expected', 0.9));
```

## LLM-As-Judge Matchers

Judge matchers return `AsyncLlmMatcher`, so they must be used with
`await expectAsync(...)`.

The list below intentionally names every public LLM-as-judge matcher.

Inside `eval(...)`, the simplest pattern is to pass the current run's
`apiService` explicitly:

```dart
await expectAsync(
  answer,
  semanticallySimilarTo(
    'Expected meaning',
    threshold: 0.8,
    apiService: apiService,
  ),
);

await expectAsync(
  answer,
  isFaithfulTo(
    sourceDocument,
    threshold: 0.9,
    apiService: apiService,
  ),
);

await expectAsync(answer, isNotToxic(apiService: apiService));
await expectAsync(answer, isNotBiased(apiService: apiService));
```

Available judge matchers include:

- `semanticallySimilarTo(...)`: semantic similarity to a reference answer
- `answersQuestion(...)`: whether the answer addresses a question
- `isFaithfulTo(...)`: whether the answer stays grounded in a source/context
- `isNotToxic(...)`: toxicity score must stay below a threshold
- `isNotBiased(...)`: bias score must stay below a threshold

You can also set `llmMatcherService` globally if you want one default judge
service for the whole file, but explicit `apiService:` wiring is usually clearer.

## RAG Evaluation

The list below intentionally names every public RAG matcher.

Available RAG matchers:

- `contextPrecision(...)`: how much of the retrieved context is relevant
- `contextRecall(...)`: whether the retrieved context covers the needed facts
- `answerGroundedness(...)`: whether the answer is supported by the contexts
- `answerRelevancy(...)`: whether the answer addresses the query
- `answerCorrectness(...)`: whether the answer matches the ground truth
- `ragScore(...)`: weighted combined RAG score across multiple metrics

### Individual Metrics

```dart
await expectAsync(
  answer,
  contextPrecision(
    contexts: retrievedDocs,
    query: 'What causes climate change?',
    threshold: 0.7,
    apiService: apiService,
  ),
);

await expectAsync(
  answer,
  contextRecall(
    contexts: retrievedDocs,
    groundTruth: 'The expected factual answer',
    threshold: 0.8,
    apiService: apiService,
  ),
);

await expectAsync(
  answer,
  answerGroundedness(
    contexts: retrievedDocs,
    threshold: 0.8,
    apiService: apiService,
  ),
);

await expectAsync(
  answer,
  answerRelevancy(
    query: 'What caused the outage?',
    threshold: 0.7,
    apiService: apiService,
  ),
);

await expectAsync(
  answer,
  answerCorrectness(
    groundTruth: 'The expected factual answer',
    threshold: 0.8,
    apiService: apiService,
  ),
);

await expectAsync(
  answer,
  ragScore(
    contexts: retrievedDocs,
    query: 'What caused the outage?',
    groundTruth: 'The expected factual answer',
    weights: {
      'groundedness': 2.0,
      'precision': 1.0,
      'recall': 1.0,
      'relevancy': 1.0,
    },
    threshold: 0.8,
    apiService: apiService,
  ),
);
```

### Detailed RAG Result

Use `evaluateRag(...)` when you want the component scores and extra metadata,
not just a pass/fail assertion.

```dart
final result = await evaluateRag(
  answer: generatedAnswer,
  contexts: retrievedDocs,
  query: 'What is quantum computing?',
  groundTruth: 'Quantum computing uses quantum mechanics...',
  apiService: apiService,
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

`eval(...)` always tracks pass/fail counts. Score statistics are available when
you use `expectAsync(...)`, because async judge matchers produce numeric scores.

Typical verbose output looks like this:

```text
=== Eval Results ===

By Model:
  ExampleClaudeService claude-sonnet-4-5-20250929:
    Pass Rate: 83% (5/6)
    Score: mean=0.81, std=0.06, min=0.74, max=0.88
    Percentiles: p50=0.81, p90=0.87, p95=0.88

Overall:
  Pass Rate: 83% (10/12)
```

You can also work with the statistics types directly:

```dart
final scores = [0.85, 0.72, 0.91, 0.68, 0.79];

final stats = EvalStatistics.compute(
  scores,
  passed: scores.where((s) => s >= 0.7).length,
  failed: scores.where((s) => s < 0.7).length,
);

print(stats.format(verbose: true));
```

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

`evalCompare(...)` is for comparing generation strategies. The `apiServices`
parameter lists the models that generate outputs. The matchers are the judges.

If the matchers need an LLM service, pass an explicit judge service when you
construct them:

```dart
final judgeService = ExampleClaudeService(
  defaultModel: ExampleClaudeModel.sonnet45,
  apiKey: apiKey,
);

await evalCompare(
  'Compare prompt strategies',
  variants: {
    'concise': (service) => service.sendRequest('Be brief: $question'),
    'detailed': (service) =>
        service.sendRequest('Explain thoroughly: $question'),
  },
  apiServices: [claudeService, gptService],
  matchers: [
    answersQuestion(question, apiService: judgeService),
    isNotToxic(apiService: judgeService),
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
