import 'package:yaml/yaml.dart';

typedef ParsedMarkdownBody = ({
  String title,
  Map<String, dynamic> frontmatter,
  String body,
});

ParsedMarkdownBody parseMarkdownBody(String body) {
  if (!body.startsWith('---\n')) {
    return (title: '', frontmatter: {}, body: body);
  }

  final endIndex = body.indexOf('\n---', 4);
  if (endIndex == -1) {
    return (title: '', frontmatter: {}, body: body);
  }

  final yamlString = body.substring(4, endIndex);
  final markdown = body.substring(endIndex + 4).trim();

  try {
    final frontMatter = loadYaml(yamlString) as Map;
    return (
      title: frontMatter['title'] ?? '',
      frontmatter: Map<String, dynamic>.from(frontMatter),
      body: markdown,
    );
  } catch (_) {
    return (title: '', frontmatter: <String, dynamic>{}, body: body);
  }
}
