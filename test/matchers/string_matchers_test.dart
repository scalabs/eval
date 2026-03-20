import 'package:eval/eval.dart' hide expect;
import 'package:test/test.dart';

void main() {
  group('containsIgnoreCase', () {
    test('matches case-insensitive substring', () {
      expect('Hello World', containsIgnoreCase('hello'));
      expect('Hello World', containsIgnoreCase('WORLD'));
      expect('Hello World', containsIgnoreCase('Hello World'));
    });

    test('does not match missing substring', () {
      expect('Hello World', isNot(containsIgnoreCase('goodbye')));
    });

    test('does not match non-string', () {
      expect(123, isNot(containsIgnoreCase('123')));
    });
  });

  group('matchesPattern', () {
    test('matches regex pattern', () {
      expect('user@example.com', matchesPattern(r'[\w.]+@[\w.]+\.\w+'));
      expect('123-456-7890', matchesPattern(r'\d{3}-\d{3}-\d{4}'));
    });

    test('matches partial pattern', () {
      expect('Hello World', matchesPattern(r'World'));
    });

    test('does not match non-matching pattern', () {
      expect('Hello World', isNot(matchesPattern(r'^\d+$')));
    });

    test('works with RegExp object', () {
      expect(
        'Hello World',
        matchesPattern(RegExp(r'hello', caseSensitive: false)),
      );
    });
  });

  group('containsAllWords', () {
    test('matches when all words present', () {
      expect('The quick brown fox', containsAllWords(['quick', 'fox']));
      expect('Hello World', containsAllWords(['hello', 'world']));
    });

    test('matches case-insensitive', () {
      expect('HELLO WORLD', containsAllWords(['hello', 'world']));
    });

    test('does not match when word missing', () {
      expect('The quick brown fox', isNot(containsAllWords(['quick', 'cat'])));
    });

    test('requires whole word match', () {
      expect('The quickest fox', isNot(containsAllWords(['quick'])));
    });
  });

  group('containsAnyOf', () {
    test('matches when any pattern present', () {
      expect('Hello World', containsAnyOf(['hello', 'goodbye']));
      expect('Error occurred', containsAnyOf(['error', 'warning', 'info']));
    });

    test('matches case-insensitive', () {
      expect('HELLO World', containsAnyOf(['hello']));
    });

    test('does not match when no patterns present', () {
      expect('Hello World', isNot(containsAnyOf(['goodbye', 'farewell'])));
    });
  });

  group('containsNoneOf', () {
    test('matches when no patterns present', () {
      expect('Hello World', containsNoneOf(['error', 'warning']));
    });

    test('does not match when any pattern present', () {
      expect('Error occurred', isNot(containsNoneOf(['error', 'warning'])));
    });

    test('checks case-insensitive', () {
      expect('ERROR occurred', isNot(containsNoneOf(['error'])));
    });
  });

  group('wordCountBetween', () {
    test('matches within range', () {
      expect('Hello World', wordCountBetween(1, 5));
      expect('One two three four five', wordCountBetween(5, 5));
    });

    test('matches at boundaries', () {
      expect('Hello', wordCountBetween(1, 1));
      expect('Hello World', wordCountBetween(2, 2));
    });

    test('does not match outside range', () {
      expect('Hello World', isNot(wordCountBetween(3, 5)));
      expect('One two three four five', isNot(wordCountBetween(1, 3)));
    });

    test('handles empty string', () {
      expect('', wordCountBetween(0, 0));
      expect('', isNot(wordCountBetween(1, 5)));
    });

    test('handles multiple spaces', () {
      expect('Hello    World', wordCountBetween(2, 2));
    });
  });

  group('sentenceCountBetween', () {
    test('matches sentence count', () {
      expect('Hello. World!', sentenceCountBetween(2, 2));
      expect('One sentence.', sentenceCountBetween(1, 1));
    });

    test('matches within range', () {
      expect('First. Second. Third.', sentenceCountBetween(2, 4));
    });

    test('handles different punctuation', () {
      expect('Hello! How are you? Fine.', sentenceCountBetween(3, 3));
    });

    test('does not match outside range', () {
      expect('One. Two. Three.', isNot(sentenceCountBetween(1, 2)));
    });

    test('handles text without sentence endings', () {
      expect('Hello World', sentenceCountBetween(0, 0));
    });
  });
}
