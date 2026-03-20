import 'package:eval/src/matchers/frontmatter_schema_matchers.dart';
import 'package:test/test.dart';

void main() {
  const validMarkdown = '''---
title: Hello World
author: John Doe
tags:
  - dart
  - eval
count: 42
status: published
---

# Content

This is the body.
''';

  const noFrontmatter = '''# Just Markdown

No frontmatter here.
''';

  group('frontmatterMatchesSchema', () {
    test('matches valid schema with type object', () {
      expect(validMarkdown, frontmatterMatchesSchema({'type': 'object'}));
    });

    test('matches schema with required fields', () {
      expect(
        validMarkdown,
        frontmatterMatchesSchema({
          'type': 'object',
          'required': ['title', 'author'],
        }),
      );
    });

    test('does not match when required field is missing', () {
      expect(
        validMarkdown,
        isNot(
          frontmatterMatchesSchema({
            'type': 'object',
            'required': ['title', 'missing_field'],
          }),
        ),
      );
    });

    test('matches schema with properties', () {
      expect(
        validMarkdown,
        frontmatterMatchesSchema({
          'type': 'object',
          'properties': {
            'title': {'type': 'string'},
            'count': {'type': 'integer'},
          },
        }),
      );
    });

    test('does not match when property type is wrong', () {
      expect(
        validMarkdown,
        isNot(
          frontmatterMatchesSchema({
            'type': 'object',
            'properties': {
              'title': {'type': 'integer'}, // title is a string
            },
          }),
        ),
      );
    });

    test('matches schema with string constraints', () {
      expect(
        validMarkdown,
        frontmatterMatchesSchema({
          'type': 'object',
          'properties': {
            'title': {'type': 'string', 'minLength': 1, 'maxLength': 50},
          },
        }),
      );
    });

    test('does not match when string is too short', () {
      const shortTitle = '''---
title: A
---

Body.
''';
      expect(
        shortTitle,
        isNot(
          frontmatterMatchesSchema({
            'type': 'object',
            'properties': {
              'title': {'type': 'string', 'minLength': 5},
            },
          }),
        ),
      );
    });

    test('does not match when string is too long', () {
      expect(
        validMarkdown,
        isNot(
          frontmatterMatchesSchema({
            'type': 'object',
            'properties': {
              'title': {'type': 'string', 'maxLength': 5},
            },
          }),
        ),
      );
    });

    test('matches schema with number constraints', () {
      expect(
        validMarkdown,
        frontmatterMatchesSchema({
          'type': 'object',
          'properties': {
            'count': {'type': 'integer', 'minimum': 0, 'maximum': 100},
          },
        }),
      );
    });

    test('does not match when number is below minimum', () {
      expect(
        validMarkdown,
        isNot(
          frontmatterMatchesSchema({
            'type': 'object',
            'properties': {
              'count': {'type': 'integer', 'minimum': 50},
            },
          }),
        ),
      );
    });

    test('does not match when number is above maximum', () {
      expect(
        validMarkdown,
        isNot(
          frontmatterMatchesSchema({
            'type': 'object',
            'properties': {
              'count': {'type': 'integer', 'maximum': 10},
            },
          }),
        ),
      );
    });

    test('matches schema with array constraints', () {
      expect(
        validMarkdown,
        frontmatterMatchesSchema({
          'type': 'object',
          'properties': {
            'tags': {'type': 'array', 'minItems': 1, 'maxItems': 5},
          },
        }),
      );
    });

    test('does not match when array has too few items', () {
      expect(
        validMarkdown,
        isNot(
          frontmatterMatchesSchema({
            'type': 'object',
            'properties': {
              'tags': {'type': 'array', 'minItems': 5},
            },
          }),
        ),
      );
    });

    test('does not match when array has too many items', () {
      expect(
        validMarkdown,
        isNot(
          frontmatterMatchesSchema({
            'type': 'object',
            'properties': {
              'tags': {'type': 'array', 'maxItems': 1},
            },
          }),
        ),
      );
    });

    test('matches schema with array items validation', () {
      expect(
        validMarkdown,
        frontmatterMatchesSchema({
          'type': 'object',
          'properties': {
            'tags': {
              'type': 'array',
              'items': {'type': 'string'},
            },
          },
        }),
      );
    });

    test('does not match when array items have wrong type', () {
      const mixedTags = '''---
tags:
  - dart
  - 123
---

Body.
''';
      expect(
        mixedTags,
        isNot(
          frontmatterMatchesSchema({
            'type': 'object',
            'properties': {
              'tags': {
                'type': 'array',
                'items': {'type': 'string'},
              },
            },
          }),
        ),
      );
    });

    test('matches schema with enum constraint', () {
      expect(
        validMarkdown,
        frontmatterMatchesSchema({
          'type': 'object',
          'properties': {
            'status': {
              'type': 'string',
              'enum': ['draft', 'published', 'archived'],
            },
          },
        }),
      );
    });

    test('does not match when value not in enum', () {
      expect(
        validMarkdown,
        isNot(
          frontmatterMatchesSchema({
            'type': 'object',
            'properties': {
              'status': {
                'type': 'string',
                'enum': ['draft', 'archived'],
              },
            },
          }),
        ),
      );
    });

    test('does not match non-string input', () {
      expect(123, isNot(frontmatterMatchesSchema({'type': 'object'})));
    });

    test('does not match when no frontmatter', () {
      expect(
        noFrontmatter,
        isNot(frontmatterMatchesSchema({'type': 'object'})),
      );
    });

    test('handles nested objects', () {
      const nested = '''---
metadata:
  version: 1.0
  settings:
    enabled: true
---

Body.
''';
      expect(
        nested,
        frontmatterMatchesSchema({
          'type': 'object',
          'properties': {
            'metadata': {
              'type': 'object',
              'properties': {
                'version': {'type': 'number'},
                'settings': {
                  'type': 'object',
                  'properties': {
                    'enabled': {'type': 'boolean'},
                  },
                },
              },
            },
          },
        }),
      );
    });

    test('handles boolean type', () {
      const withBool = '''---
draft: true
---

Body.
''';
      expect(
        withBool,
        frontmatterMatchesSchema({
          'type': 'object',
          'properties': {
            'draft': {'type': 'boolean'},
          },
        }),
      );
    });

    test('handles null type', () {
      const withNull = '''---
description: null
---

Body.
''';
      expect(
        withNull,
        frontmatterMatchesSchema({
          'type': 'object',
          'properties': {
            'description': {'type': 'null'},
          },
        }),
      );
    });
  });

  group('frontmatterHasRequiredFields', () {
    test('matches when all fields present with correct types', () {
      expect(
        validMarkdown,
        frontmatterHasRequiredFields({'title': String, 'count': int}),
      );
    });

    test('matches with different type combinations', () {
      const withTypes = '''---
name: Test
age: 25
score: 3.14
active: true
tags:
  - a
  - b
metadata:
  key: value
---

Body.
''';
      expect(
        withTypes,
        frontmatterHasRequiredFields({
          'name': String,
          'age': int,
          'score': num,
          'active': bool,
          'tags': List,
          'metadata': Map,
        }),
      );
    });

    test('does not match when field is missing', () {
      expect(
        validMarkdown,
        isNot(
          frontmatterHasRequiredFields({'title': String, 'missing': String}),
        ),
      );
    });

    test('does not match when field has wrong type', () {
      expect(
        validMarkdown,
        isNot(
          frontmatterHasRequiredFields({
            'title': int, // title is String
          }),
        ),
      );
    });

    test('does not match non-string input', () {
      expect(123, isNot(frontmatterHasRequiredFields({'title': String})));
    });

    test('does not match when no frontmatter', () {
      expect(
        noFrontmatter,
        isNot(frontmatterHasRequiredFields({'title': String})),
      );
    });
  });

  group('frontmatterArrayLengthBetween', () {
    test('matches when array length is within bounds', () {
      expect(validMarkdown, frontmatterArrayLengthBetween('tags', 1, 5));
      expect(validMarkdown, frontmatterArrayLengthBetween('tags', 2, 2));
    });

    test('does not match when array is too short', () {
      expect(
        validMarkdown,
        isNot(frontmatterArrayLengthBetween('tags', 5, 10)),
      );
    });

    test('does not match when array is too long', () {
      expect(validMarkdown, isNot(frontmatterArrayLengthBetween('tags', 0, 1)));
    });

    test('does not match when key is missing', () {
      expect(
        validMarkdown,
        isNot(frontmatterArrayLengthBetween('missing', 0, 10)),
      );
    });

    test('does not match when value is not an array', () {
      expect(
        validMarkdown,
        isNot(frontmatterArrayLengthBetween('title', 0, 10)),
      );
    });

    test('does not match non-string input', () {
      expect(123, isNot(frontmatterArrayLengthBetween('tags', 0, 10)));
    });

    test('does not match when no frontmatter', () {
      expect(
        noFrontmatter,
        isNot(frontmatterArrayLengthBetween('tags', 0, 10)),
      );
    });
  });

  group('frontmatterFieldOneOf', () {
    test('matches when value is in allowed values', () {
      expect(
        validMarkdown,
        frontmatterFieldOneOf('status', ['draft', 'published', 'archived']),
      );
    });

    test('does not match when value is not in allowed values', () {
      expect(
        validMarkdown,
        isNot(frontmatterFieldOneOf('status', ['draft', 'archived'])),
      );
    });

    test('does not match when key is missing', () {
      expect(
        validMarkdown,
        isNot(frontmatterFieldOneOf('missing', ['a', 'b'])),
      );
    });

    test('matches missing key when null is allowed', () {
      expect(validMarkdown, frontmatterFieldOneOf('missing', ['a', 'b', null]));
    });

    test('matches different value types', () {
      expect(validMarkdown, frontmatterFieldOneOf('count', [40, 41, 42, 43]));
    });

    test('does not match non-string input', () {
      expect(123, isNot(frontmatterFieldOneOf('status', ['draft'])));
    });

    test('does not match when no frontmatter', () {
      expect(noFrontmatter, isNot(frontmatterFieldOneOf('status', ['draft'])));
    });
  });

  group('frontmatterFieldHasType', () {
    test('matches when field has correct type - String', () {
      expect(validMarkdown, frontmatterFieldHasType('title', String));
    });

    test('matches when field has correct type - int', () {
      expect(validMarkdown, frontmatterFieldHasType('count', int));
    });

    test('matches when field has correct type - num', () {
      expect(validMarkdown, frontmatterFieldHasType('count', num));
    });

    test('matches when field has correct type - bool', () {
      const withBool = '''---
active: true
---

Body.
''';
      expect(withBool, frontmatterFieldHasType('active', bool));
    });

    test('matches when field has correct type - List', () {
      expect(validMarkdown, frontmatterFieldHasType('tags', List));
    });

    test('matches when field has correct type - Map', () {
      const nested = '''---
metadata:
  key: value
---

Body.
''';
      expect(nested, frontmatterFieldHasType('metadata', Map));
    });

    test('does not match when field has wrong type', () {
      expect(validMarkdown, isNot(frontmatterFieldHasType('title', int)));
      expect(validMarkdown, isNot(frontmatterFieldHasType('count', String)));
    });

    test('does not match when key is missing', () {
      expect(validMarkdown, isNot(frontmatterFieldHasType('missing', String)));
    });

    test('does not match non-string input', () {
      expect(123, isNot(frontmatterFieldHasType('title', String)));
    });

    test('does not match when no frontmatter', () {
      expect(noFrontmatter, isNot(frontmatterFieldHasType('title', String)));
    });
  });

  group('describeMismatch messages', () {
    test('frontmatterMatchesSchema describes non-string input', () {
      final matcher = frontmatterMatchesSchema({'type': 'object'});
      final matchState = <dynamic, dynamic>{};
      const item = 123;
      matcher.matches(item, matchState);
      final description = StringDescription();
      matcher.describeMismatch(item, description, matchState, false);
      expect(description.toString(), equals('Expected a String, got int'));
    });

    test('frontmatterMatchesSchema describes parse failure', () {
      final matcher = frontmatterMatchesSchema({'type': 'object'});
      final matchState = <dynamic, dynamic>{};
      const item = 'no frontmatter';
      matcher.matches(item, matchState);
      final description = StringDescription();
      matcher.describeMismatch(item, description, matchState, false);
      expect(description.toString(), equals('Failed to parse frontmatter'));
    });

    test('frontmatterMatchesSchema describes schema violations', () {
      final matcher = frontmatterMatchesSchema({
        'type': 'object',
        'required': ['missing1', 'missing2'],
      });
      final matchState = <dynamic, dynamic>{};
      matcher.matches(validMarkdown, matchState);
      final description = StringDescription();
      matcher.describeMismatch(validMarkdown, description, matchState, false);
      expect(description.toString(), contains('schema violations'));
      expect(description.toString(), contains('missing required field'));
    });

    test('frontmatterHasRequiredFields describes non-string input', () {
      final matcher = frontmatterHasRequiredFields({'title': String});
      final matchState = <dynamic, dynamic>{};
      matcher.matches(null, matchState);
      final description = StringDescription();
      matcher.describeMismatch(null, description, matchState, false);
      expect(description.toString(), equals('Expected a String, got Null'));
    });

    test('frontmatterHasRequiredFields describes parse failure', () {
      final matcher = frontmatterHasRequiredFields({'title': String});
      final matchState = <dynamic, dynamic>{};
      const item = 'no frontmatter';
      matcher.matches(item, matchState);
      final description = StringDescription();
      matcher.describeMismatch(item, description, matchState, false);
      expect(description.toString(), equals('Failed to parse frontmatter'));
    });

    test('frontmatterHasRequiredFields describes missing field', () {
      final matcher = frontmatterHasRequiredFields({'missing': String});
      final matchState = <dynamic, dynamic>{};
      matcher.matches(validMarkdown, matchState);
      final description = StringDescription();
      matcher.describeMismatch(validMarkdown, description, matchState, false);
      expect(description.toString(), contains('missing field "missing"'));
    });

    test('frontmatterHasRequiredFields describes type mismatch', () {
      final matcher = frontmatterHasRequiredFields({'title': int});
      final matchState = <dynamic, dynamic>{};
      matcher.matches(validMarkdown, matchState);
      final description = StringDescription();
      matcher.describeMismatch(validMarkdown, description, matchState, false);
      expect(description.toString(), contains('has type String'));
      expect(description.toString(), contains('expected int'));
    });

    test('frontmatterArrayLengthBetween describes non-string input', () {
      final matcher = frontmatterArrayLengthBetween('tags', 0, 10);
      final matchState = <dynamic, dynamic>{};
      final item = ['list'];
      matcher.matches(item, matchState);
      final description = StringDescription();
      matcher.describeMismatch(item, description, matchState, false);
      expect(
        description.toString(),
        equals('Expected a String, got List<String>'),
      );
    });

    test('frontmatterArrayLengthBetween describes parse failure', () {
      final matcher = frontmatterArrayLengthBetween('tags', 0, 10);
      final matchState = <dynamic, dynamic>{};
      const item = 'no frontmatter';
      matcher.matches(item, matchState);
      final description = StringDescription();
      matcher.describeMismatch(item, description, matchState, false);
      expect(description.toString(), equals('Failed to parse frontmatter'));
    });

    test('frontmatterArrayLengthBetween describes missing key', () {
      final matcher = frontmatterArrayLengthBetween('missing', 0, 10);
      final matchState = <dynamic, dynamic>{};
      matcher.matches(validMarkdown, matchState);
      final description = StringDescription();
      matcher.describeMismatch(validMarkdown, description, matchState, false);
      expect(
        description.toString(),
        equals('Key "missing" not found in frontmatter'),
      );
    });

    test('frontmatterArrayLengthBetween describes non-array value', () {
      final matcher = frontmatterArrayLengthBetween('title', 0, 10);
      final matchState = <dynamic, dynamic>{};
      matcher.matches(validMarkdown, matchState);
      final description = StringDescription();
      matcher.describeMismatch(validMarkdown, description, matchState, false);
      expect(
        description.toString(),
        equals('Value at "title" is not an array'),
      );
    });

    test('frontmatterArrayLengthBetween describes wrong length', () {
      final matcher = frontmatterArrayLengthBetween('tags', 5, 10);
      final matchState = <dynamic, dynamic>{};
      matcher.matches(validMarkdown, matchState);
      final description = StringDescription();
      matcher.describeMismatch(validMarkdown, description, matchState, false);
      expect(description.toString(), equals('has length 2'));
    });

    test('frontmatterFieldOneOf describes non-string input', () {
      final matcher = frontmatterFieldOneOf('status', ['draft']);
      final matchState = <dynamic, dynamic>{};
      const item = 42;
      matcher.matches(item, matchState);
      final description = StringDescription();
      matcher.describeMismatch(item, description, matchState, false);
      expect(description.toString(), equals('Expected a String, got int'));
    });

    test('frontmatterFieldOneOf describes parse failure', () {
      final matcher = frontmatterFieldOneOf('status', ['draft']);
      final matchState = <dynamic, dynamic>{};
      const item = 'no frontmatter';
      matcher.matches(item, matchState);
      final description = StringDescription();
      matcher.describeMismatch(item, description, matchState, false);
      expect(description.toString(), equals('Failed to parse frontmatter'));
    });

    test('frontmatterFieldOneOf describes missing key', () {
      final matcher = frontmatterFieldOneOf('missing', ['a', 'b']);
      final matchState = <dynamic, dynamic>{};
      matcher.matches(validMarkdown, matchState);
      final description = StringDescription();
      matcher.describeMismatch(validMarkdown, description, matchState, false);
      expect(
        description.toString(),
        equals('Key "missing" not found in frontmatter'),
      );
    });

    test('frontmatterFieldOneOf describes invalid value', () {
      final matcher = frontmatterFieldOneOf('status', ['draft', 'archived']);
      final matchState = <dynamic, dynamic>{};
      matcher.matches(validMarkdown, matchState);
      final description = StringDescription();
      matcher.describeMismatch(validMarkdown, description, matchState, false);
      expect(description.toString(), equals('has value published'));
    });

    test('frontmatterFieldHasType describes non-string input', () {
      final matcher = frontmatterFieldHasType('title', String);
      final matchState = <dynamic, dynamic>{};
      const item = true;
      matcher.matches(item, matchState);
      final description = StringDescription();
      matcher.describeMismatch(item, description, matchState, false);
      expect(description.toString(), equals('Expected a String, got bool'));
    });

    test('frontmatterFieldHasType describes parse failure', () {
      final matcher = frontmatterFieldHasType('title', String);
      final matchState = <dynamic, dynamic>{};
      const item = 'no frontmatter';
      matcher.matches(item, matchState);
      final description = StringDescription();
      matcher.describeMismatch(item, description, matchState, false);
      expect(description.toString(), equals('Failed to parse frontmatter'));
    });

    test('frontmatterFieldHasType describes missing key', () {
      final matcher = frontmatterFieldHasType('missing', String);
      final matchState = <dynamic, dynamic>{};
      matcher.matches(validMarkdown, matchState);
      final description = StringDescription();
      matcher.describeMismatch(validMarkdown, description, matchState, false);
      expect(
        description.toString(),
        equals('Key "missing" not found in frontmatter'),
      );
    });

    test('frontmatterFieldHasType describes type mismatch', () {
      final matcher = frontmatterFieldHasType('title', int);
      final matchState = <dynamic, dynamic>{};
      matcher.matches(validMarkdown, matchState);
      final description = StringDescription();
      matcher.describeMismatch(validMarkdown, description, matchState, false);
      expect(description.toString(), equals('has type String'));
    });

    test('describe methods return expected descriptions', () {
      expect(
        frontmatterMatchesSchema({
          'type': 'object',
        }).describe(StringDescription()).toString(),
        equals('frontmatter matches schema'),
      );
      expect(
        frontmatterHasRequiredFields({
          'title': String,
          'count': int,
        }).describe(StringDescription()).toString(),
        equals('frontmatter has required fields: title, count'),
      );
      expect(
        frontmatterArrayLengthBetween(
          'tags',
          1,
          5,
        ).describe(StringDescription()).toString(),
        equals('frontmatter array "tags" has length between 1 and 5'),
      );
      expect(
        frontmatterFieldOneOf('status', [
          'draft',
          'published',
        ]).describe(StringDescription()).toString(),
        equals('frontmatter field "status" is one of [draft, published]'),
      );
      expect(
        frontmatterFieldHasType(
          'count',
          int,
        ).describe(StringDescription()).toString(),
        equals('frontmatter field "count" has type int'),
      );
    });
  });

  group('edge cases', () {
    test('handles empty frontmatter with minimal schema', () {
      const empty = '''---
title: X
---

Body.
''';
      expect(empty, frontmatterMatchesSchema({'type': 'object'}));
    });

    test('handles double type in frontmatter', () {
      const withDouble = '''---
price: 19.99
---

Body.
''';
      expect(withDouble, frontmatterFieldHasType('price', double));
      expect(withDouble, frontmatterFieldHasType('price', num));
    });

    test('handles complex nested validation', () {
      const complex = '''---
post:
  title: My Post
  metadata:
    views: 100
    tags:
      - tech
      - dart
---

Body.
''';
      expect(
        complex,
        frontmatterMatchesSchema({
          'type': 'object',
          'properties': {
            'post': {
              'type': 'object',
              'required': ['title', 'metadata'],
              'properties': {
                'title': {'type': 'string', 'minLength': 1},
                'metadata': {
                  'type': 'object',
                  'properties': {
                    'views': {'type': 'integer', 'minimum': 0},
                    'tags': {
                      'type': 'array',
                      'items': {'type': 'string'},
                    },
                  },
                },
              },
            },
          },
        }),
      );
    });
  });
}
