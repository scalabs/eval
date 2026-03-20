import 'package:eval/eval.dart' hide expect;
import 'package:test/test.dart';

void main() {
  group('isValidJson', () {
    test('matches valid JSON object', () {
      expect('{"key": "value"}', isValidJson);
    });

    test('matches valid JSON array', () {
      expect('[1, 2, 3]', isValidJson);
    });

    test('matches valid JSON primitives', () {
      expect('"hello"', isValidJson);
      expect('123', isValidJson);
      expect('true', isValidJson);
      expect('null', isValidJson);
    });

    test('does not match invalid JSON', () {
      expect('{invalid}', isNot(isValidJson));
      expect('```json\n{"key": "value"}\n```', isNot(isValidJson));
      expect('not json at all', isNot(isValidJson));
    });

    test('does not match non-string', () {
      expect(123, isNot(isValidJson));
      expect(null, isNot(isValidJson));
    });
  });

  group('isJsonObject', () {
    test('matches JSON object', () {
      expect('{"key": "value"}', isJsonObject);
      expect('{}', isJsonObject);
      expect('{"nested": {"key": "value"}}', isJsonObject);
    });

    test('does not match JSON array', () {
      expect('[1, 2, 3]', isNot(isJsonObject));
    });

    test('does not match JSON primitives', () {
      expect('"hello"', isNot(isJsonObject));
      expect('123', isNot(isJsonObject));
    });

    test('does not match invalid JSON', () {
      expect('{invalid}', isNot(isJsonObject));
    });
  });

  group('isJsonArray', () {
    test('matches JSON array', () {
      expect('[1, 2, 3]', isJsonArray);
      expect('[]', isJsonArray);
      expect('[{"key": "value"}]', isJsonArray);
    });

    test('does not match JSON object', () {
      expect('{"key": "value"}', isNot(isJsonArray));
    });

    test('does not match JSON primitives', () {
      expect('"hello"', isNot(isJsonArray));
      expect('123', isNot(isJsonArray));
    });
  });

  group('hasJsonKey', () {
    test('matches when key exists', () {
      expect('{"message": "Hello"}', hasJsonKey('message'));
      expect('{"a": 1, "b": 2}', hasJsonKey('a'));
      expect('{"a": 1, "b": 2}', hasJsonKey('b'));
    });

    test('does not match when key is missing', () {
      expect('{"message": "Hello"}', isNot(hasJsonKey('other')));
      expect('{}', isNot(hasJsonKey('any')));
    });

    test('does not match nested keys at top level', () {
      expect('{"outer": {"inner": "value"}}', isNot(hasJsonKey('inner')));
    });

    test('does not match for arrays', () {
      expect('[1, 2, 3]', isNot(hasJsonKey('0')));
    });

    test('does not match invalid JSON', () {
      expect('{invalid}', isNot(hasJsonKey('key')));
    });
  });

  group('hasJsonPath', () {
    test('matches simple path', () {
      expect('{"key": "value"}', hasJsonPath('key'));
    });

    test('matches nested path', () {
      expect('{"user": {"name": "John"}}', hasJsonPath('user.name'));
      expect('{"a": {"b": {"c": "deep"}}}', hasJsonPath('a.b.c'));
    });

    test('matches array index path', () {
      expect('{"items": [1, 2, 3]}', hasJsonPath('items.0'));
      expect('{"items": [1, 2, 3]}', hasJsonPath('items.2'));
    });

    test('matches mixed path', () {
      expect('{"users": [{"name": "John"}]}', hasJsonPath('users.0.name'));
    });

    test('does not match missing path', () {
      expect('{"user": {"name": "John"}}', isNot(hasJsonPath('user.age')));
      expect('{"items": [1, 2]}', isNot(hasJsonPath('items.5')));
    });

    test('does not match invalid JSON', () {
      expect('{invalid}', isNot(hasJsonPath('key')));
    });
  });

  group('hasJsonPathValue', () {
    test('matches when path has expected value', () {
      expect('{"message": "Hello"}', hasJsonPathValue('message', 'Hello'));
      expect('{"count": 42}', hasJsonPathValue('count', 42));
      expect('{"active": true}', hasJsonPathValue('active', true));
    });

    test('matches nested path value', () {
      expect(
        '{"user": {"name": "John"}}',
        hasJsonPathValue('user.name', 'John'),
      );
    });

    test('matches null value', () {
      expect('{"value": null}', hasJsonPathValue('value', null));
    });

    test('does not match wrong value', () {
      expect('{"message": "Hello"}', isNot(hasJsonPathValue('message', 'Hi')));
    });

    test('does not match missing path', () {
      expect('{"message": "Hello"}', isNot(hasJsonPathValue('other', 'value')));
    });
  });
}
