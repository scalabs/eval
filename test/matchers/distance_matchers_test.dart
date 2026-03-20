import 'package:eval/eval.dart' hide expect;
import 'package:test/test.dart';

void main() {
  group('levenshteinDistance', () {
    test('returns 0 for identical strings', () {
      expect(levenshteinDistance('hello', 'hello'), equals(0));
      expect(levenshteinDistance('', ''), equals(0));
    });

    test('returns length for empty comparison', () {
      expect(levenshteinDistance('hello', ''), equals(5));
      expect(levenshteinDistance('', 'world'), equals(5));
    });

    test('calculates single character edits', () {
      expect(levenshteinDistance('hello', 'hallo'), equals(1)); // substitution
      expect(levenshteinDistance('hello', 'helloo'), equals(1)); // insertion
      expect(levenshteinDistance('hello', 'helo'), equals(1)); // deletion
    });

    test('calculates multiple edits', () {
      expect(levenshteinDistance('kitten', 'sitting'), equals(3));
      expect(levenshteinDistance('sunday', 'saturday'), equals(3));
    });
  });

  group('editDistanceLessThan', () {
    test('matches when distance is below threshold', () {
      expect('hello', editDistanceLessThan('hallo', 2));
      expect('kitten', editDistanceLessThan('sitting', 4));
    });

    test('does not match when distance equals threshold', () {
      expect('hello', isNot(editDistanceLessThan('hallo', 1)));
    });

    test('does not match when distance exceeds threshold', () {
      expect('hello', isNot(editDistanceLessThan('world', 3)));
    });

    test('matches identical strings with any threshold', () {
      expect('hello', editDistanceLessThan('hello', 1));
    });
  });

  group('editDistanceRatio', () {
    test('matches when ratio is below threshold', () {
      expect('hello', editDistanceRatio('hallo', 0.3)); // 1/5 = 0.2
    });

    test('does not match when ratio exceeds threshold', () {
      expect('hello', isNot(editDistanceRatio('world', 0.5))); // 4/5 = 0.8
    });

    test('matches identical strings', () {
      expect('hello', editDistanceRatio('hello', 0.01)); // 0/5 = 0.0
    });

    test('handles empty strings', () {
      expect('', editDistanceRatio('', 0.01)); // 0/0 = 0.0 (clamped)
    });
  });

  group('jaroSimilarity', () {
    test('returns 1.0 for identical strings', () {
      expect(jaroSimilarity('hello', 'hello'), equals(1.0));
    });

    test('returns 0.0 for empty string comparison', () {
      expect(jaroSimilarity('hello', ''), equals(0.0));
      expect(jaroSimilarity('', 'world'), equals(0.0));
    });

    test('calculates similarity for similar strings', () {
      final similarity = jaroSimilarity('MARTHA', 'MARHTA');
      expect(similarity, greaterThan(0.9));
    });

    test('returns lower score for dissimilar strings', () {
      final similarity = jaroSimilarity('hello', 'world');
      expect(similarity, lessThan(0.5));
    });
  });

  group('jaroWinklerSimilarityScore', () {
    test('returns 1.0 for identical strings', () {
      expect(jaroWinklerSimilarityScore('hello', 'hello'), equals(1.0));
    });

    test('boosts score for common prefix', () {
      final jaro = jaroSimilarity('MARTHA', 'MARHTA');
      final jaroWinkler = jaroWinklerSimilarityScore('MARTHA', 'MARHTA');
      expect(jaroWinkler, greaterThan(jaro));
    });

    test('prefix boost limited to 4 characters', () {
      final sim1 = jaroWinklerSimilarityScore('abcdefgh', 'abcdxxxx');
      final sim2 = jaroWinklerSimilarityScore('abcdefgh', 'abcdeyyy');
      // Both should have similar boost since prefix limit is 4
      expect((sim1 - sim2).abs(), lessThan(0.1));
    });
  });

  group('jaroWinklerSimilarity matcher', () {
    test('matches when similarity meets threshold', () {
      expect('MARTHA', jaroWinklerSimilarity('MARHTA', 0.9));
      expect('hello', jaroWinklerSimilarity('hello', 1.0));
    });

    test('does not match when similarity below threshold', () {
      expect('hello', isNot(jaroWinklerSimilarity('world', 0.9)));
    });

    test('handles case sensitivity', () {
      // Default is case-sensitive
      final sim = jaroWinklerSimilarityScore('Hello', 'hello');
      expect(sim, lessThan(1.0));
    });
  });
}
