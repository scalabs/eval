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
    final frontmatter = parsedYaml == null
        ? <String, dynamic>{}
        : _normalizeYamlMap(parsedYaml);
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

Map<String, dynamic> _normalizeYamlMap(Object? value) {
  if (value is! Map) {
    throw FormatException('Expected YAML frontmatter to parse to a map.');
  }

  return {
    for (final entry in value.entries)
      entry.key.toString(): _normalizeYamlValue(entry.value),
  };
}

dynamic _normalizeYamlValue(Object? value) {
  if (value is YamlMap) {
    return _normalizeYamlMap(value);
  }
  if (value is YamlList) {
    return value.map(_normalizeYamlValue).toList();
  }
  return value;
}
