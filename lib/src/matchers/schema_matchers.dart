import 'dart:convert';

import 'package:matcher/matcher.dart';

/// Validates that a JSON string matches a JSON Schema.
///
/// Supports a subset of JSON Schema keywords:
/// - `type`: string, number, integer, boolean, array, object, null
/// - `required`: list of required property names
/// - `properties`: map of property schemas
/// - `items`: schema for array items
/// - `enum`: list of allowed values
/// - `minLength`, `maxLength`: string length constraints
/// - `minimum`, `maximum`: number range constraints
/// - `minItems`, `maxItems`: array length constraints
///
/// Example:
/// ```dart
/// expect(jsonString, matchesSchema({
///   'type': 'object',
///   'required': ['name', 'age'],
///   'properties': {
///     'name': {'type': 'string'},
///     'age': {'type': 'integer', 'minimum': 0},
///   },
/// }));
/// ```
Matcher matchesSchema(Map<String, dynamic> schema) => _MatchesSchema(schema);

/// Validates that a JSON object has all required fields with correct types.
///
/// Example:
/// ```dart
/// expect(jsonString, hasRequiredFields({
///   'name': String,
///   'age': int,
///   'active': bool,
/// }));
/// ```
Matcher hasRequiredFields(Map<String, Type> fields) =>
    _HasRequiredFields(fields);

/// Validates that a JSON array at the given path has length within bounds.
///
/// Example:
/// ```dart
/// expect(jsonString, jsonArrayLengthBetween('items', 1, 10));
/// expect(jsonString, jsonArrayLengthBetween('users.0.orders', 0, 5));
/// ```
Matcher jsonArrayLengthBetween(String jsonPath, int min, int max) =>
    _JsonArrayLengthBetween(jsonPath, min, max);

/// Validates that a field value at the given path is one of allowed values.
///
/// Example:
/// ```dart
/// expect(jsonString, fieldOneOf('status', ['pending', 'active', 'completed']));
/// expect(jsonString, fieldOneOf('user.role', ['admin', 'user', 'guest']));
/// ```
Matcher fieldOneOf(String jsonPath, List<dynamic> allowedValues) =>
    _FieldOneOf(jsonPath, allowedValues);

/// Validates that a field value at the given path matches the expected type.
///
/// Example:
/// ```dart
/// expect(jsonString, fieldHasType('age', int));
/// expect(jsonString, fieldHasType('name', String));
/// ```
Matcher fieldHasType(String jsonPath, Type expectedType) =>
    _FieldHasType(jsonPath, expectedType);

const _pathNotFound = _PathNotFound();

class _PathNotFound {
  const _PathNotFound();
}

class _MatchesSchema extends Matcher {
  final Map<String, dynamic> schema;

  const _MatchesSchema(this.schema);

  @override
  bool matches(Object? item, Map<dynamic, dynamic> matchState) {
    if (item is! String) {
      matchState['error'] = 'Expected a String, got ${item.runtimeType}';
      return false;
    }

    dynamic json;
    try {
      json = jsonDecode(item);
    } catch (e) {
      matchState['error'] = 'Invalid JSON: $e';
      return false;
    }

    final errors = <String>[];
    _validateSchema(json, schema, '', errors);

    if (errors.isNotEmpty) {
      matchState['errors'] = errors;
      return false;
    }
    return true;
  }

  void _validateSchema(
    dynamic value,
    Map<String, dynamic> schema,
    String path,
    List<String> errors,
  ) {
    // Check type
    if (schema.containsKey('type')) {
      if (!_checkType(value, schema['type'] as String)) {
        errors.add(
          '$path: expected type ${schema['type']}, got ${_getType(value)}',
        );
        return;
      }
    }

    // Check enum
    if (schema.containsKey('enum')) {
      final allowedValues = schema['enum'] as List;
      if (!allowedValues.contains(value)) {
        errors.add('$path: value $value not in enum $allowedValues');
      }
    }

    // String constraints
    if (value is String) {
      if (schema.containsKey('minLength')) {
        final minLength = schema['minLength'] as int;
        if (value.length < minLength) {
          errors.add(
            '$path: string length ${value.length} < minLength $minLength',
          );
        }
      }
      if (schema.containsKey('maxLength')) {
        final maxLength = schema['maxLength'] as int;
        if (value.length > maxLength) {
          errors.add(
            '$path: string length ${value.length} > maxLength $maxLength',
          );
        }
      }
    }

    // Number constraints
    if (value is num) {
      if (schema.containsKey('minimum')) {
        final minimum = schema['minimum'] as num;
        if (value < minimum) {
          errors.add('$path: value $value < minimum $minimum');
        }
      }
      if (schema.containsKey('maximum')) {
        final maximum = schema['maximum'] as num;
        if (value > maximum) {
          errors.add('$path: value $value > maximum $maximum');
        }
      }
    }

    // Array constraints
    if (value is List) {
      if (schema.containsKey('minItems')) {
        final minItems = schema['minItems'] as int;
        if (value.length < minItems) {
          errors.add(
            '$path: array length ${value.length} < minItems $minItems',
          );
        }
      }
      if (schema.containsKey('maxItems')) {
        final maxItems = schema['maxItems'] as int;
        if (value.length > maxItems) {
          errors.add(
            '$path: array length ${value.length} > maxItems $maxItems',
          );
        }
      }
      if (schema.containsKey('items')) {
        final itemSchema = schema['items'] as Map<String, dynamic>;
        for (var i = 0; i < value.length; i++) {
          _validateSchema(value[i], itemSchema, '$path[$i]', errors);
        }
      }
    }

    // Object constraints
    if (value is Map) {
      // Check required fields
      if (schema.containsKey('required')) {
        final required = schema['required'] as List;
        for (final field in required) {
          if (!value.containsKey(field)) {
            errors.add('$path: missing required field "$field"');
          }
        }
      }

      // Validate properties
      if (schema.containsKey('properties')) {
        final properties = schema['properties'] as Map<String, dynamic>;
        for (final entry in properties.entries) {
          final fieldName = entry.key;
          final fieldSchema = entry.value as Map<String, dynamic>;
          if (value.containsKey(fieldName)) {
            final fieldPath = path.isEmpty ? fieldName : '$path.$fieldName';
            _validateSchema(value[fieldName], fieldSchema, fieldPath, errors);
          }
        }
      }
    }
  }

  bool _checkType(dynamic value, String type) {
    switch (type) {
      case 'string':
        return value is String;
      case 'number':
        return value is num;
      case 'integer':
        return value is int;
      case 'boolean':
        return value is bool;
      case 'array':
        return value is List;
      case 'object':
        return value is Map;
      case 'null':
        return value == null;
      default:
        return true;
    }
  }

  String _getType(dynamic value) {
    if (value == null) return 'null';
    if (value is String) return 'string';
    if (value is int) return 'integer';
    if (value is num) return 'number';
    if (value is bool) return 'boolean';
    if (value is List) return 'array';
    if (value is Map) return 'object';
    return value.runtimeType.toString();
  }

  @override
  Description describe(Description description) =>
      description.add('matches JSON schema');

  @override
  Description describeMismatch(
    Object? item,
    Description mismatchDescription,
    Map<dynamic, dynamic> matchState,
    bool verbose,
  ) {
    if (matchState.containsKey('error')) {
      return mismatchDescription.add(matchState['error'] as String);
    }
    if (matchState.containsKey('errors')) {
      final errors = matchState['errors'] as List<String>;
      return mismatchDescription.add(
        'schema violations:\n  ${errors.join('\n  ')}',
      );
    }
    return mismatchDescription;
  }
}

class _HasRequiredFields extends Matcher {
  final Map<String, Type> fields;

  const _HasRequiredFields(this.fields);

  @override
  bool matches(Object? item, Map<dynamic, dynamic> matchState) {
    if (item is! String) {
      matchState['error'] = 'Expected a String, got ${item.runtimeType}';
      return false;
    }

    dynamic json;
    try {
      json = jsonDecode(item);
    } catch (e) {
      matchState['error'] = 'Invalid JSON: $e';
      return false;
    }

    if (json is! Map) {
      matchState['error'] = 'Expected JSON object, got ${json.runtimeType}';
      return false;
    }

    final errors = <String>[];
    for (final entry in fields.entries) {
      final fieldName = entry.key;
      final expectedType = entry.value;

      if (!json.containsKey(fieldName)) {
        errors.add('missing field "$fieldName"');
        continue;
      }

      final value = json[fieldName];
      if (!_matchesType(value, expectedType)) {
        errors.add(
          'field "$fieldName" has type ${value.runtimeType}, expected $expectedType',
        );
      }
    }

    if (errors.isNotEmpty) {
      matchState['errors'] = errors;
      return false;
    }
    return true;
  }

  bool _matchesType(dynamic value, Type expectedType) {
    if (expectedType == String) return value is String;
    if (expectedType == int) return value is int;
    if (expectedType == double) return value is double;
    if (expectedType == num) return value is num;
    if (expectedType == bool) return value is bool;
    if (expectedType == List) return value is List;
    if (expectedType == Map) return value is Map;
    return value.runtimeType == expectedType;
  }

  @override
  Description describe(Description description) =>
      description.add('has required fields: ${fields.keys.join(', ')}');

  @override
  Description describeMismatch(
    Object? item,
    Description mismatchDescription,
    Map<dynamic, dynamic> matchState,
    bool verbose,
  ) {
    if (matchState.containsKey('error')) {
      return mismatchDescription.add(matchState['error'] as String);
    }
    if (matchState.containsKey('errors')) {
      final errors = matchState['errors'] as List<String>;
      return mismatchDescription.add(errors.join(', '));
    }
    return mismatchDescription;
  }
}

class _JsonArrayLengthBetween extends Matcher {
  final String jsonPath;
  final int min;
  final int max;

  const _JsonArrayLengthBetween(this.jsonPath, this.min, this.max);

  @override
  bool matches(Object? item, Map<dynamic, dynamic> matchState) {
    if (item is! String) {
      matchState['error'] = 'Expected a String, got ${item.runtimeType}';
      return false;
    }

    dynamic json;
    try {
      json = jsonDecode(item);
    } catch (e) {
      matchState['error'] = 'Invalid JSON: $e';
      return false;
    }

    final value = _getPath(json, jsonPath);
    if (value == _pathNotFound) {
      matchState['error'] = 'Path "$jsonPath" not found';
      return false;
    }

    if (value is! List) {
      matchState['error'] = 'Value at "$jsonPath" is not an array';
      return false;
    }

    final length = value.length;
    if (length < min || length > max) {
      matchState['length'] = length;
      return false;
    }
    return true;
  }

  @override
  Description describe(Description description) =>
      description.add('array at "$jsonPath" has length between $min and $max');

  @override
  Description describeMismatch(
    Object? item,
    Description mismatchDescription,
    Map<dynamic, dynamic> matchState,
    bool verbose,
  ) {
    if (matchState.containsKey('error')) {
      return mismatchDescription.add(matchState['error'] as String);
    }
    if (matchState.containsKey('length')) {
      return mismatchDescription.add('has length ${matchState['length']}');
    }
    return mismatchDescription;
  }
}

class _FieldOneOf extends Matcher {
  final String jsonPath;
  final List<dynamic> allowedValues;

  const _FieldOneOf(this.jsonPath, this.allowedValues);

  @override
  bool matches(Object? item, Map<dynamic, dynamic> matchState) {
    if (item is! String) {
      matchState['error'] = 'Expected a String, got ${item.runtimeType}';
      return false;
    }

    dynamic json;
    try {
      json = jsonDecode(item);
    } catch (e) {
      matchState['error'] = 'Invalid JSON: $e';
      return false;
    }

    final value = _getPath(json, jsonPath);
    if (value == _pathNotFound) {
      matchState['error'] = 'Path "$jsonPath" not found';
      return false;
    }

    if (!allowedValues.contains(value)) {
      matchState['value'] = value;
      return false;
    }
    return true;
  }

  @override
  Description describe(Description description) =>
      description.add('field "$jsonPath" is one of $allowedValues');

  @override
  Description describeMismatch(
    Object? item,
    Description mismatchDescription,
    Map<dynamic, dynamic> matchState,
    bool verbose,
  ) {
    if (matchState.containsKey('error')) {
      return mismatchDescription.add(matchState['error'] as String);
    }
    if (matchState.containsKey('value')) {
      return mismatchDescription.add('has value ${matchState['value']}');
    }
    return mismatchDescription;
  }
}

class _FieldHasType extends Matcher {
  final String jsonPath;
  final Type expectedType;

  const _FieldHasType(this.jsonPath, this.expectedType);

  @override
  bool matches(Object? item, Map<dynamic, dynamic> matchState) {
    if (item is! String) {
      matchState['error'] = 'Expected a String, got ${item.runtimeType}';
      return false;
    }

    dynamic json;
    try {
      json = jsonDecode(item);
    } catch (e) {
      matchState['error'] = 'Invalid JSON: $e';
      return false;
    }

    final value = _getPath(json, jsonPath);
    if (value == _pathNotFound) {
      matchState['error'] = 'Path "$jsonPath" not found';
      return false;
    }

    if (!_matchesType(value, expectedType)) {
      matchState['actualType'] = value.runtimeType;
      return false;
    }
    return true;
  }

  bool _matchesType(dynamic value, Type expectedType) {
    if (expectedType == String) return value is String;
    if (expectedType == int) return value is int;
    if (expectedType == double) return value is double;
    if (expectedType == num) return value is num;
    if (expectedType == bool) return value is bool;
    if (expectedType == List) return value is List;
    if (expectedType == Map) return value is Map;
    return value.runtimeType == expectedType;
  }

  @override
  Description describe(Description description) =>
      description.add('field "$jsonPath" has type $expectedType');

  @override
  Description describeMismatch(
    Object? item,
    Description mismatchDescription,
    Map<dynamic, dynamic> matchState,
    bool verbose,
  ) {
    if (matchState.containsKey('error')) {
      return mismatchDescription.add(matchState['error'] as String);
    }
    if (matchState.containsKey('actualType')) {
      return mismatchDescription.add('has type ${matchState['actualType']}');
    }
    return mismatchDescription;
  }
}

/// Helper to navigate JSON by dot-notation path.
dynamic _getPath(dynamic json, String path) {
  final parts = path.split('.');
  dynamic current = json;

  for (final part in parts) {
    if (current == null) return _pathNotFound;

    // Check if part is an array index
    final index = int.tryParse(part);
    if (index != null && current is List) {
      if (index < 0 || index >= current.length) return _pathNotFound;
      current = current[index];
    } else if (current is Map) {
      if (!current.containsKey(part)) return _pathNotFound;
      current = current[part];
    } else {
      return _pathNotFound;
    }
  }

  return current;
}
