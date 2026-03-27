import 'dart:math' as math;

import 'package:matcher/matcher.dart';

/// Matches a string where the Levenshtein edit distance to [reference]
/// is less than [threshold].
///
/// Edit distance is the minimum number of single-character edits
/// (insertions, deletions, or substitutions) required to change
/// one string into another.
///
/// Example:
/// ```dart
/// expect('hello', editDistanceLessThan('hallo', 2)); // distance is 1
/// expect('kitten', editDistanceLessThan('sitting', 4)); // distance is 3
/// ```
Matcher editDistanceLessThan(String reference, int threshold) =>
    _EditDistanceLessThan(reference, threshold);

/// Matches a string where the normalized edit distance ratio to [reference]
/// is less than [threshold].
///
/// The ratio is calculated as: distance / max(len1, len2)
/// Returns a value between 0.0 (identical) and 1.0 (completely different).
///
/// Example:
/// ```dart
/// expect('hello', editDistanceRatio('hallo', 0.3)); // ratio ~0.2
/// ```
Matcher editDistanceRatio(String reference, double threshold) =>
    _EditDistanceRatio(reference, threshold);

/// Matches a string where the Jaro-Winkler similarity to [reference]
/// is greater than or equal to [threshold].
///
/// Jaro-Winkler similarity returns a value between 0.0 (no similarity)
/// and 1.0 (exact match). It gives more favorable ratings to strings
/// that match from the beginning.
///
/// Example:
/// ```dart
/// expect('MARTHA', jaroWinklerSimilarity('MARHTA', 0.9)); // similarity ~0.96
/// ```
Matcher jaroWinklerSimilarity(String reference, double threshold) =>
    _JaroWinklerSimilarity(reference, threshold);

/// Calculates the Levenshtein edit distance between two strings.
int levenshteinDistance(String s1, String s2) {
  if (s1 == s2) return 0;
  if (s1.isEmpty) return s2.length;
  if (s2.isEmpty) return s1.length;

  // Create two rows for the dynamic programming table
  var previousRow = List<int>.generate(s2.length + 1, (i) => i);
  var currentRow = List<int>.filled(s2.length + 1, 0);

  for (var i = 0; i < s1.length; i++) {
    currentRow[0] = i + 1;

    for (var j = 0; j < s2.length; j++) {
      final cost = s1[i] == s2[j] ? 0 : 1;
      currentRow[j + 1] = [
        currentRow[j] + 1, // insertion
        previousRow[j + 1] + 1, // deletion
        previousRow[j] + cost, // substitution
      ].reduce(math.min);
    }

    // Swap rows
    final temp = previousRow;
    previousRow = currentRow;
    currentRow = temp;
  }

  return previousRow[s2.length];
}

/// Calculates the Jaro similarity between two strings.
double jaroSimilarity(String s1, String s2) {
  if (s1 == s2) return 1.0;
  if (s1.isEmpty || s2.isEmpty) return 0.0;

  final matchDistance = (math.max(s1.length, s2.length) ~/ 2) - 1;
  final s1Matches = List<bool>.filled(s1.length, false);
  final s2Matches = List<bool>.filled(s2.length, false);

  var matches = 0;
  var transpositions = 0;

  // Find matches
  for (var i = 0; i < s1.length; i++) {
    final start = math.max(0, i - matchDistance);
    final end = math.min(i + matchDistance + 1, s2.length);

    for (var j = start; j < end; j++) {
      if (s2Matches[j] || s1[i] != s2[j]) continue;
      s1Matches[i] = true;
      s2Matches[j] = true;
      matches++;
      break;
    }
  }

  if (matches == 0) return 0.0;

  // Count transpositions
  var k = 0;
  for (var i = 0; i < s1.length; i++) {
    if (!s1Matches[i]) continue;
    while (!s2Matches[k]) {
      k++;
    }
    if (s1[i] != s2[k]) transpositions++;
    k++;
  }

  return (matches / s1.length +
          matches / s2.length +
          (matches - transpositions / 2) / matches) /
      3;
}

/// Calculates the Jaro-Winkler similarity between two strings.
double jaroWinklerSimilarityScore(String s1, String s2, {double p = 0.1}) {
  final jaro = jaroSimilarity(s1, s2);

  // Find common prefix (up to 4 characters)
  var prefixLength = 0;
  for (var i = 0; i < math.min(4, math.min(s1.length, s2.length)); i++) {
    if (s1[i] == s2[i]) {
      prefixLength++;
    } else {
      break;
    }
  }

  return jaro + prefixLength * p * (1 - jaro);
}

class _EditDistanceLessThan extends Matcher {
  final String reference;
  final int threshold;

  const _EditDistanceLessThan(this.reference, this.threshold);

  @override
  bool matches(Object? item, Map<dynamic, dynamic> matchState) {
    if (item is! String) return false;
    final distance = levenshteinDistance(item, reference);
    matchState['distance'] = distance;
    return distance < threshold;
  }

  @override
  Description describe(Description description) => description.add(
    'has edit distance less than $threshold from "$reference"',
  );

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
    final distance = matchState['distance'] as int?;
    return mismatchDescription.add('has edit distance of $distance');
  }
}

class _EditDistanceRatio extends Matcher {
  final String reference;
  final double threshold;

  const _EditDistanceRatio(this.reference, this.threshold);

  @override
  bool matches(Object? item, Map<dynamic, dynamic> matchState) {
    if (item is! String) return false;
    final distance = levenshteinDistance(item, reference);
    final maxLen = math.max(item.length, reference.length);
    final ratio = maxLen == 0 ? 0.0 : distance / maxLen;
    matchState['ratio'] = ratio;
    matchState['distance'] = distance;
    return ratio < threshold;
  }

  @override
  Description describe(Description description) => description.add(
    'has edit distance ratio less than $threshold from "$reference"',
  );

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
    final ratio = matchState['ratio'] as double?;
    return mismatchDescription.add(
      'has edit distance ratio of ${ratio?.toStringAsFixed(3)}',
    );
  }
}

class _JaroWinklerSimilarity extends Matcher {
  final String reference;
  final double threshold;

  const _JaroWinklerSimilarity(this.reference, this.threshold);

  @override
  bool matches(Object? item, Map<dynamic, dynamic> matchState) {
    if (item is! String) return false;
    final similarity = jaroWinklerSimilarityScore(item, reference);
    matchState['similarity'] = similarity;
    return similarity >= threshold;
  }

  @override
  Description describe(Description description) => description.add(
    'has Jaro-Winkler similarity >= $threshold with "$reference"',
  );

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
    final similarity = matchState['similarity'] as double?;
    return mismatchDescription.add(
      'has Jaro-Winkler similarity of ${similarity?.toStringAsFixed(3)}',
    );
  }
}
