import 'dart:convert';

import 'package:matcher/matcher.dart';

/// Matches a string that is valid JSON.
const Matcher isValidJson = _IsValidJson();

/// Matches a string that is a valid JSON object (starts with `{`).
const Matcher isJsonObject = _IsJsonObject();

/// Matches a string that is a valid JSON array (starts with `[`).
const Matcher isJsonArray = _IsJsonArray();

/// Matches a JSON string that contains the specified [key] at the top level.
Matcher hasJsonKey(String key) => _HasJsonKey(key);

/// Matches a JSON string that has a value at the specified [path].
///
/// The path uses dot notation, e.g., `user.name` or `items.0.id`.
/// Array indices are specified as numbers in the path.
///
/// Example:
/// ```dart
/// expect('{"user": {"name": "John"}}', hasJsonPath('user.name'));
/// expect('{"items": [{"id": 1}]}', hasJsonPath('items.0.id'));
/// ```
Matcher hasJsonPath(String path) => _HasJsonPath(path);

/// Matches a JSON string that has the specified [value] at the given [path].
///
/// Example:
/// ```dart
/// expect('{"user": {"name": "John"}}', hasJsonPathValue('user.name', 'John'));
/// ```
Matcher hasJsonPathValue(String path, Object? value) =>
    _HasJsonPathValue(path, value);

class _IsValidJson extends Matcher {
  const _IsValidJson();

  @override
  bool matches(Object? item, Map<dynamic, dynamic> matchState) {
    if (item is! String) return false;
    try {
      jsonDecode(item);
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Description describe(Description description) =>
      description.add('is valid JSON');

  @override
  Description describeMismatch(
    Object? item,
    Description mismatchDescription,
    Map<dynamic, dynamic> matchState,
    bool verbose,
  ) {
    if (item is! String) {
      return mismatchDescription.add('is not a String');
    }
    try {
      jsonDecode(item);
      return mismatchDescription;
    } catch (e) {
      return mismatchDescription.add('failed to parse: $e');
    }
  }
}

class _IsJsonObject extends Matcher {
  const _IsJsonObject();

  @override
  bool matches(Object? item, Map<dynamic, dynamic> matchState) {
    if (item is! String) return false;
    try {
      final decoded = jsonDecode(item);
      return decoded is Map;
    } catch (_) {
      return false;
    }
  }

  @override
  Description describe(Description description) =>
      description.add('is a JSON object');

  @override
  Description describeMismatch(
    Object? item,
    Description mismatchDescription,
    Map<dynamic, dynamic> matchState,
    bool verbose,
  ) {
    if (item is! String) {
      return mismatchDescription.add('is not a String');
    }
    try {
      final decoded = jsonDecode(item);
      if (decoded is! Map) {
        return mismatchDescription.add('is a JSON ${decoded.runtimeType}');
      }
      return mismatchDescription;
    } catch (e) {
      return mismatchDescription.add('failed to parse: $e');
    }
  }
}

class _IsJsonArray extends Matcher {
  const _IsJsonArray();

  @override
  bool matches(Object? item, Map<dynamic, dynamic> matchState) {
    if (item is! String) return false;
    try {
      final decoded = jsonDecode(item);
      return decoded is List;
    } catch (_) {
      return false;
    }
  }

  @override
  Description describe(Description description) =>
      description.add('is a JSON array');

  @override
  Description describeMismatch(
    Object? item,
    Description mismatchDescription,
    Map<dynamic, dynamic> matchState,
    bool verbose,
  ) {
    if (item is! String) {
      return mismatchDescription.add('is not a String');
    }
    try {
      final decoded = jsonDecode(item);
      if (decoded is! List) {
        return mismatchDescription.add('is a JSON ${decoded.runtimeType}');
      }
      return mismatchDescription;
    } catch (e) {
      return mismatchDescription.add('failed to parse: $e');
    }
  }
}

class _HasJsonKey extends Matcher {
  final String key;

  const _HasJsonKey(this.key);

  @override
  bool matches(Object? item, Map<dynamic, dynamic> matchState) {
    if (item is! String) return false;
    try {
      final decoded = jsonDecode(item);
      if (decoded is! Map) return false;
      return decoded.containsKey(key);
    } catch (_) {
      return false;
    }
  }

  @override
  Description describe(Description description) =>
      description.add('has JSON key "$key"');

  @override
  Description describeMismatch(
    Object? item,
    Description mismatchDescription,
    Map<dynamic, dynamic> matchState,
    bool verbose,
  ) {
    if (item is! String) {
      return mismatchDescription.add('is not a String');
    }
    try {
      final decoded = jsonDecode(item);
      if (decoded is! Map) {
        return mismatchDescription.add('is not a JSON object');
      }
      return mismatchDescription.add('does not contain key "$key"');
    } catch (e) {
      return mismatchDescription.add('failed to parse: $e');
    }
  }
}

class _HasJsonPath extends Matcher {
  final String path;

  const _HasJsonPath(this.path);

  @override
  bool matches(Object? item, Map<dynamic, dynamic> matchState) {
    if (item is! String) return false;
    try {
      final decoded = jsonDecode(item);
      return _getValueAtPath(decoded, path) != _notFound;
    } catch (_) {
      return false;
    }
  }

  @override
  Description describe(Description description) =>
      description.add('has JSON path "$path"');

  @override
  Description describeMismatch(
    Object? item,
    Description mismatchDescription,
    Map<dynamic, dynamic> matchState,
    bool verbose,
  ) {
    if (item is! String) {
      return mismatchDescription.add('is not a String');
    }
    try {
      final decoded = jsonDecode(item);
      final result = _getValueAtPath(decoded, path);
      if (result == _notFound) {
        return mismatchDescription.add('path "$path" not found');
      }
      return mismatchDescription;
    } catch (e) {
      return mismatchDescription.add('failed to parse: $e');
    }
  }
}

class _HasJsonPathValue extends Matcher {
  final String path;
  final Object? expectedValue;

  const _HasJsonPathValue(this.path, this.expectedValue);

  @override
  bool matches(Object? item, Map<dynamic, dynamic> matchState) {
    if (item is! String) return false;
    try {
      final decoded = jsonDecode(item);
      final value = _getValueAtPath(decoded, path);
      if (value == _notFound) return false;
      return value == expectedValue;
    } catch (_) {
      return false;
    }
  }

  @override
  Description describe(Description description) =>
      description.add('has JSON path "$path" with value $expectedValue');

  @override
  Description describeMismatch(
    Object? item,
    Description mismatchDescription,
    Map<dynamic, dynamic> matchState,
    bool verbose,
  ) {
    if (item is! String) {
      return mismatchDescription.add('is not a String');
    }
    try {
      final decoded = jsonDecode(item);
      final value = _getValueAtPath(decoded, path);
      if (value == _notFound) {
        return mismatchDescription.add('path "$path" not found');
      }
      return mismatchDescription.add('has value $value at path "$path"');
    } catch (e) {
      return mismatchDescription.add('failed to parse: $e');
    }
  }
}

// Sentinel value to indicate path not found
const _notFound = _NotFound();

class _NotFound {
  const _NotFound();
}

/// Gets the value at a dot-notation path in a JSON structure.
/// Returns [_notFound] if the path doesn't exist.
Object? _getValueAtPath(Object? json, String path) {
  final segments = path.split('.');
  Object? current = json;

  for (final segment in segments) {
    if (current is Map) {
      if (!current.containsKey(segment)) return _notFound;
      current = current[segment];
    } else if (current is List) {
      final index = int.tryParse(segment);
      if (index == null || index < 0 || index >= current.length) {
        return _notFound;
      }
      current = current[index];
    } else {
      return _notFound;
    }
  }

  return current;
}
