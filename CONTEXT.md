# Domain Glossary — Social Media Domains Reference List

Shared vocabulary for this repo. Keep it current as design decisions land.

## Terms

### Platform list
A file in `lists/` (e.g. `youtube.txt`) holding the domains for one platform, plus a
header block of `# key: value` metadata. The unit of contribution — a PR normally
touches exactly one platform list.

### Domain entry
A single domain line inside a platform list. **Canonical stored form is the bare
domain, lowercase, one per line** — e.g. `googlevideo.com`. No IP prefix, no scheme,
no path, no wildcard. Comment lines (`#…`) and blank lines are not entries.

### Canonical form
The one legal shape of a stored file: bare-domain entries, lowercased, de-duplicated,
sorted, with the header preserved. A file is "canonical" when `normalize(file) == file`.

### Normalizer
The pure function that maps any platform-list text to its canonical form (strip IP
prefixes / schemes, lowercase, dedupe, sort). The single source of truth for "what is a
valid entry". The first real test seam in the repo.

### Emitter
The adapter that renders canonical bare domains into an output format. The
`master-blocklist.txt` emitter renders `0.0.0.0 <domain>` (hosts format) so the built
list stays maximally compatible with Pi-hole / AdGuard; other emitters (plain, ABP)
are one-liners over the same canonical input.

### Master blocklist
`master-blocklist.txt` — the built artifact users actually subscribe to. Derived
entirely from `lists/`; not hand-edited.

## Decisions
- Stored form = bare domain; emitted master = `0.0.0.0`-hosts. (grilling, 2026-07-05)
- One pure `normalize()` core, two modes: `--write` (auto-canonicalize, friendly) and
  `--check` (CI gate, fails iff `normalize(file) != file`). gofmt/prettier pattern. (grilling, 2026-07-05)
- Ruleset: **mechanical** (auto-fixed) = strip IP prefix, lowercase, trim, strip trailing dot,
  dedupe, sort. **hard-fail** = scheme/path/port, wildcards, no-dot, non-ASCII (must be punycode).
  Keep `www.` (distinct host); ban inline comments among entries. (grilling, 2026-07-05)
- `normalize()` implemented in Python 3, stdlib-only (no pip), single file `tools/normalize.py`.
  Punycode/IDN check via `str.encode('idna')`. GitHub Actions (free/unlimited on public repo)
  runs `--check`. (grilling, 2026-07-05)
