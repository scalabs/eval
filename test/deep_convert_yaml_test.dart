import 'package:eval/src/md_file.dart';
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

void main() {
  group('deepConvertYaml', () {
    test('converts YamlMap to mutable Map<String, dynamic>', () {
      final yaml = loadYaml('key: value') as YamlMap;
      final result = deepConvertYaml(yaml);

      expect(result, isA<Map<String, dynamic>>());
      expect(result['key'], 'value');

      // Must be mutable
      result['key'] = 'changed';
      expect(result['key'], 'changed');

      result['newKey'] = 'added';
      expect(result['newKey'], 'added');
    });

    test('converts YamlList to mutable List', () {
      final yaml = loadYaml('[a, b, c]') as YamlList;
      final result = deepConvertYaml(yaml);

      expect(result, isA<List>());
      expect(result, ['a', 'b', 'c']);

      // Must be mutable
      result[0] = 'changed';
      expect(result[0], 'changed');

      result.add('d');
      expect(result.length, 4);
    });

    test('deep-converts nested YamlMap inside YamlList', () {
      final yaml =
          loadYaml('''
- name: Alice
  age: 30
- name: Bob
  age: 25
''')
              as YamlList;

      final result = deepConvertYaml(yaml) as List;

      // Nested maps must be mutable
      expect(result[0], isA<Map<String, dynamic>>());
      result[0]['name'] = 'Charlie';
      expect(result[0]['name'], 'Charlie');

      result[0]['newField'] = true;
      expect(result[0]['newField'], true);
    });

    test('deep-converts nested YamlList inside YamlMap', () {
      final yaml =
          loadYaml('''
tags:
  - dart
  - yaml
''')
              as YamlMap;

      final result = deepConvertYaml(yaml) as Map<String, dynamic>;

      expect(result['tags'], isA<List>());
      result['tags'][0] = 'flutter';
      expect(result['tags'][0], 'flutter');

      result['tags'].add('test');
      expect(result['tags'].length, 3);
    });

    test('deep-converts 3+ levels of nesting', () {
      final yaml =
          loadYaml('''
slides:
  - image: https://example.com/img.jpg
    sections:
      - title: Hello
        styles:
          color: white
          background_color: gradient-black
''')
              as YamlMap;

      final result = deepConvertYaml(yaml) as Map<String, dynamic>;

      // Level 1: slides list
      final slides = result['slides'] as List;
      expect(slides, isA<List>());

      // Level 2: slide map
      final slide = slides[0] as Map<String, dynamic>;
      slide['image'] = 'https://cloudinary.com/new.jpg';
      expect(slide['image'], 'https://cloudinary.com/new.jpg');

      // Level 3: sections list → section map
      final section = (slide['sections'] as List)[0] as Map<String, dynamic>;
      section['title'] = 'Changed';
      expect(section['title'], 'Changed');

      // Level 4: styles map
      final styles = section['styles'] as Map<String, dynamic>;
      styles['color'] = 'black';
      expect(styles['color'], 'black');

      styles['text_animation'] = 'fade-in';
      expect(styles['text_animation'], 'fade-in');
    });

    test('passes through primitives unchanged', () {
      expect(deepConvertYaml('hello'), 'hello');
      expect(deepConvertYaml(42), 42);
      expect(deepConvertYaml(3.14), 3.14);
      expect(deepConvertYaml(true), true);
      expect(deepConvertYaml(null), null);
    });

    test('is idempotent on already-mutable data', () {
      final input = <String, dynamic>{
        'slides': [
          <String, dynamic>{
            'image': 'url',
            'sections': [
              <String, dynamic>{'title': 'Hi'},
            ],
          },
        ],
      };

      final result = deepConvertYaml(input) as Map<String, dynamic>;

      expect(result['slides'][0]['image'], 'url');
      result['slides'][0]['image'] = 'changed';
      expect(result['slides'][0]['image'], 'changed');
    });

    test('converts YamlMap keys to String', () {
      // YAML keys can technically be non-strings; deepConvertYaml should
      // call .toString() on them
      final yaml = loadYaml('42: answer') as YamlMap;
      final result = deepConvertYaml(yaml) as Map<String, dynamic>;

      expect(result.containsKey('42'), isTrue);
      expect(result['42'], 'answer');
    });

    test('handles empty map', () {
      final yaml = loadYaml('{}') as YamlMap;
      final result = deepConvertYaml(yaml) as Map<String, dynamic>;

      expect(result, isEmpty);
      result['key'] = 'value';
      expect(result['key'], 'value');
    });

    test('handles empty list', () {
      final yaml = loadYaml('[]') as YamlList;
      final result = deepConvertYaml(yaml) as List;

      expect(result, isEmpty);
      result.add('item');
      expect(result.length, 1);
    });
  });

  group('parseMarkdownBody returns mutable nested data', () {
    test('story slides can be mutated after parsing', () {
      const storyYaml = '''---
title: Test Story
slides:
  - image: https://example.com/broken.jpg
    animation: fade-in
    sections:
      - title: Intro
        styles:
          color: white
          background_color: gradient-black
  - image: https://example.com/img2.jpg
    sections:
      - title: Second Slide
---

Body content.
''';

      final parsed = parseMarkdownBody(storyYaml);
      final slides = parsed.frontmatter['slides'] as List;

      // This is THE mutation that was throwing UnsupportedError before the fix
      expect(
        () => slides[0]['image'] = 'https://cloudinary.com/replaced.jpg',
        returnsNormally,
      );
      expect(slides[0]['image'], 'https://cloudinary.com/replaced.jpg');
    });

    test('nested section styles can be mutated after parsing', () {
      const yaml = '''---
title: Style Test
slides:
  - sections:
      - title: Hello
        styles:
          color: white
---
''';

      final parsed = parseMarkdownBody(yaml);
      final slide = (parsed.frontmatter['slides'] as List)[0];
      final section = (slide['sections'] as List)[0] as Map<String, dynamic>;
      final styles = section['styles'] as Map<String, dynamic>;

      expect(
        () => styles['background_color'] = 'gradient-black',
        returnsNormally,
      );
      expect(styles['background_color'], 'gradient-black');

      expect(() => styles['text_animation'] = 'fade-in', returnsNormally);
    });

    test('new keys can be added to parsed slide maps', () {
      const yaml = '''---
title: Add Key Test
slides:
  - sections:
      - title: No Image Slide
---
''';

      final parsed = parseMarkdownBody(yaml);
      final slide =
          (parsed.frontmatter['slides'] as List)[0] as Map<String, dynamic>;

      // Adding 'image' to a text-only slide — must not throw
      expect(
        () => slide['image'] = 'https://cloudinary.com/unsplash.jpg',
        returnsNormally,
      );
      expect(slide['image'], 'https://cloudinary.com/unsplash.jpg');
    });

    test('slides list can be replaced on frontmatter', () {
      const yaml = '''---
title: Replace Test
slides:
  - image: https://example.com/a.jpg
    sections:
      - title: A
---
''';

      final parsed = parseMarkdownBody(yaml);

      // This is what processStoryImages does: replace the slides list
      expect(
        () => parsed.frontmatter['slides'] = [
          {'image': 'new.jpg', 'sections': []},
        ],
        returnsNormally,
      );
    });

    test('gallery items can be mutated after parsing', () {
      const yaml = '''---
title: Gallery Test
image: https://example.com/lead.jpg
gallery:
  - image: https://example.com/g1.jpg
    label: Photo 1
  - image: https://example.com/g2.jpg
    label: Photo 2
---

Body.
''';

      final parsed = parseMarkdownBody(yaml);
      final gallery = parsed.frontmatter['gallery'] as List;

      // Gallery items must be mutable for replaceImages()
      expect(
        () => (gallery[0] as Map)['image'] = 'https://cloudinary.com/g1.jpg',
        returnsNormally,
      );
      expect((gallery[0] as Map)['image'], 'https://cloudinary.com/g1.jpg');
    });

    test('previously this threw UnsupportedError with shallow copy', () {
      // Reproduce the exact scenario that was failing in production:
      // 1. LLM returns story YAML
      // 2. parseMarkdownBody parses it
      // 3. processStoryImages tries to assign slide['image']
      const llmResponse = '''---
title: Breaking News Story
slides:
  - image: https://hallucinated-url.com/fake.jpg
    animation: fade-in
    duration: 5s
    orientation: middle
    sections:
      - title: Breaking News
        body: Something happened
        styles:
          color: white
          background_color: gradient-black
          text_animation: fade-in
  - sections:
      - title: Text Only Slide
        styles:
          color: black
          background_color: gradient-white
---

Source content.
''';

      final parsed = parseMarkdownBody(llmResponse);
      final slides = parsed.frontmatter['slides'] as List;

      // Slide 0: replace broken image URL
      expect(
        () => slides[0]['image'] =
            'https://res.cloudinary.com/x/image/upload/v1/fixed.jpg',
        returnsNormally,
      );

      // Slide 1: add image to text-only slide (the second pass)
      expect(
        () => slides[1]['image'] =
            'https://res.cloudinary.com/x/image/upload/v1/unsplash.jpg',
        returnsNormally,
      );

      // Verify both mutations took effect
      expect(slides[0]['image'], contains('cloudinary.com'));
      expect(slides[1]['image'], contains('cloudinary.com'));

      // Verify we can also modify nested styles
      final styles =
          ((slides[0]['sections'] as List)[0] as Map)['styles'] as Map;
      expect(() => styles['color'] = 'black', returnsNormally);
    });
  });
}
