import 'package:matcher/matcher.dart';

import '../md_file.dart';

/// Validates that a Jekyll-style markdown string's frontmatter matches a schema.
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
/// expect(markdown, frontmatterMatchesSchema({
///   'type': 'object',
///   'required': ['title', 'date'],
///   'properties': {
///     'title': {'type': 'string', 'minLength': 1},
///     'date': {'type': 'string'},
///     'tags': {'type': 'array', 'items': {'type': 'string'}},
///   },
/// }));
/// ```
Matcher frontmatterMatchesSchema(Map<String, dynamic> schema) =>
    _FrontmatterMatchesSchema(schema);

/// Validates that frontmatter has all required fields with correct types.
///
/// Example:
/// ```dart
/// expect(markdown, frontmatterHasRequiredFields({
///   'title': String,
///   'count': int,
///   'published': bool,
/// }));
/// ```
Matcher frontmatterHasRequiredFields(Map<String, Type> fields) =>
    _FrontmatterHasRequiredFields(fields);

/// Validates that a frontmatter array field has length within bounds.
///
/// Example:
/// ```dart
/// expect(markdown, frontmatterArrayLengthBetween('tags', 1, 5));
/// ```
Matcher frontmatterArrayLengthBetween(String key, int min, int max) =>
    _FrontmatterArrayLengthBetween(key, min, max);

/// Validates that a frontmatter field value is one of allowed values.
///
/// Example:
/// ```dart
/// expect(markdown, frontmatterFieldOneOf('status', ['draft', 'published']));
/// ```
Matcher frontmatterFieldOneOf(String key, List<dynamic> allowedValues) =>
    _FrontmatterFieldOneOf(key, allowedValues);

/// Validates that a frontmatter field has the expected type.
///
/// Example:
/// ```dart
/// expect(markdown, frontmatterFieldHasType('count', int));
/// expect(markdown, frontmatterFieldHasType('title', String));
/// ```
Matcher frontmatterFieldHasType(String key, Type expectedType) =>
    _FrontmatterFieldHasType(key, expectedType);

// Sentinel for parse failures
const _parseFailed = _ParseFailed();

class _ParseFailed {
  const _ParseFailed();
}

/// Attempts to parse frontmatter, returns _parseFailed on failure.
Object _tryParse(Object? item) {
  if (item is! String) return _parseFailed;
  final result = inspectMarkdownBody(item);
  if (!result.hasFrontmatter || !result.isValidFrontmatter) {
    return _parseFailed;
  }
  return result;
}

class _FrontmatterMatchesSchema extends Matcher {
  final Map<String, dynamic> schema;

  const _FrontmatterMatchesSchema(this.schema);

  @override
  bool matches(Object? item, Map<dynamic, dynamic> matchState) {
    if (item is! String) {
      matchState['error'] = 'Expected a String, got ${item.runtimeType}';
      return false;
    }

    final result = _tryParse(item);
    if (result == _parseFailed) {
      matchState['error'] = 'Failed to parse frontmatter';
      return false;
    }

    final parsed = result as ParsedMarkdownDocument;
    final errors = <String>[];
    _validateSchema(parsed.frontmatter, schema, '', errors);

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
          '${path.isEmpty ? "root" : path}: expected type ${schema['type']}, got ${_getType(value)}',
        );
        return;
      }
    }

    // Check enum
    if (schema.containsKey('enum')) {
      final allowedValues = schema['enum'] as List;
      if (!allowedValues.contains(value)) {
        errors.add(
          '${path.isEmpty ? "root" : path}: value $value not in enum $allowedValues',
        );
      }
    }

    // String constraints
    if (value is String) {
      if (schema.containsKey('minLength')) {
        final minLength = schema['minLength'] as int;
        if (value.length < minLength) {
          errors.add(
            '${path.isEmpty ? "root" : path}: string length ${value.length} < minLength $minLength',
          );
        }
      }
      if (schema.containsKey('maxLength')) {
        final maxLength = schema['maxLength'] as int;
        if (value.length > maxLength) {
          errors.add(
            '${path.isEmpty ? "root" : path}: string length ${value.length} > maxLength $maxLength',
          );
        }
      }
    }

    // Number constraints
    if (value is num) {
      if (schema.containsKey('minimum')) {
        final minimum = schema['minimum'] as num;
        if (value < minimum) {
          errors.add(
            '${path.isEmpty ? "root" : path}: value $value < minimum $minimum',
          );
        }
      }
      if (schema.containsKey('maximum')) {
        final maximum = schema['maximum'] as num;
        if (value > maximum) {
          errors.add(
            '${path.isEmpty ? "root" : path}: value $value > maximum $maximum',
          );
        }
      }
    }

    // Array constraints (including YamlList)
    if (value is List) {
      if (schema.containsKey('minItems')) {
        final minItems = schema['minItems'] as int;
        if (value.length < minItems) {
          errors.add(
            '${path.isEmpty ? "root" : path}: array length ${value.length} < minItems $minItems',
          );
        }
      }
      if (schema.containsKey('maxItems')) {
        final maxItems = schema['maxItems'] as int;
        if (value.length > maxItems) {
          errors.add(
            '${path.isEmpty ? "root" : path}: array length ${value.length} > maxItems $maxItems',
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

    // Object constraints (including YamlMap)
    if (value is Map) {
      // Check required fields
      if (schema.containsKey('required')) {
        final required = schema['required'] as List;
        for (final field in required) {
          if (!value.containsKey(field)) {
            errors.add(
              '${path.isEmpty ? "root" : path}: missing required field "$field"',
            );
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
      description.add('frontmatter matches schema');

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

class _FrontmatterHasRequiredFields extends Matcher {
  final Map<String, Type> fields;

  const _FrontmatterHasRequiredFields(this.fields);

  @override
  bool matches(Object? item, Map<dynamic, dynamic> matchState) {
    if (item is! String) {
      matchState['error'] = 'Expected a String, got ${item.runtimeType}';
      return false;
    }

    final result = _tryParse(item);
    if (result == _parseFailed) {
      matchState['error'] = 'Failed to parse frontmatter';
      return false;
    }

    final parsed = result as ParsedMarkdownDocument;
    final frontmatter = parsed.frontmatter;

    final errors = <String>[];
    for (final entry in fields.entries) {
      final fieldName = entry.key;
      final expectedType = entry.value;

      if (!frontmatter.containsKey(fieldName)) {
        errors.add('missing field "$fieldName"');
        continue;
      }

      final value = frontmatter[fieldName];
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
  Description describe(Description description) => description.add(
    'frontmatter has required fields: ${fields.keys.join(', ')}',
  );

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

class _FrontmatterArrayLengthBetween extends Matcher {
  final String key;
  final int min;
  final int max;

  const _FrontmatterArrayLengthBetween(this.key, this.min, this.max);

  @override
  bool matches(Object? item, Map<dynamic, dynamic> matchState) {
    if (item is! String) {
      matchState['error'] = 'Expected a String, got ${item.runtimeType}';
      return false;
    }

    final result = _tryParse(item);
    if (result == _parseFailed) {
      matchState['error'] = 'Failed to parse frontmatter';
      return false;
    }

    final parsed = result as ParsedMarkdownDocument;
    if (!parsed.frontmatter.containsKey(key)) {
      matchState['error'] = 'Key "$key" not found in frontmatter';
      return false;
    }

    final value = parsed.frontmatter[key];
    if (value is! List) {
      matchState['error'] = 'Value at "$key" is not an array';
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
  Description describe(Description description) => description.add(
    'frontmatter array "$key" has length between $min and $max',
  );

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

class _FrontmatterFieldOneOf extends Matcher {
  final String key;
  final List<dynamic> allowedValues;

  const _FrontmatterFieldOneOf(this.key, this.allowedValues);

  @override
  bool matches(Object? item, Map<dynamic, dynamic> matchState) {
    if (item is! String) {
      matchState['error'] = 'Expected a String, got ${item.runtimeType}';
      return false;
    }

    final result = _tryParse(item);
    if (result == _parseFailed) {
      matchState['error'] = 'Failed to parse frontmatter';
      return false;
    }

    final parsed = result as ParsedMarkdownDocument;
    if (!parsed.frontmatter.containsKey(key)) {
      matchState['error'] = 'Key "$key" not found in frontmatter';
      return false;
    }

    final value = parsed.frontmatter[key];
    if (!allowedValues.contains(value)) {
      matchState['value'] = value;
      return false;
    }
    return true;
  }

  @override
  Description describe(Description description) =>
      description.add('frontmatter field "$key" is one of $allowedValues');

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

class _FrontmatterFieldHasType extends Matcher {
  final String key;
  final Type expectedType;

  const _FrontmatterFieldHasType(this.key, this.expectedType);

  @override
  bool matches(Object? item, Map<dynamic, dynamic> matchState) {
    if (item is! String) {
      matchState['error'] = 'Expected a String, got ${item.runtimeType}';
      return false;
    }

    final result = _tryParse(item);
    if (result == _parseFailed) {
      matchState['error'] = 'Failed to parse frontmatter';
      return false;
    }

    final parsed = result as ParsedMarkdownDocument;
    if (!parsed.frontmatter.containsKey(key)) {
      matchState['error'] = 'Key "$key" not found in frontmatter';
      return false;
    }

    final value = parsed.frontmatter[key];
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
      description.add('frontmatter field "$key" has type $expectedType');

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
