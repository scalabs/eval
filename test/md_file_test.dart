import 'package:eval/src/md_file.dart';
import 'package:test/test.dart';

void main() {
  group('parseMarkdownBody', () {
    test('parses frontmatter and body', () {
      const input = '''---
title: Hello World
author: John Doe
---

This is the content.
''';

      final result = parseMarkdownBody(input);

      expect(result.title, equals('Hello World'));
      expect(result.frontmatter['title'], equals('Hello World'));
      expect(result.frontmatter['author'], equals('John Doe'));
      expect(result.body, equals('This is the content.'));
    });

    test('handles missing title in frontmatter', () {
      const input = '''---
author: Jane Doe
tags:
  - one
  - two
---

Content here.
''';

      final result = parseMarkdownBody(input);

      expect(result.title, equals(''));
      expect(result.frontmatter['author'], equals('Jane Doe'));
      expect(result.frontmatter['tags'], equals(['one', 'two']));
      expect(result.body, equals('Content here.'));
    });

    test('returns empty frontmatter when no frontmatter present', () {
      const input = '''# Just Markdown

No frontmatter here.
''';

      final result = parseMarkdownBody(input);

      expect(result.title, equals(''));
      expect(result.frontmatter, isEmpty);
      expect(result.body, equals(input));
    });

    test('handles malformed frontmatter (no closing ---)', () {
      const input = '''---
title: Broken

This never closes properly.
''';

      final result = parseMarkdownBody(input);

      expect(result.title, equals(''));
      expect(result.frontmatter, isEmpty);
      expect(result.body, equals(input));
    });

    test('handles empty body after frontmatter', () {
      const input = '''---
title: Title Only
---
''';

      final result = parseMarkdownBody(input);

      expect(result.title, equals('Title Only'));
      expect(result.body, equals(''));
    });

    test('handles complex yaml in frontmatter', () {
      const input = '''---
title: Complex Example
metadata:
  version: 1.0
  enabled: true
  count: 42
tags:
  - dart
  - eval
---

Body content.
''';

      final result = parseMarkdownBody(input);

      expect(result.title, equals('Complex Example'));
      expect(result.frontmatter['metadata']['version'], equals(1.0));
      expect(result.frontmatter['metadata']['enabled'], equals(true));
      expect(result.frontmatter['metadata']['count'], equals(42));
      expect(result.frontmatter['tags'], equals(['dart', 'eval']));
      expect(result.body, equals('Body content.'));
    });

    test('preserves markdown formatting in body', () {
      const input = '''---
title: Formatted
---

# Heading

This is **bold** and *italic*.

- List item 1
- List item 2

```dart
void main() {}
```
''';

      final result = parseMarkdownBody(input);

      expect(result.title, equals('Formatted'));
      expect(result.body, contains('# Heading'));
      expect(result.body, contains('**bold**'));
      expect(result.body, contains('```dart'));
    });

    test('handles empty input', () {
      const input = '';

      final result = parseMarkdownBody(input);

      expect(result.title, equals(''));
      expect(result.frontmatter, isEmpty);
      expect(result.body, equals(''));
    });

    test('handles frontmatter with only dashes', () {
      const input = '''---
---

Just body.
''';

      final result = parseMarkdownBody(input);

      expect(result.title, equals(''));
      expect(result.frontmatter, isEmpty);
      expect(result.body, equals('Just body.'));
    });
  });
}
