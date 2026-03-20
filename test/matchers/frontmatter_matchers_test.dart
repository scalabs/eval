import 'package:eval/src/matchers/frontmatter_matchers.dart';
import 'package:test/test.dart';

void main() {
  const validMarkdown = '''---
title: Hello World
author: John Doe
tags:
  - dart
  - eval
count: 42
---

# Content

This is the body.
''';

  const noFrontmatter = '''# Just Markdown

No frontmatter here.
''';

  const emptyBody = '''---
title: Title Only
---
''';

  group('hasValidFrontmatter', () {
    test('matches valid frontmatter', () {
      expect(validMarkdown, hasValidFrontmatter);
    });

    test('matches frontmatter with empty body', () {
      expect(emptyBody, hasValidFrontmatter);
    });

    test('does not match content without frontmatter', () {
      expect(noFrontmatter, isNot(hasValidFrontmatter));
    });

    test('does not match non-string', () {
      expect(123, isNot(hasValidFrontmatter));
    });

    test('does not match malformed frontmatter', () {
      const malformed = '''---
title: Broken
No closing delimiter
''';
      expect(malformed, isNot(hasValidFrontmatter));
    });
  });

  group('hasFrontmatterTitle', () {
    test('matches when title is present', () {
      expect(validMarkdown, hasFrontmatterTitle);
    });

    test('does not match when title is missing', () {
      const noTitle = '''---
author: Jane
---

Body.
''';
      expect(noTitle, isNot(hasFrontmatterTitle));
    });

    test('does not match when no frontmatter', () {
      expect(noFrontmatter, isNot(hasFrontmatterTitle));
    });
  });

  group('hasFrontmatterKey', () {
    test('matches when key exists', () {
      expect(validMarkdown, hasFrontmatterKey('title'));
      expect(validMarkdown, hasFrontmatterKey('author'));
      expect(validMarkdown, hasFrontmatterKey('tags'));
      expect(validMarkdown, hasFrontmatterKey('count'));
    });

    test('does not match when key is missing', () {
      expect(validMarkdown, isNot(hasFrontmatterKey('missing')));
    });

    test('does not match when no frontmatter', () {
      expect(noFrontmatter, isNot(hasFrontmatterKey('title')));
    });
  });

  group('hasFrontmatterValue', () {
    test('matches when key has expected value', () {
      expect(validMarkdown, hasFrontmatterValue('title', 'Hello World'));
      expect(validMarkdown, hasFrontmatterValue('author', 'John Doe'));
      expect(validMarkdown, hasFrontmatterValue('count', 42));
    });

    test('does not match when value differs', () {
      expect(validMarkdown, isNot(hasFrontmatterValue('title', 'Wrong Title')));
      expect(validMarkdown, isNot(hasFrontmatterValue('count', 100)));
    });

    test('does not match when key is missing', () {
      expect(validMarkdown, isNot(hasFrontmatterValue('missing', 'value')));
    });

    test('matches list values with frontmatterKeyMatches', () {
      // YAML lists are YamlList, not regular List, so use matcher
      expect(
        validMarkdown,
        frontmatterKeyMatches('tags', containsAll(['dart', 'eval'])),
      );
    });
  });

  group('frontmatterKeyMatches', () {
    test('matches with contains matcher on list', () {
      expect(validMarkdown, frontmatterKeyMatches('tags', contains('dart')));
      expect(validMarkdown, frontmatterKeyMatches('tags', contains('eval')));
    });

    test('matches with numeric matchers', () {
      expect(validMarkdown, frontmatterKeyMatches('count', greaterThan(40)));
      expect(validMarkdown, frontmatterKeyMatches('count', lessThan(50)));
    });

    test('matches with string matchers', () {
      expect(validMarkdown, frontmatterKeyMatches('title', contains('Hello')));
      expect(
        validMarkdown,
        frontmatterKeyMatches('author', startsWith('John')),
      );
    });

    test('does not match when matcher fails', () {
      expect(
        validMarkdown,
        isNot(frontmatterKeyMatches('count', greaterThan(100))),
      );
    });

    test('does not match when key is missing', () {
      expect(validMarkdown, isNot(frontmatterKeyMatches('missing', anything)));
    });
  });

  group('hasMarkdownBody', () {
    test('matches when body is present', () {
      expect(validMarkdown, hasMarkdownBody);
    });

    test('does not match when body is empty', () {
      expect(emptyBody, isNot(hasMarkdownBody));
    });

    test('does not match when no frontmatter', () {
      expect(noFrontmatter, isNot(hasMarkdownBody));
    });
  });

  group('bodyContains', () {
    test('matches when body contains text', () {
      expect(validMarkdown, bodyContains('Content'));
      expect(validMarkdown, bodyContains('This is the body'));
      expect(validMarkdown, bodyContains('#'));
    });

    test('does not match when text is in frontmatter only', () {
      expect(validMarkdown, isNot(bodyContains('Hello World')));
      expect(validMarkdown, isNot(bodyContains('John Doe')));
    });

    test('does not match when text is not present', () {
      expect(validMarkdown, isNot(bodyContains('nonexistent')));
    });
  });

  group('bodyMatches', () {
    test('matches with contains matcher', () {
      expect(validMarkdown, bodyMatches(contains('Content')));
    });

    test('matches with hasLength matcher', () {
      expect(validMarkdown, bodyMatches(hasLength(greaterThan(10))));
    });

    test('matches with startsWith matcher', () {
      expect(validMarkdown, bodyMatches(startsWith('#')));
    });

    test('does not match when matcher fails', () {
      expect(validMarkdown, isNot(bodyMatches(isEmpty)));
    });
  });

  group('edge cases', () {
    test('handles nested yaml structures', () {
      const nested = '''---
title: Nested
metadata:
  version: 1.0
  settings:
    enabled: true
---

Body.
''';
      expect(nested, hasValidFrontmatter);
      expect(nested, hasFrontmatterKey('metadata'));
      expect(
        nested,
        frontmatterKeyMatches('metadata', containsPair('version', 1.0)),
      );
    });

    test('handles boolean values', () {
      const withBool = '''---
draft: true
published: false
---

Body.
''';
      expect(withBool, hasFrontmatterValue('draft', true));
      expect(withBool, hasFrontmatterValue('published', false));
    });

    test('handles null values', () {
      const withNull = '''---
title: Test
description: null
---

Body.
''';
      // YAML 'null' literal becomes null
      expect(withNull, hasFrontmatterKey('description'));
    });

    test('handles multiline body content', () {
      const multiline = '''---
title: Test
---

# Heading 1

Paragraph one.

## Heading 2

Paragraph two.

```dart
void main() {}
```
''';
      expect(multiline, hasMarkdownBody);
      expect(multiline, bodyContains('# Heading 1'));
      expect(multiline, bodyContains('```dart'));
      expect(multiline, bodyContains('Paragraph two'));
    });

    test('non-string input fails gracefully', () {
      expect(123, isNot(hasValidFrontmatter));
      expect(null, isNot(hasFrontmatterTitle));
      expect(['list'], isNot(hasFrontmatterKey('key')));
      expect({'map': 'value'}, isNot(bodyContains('text')));
    });
  });

  group('describeMismatch messages', () {
    test('hasValidFrontmatter describes non-string input', () {
      final matcher = hasValidFrontmatter;
      final description = StringDescription();
      matcher.describeMismatch(123, description, {}, false);
      expect(description.toString(), equals('is not a String'));
    });

    test('hasValidFrontmatter describes missing delimiter', () {
      final matcher = hasValidFrontmatter;
      final description = StringDescription();
      matcher.describeMismatch('no frontmatter', description, {}, false);
      expect(
        description.toString(),
        equals('does not start with frontmatter delimiter'),
      );
    });

    test('hasValidFrontmatter describes parse failure', () {
      final matcher = hasValidFrontmatter;
      final description = StringDescription();
      // Starts with --- but has invalid YAML
      matcher.describeMismatch('---\n: invalid\n', description, {}, false);
      expect(description.toString(), equals('failed to parse frontmatter'));
    });

    test('hasFrontmatterTitle describes non-string input', () {
      final matcher = hasFrontmatterTitle;
      final description = StringDescription();
      matcher.describeMismatch(42, description, {}, false);
      expect(description.toString(), equals('is not a String'));
    });

    test('hasFrontmatterTitle describes parse failure', () {
      final matcher = hasFrontmatterTitle;
      final description = StringDescription();
      matcher.describeMismatch('no frontmatter', description, {}, false);
      expect(description.toString(), equals('failed to parse frontmatter'));
    });

    test('hasFrontmatterTitle describes missing title', () {
      final matcher = hasFrontmatterTitle;
      final description = StringDescription();
      const noTitle = '''---
author: Jane
---

Body.
''';
      matcher.describeMismatch(noTitle, description, {}, false);
      expect(description.toString(), equals('title is empty or missing'));
    });

    test('hasFrontmatterKey describes non-string input', () {
      final matcher = hasFrontmatterKey('key');
      final description = StringDescription();
      matcher.describeMismatch(null, description, {}, false);
      expect(description.toString(), equals('is not a String'));
    });

    test('hasFrontmatterKey describes available keys', () {
      final matcher = hasFrontmatterKey('missing');
      final description = StringDescription();
      const md = '''---
title: Test
author: Jane
---

Body.
''';
      matcher.describeMismatch(md, description, {}, false);
      expect(
        description.toString(),
        equals('frontmatter keys are: [title, author]'),
      );
    });

    test('hasFrontmatterValue describes non-string input', () {
      final matcher = hasFrontmatterValue('key', 'value');
      final description = StringDescription();
      matcher.describeMismatch(['list'], description, {}, false);
      expect(description.toString(), equals('is not a String'));
    });

    test('hasFrontmatterValue describes key not found', () {
      final matcher = hasFrontmatterValue('missing', 'value');
      final description = StringDescription();
      const md = '''---
title: Test
---

Body.
''';
      matcher.describeMismatch(md, description, {}, false);
      expect(
        description.toString(),
        equals('key "missing" not found in frontmatter'),
      );
    });

    test('hasFrontmatterValue describes value mismatch', () {
      final matcher = hasFrontmatterValue('title', 'Expected');
      final description = StringDescription();
      const md = '''---
title: Actual
---

Body.
''';
      matcher.describeMismatch(md, description, {}, false);
      expect(
        description.toString(),
        equals('has value Actual for key "title"'),
      );
    });

    test('frontmatterKeyMatches describes non-string input', () {
      final matcher = frontmatterKeyMatches('key', equals('value'));
      final description = StringDescription();
      matcher.describeMismatch({'map': true}, description, {}, false);
      expect(description.toString(), equals('is not a String'));
    });

    test('frontmatterKeyMatches describes key not found', () {
      final matcher = frontmatterKeyMatches('missing', anything);
      final description = StringDescription();
      const md = '''---
title: Test
---

Body.
''';
      matcher.describeMismatch(md, description, {}, false);
      expect(
        description.toString(),
        equals('key "missing" not found in frontmatter'),
      );
    });

    test('frontmatterKeyMatches describes matcher failure', () {
      final matcher = frontmatterKeyMatches('count', greaterThan(100));
      final description = StringDescription();
      const md = '''---
count: 50
---

Body.
''';
      matcher.describeMismatch(md, description, {}, false);
      expect(description.toString(), contains('value 50'));
    });

    test('hasMarkdownBody describes non-string input', () {
      final matcher = hasMarkdownBody;
      final description = StringDescription();
      matcher.describeMismatch(123, description, {}, false);
      expect(description.toString(), equals('is not a String'));
    });

    test('hasMarkdownBody describes parse failure', () {
      final matcher = hasMarkdownBody;
      final description = StringDescription();
      matcher.describeMismatch('no frontmatter', description, {}, false);
      expect(description.toString(), equals('failed to parse frontmatter'));
    });

    test('hasMarkdownBody describes empty body', () {
      final matcher = hasMarkdownBody;
      final description = StringDescription();
      const emptyBody = '''---
title: Test
---
''';
      matcher.describeMismatch(emptyBody, description, {}, false);
      expect(description.toString(), equals('body is empty'));
    });

    test('bodyContains describes non-string input', () {
      final matcher = bodyContains('text');
      final description = StringDescription();
      matcher.describeMismatch(999, description, {}, false);
      expect(description.toString(), equals('is not a String'));
    });

    test('bodyContains describes parse failure', () {
      final matcher = bodyContains('text');
      final description = StringDescription();
      matcher.describeMismatch('no frontmatter', description, {}, false);
      expect(description.toString(), equals('failed to parse frontmatter'));
    });

    test('bodyContains describes missing text', () {
      final matcher = bodyContains('missing');
      final description = StringDescription();
      const md = '''---
title: Test
---

Some body content.
''';
      matcher.describeMismatch(md, description, {}, false);
      expect(description.toString(), equals('body does not contain "missing"'));
    });

    test('bodyMatches describes non-string input', () {
      final matcher = bodyMatches(contains('text'));
      final description = StringDescription();
      matcher.describeMismatch(true, description, {}, false);
      expect(description.toString(), equals('is not a String'));
    });

    test('bodyMatches describes parse failure', () {
      final matcher = bodyMatches(contains('text'));
      final description = StringDescription();
      matcher.describeMismatch('no frontmatter', description, {}, false);
      expect(description.toString(), equals('failed to parse frontmatter'));
    });

    test('bodyMatches describes inner matcher failure', () {
      final matcher = bodyMatches(isEmpty);
      final description = StringDescription();
      const md = '''---
title: Test
---

Some content.
''';
      matcher.describeMismatch(md, description, {}, false);
      expect(description.toString(), contains('body'));
    });

    test('describe methods return expected descriptions', () {
      expect(
        hasValidFrontmatter.describe(StringDescription()).toString(),
        equals('has valid frontmatter'),
      );
      expect(
        hasFrontmatterTitle.describe(StringDescription()).toString(),
        equals('has frontmatter title'),
      );
      expect(
        hasFrontmatterKey('myKey').describe(StringDescription()).toString(),
        equals('has frontmatter key "myKey"'),
      );
      expect(
        hasFrontmatterValue(
          'key',
          'val',
        ).describe(StringDescription()).toString(),
        equals('has frontmatter "key" with value val'),
      );
      expect(
        hasMarkdownBody.describe(StringDescription()).toString(),
        equals('has markdown body'),
      );
      expect(
        bodyContains('text').describe(StringDescription()).toString(),
        equals('body contains "text"'),
      );
    });
  });
}
