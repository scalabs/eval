import 'package:matcher/matcher.dart';

/// Matches a string that contains [pattern] (case-insensitive).
///
/// Example:
/// ```dart
/// expect('Hello World', containsIgnoreCase('HELLO'));
/// expect('Hello World', containsIgnoreCase('world'));
/// ```
Matcher containsIgnoreCase(String pattern) => _ContainsIgnoreCase(pattern);

/// Matches a string that matches the given [regex] pattern.
///
/// Example:
/// ```dart
/// expect('user@example.com', matchesPattern(r'^[\w.]+@[\w.]+\.\w+$'));
/// expect('123-456-7890', matchesPattern(r'^\d{3}-\d{3}-\d{4}$'));
/// ```
Matcher matchesPattern(Pattern regex) => _MatchesPattern(regex);

/// Matches a string that contains all of the specified [words] (order-independent).
///
/// Words are matched case-insensitively and must appear as whole words.
///
/// Example:
/// ```dart
/// expect('The quick brown fox', containsAllWords(['quick', 'fox']));
/// ```
Matcher containsAllWords(List<String> words) => _ContainsAllWords(words);

/// Matches a string that contains at least one of the specified [patterns].
///
/// Example:
/// ```dart
/// expect('Hello World', containsAnyOf(['hello', 'goodbye']));
/// expect('Error occurred', containsAnyOf(['error', 'warning', 'info']));
/// ```
Matcher containsAnyOf(List<String> patterns) => _ContainsAnyOf(patterns);

/// Matches a string that contains none of the specified [patterns].
///
/// Useful for blacklist checking.
///
/// Example:
/// ```dart
/// expect('Hello World', containsNoneOf(['error', 'warning']));
/// ```
Matcher containsNoneOf(List<String> patterns) => _ContainsNoneOf(patterns);

/// Matches a string with word count between [min] and [max] (inclusive).
///
/// Example:
/// ```dart
/// expect('Hello World', wordCountBetween(1, 5));
/// expect('This is a longer sentence', wordCountBetween(3, 10));
/// ```
Matcher wordCountBetween(int min, int max) => _WordCountBetween(min, max);

/// Matches a string with sentence count between [min] and [max] (inclusive).
///
/// Sentences are detected by `.`, `!`, or `?` followed by space or end of string.
///
/// Example:
/// ```dart
/// expect('Hello. World!', sentenceCountBetween(1, 3));
/// ```
Matcher sentenceCountBetween(int min, int max) =>
    _SentenceCountBetween(min, max);

class _ContainsIgnoreCase extends Matcher {
  final String pattern;

  const _ContainsIgnoreCase(this.pattern);

  @override
  bool matches(Object? item, Map<dynamic, dynamic> matchState) {
    if (item is! String) return false;
    return item.toLowerCase().contains(pattern.toLowerCase());
  }

  @override
  Description describe(Description description) =>
      description.add('contains "$pattern" (case-insensitive)');

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
    return mismatchDescription.add('does not contain "$pattern"');
  }
}

class _MatchesPattern extends Matcher {
  final Pattern pattern;

  const _MatchesPattern(this.pattern);

  @override
  bool matches(Object? item, Map<dynamic, dynamic> matchState) {
    if (item is! String) return false;
    final regex =
        pattern is RegExp ? pattern as RegExp : RegExp(pattern.toString());
    return regex.hasMatch(item);
  }

  @override
  Description describe(Description description) =>
      description.add('matches pattern $pattern');

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
    return mismatchDescription.add('does not match pattern');
  }
}

class _ContainsAllWords extends Matcher {
  final List<String> words;

  const _ContainsAllWords(this.words);

  @override
  bool matches(Object? item, Map<dynamic, dynamic> matchState) {
    if (item is! String) return false;
    final lowerItem = item.toLowerCase();
    final missingWords = <String>[];

    for (final word in words) {
      // Match whole words using word boundaries
      final regex = RegExp(r'\b' + RegExp.escape(word.toLowerCase()) + r'\b');
      if (!regex.hasMatch(lowerItem)) {
        missingWords.add(word);
      }
    }

    if (missingWords.isNotEmpty) {
      matchState['missing'] = missingWords;
      return false;
    }
    return true;
  }

  @override
  Description describe(Description description) =>
      description.add('contains all words: ${words.join(", ")}');

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
    final missing = matchState['missing'] as List<String>?;
    if (missing != null && missing.isNotEmpty) {
      return mismatchDescription.add('missing words: ${missing.join(", ")}');
    }
    return mismatchDescription;
  }
}

class _ContainsAnyOf extends Matcher {
  final List<String> patterns;

  const _ContainsAnyOf(this.patterns);

  @override
  bool matches(Object? item, Map<dynamic, dynamic> matchState) {
    if (item is! String) return false;
    final lowerItem = item.toLowerCase();
    return patterns.any((p) => lowerItem.contains(p.toLowerCase()));
  }

  @override
  Description describe(Description description) =>
      description.add('contains any of: ${patterns.join(", ")}');

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
    return mismatchDescription.add('contains none of the patterns');
  }
}

class _ContainsNoneOf extends Matcher {
  final List<String> patterns;

  const _ContainsNoneOf(this.patterns);

  @override
  bool matches(Object? item, Map<dynamic, dynamic> matchState) {
    if (item is! String) return false;
    final lowerItem = item.toLowerCase();
    for (final pattern in patterns) {
      if (lowerItem.contains(pattern.toLowerCase())) {
        matchState['found'] = pattern;
        return false;
      }
    }
    return true;
  }

  @override
  Description describe(Description description) =>
      description.add('contains none of: ${patterns.join(", ")}');

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
    final found = matchState['found'] as String?;
    if (found != null) {
      return mismatchDescription.add('contains blacklisted pattern "$found"');
    }
    return mismatchDescription;
  }
}

class _WordCountBetween extends Matcher {
  final int min;
  final int max;

  const _WordCountBetween(this.min, this.max);

  int _countWords(String text) {
    final words = text.trim().split(RegExp(r'\s+'));
    return words.where((w) => w.isNotEmpty).length;
  }

  @override
  bool matches(Object? item, Map<dynamic, dynamic> matchState) {
    if (item is! String) return false;
    final count = _countWords(item);
    matchState['count'] = count;
    return count >= min && count <= max;
  }

  @override
  Description describe(Description description) =>
      description.add('has word count between $min and $max');

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
    final count = matchState['count'] as int?;
    return mismatchDescription.add('has $count words');
  }
}

class _SentenceCountBetween extends Matcher {
  final int min;
  final int max;

  const _SentenceCountBetween(this.min, this.max);

  int _countSentences(String text) {
    // Match sentence-ending punctuation followed by space or end of string
    final matches = RegExp(r'[.!?]+(?:\s|$)').allMatches(text);
    return matches.length;
  }

  @override
  bool matches(Object? item, Map<dynamic, dynamic> matchState) {
    if (item is! String) return false;
    final count = _countSentences(item);
    matchState['count'] = count;
    return count >= min && count <= max;
  }

  @override
  Description describe(Description description) =>
      description.add('has sentence count between $min and $max');

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
    final count = matchState['count'] as int?;
    return mismatchDescription.add('has $count sentences');
  }
}
