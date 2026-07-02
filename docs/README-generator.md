---
type: Reference
title: Docs Index Generator
description: How to regenerate the OKF bundle's index.md files and validate the bundle in CI.
---

# Docs Index Generator

Every `index.md` under `docs/` (root + one per section: `ARCHITECTURE/`, `SYSTEMS/`,
`REFERENCE/`, `DATA_MODELS/`, `OPERATIONS/`, `FEATURES/`, `RESEARCH/`, `ADR/`) is
**generated** — never hand-edit them. Run the generator from the repo root:

```bash
node scripts/generate-docs-index.mjs          # (re)generate the indexes
node scripts/generate-docs-index.mjs --check  # validate only, exit non-zero on any failure
```

`--check` is the CI/pre-commit gate: it catches unparseable or `type`-less frontmatter,
dangling bundle-relative cross-links, stale (out-of-date) indexes, and orphaned concepts
missing from their section index. No external dependencies — the generator ships as one
plain Node ESM script, per this project's zero-new-dependency constraint.

Full design + CI contract: `.samantha/references/canonical-docs-system/INDEX-generator.README.md`.
The bundle's frontmatter/format rules: `.samantha/references/okf-format.md`.
