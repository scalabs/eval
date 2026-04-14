## 0.0.3

- Overhaul the README and public Dartdoc so `eval(...)` is documented as the
  primary workflow instead of raw `test(...)`.
- Document the full exported matcher surface, including the previously omitted
  JSON array, schema-path, frontmatter schema, and RAG matchers.
- Refresh the bundled example to show an end-to-end `eval(...)` run with sync
  and async assertions.
- Reset internal eval run state after each run so `expect(...)` cleanly falls
  back to normal test behavior outside an active eval.

## 0.0.2

- Align package metadata and documentation with the published API.
- Fix async LLM and RAG matcher behavior so sync `expect(...)` usage fails with clear guidance instead of silently succeeding.
- Fix `APICallQueue` recovery so one failed request does not poison later queued calls.
- Preserve detailed `evaluateRag()` metadata including relevant context indices, unsupported claims, and joined metric reasons.
- Treat empty frontmatter as valid frontmatter and reject malformed YAML with closing delimiters.
- Distinguish missing paths from explicit `null` values in schema-based path matchers.

## 0.0.1

- Initial public release of the `eval` package.
- Added string, JSON, schema, frontmatter, distance, LLM-judge, and RAG matchers.
- Added aggregate statistics and prompt comparison helpers.
- Added the `APICallService` abstraction and the bundled Claude example service.
