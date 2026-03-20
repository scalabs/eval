# Eval

A powerful LLM evaluation library written in pure Dart. Test your AI outputs with flexible matchers, statistical analysis, and comprehensive RAG evaluation metrics.

## Features

- **Intuitive Test Syntax** - Familiar `expect()` API that integrates with Dart's test framework
- **LLM-as-Judge** - Use AI models to evaluate semantic similarity, faithfulness, and more
- **RAG Evaluation** - Complete suite for evaluating retrieval-augmented generation pipelines
- **Statistical Analysis** - Compute mean, std dev, percentiles, and statistical significance
- **A/B Testing** - Compare prompt variants with Welch's t-test for significance
- **Rich Matchers** - String patterns, JSON schemas, frontmatter validation, and more

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  eval:
    path: ../eval  # or your package location
```

## Quick Start

```dart
import 'package:eval/eval.dart';
import 'package:test/test.dart';

void main() {
  test('LLM generates accurate response', () async {
    final response = await myLlm.generate('What is the capital of France?');

    // Simple string matching
    expect(response, containsIgnoreCase('paris'));

    // LLM-as-judge for semantic evaluation
    await expectAsync(response, semanticallySimilarTo(
      'Paris is the capital of France',
      threshold: 0.8,
    ));
  });
}
```

## Matchers

### String Matchers

```dart
expect(text, containsIgnoreCase('hello'));
expect(text, matchesPattern(r'\d{3}-\d{4}'));
expect(text, containsAllWords(['important', 'keywords']));
expect(text, wordCountBetween(50, 100));
expect(text, sentenceCountBetween(3, 5));
```

### JSON Matchers

```dart
expect(jsonString, isValidJson);
expect(jsonString, isJsonObject);
expect(jsonString, hasJsonPath('user.address.city'));
expect(jsonString, hasJsonPathValue('status', 'active'));
```

### Schema Validation

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
```

### Frontmatter Matchers

For markdown files with YAML frontmatter:

```dart
expect(markdown, hasValidFrontmatter);
expect(markdown, hasFrontmatterKey('title'));
expect(markdown, hasFrontmatterValue('draft', false));
expect(markdown, frontmatterMatchesSchema({
  'type': 'object',
  'required': ['title', 'date'],
  'properties': {
    'title': {'type': 'string'},
    'tags': {'type': 'array', 'items': {'type': 'string'}},
  },
}));
```

### Distance Matchers

```dart
expect(text, editDistanceLessThan('expected', 3));
expect(text, editDistanceRatio('expected', maxRatio: 0.2));
expect(text, jaroWinklerSimilarityScore('expected', minScore: 0.9));
```

## LLM-as-Judge Matchers

These matchers use an LLM to evaluate responses. Configure your API service first:

```dart
// Set up your LLM service globally
llmMatcherService = MyClaudeService(apiKey: 'your-key');

test('response is semantically correct', () async {
  final response = await myLlm.generate(prompt);

  await expectAsync(response, semanticallySimilarTo(
    'The expected meaning of the response',
    threshold: 0.8,
  ));

  await expectAsync(response, answersQuestion(
    'What is machine learning?',
    threshold: 0.7,
  ));

  await expectAsync(response, isFaithfulTo(
    sourceDocument,
    threshold: 0.9,
  ));

  await expectAsync(response, isNotToxic());
  await expectAsync(response, isNotBiased());
});
```

## RAG Evaluation

Complete toolkit for evaluating retrieval-augmented generation pipelines:

### Individual Metrics

```dart
final answer = await ragPipeline.generate(query, contexts);

// Context quality
await expectAsync(answer, contextPrecision(
  contexts: retrievedDocs,
  query: 'What causes climate change?',
  threshold: 0.7,
));

await expectAsync(answer, contextRecall(
  contexts: retrievedDocs,
  groundTruth: 'Human activities, primarily burning fossil fuels...',
  threshold: 0.7,
));

// Answer quality
await expectAsync(answer, answerGroundedness(
  contexts: retrievedDocs,
  threshold: 0.8,  // Detect hallucinations
));

await expectAsync(answer, answerRelevancy(
  query: 'What causes climate change?',
  threshold: 0.7,
));

await expectAsync(answer, answerCorrectness(
  groundTruth: 'The expected factual answer',
  threshold: 0.8,
));
```

### Combined RAG Score

```dart
// Simple combined score
await expectAsync(answer, ragScore(
  contexts: retrievedDocs,
  query: query,
  groundTruth: expectedAnswer,
  threshold: 0.75,
));

// With custom weights (prioritize groundedness)
await expectAsync(answer, ragScore(
  contexts: retrievedDocs,
  query: query,
  groundTruth: expectedAnswer,
  weights: {
    'groundedness': 2.0,  // Double weight
    'precision': 1.0,
    'recall': 1.0,
    'relevancy': 1.0,
  },
));
```

### Detailed RAG Results

Get full breakdown of all metrics:

```dart
final result = await evaluateRag(
  answer: generatedAnswer,
  contexts: retrievedDocs,
  query: 'What is quantum computing?',
  groundTruth: 'Quantum computing uses quantum mechanics...',
  apiService: myService,
);

print('Overall: ${result.score}');
print('Precision: ${result.contextPrecision}');
print('Recall: ${result.contextRecall}');
print('Groundedness: ${result.answerGroundedness}');
print('Relevancy: ${result.answerRelevancy}');
```

## Statistical Analysis

### Basic Statistics

```dart
final scores = [0.85, 0.72, 0.91, 0.68, 0.79];

final stats = EvalStatistics.compute(
  scores,
  passed: scores.where((s) => s >= 0.7).length,
  failed: scores.where((s) => s < 0.7).length,
);

print(stats.format());
// Mean: 0.79 | Std: 0.09 | P50: 0.79 | P90: 0.89 | Pass: 80%
```

### Aggregate Statistics

```dart
final aggregate = AggregateStatistics.fromTestRuns({
  'test with claude-3-opus 1': stats1,
  'test with claude-3-opus 2': stats2,
  'test with gpt-4 1': stats3,
});

print(aggregate.format(verbose: true));
// Shows breakdown by model and by test run
```

## A/B Testing with Statistical Significance

Compare prompt variants across multiple models and runs:

```dart
evalCompare(
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
  passThreshold: 0.7,  // Custom pass threshold
);
```

This will:
- Run each variant with each model multiple times
- Compute statistics for each combination
- Determine the winner using mean scores
- Calculate p-value using Welch's t-test for statistical significance

## API Reference

### Core Functions

| Function | Description |
|----------|-------------|
| `expect(actual, matcher)` | Synchronous assertion |
| `expectAsync(actual, matcher)` | Async assertion for LLM matchers |
| `eval(description, fn)` | Named eval block for organization |
| `evalCompare(...)` | A/B testing with statistics |
| `evaluateRag(...)` | Detailed RAG evaluation |

### Matcher Categories

| Category | Matchers |
|----------|----------|
| **String** | `containsIgnoreCase`, `matchesPattern`, `containsAllWords`, `wordCountBetween` |
| **JSON** | `isValidJson`, `isJsonObject`, `hasJsonPath`, `hasJsonPathValue` |
| **Schema** | `matchesSchema`, `hasRequiredFields`, `fieldOneOf`, `fieldHasType` |
| **Frontmatter** | `hasValidFrontmatter`, `frontmatterMatchesSchema`, `hasFrontmatterKey` |
| **Story** | `hasValidStoryStructure`, `storySchema` |
| **Distance** | `levenshteinDistance`, `editDistanceRatio`, `jaroWinklerSimilarityScore` |
| **LLM** | `semanticallySimilarTo`, `answersQuestion`, `isFaithfulTo`, `isNotToxic` |
| **RAG** | `contextPrecision`, `contextRecall`, `answerGroundedness`, `answerRelevancy`, `ragScore` |

### Statistics Classes

| Class | Description |
|-------|-------------|
| `EvalStatistics` | Single evaluation run statistics |
| `AggregateStatistics` | Multi-run statistics with model grouping |
| `CompareResult` | A/B test results with significance testing |
| `RagEvalResult` | Detailed RAG metric breakdown |

## Implementing Your Own API Service

```dart
class MyLlmService extends APICallService<MyModelEnum> {
  MyLlmService({required this.apiKey});

  final String apiKey;

  @override
  Future<String> sendRequest(
    String prompt, {
    String? systemPrompt,
    MyModelEnum? model,
  }) async {
    // Your API call implementation
    final response = await http.post(
      Uri.parse('https://api.example.com/v1/chat'),
      headers: {'Authorization': 'Bearer $apiKey'},
      body: jsonEncode({
        'model': model?.name ?? 'default-model',
        'messages': [
          if (systemPrompt != null) {'role': 'system', 'content': systemPrompt},
          {'role': 'user', 'content': prompt},
        ],
      }),
    );
    return jsonDecode(response.body)['content'];
  }

  @override
  String get name => 'MyLLM';
}
```

## Running Tests

```bash
cd eval
dart test
```

## License

MIT
