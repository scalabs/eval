import 'dart:convert';

import 'package:eval/src/matchers/schema_matchers.dart';
import 'package:test/test.dart';

void main() {
  group('matchesSchema', () {
    test('validates type: string', () {
      expect('"hello"', matchesSchema({'type': 'string'}));
      expect('123', isNot(matchesSchema({'type': 'string'})));
    });

    test('validates type: number', () {
      expect('123', matchesSchema({'type': 'number'}));
      expect('123.45', matchesSchema({'type': 'number'}));
      expect('"hello"', isNot(matchesSchema({'type': 'number'})));
    });

    test('validates type: integer', () {
      expect('123', matchesSchema({'type': 'integer'}));
      expect('123.45', isNot(matchesSchema({'type': 'integer'})));
    });

    test('validates type: boolean', () {
      expect('true', matchesSchema({'type': 'boolean'}));
      expect('false', matchesSchema({'type': 'boolean'}));
      expect('"true"', isNot(matchesSchema({'type': 'boolean'})));
    });

    test('validates type: array', () {
      expect('[1, 2, 3]', matchesSchema({'type': 'array'}));
      expect('{}', isNot(matchesSchema({'type': 'array'})));
    });

    test('validates type: object', () {
      expect('{}', matchesSchema({'type': 'object'}));
      expect('{"key": "value"}', matchesSchema({'type': 'object'}));
      expect('[]', isNot(matchesSchema({'type': 'object'})));
    });

    test('validates type: null', () {
      expect('null', matchesSchema({'type': 'null'}));
      expect('0', isNot(matchesSchema({'type': 'null'})));
    });

    test('validates enum', () {
      expect(
        '"active"',
        matchesSchema({
          'enum': ['active', 'inactive'],
        }),
      );
      expect(
        '"pending"',
        isNot(
          matchesSchema({
            'enum': ['active', 'inactive'],
          }),
        ),
      );
    });

    test('validates minLength/maxLength for strings', () {
      expect('"hello"', matchesSchema({'type': 'string', 'minLength': 3}));
      expect('"hi"', isNot(matchesSchema({'type': 'string', 'minLength': 3})));
      expect('"hi"', matchesSchema({'type': 'string', 'maxLength': 5}));
      expect(
        '"hello world"',
        isNot(matchesSchema({'type': 'string', 'maxLength': 5})),
      );
    });

    test('validates minimum/maximum for numbers', () {
      expect('10', matchesSchema({'type': 'integer', 'minimum': 5}));
      expect('3', isNot(matchesSchema({'type': 'integer', 'minimum': 5})));
      expect('10', matchesSchema({'type': 'integer', 'maximum': 15}));
      expect('20', isNot(matchesSchema({'type': 'integer', 'maximum': 15})));
    });

    test('validates minItems/maxItems for arrays', () {
      expect('[1, 2, 3]', matchesSchema({'type': 'array', 'minItems': 2}));
      expect('[1]', isNot(matchesSchema({'type': 'array', 'minItems': 2})));
      expect('[1, 2]', matchesSchema({'type': 'array', 'maxItems': 3}));
      expect(
        '[1, 2, 3, 4]',
        isNot(matchesSchema({'type': 'array', 'maxItems': 3})),
      );
    });

    test('validates array items schema', () {
      expect(
        '[1, 2, 3]',
        matchesSchema({
          'type': 'array',
          'items': {'type': 'integer'},
        }),
      );
      expect(
        '["a", "b"]',
        isNot(
          matchesSchema({
            'type': 'array',
            'items': {'type': 'integer'},
          }),
        ),
      );
    });

    test('validates required fields', () {
      final schema = {
        'type': 'object',
        'required': ['name', 'age'],
      };

      expect('{"name": "John", "age": 30}', matchesSchema(schema));
      expect('{"name": "John"}', isNot(matchesSchema(schema)));
    });

    test('validates property schemas', () {
      final schema = {
        'type': 'object',
        'properties': {
          'name': {'type': 'string'},
          'age': {'type': 'integer', 'minimum': 0},
        },
      };

      expect('{"name": "John", "age": 30}', matchesSchema(schema));
      expect('{"name": 123, "age": 30}', isNot(matchesSchema(schema)));
      expect('{"name": "John", "age": -5}', isNot(matchesSchema(schema)));
    });

    test('validates nested objects', () {
      final schema = {
        'type': 'object',
        'properties': {
          'user': {
            'type': 'object',
            'required': ['name'],
            'properties': {
              'name': {'type': 'string'},
            },
          },
        },
      };

      expect('{"user": {"name": "John"}}', matchesSchema(schema));
      expect('{"user": {}}', isNot(matchesSchema(schema)));
    });

    test('rejects invalid JSON', () {
      expect('{invalid}', isNot(matchesSchema({'type': 'object'})));
    });

    test('rejects non-string input', () {
      expect(123, isNot(matchesSchema({'type': 'integer'})));
    });

    test('complex schema validation', () {
      final schema = {
        'type': 'object',
        'required': ['id', 'name', 'items'],
        'properties': {
          'id': {'type': 'integer', 'minimum': 1},
          'name': {'type': 'string', 'minLength': 1, 'maxLength': 100},
          'active': {'type': 'boolean'},
          'items': {
            'type': 'array',
            'minItems': 1,
            'maxItems': 10,
            'items': {
              'type': 'object',
              'required': ['sku'],
              'properties': {
                'sku': {'type': 'string'},
                'quantity': {'type': 'integer', 'minimum': 1},
              },
            },
          },
        },
      };

      final validJson = jsonEncode({
        'id': 1,
        'name': 'Order',
        'active': true,
        'items': [
          {'sku': 'ABC123', 'quantity': 2},
          {'sku': 'XYZ789', 'quantity': 1},
        ],
      });

      expect(validJson, matchesSchema(schema));

      // Missing required field
      final missingItems = jsonEncode({'id': 1, 'name': 'Order'});
      expect(missingItems, isNot(matchesSchema(schema)));

      // Invalid item
      final invalidItem = jsonEncode({
        'id': 1,
        'name': 'Order',
        'items': [
          {'quantity': 2}, // missing sku
        ],
      });
      expect(invalidItem, isNot(matchesSchema(schema)));
    });
  });

  group('hasRequiredFields', () {
    test('matches when all fields present with correct types', () {
      final json = jsonEncode({'name': 'John', 'age': 30, 'active': true});
      expect(
        json,
        hasRequiredFields({'name': String, 'age': int, 'active': bool}),
      );
    });

    test('fails when field is missing', () {
      final json = jsonEncode({'name': 'John'});
      expect(json, isNot(hasRequiredFields({'name': String, 'age': int})));
    });

    test('fails when field has wrong type', () {
      final json = jsonEncode({'name': 'John', 'age': '30'});
      expect(json, isNot(hasRequiredFields({'name': String, 'age': int})));
    });

    test('handles num type for both int and double', () {
      expect(jsonEncode({'value': 10}), hasRequiredFields({'value': num}));
      expect(jsonEncode({'value': 10.5}), hasRequiredFields({'value': num}));
    });

    test('handles List and Map types', () {
      final json = jsonEncode({
        'items': [1, 2, 3],
        'metadata': {'key': 'value'},
      });
      expect(json, hasRequiredFields({'items': List, 'metadata': Map}));
    });

    test('rejects invalid JSON', () {
      expect('{invalid}', isNot(hasRequiredFields({'key': String})));
    });

    test('rejects non-object JSON', () {
      expect('[1, 2, 3]', isNot(hasRequiredFields({'key': String})));
    });
  });

  group('jsonArrayLengthBetween', () {
    test('matches when array length is within bounds', () {
      final json = jsonEncode({
        'items': [1, 2, 3],
      });
      expect(json, jsonArrayLengthBetween('items', 1, 5));
      expect(json, jsonArrayLengthBetween('items', 3, 3));
    });

    test('fails when array is too short', () {
      final json = jsonEncode({
        'items': [1],
      });
      expect(json, isNot(jsonArrayLengthBetween('items', 2, 5)));
    });

    test('fails when array is too long', () {
      final json = jsonEncode({
        'items': [1, 2, 3, 4, 5],
      });
      expect(json, isNot(jsonArrayLengthBetween('items', 1, 3)));
    });

    test('handles nested paths', () {
      final json = jsonEncode({
        'user': {
          'orders': [1, 2, 3],
        },
      });
      expect(json, jsonArrayLengthBetween('user.orders', 1, 5));
    });

    test('handles array index in path', () {
      final json = jsonEncode({
        'users': [
          {
            'items': [1, 2],
          },
          {
            'items': [3, 4, 5],
          },
        ],
      });
      expect(json, jsonArrayLengthBetween('users.0.items', 1, 3));
      expect(json, jsonArrayLengthBetween('users.1.items', 3, 5));
    });

    test('fails when path not found', () {
      final json = jsonEncode({
        'items': [1, 2],
      });
      expect(json, isNot(jsonArrayLengthBetween('missing', 0, 10)));
    });

    test('fails when value at path is not an array', () {
      final json = jsonEncode({'items': 'not an array'});
      expect(json, isNot(jsonArrayLengthBetween('items', 0, 10)));
    });
  });

  group('fieldOneOf', () {
    test('matches when value is in allowed list', () {
      final json = jsonEncode({'status': 'active'});
      expect(json, fieldOneOf('status', ['active', 'inactive', 'pending']));
    });

    test('fails when value is not in allowed list', () {
      final json = jsonEncode({'status': 'deleted'});
      expect(json, isNot(fieldOneOf('status', ['active', 'inactive'])));
    });

    test('handles nested paths', () {
      final json = jsonEncode({
        'user': {'role': 'admin'},
      });
      expect(json, fieldOneOf('user.role', ['admin', 'user', 'guest']));
    });

    test('handles null values', () {
      final json = jsonEncode({'value': null});
      expect(json, fieldOneOf('value', [null, 'option']));
      expect(json, isNot(fieldOneOf('value', ['option'])));
    });

    test('handles numeric values', () {
      final json = jsonEncode({'priority': 1});
      expect(json, fieldOneOf('priority', [1, 2, 3]));
      expect(json, isNot(fieldOneOf('priority', [2, 3])));
    });

    test('fails when path not found', () {
      final json = jsonEncode({'other': 'value'});
      expect(json, isNot(fieldOneOf('missing', ['value'])));
    });
  });

  group('fieldHasType', () {
    test('validates String type', () {
      final json = jsonEncode({'name': 'John'});
      expect(json, fieldHasType('name', String));
      expect(jsonEncode({'name': 123}), isNot(fieldHasType('name', String)));
    });

    test('validates int type', () {
      final json = jsonEncode({'age': 30});
      expect(json, fieldHasType('age', int));
      expect(jsonEncode({'age': 30.5}), isNot(fieldHasType('age', int)));
    });

    test('validates bool type', () {
      final json = jsonEncode({'active': true});
      expect(json, fieldHasType('active', bool));
      expect(
        jsonEncode({'active': 'true'}),
        isNot(fieldHasType('active', bool)),
      );
    });

    test('validates List type', () {
      final json = jsonEncode({
        'items': [1, 2, 3],
      });
      expect(json, fieldHasType('items', List));
    });

    test('validates Map type', () {
      final json = jsonEncode({
        'data': {'key': 'value'},
      });
      expect(json, fieldHasType('data', Map));
    });

    test('handles nested paths', () {
      final json = jsonEncode({
        'user': {'name': 'John'},
      });
      expect(json, fieldHasType('user.name', String));
    });

    test('fails when path not found', () {
      final json = jsonEncode({'other': 'value'});
      expect(json, isNot(fieldHasType('missing', String)));
    });
  });
}
