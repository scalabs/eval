import 'package:matcher/matcher.dart';

import '../md_file.dart';

/// Matches a string that is valid Jekyll-style markdown with frontmatter.
///
/// The string must start with `---\n`, contain valid YAML frontmatter,
/// and end the frontmatter section with `\n---`.
const Matcher hasValidFrontmatter = _HasValidFrontmatter();

/// Matches a Jekyll-style markdown string that has a non-empty title in frontmatter.
const Matcher hasFrontmatterTitle = _HasFrontmatterTitle();

/// Matches a Jekyll-style markdown string that has the specified [key] in frontmatter.
Matcher hasFrontmatterKey(String key) => _HasFrontmatterKey(key);

/// Matches a Jekyll-style markdown string that has the specified [value] for [key] in frontmatter.
Matcher hasFrontmatterValue(String key, Object? value) =>
    _HasFrontmatterValue(key, value);

/// Matches a Jekyll-style markdown string where the frontmatter [key] matches the given [matcher].
///
/// Example:
/// ```dart
/// expect(markdown, frontmatterKeyMatches('tags', contains('dart')));
/// expect(markdown, frontmatterKeyMatches('count', greaterThan(5)));
/// ```
Matcher frontmatterKeyMatches(String key, Matcher matcher) =>
    _FrontmatterKeyMatches(key, matcher);

/// Matches a Jekyll-style markdown string that has a non-empty body (content after frontmatter).
const Matcher hasMarkdownBody = _HasMarkdownBody();

/// Matches a Jekyll-style markdown string where the body contains the specified [text].
Matcher bodyContains(String text) => _BodyContains(text);

/// Matches a Jekyll-style markdown string where the body matches the given [matcher].
///
/// Example:
/// ```dart
/// expect(markdown, bodyMatches(contains('# Heading')));
/// expect(markdown, bodyMatches(hasLength(greaterThan(100))));
/// ```
Matcher bodyMatches(Matcher matcher) => _BodyMatches(matcher);

// Sentinel for parse failures
const _parseFailed = _ParseFailed();

class _ParseFailed {
  const _ParseFailed();
}

/// Attempts to parse frontmatter, returns _parseFailed on failure.
Object _tryParse(Object? item) {
  if (item is! String) return _parseFailed;
  if (!item.startsWith('---\n')) return _parseFailed;

  try {
    final result = parseMarkdownBody(item);
    // Check if parsing actually succeeded (frontmatter was found)
    if (result.frontmatter.isEmpty && !item.contains('\n---')) {
      return _parseFailed;
    }
    return result;
  } catch (_) {
    return _parseFailed;
  }
}

class _HasValidFrontmatter extends Matcher {
  const _HasValidFrontmatter();

  @override
  bool matches(Object? item, Map<dynamic, dynamic> matchState) {
    final result = _tryParse(item);
    if (result == _parseFailed) return false;
    final parsed = result as ParsedMarkdownBody;
    // Valid if we successfully parsed frontmatter
    return parsed.frontmatter.isNotEmpty || item.toString().contains('\n---');
  }

  @override
  Description describe(Description description) =>
      description.add('has valid frontmatter');

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
    if (!item.startsWith('---\n')) {
      return mismatchDescription.add(
        'does not start with frontmatter delimiter',
      );
    }
    return mismatchDescription.add('failed to parse frontmatter');
  }
}

class _HasFrontmatterTitle extends Matcher {
  const _HasFrontmatterTitle();

  @override
  bool matches(Object? item, Map<dynamic, dynamic> matchState) {
    final result = _tryParse(item);
    if (result == _parseFailed) return false;
    final parsed = result as ParsedMarkdownBody;
    return parsed.title.isNotEmpty;
  }

  @override
  Description describe(Description description) =>
      description.add('has frontmatter title');

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
    final result = _tryParse(item);
    if (result == _parseFailed) {
      return mismatchDescription.add('failed to parse frontmatter');
    }
    return mismatchDescription.add('title is empty or missing');
  }
}

class _HasFrontmatterKey extends Matcher {
  final String key;

  const _HasFrontmatterKey(this.key);

  @override
  bool matches(Object? item, Map<dynamic, dynamic> matchState) {
    final result = _tryParse(item);
    if (result == _parseFailed) return false;
    final parsed = result as ParsedMarkdownBody;
    return parsed.frontmatter.containsKey(key);
  }

  @override
  Description describe(Description description) =>
      description.add('has frontmatter key "$key"');

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
    final result = _tryParse(item);
    if (result == _parseFailed) {
      return mismatchDescription.add('failed to parse frontmatter');
    }
    final parsed = result as ParsedMarkdownBody;
    return mismatchDescription.add(
      'frontmatter keys are: ${parsed.frontmatter.keys.toList()}',
    );
  }
}

class _HasFrontmatterValue extends Matcher {
  final String key;
  final Object? expectedValue;

  const _HasFrontmatterValue(this.key, this.expectedValue);

  @override
  bool matches(Object? item, Map<dynamic, dynamic> matchState) {
    final result = _tryParse(item);
    if (result == _parseFailed) return false;
    final parsed = result as ParsedMarkdownBody;
    if (!parsed.frontmatter.containsKey(key)) return false;
    return parsed.frontmatter[key] == expectedValue;
  }

  @override
  Description describe(Description description) =>
      description.add('has frontmatter "$key" with value $expectedValue');

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
    final result = _tryParse(item);
    if (result == _parseFailed) {
      return mismatchDescription.add('failed to parse frontmatter');
    }
    final parsed = result as ParsedMarkdownBody;
    if (!parsed.frontmatter.containsKey(key)) {
      return mismatchDescription.add('key "$key" not found in frontmatter');
    }
    return mismatchDescription.add(
      'has value ${parsed.frontmatter[key]} for key "$key"',
    );
  }
}

class _FrontmatterKeyMatches extends Matcher {
  final String key;
  final Matcher matcher;

  const _FrontmatterKeyMatches(this.key, this.matcher);

  @override
  bool matches(Object? item, Map<dynamic, dynamic> matchState) {
    final result = _tryParse(item);
    if (result == _parseFailed) return false;
    final parsed = result as ParsedMarkdownBody;
    if (!parsed.frontmatter.containsKey(key)) return false;
    return matcher.matches(parsed.frontmatter[key], matchState);
  }

  @override
  Description describe(Description description) {
    description.add('has frontmatter "$key" that ');
    return matcher.describe(description);
  }

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
    final result = _tryParse(item);
    if (result == _parseFailed) {
      return mismatchDescription.add('failed to parse frontmatter');
    }
    final parsed = result as ParsedMarkdownBody;
    if (!parsed.frontmatter.containsKey(key)) {
      return mismatchDescription.add('key "$key" not found in frontmatter');
    }
    mismatchDescription.add('value ${parsed.frontmatter[key]} ');
    return matcher.describeMismatch(
      parsed.frontmatter[key],
      mismatchDescription,
      matchState,
      verbose,
    );
  }
}

class _HasMarkdownBody extends Matcher {
  const _HasMarkdownBody();

  @override
  bool matches(Object? item, Map<dynamic, dynamic> matchState) {
    final result = _tryParse(item);
    if (result == _parseFailed) return false;
    final parsed = result as ParsedMarkdownBody;
    return parsed.body.trim().isNotEmpty;
  }

  @override
  Description describe(Description description) =>
      description.add('has markdown body');

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
    final result = _tryParse(item);
    if (result == _parseFailed) {
      return mismatchDescription.add('failed to parse frontmatter');
    }
    return mismatchDescription.add('body is empty');
  }
}

class _BodyContains extends Matcher {
  final String text;

  const _BodyContains(this.text);

  @override
  bool matches(Object? item, Map<dynamic, dynamic> matchState) {
    final result = _tryParse(item);
    if (result == _parseFailed) return false;
    final parsed = result as ParsedMarkdownBody;
    return parsed.body.contains(text);
  }

  @override
  Description describe(Description description) =>
      description.add('body contains "$text"');

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
    final result = _tryParse(item);
    if (result == _parseFailed) {
      return mismatchDescription.add('failed to parse frontmatter');
    }
    return mismatchDescription.add('body does not contain "$text"');
  }
}

class _BodyMatches extends Matcher {
  final Matcher matcher;

  const _BodyMatches(this.matcher);

  @override
  bool matches(Object? item, Map<dynamic, dynamic> matchState) {
    final result = _tryParse(item);
    if (result == _parseFailed) return false;
    final parsed = result as ParsedMarkdownBody;
    return matcher.matches(parsed.body, matchState);
  }

  @override
  Description describe(Description description) {
    description.add('body ');
    return matcher.describe(description);
  }

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
    final result = _tryParse(item);
    if (result == _parseFailed) {
      return mismatchDescription.add('failed to parse frontmatter');
    }
    final parsed = result as ParsedMarkdownBody;
    mismatchDescription.add('body ');
    return matcher.describeMismatch(
      parsed.body,
      mismatchDescription,
      matchState,
      verbose,
    );
  }
}
