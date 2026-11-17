## TensorBuzz path filtering

The five effective lanes in `peak_flow.yml` intentionally share the same path
rules:

```yaml
paths:
  - "**/*"
  - "!docs/**"
```

Each test lane exercises the complete suite at its configured interpreter, so
there is no truthful source-path family that belongs to only one lane. The
whole-graph rule keeps every code, dependency, lockfile, and CI configuration
change eligible for every affected lane. The final negation makes a docs-only
change a safe no-build case without pretending that the test lanes are
independently partitioned.

The duplicate `build_5` key was removed by retaining the effective Linters
lane. This keeps the parsed graph at five lanes instead of silently replacing
one lane through YAML key collision.
