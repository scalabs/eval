import 'package:yaml/yaml.dart';

typedef ParsedMarkdownBody = ({
  String title,
  Map<String, dynamic> frontmatter,
  String body,
});

typedef ParsedMarkdownDocument = ({
  bool hasFrontmatter,
  bool isValidFrontmatter,
  String title,
  Map<String, dynamic> frontmatter,
  String body,
});

final _frontmatterPattern = RegExp(
  r'^---\n([\s\S]*?)^---(?:\n|$)',
  multiLine: true,
);

/// Recursively converts immutable [YamlMap]/[YamlList] to mutable Dart
/// [Map<String, dynamic>] and [List].
///
/// [loadYaml] returns immutable YAML types. A shallow `Map.from()` only makes
/// the top-level map mutable — nested structures (lists, maps) stay immutable
/// and throw [UnsupportedError] on mutation. This function deep-converts the
/// entire tree so callers can freely mutate any level.
dynamic deepConvertYaml(dynamic value) {
  if (value is Map) {
    return <String, dynamic>{
      for (final entry in value.entries)
        entry.key.toString(): deepConvertYaml(entry.value),
    };
  }
  if (value is List) {
    return value.map(deepConvertYaml).toList();
  }
  return value;
}

ParsedMarkdownDocument inspectMarkdownBody(String source) {
  if (!source.startsWith('---\n')) {
    return (
      hasFrontmatter: false,
      isValidFrontmatter: false,
      title: '',
      frontmatter: <String, dynamic>{},
      body: source,
    );
  }

  final match = _frontmatterPattern.firstMatch(source);
  if (match == null) {
    return (
      hasFrontmatter: true,
      isValidFrontmatter: false,
      title: '',
      frontmatter: <String, dynamic>{},
      body: source,
    );
  }

  final yamlString = match.group(1)!;
  final markdown = source.substring(match.end).trim();

  try {
    final parsedYaml = loadYaml(yamlString);
    if (parsedYaml != null && parsedYaml is! Map) {
      throw const FormatException(
        'Expected YAML frontmatter to parse to a map.',
      );
    }
    final frontmatter = parsedYaml == null
        ? <String, dynamic>{}
        : deepConvertYaml(parsedYaml) as Map<String, dynamic>;
    final title = frontmatter['title'];

    return (
      hasFrontmatter: true,
      isValidFrontmatter: true,
      title: title is String ? title : '',
      frontmatter: frontmatter,
      body: markdown,
    );
  } catch (_) {
    return (
      hasFrontmatter: true,
      isValidFrontmatter: false,
      title: '',
      frontmatter: <String, dynamic>{},
      body: source,
    );
  }
}

ParsedMarkdownBody parseMarkdownBody(String body) {
  final parsed = inspectMarkdownBody(body);
  return (
    title: parsed.title,
    frontmatter: parsed.frontmatter,
    body: parsed.body,
  );
}
