#!/usr/bin/env node
// Generates OKF bundle indexes for pushling/docs/.
//
// Zero external dependencies. Frontmatter is parsed with a minimal
// hand-rolled parser for our controlled authoring subset (see
// parseFrontmatter below) — no YAML library, no npm install.
//
// Usage:
//   node scripts/generate-docs-index.mjs          # (re)generate index.md files
//   node scripts/generate-docs-index.mjs --check  # validate only; exit non-zero on failure
//
// See docs/README-generator.md and
// .samantha/references/canonical-docs-system/INDEX-generator.README.md
// for the full design + CI contract this script implements.

import { readFileSync, writeFileSync, renameSync, readdirSync, existsSync } from 'node:fs';
import { join, relative, dirname, basename } from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const DOCS_ROOT = join(__dirname, '..', 'docs');
const GENERATOR_CMD = 'node scripts/generate-docs-index.mjs';
const GENERATED_BANNER = `<!-- GENERATED — do not hand-edit. Run: ${GENERATOR_CMD} -->`;

// Root-index-only preamble declaring archive/ out of the OKF conformance
// boundary. Not a bundle cross-link (backticked, not a markdown link), so
// checkCrossLinks never touches it.
const ARCHIVE_EXEMPTION_LINE =
  "> **`archive/`** holds retired source documents and traceability records — historical storage outside the bundle's OKF conformance boundary (not scanned, not indexed, not link-checked). See `archive/traceability-matrix.md` for the migration record.";

// Section directories that get their own generated index.md. Root docs/
// also carries legacy pre-OKF files and docs/plan/ — those are untouched
// scaffolding-era holdovers, not concepts, so they are never scanned.
const SECTIONS = ['ARCHITECTURE', 'SYSTEMS', 'REFERENCE', 'DATA_MODELS', 'OPERATIONS', 'FEATURES', 'RESEARCH', 'ADR'];

// OKF reserved files + the open-questions workspace + this bundle's own
// generator pointer doc — never treated as concepts.
const RESERVED_FILES = new Set(['index.md', 'log.md', 'DECISIONS.md', 'README-generator.md']);

// ---------- frontmatter parsing (dependency-free, controlled subset) ----------

function stripQuotes(s) {
  const t = s.trim();
  if ((t.startsWith('"') && t.endsWith('"')) || (t.startsWith("'") && t.endsWith("'"))) {
    return t.slice(1, -1);
  }
  return t;
}

function parseInlineList(s) {
  const inner = s.slice(1, -1).trim();
  if (inner === '') return [];
  return inner.split(',').map((item) => stripQuotes(item.trim()));
}

/**
 * Minimal YAML frontmatter parser for our controlled authoring subset:
 * `---` fences, `key: value`, quoted scalars, inline `[a, b]` lists,
 * and `- item` block lists. Deliberately NOT a general YAML parser —
 * no nested maps, no multi-line scalars, no in-block comments. If a
 * concept needs more than this, the concept's authoring is out of
 * subset and should be simplified, not the parser expanded.
 */
function parseFrontmatter(text) {
  const lines = text.split('\n');
  if (lines[0].trim() !== '---') {
    return { error: 'missing opening --- fence' };
  }
  let closeIdx = -1;
  for (let i = 1; i < lines.length; i++) {
    if (lines[i].trim() === '---') {
      closeIdx = i;
      break;
    }
  }
  if (closeIdx === -1) {
    return { error: 'missing closing --- fence' };
  }

  const yamlLines = lines.slice(1, closeIdx);
  const body = lines.slice(closeIdx + 1).join('\n');
  const frontmatter = {};
  let pendingKey = null;

  for (const raw of yamlLines) {
    if (raw.trim() === '') continue;

    const listItemMatch = raw.match(/^\s+-\s?(.*)$/);
    if (listItemMatch && pendingKey) {
      frontmatter[pendingKey].push(stripQuotes(listItemMatch[1]));
      continue;
    }

    const kv = raw.match(/^([A-Za-z0-9_-]+):\s*(.*)$/);
    if (!kv) {
      return { error: `unparseable line: "${raw}"` };
    }
    const [, key, rawValue] = kv;
    pendingKey = null;

    if (rawValue === '') {
      // Empty value — either a genuinely empty scalar, or a block-list
      // header whose items follow on subsequent `- item` lines.
      frontmatter[key] = [];
      pendingKey = key;
      continue;
    }
    if (rawValue.startsWith('[') && rawValue.endsWith(']')) {
      frontmatter[key] = parseInlineList(rawValue);
      continue;
    }
    frontmatter[key] = stripQuotes(rawValue);
  }

  return { frontmatter, body };
}

// ---------- filesystem scanning ----------

function walkMarkdownFiles(dir) {
  const results = [];
  if (!existsSync(dir)) return results;
  for (const entry of readdirSync(dir, { withFileTypes: true })) {
    const full = join(dir, entry.name);
    if (entry.isDirectory()) {
      results.push(...walkMarkdownFiles(full));
    } else if (entry.isFile() && entry.name.endsWith('.md') && !RESERVED_FILES.has(entry.name)) {
      results.push(full);
    }
  }
  return results;
}

function scanSection(section) {
  const dir = join(DOCS_ROOT, section);
  const files = walkMarkdownFiles(dir).sort();
  const concepts = [];
  const failures = [];

  for (const file of files) {
    const text = readFileSync(file, 'utf8');
    const parsed = parseFrontmatter(text);
    if (parsed.error) {
      failures.push({ file, reason: `unparseable frontmatter (${parsed.error})` });
      continue;
    }
    const type = parsed.frontmatter.type;
    if (typeof type !== 'string' || type.trim() === '') {
      failures.push({ file, reason: 'missing non-empty "type"' });
      continue;
    }
    concepts.push({
      file,
      relPath: relative(dir, file).split('\\').join('/'),
      title: parsed.frontmatter.title || basename(file, '.md'),
      description: parsed.frontmatter.description || '',
      body: parsed.body,
    });
  }

  return { concepts, failures };
}

/**
 * Non-recursive scan of docs/*.md at the bundle root. Root is a mixed
 * zone during migration: some files are already-OKF concepts (e.g.
 * `vision.md`), others are transitional legacy/pointer files with no
 * frontmatter at all (retired at SP8). A root `.md` with no opening
 * `---` fence on line 1 is treated as legacy and skipped silently —
 * NOT a failure. A root `.md` that DOES open with `---` is a concept
 * and is held to the same `type`-required rule as section concepts.
 * Never recurses into archive/, plan/, or the section dirs — those
 * are scanned elsewhere (or never, for archive/plan).
 */
function scanRootConcepts() {
  const concepts = [];
  const failures = [];

  for (const entry of readdirSync(DOCS_ROOT, { withFileTypes: true })) {
    if (!entry.isFile() || !entry.name.endsWith('.md') || RESERVED_FILES.has(entry.name)) continue;

    const file = join(DOCS_ROOT, entry.name);
    const text = readFileSync(file, 'utf8');
    if (text.split('\n')[0].trim() !== '---') {
      continue; // legacy/pointer file mid-migration — not a concept
    }

    const parsed = parseFrontmatter(text);
    if (parsed.error) {
      failures.push({ file, reason: `unparseable frontmatter (${parsed.error})` });
      continue;
    }
    const type = parsed.frontmatter.type;
    if (typeof type !== 'string' || type.trim() === '') {
      failures.push({ file, reason: 'missing non-empty "type"' });
      continue;
    }
    concepts.push({
      file,
      relPath: entry.name,
      title: parsed.frontmatter.title || basename(file, '.md'),
      description: parsed.frontmatter.description || '',
      body: parsed.body,
    });
  }

  return { concepts, failures };
}

// ---------- cross-link checking ----------

function findBundleLinks(body) {
  const links = [];
  const re = /\[[^\]]*\]\(([^)]+)\)/g;
  let m;
  while ((m = re.exec(body)) !== null) {
    const target = m[1].trim();
    if (target.startsWith('/') && /\.md(#.*)?$/.test(target)) {
      links.push(target);
    }
  }
  return links;
}

function checkCrossLinks(concepts) {
  const failures = [];
  for (const c of concepts) {
    for (const link of findBundleLinks(c.body)) {
      const withoutAnchor = link.split('#')[0];
      const resolved = join(DOCS_ROOT, withoutAnchor);
      if (!existsSync(resolved)) {
        failures.push({ file: c.file, reason: `dangling cross-link: ${link}` });
      }
    }
  }
  return failures;
}

// ---------- anchor checking (github-slugger algorithm) ----------

/**
 * Reproduces github-slugger's heading-to-anchor algorithm for our
 * controlled markdown subset: lowercase, then strip anything that
 * isn't alphanumeric/space/hyphen (markdown formatting chars like
 * `**`, backticks, `()`, `&`, `+`, an em-dash all fall out here —
 * critically, NO collapsing is applied afterward, so a stripped
 * symbol that sat between two spaces leaves a double hyphen behind,
 * e.g. "A — B" -> "a--b"), then spaces -> hyphens.
 */
function slugify(text) {
  // Mirror github-slugger: lowercase, drop punctuation but KEEP underscores
  // (`# pushling_sense` -> `pushling_sense`); spaces -> hyphens; consecutive
  // hyphens NOT collapsed (a stripped `—` between spaces leaves `--`).
  return text
    .toLowerCase()
    .replace(/[^a-z0-9_ -]/g, '')
    .replace(/ /g, '-');
}

/**
 * ATX headings only (`#` through `######`), skipping fenced code
 * blocks — a `#` inside a ``` or ~~~ fence is a shell/Python comment,
 * not a heading.
 */
function extractHeadings(body) {
  const headings = [];
  let inFence = false;
  let fenceMarker = null;
  for (const line of body.split('\n')) {
    const fence = line.match(/^(```|~~~)/);
    if (fence) {
      if (!inFence) {
        inFence = true;
        fenceMarker = fence[1];
      } else if (line.trim().startsWith(fenceMarker)) {
        inFence = false;
        fenceMarker = null;
      }
      continue;
    }
    if (inFence) continue;
    const m = line.match(/^#{1,6}\s+(.+?)\s*$/);
    if (m) headings.push(m[1]);
  }
  return headings;
}

/**
 * All anchor slugs a document's headings resolve to, duplicate-suffixed
 * the github way: 1st occurrence of a slug keeps the bare slug, 2nd
 * gets `-1`, 3rd gets `-2`, and so on.
 */
function anchorSlugsForBody(body) {
  const occurrences = new Map();
  const slugs = new Set();
  for (const heading of extractHeadings(body)) {
    const base = slugify(heading);
    let slug = base;
    if (occurrences.has(base)) {
      const n = occurrences.get(base) + 1;
      occurrences.set(base, n);
      slug = `${base}-${n}`;
    } else {
      occurrences.set(base, 0);
    }
    slugs.add(slug);
  }
  return slugs;
}

/**
 * Every markdown link in the body that carries a `#fragment` — same-
 * file (`#foo`) or cross-file bundle links (`/X.md#foo`). Unlike
 * findBundleLinks, a bare `#foo` (no leading `/…md`) is included here
 * since same-file anchors are exactly what this check exists for.
 * Anything else (external URLs, plain file links with no fragment) is
 * skipped — nothing to validate.
 */
function findLinksWithFragments(body) {
  const links = [];
  const re = /\[[^\]]*\]\(([^)]+)\)/g;
  let m;
  while ((m = re.exec(body)) !== null) {
    const target = m[1].trim();
    const hashIdx = target.indexOf('#');
    if (hashIdx === -1) continue;
    const filePart = target.slice(0, hashIdx);
    const fragment = target.slice(hashIdx + 1);
    if (fragment === '') continue;
    if (filePart !== '' && !(filePart.startsWith('/') && filePart.endsWith('.md'))) continue;
    links.push({ raw: target, filePart, fragment });
  }
  return links;
}

function checkAnchors(concepts) {
  const failures = [];
  const anchorCache = new Map(); // resolved file path -> Set<slug>

  function slugsForFile(resolvedPath) {
    if (anchorCache.has(resolvedPath)) return anchorCache.get(resolvedPath);
    const slugs = anchorSlugsForBody(readFileSync(resolvedPath, 'utf8'));
    anchorCache.set(resolvedPath, slugs);
    return slugs;
  }

  for (const c of concepts) {
    for (const { raw, filePart, fragment } of findLinksWithFragments(c.body)) {
      const resolved = filePart === '' ? c.file : join(DOCS_ROOT, filePart);
      if (!existsSync(resolved)) continue; // already reported by checkCrossLinks
      if (!slugsForFile(resolved).has(fragment)) {
        failures.push({ file: c.file, reason: `dangling anchor: ${raw}` });
      }
    }
  }
  return failures;
}

// ---------- rendering ----------

function renderSectionIndex(section, concepts) {
  const lines = [GENERATED_BANNER, '', `# ${section} Index`, ''];
  if (concepts.length === 0) {
    lines.push('_No concepts yet._');
  } else {
    for (const c of concepts) {
      const desc = c.description ? ` — ${c.description}` : '';
      lines.push(`- [${c.title}](${c.relPath})${desc}`);
    }
  }
  lines.push('');
  return lines.join('\n');
}

function renderRootIndex(sectionData, rootConcepts) {
  const lines = [GENERATED_BANNER, '', '# Docs Index', '', ARCHIVE_EXEMPTION_LINE, '', '## Root', ''];
  if (rootConcepts.length === 0) {
    lines.push('_No root-level concepts yet._');
  } else {
    for (const c of rootConcepts) {
      const desc = c.description ? ` — ${c.description}` : '';
      lines.push(`- [${c.title}](${c.relPath})${desc}`);
    }
  }

  lines.push('', '## Sections', '');
  for (const section of SECTIONS) {
    lines.push(`- [${section}](${section}/index.md)`);
  }

  lines.push('', '## All Concepts', '');
  const allConcepts = rootConcepts.map((c) => ({ ...c, section: null }));
  for (const section of SECTIONS) {
    for (const c of sectionData[section].concepts) {
      allConcepts.push({ ...c, section });
    }
  }
  if (allConcepts.length === 0) {
    lines.push('_No concepts yet._');
  } else {
    const linkFor = (c) => (c.section ? `${c.section}/${c.relPath}` : c.relPath);
    allConcepts.sort((a, b) => linkFor(a).localeCompare(linkFor(b)));
    for (const c of allConcepts) {
      const desc = c.description ? ` — ${c.description}` : '';
      lines.push(`- [${c.title}](${linkFor(c)})${desc}`);
    }
  }
  lines.push('');
  return lines.join('\n');
}

// ---------- atomic write ----------

function writeAtomic(path, content) {
  const tmp = `${path}.tmp`;
  writeFileSync(tmp, content, 'utf8');
  renameSync(tmp, path);
}

// ---------- main ----------

function main() {
  const checkMode = process.argv.includes('--check');

  const sectionData = {};
  const allFailures = [];
  for (const section of SECTIONS) {
    const { concepts, failures } = scanSection(section);
    sectionData[section] = { concepts };
    allFailures.push(...failures);
  }
  const { concepts: rootConcepts, failures: rootFailures } = scanRootConcepts();
  allFailures.push(...rootFailures);

  const allConcepts = [...rootConcepts, ...SECTIONS.flatMap((s) => sectionData[s].concepts)];
  allFailures.push(...checkCrossLinks(allConcepts));
  allFailures.push(...checkAnchors(allConcepts));

  if (checkMode) {
    // Orphan check — every valid concept must be registered (as a link
    // target) in its section's on-disk index.
    for (const section of SECTIONS) {
      const indexPath = join(DOCS_ROOT, section, 'index.md');
      const onDisk = existsSync(indexPath) ? readFileSync(indexPath, 'utf8') : null;
      for (const c of sectionData[section].concepts) {
        if (onDisk === null || !onDisk.includes(`(${c.relPath})`)) {
          allFailures.push({ file: c.file, reason: `orphan: not registered in ${section}/index.md` });
        }
      }
    }
    // Orphan check — root concepts must be registered in the root index.
    const rootIndexPathForOrphan = join(DOCS_ROOT, 'index.md');
    const onDiskRootForOrphan = existsSync(rootIndexPathForOrphan) ? readFileSync(rootIndexPathForOrphan, 'utf8') : null;
    for (const c of rootConcepts) {
      if (onDiskRootForOrphan === null || !onDiskRootForOrphan.includes(`(${c.relPath})`)) {
        allFailures.push({ file: c.file, reason: 'orphan: not registered in docs/index.md' });
      }
    }

    // Staleness check — on-disk index vs a freshly generated one.
    for (const section of SECTIONS) {
      const indexPath = join(DOCS_ROOT, section, 'index.md');
      const fresh = renderSectionIndex(section, sectionData[section].concepts);
      const onDisk = existsSync(indexPath) ? readFileSync(indexPath, 'utf8') : null;
      if (onDisk !== fresh) {
        allFailures.push({ file: indexPath, reason: 'stale index (on-disk differs from freshly generated)' });
      }
    }
    const rootIndexPath = join(DOCS_ROOT, 'index.md');
    const freshRoot = renderRootIndex(sectionData, rootConcepts);
    const onDiskRoot = existsSync(rootIndexPath) ? readFileSync(rootIndexPath, 'utf8') : null;
    if (onDiskRoot !== freshRoot) {
      allFailures.push({ file: rootIndexPath, reason: 'stale index (on-disk differs from freshly generated)' });
    }

    if (allFailures.length > 0) {
      for (const f of allFailures) {
        console.error(`FAIL  ${relative(DOCS_ROOT, f.file)}  —  ${f.reason}`);
      }
      console.error(`\n${allFailures.length} failure(s).`);
      process.exit(1);
    }
    console.log('OK — bundle is clean.');
    process.exit(0);
  }

  // Generate mode — write the indexes; concepts with bad frontmatter are
  // excluded and warned about, not fatal (that's what --check is for).
  for (const f of allFailures) {
    console.warn(`WARN  ${relative(DOCS_ROOT, f.file)}  —  ${f.reason} (excluded from index)`);
  }
  for (const section of SECTIONS) {
    writeAtomic(join(DOCS_ROOT, section, 'index.md'), renderSectionIndex(section, sectionData[section].concepts));
  }
  writeAtomic(join(DOCS_ROOT, 'index.md'), renderRootIndex(sectionData, rootConcepts));
  console.log('Generated docs/index.md and per-section indexes.');
}

main();
