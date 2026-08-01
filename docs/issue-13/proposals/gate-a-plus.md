# issue-13 proposal — harden the gate-house enforcement machine to Gate A+

Subject: issue-13. Phase-1 proposal (role-handoff contract v3 s19) — no
plugin/hook code changes in this commit; execution starts only after
Approve.

Verification Level: L2 (standard). Rationale: this hardens the same
enforcement machine adopted at L2 in
`docs/issue-10/proposals/enforcement-machine.md` section (i) — the gates
being fixed are still standard-rigor process-integrity controls guarding a
human-approval boundary, not a cryptographic primitive or a
multi-tenant/regulated-data boundary (no change of level is warranted by
this hardening pass). The current-state survey this proposal builds on is
`docs/issue-13/reports/secure-coding/survey.md` (current-state-survey),
citing exact file:line locations for every gap addressed below. The
requirement IDs enumerated in section 4 (e.g. `V1.1.1`) are ASVS-style
identifiers for the phase-2 checklist this proposal defines — none appear
above this level statement, per the same phase-1 ordering norm
`asvs-verification/hooks/level-gate.sh` itself enforces on other proposals
in this rulebook.

## 0. Design constraint — reference-adopt `gate-lib.sh`, do not reimplement

Per issue #13's precondition ("core issue #72(게이트 하우스 표준)가 랜딩된
뒤 그 공유 라이브러리를 참조해 구현(자체 재구현 금지)") and per
`docs/issue-13/reports/secure-coding/survey.md` §0, `core/hooks/lib/gate-lib.sh`
and `docs/handbooks/gate-house-standard.md` do not exist in this repo yet.
This proposal treats that landing as a **hard precondition for phase-2
implementation**, not something phase 2 works around:

- Phase-2 execution MUST first confirm `core/hooks/lib/gate-lib.sh` and
  `docs/handbooks/gate-house-standard.md` exist (post core issue #72
  landing). If they do not, phase-2 execution is blocked and must not
  proceed with a self-reimplemented fix.
- Once available, every fix in sections 1–4 below is expressed as an
  **extension of, or a call into, `gate-lib.sh`'s shared functions** — the
  root-resolution, JSON-parsing, path-normalization, kill-switch, and
  Write/Edit/MultiEdit-reconstruction logic currently duplicated
  independently in `level-gate.sh` and `finding-gate.sh` (survey §1) is
  the exact logic this rulebook's two gates must delete locally and call
  from `gate-lib.sh` instead. No new copy of root-resolution, kill-switch
  parsing, or content-reconstruction logic is to be written inside
  `asvs-verification/` or `cwe-cvss-findings/` once the shared library
  exists — this mirrors the same never-vendor rule this rulebook already
  applies to `stub-check.sh` (issue-5) and `record-fields-gate.sh`
  (issue-10 §(vi)).
- This proposal specifies the **function contracts** the phase-2
  implementer needs from `gate-lib.sh` (section 3), so the shared-library
  design and this rulebook's consuming gates can be reviewed together
  before either lands. If `gate-lib.sh`'s actual landed signatures differ
  from what is specified here, phase-2 execution adapts the call sites to
  the real signatures — it does not fork or shadow-copy the library to
  match this proposal's guess.

## 1. Mapping: audit defect → conservative, additive-first fix

Every numbered item from issue #13's 요구 section, plus the standalone
severity-prose finding, addressed below. All fixes are additive/corrective
to the existing two gates — no gate is replaced wholesale, no existing
passing case in `docs/issue-10/proposals/enforcement-machine.md` §(vii)
is removed, only tightened.

### 1a. Severity-prose defect (CVSS vector not validated)

Current: `finding-gate.sh:157`'s `sev_re` matches bare adjectives
(`high`/`critical`/`medium`/`low`) or the literal word `cvss`, with no
structure requirement (survey §2, defect group 1).

Fix: replace `sev_re` with two alternatives, either of which satisfies
`cvss-labeled-severity`, matched via `gate_lib::cvss_label_present(window)`
(section 3):

- A full or partial CVSS vector string:
  `CVSS:3\.[01]/AV:[NALP]/AC:[LH]/PR:[NLH]/UI:[NR]/S:[UC]/C:[NLH]/I:[NLH]/A:[NLH]` —
  at minimum `AV`, `AC`, and one impact metric (`C`/`I`/`A`) present, not
  just the literal substring `CVSS`.
- A numeric CVSS base score in `[0.0, 10.0]` co-located with a severity
  band word from the CVSS v3.1 official band table (`None`/`Low`/
  `Medium`/`High`/`Critical` mapped to their score ranges) — i.e. the
  score and the band word must agree with the official CVSS band mapping,
  not just both appear near a CWE-ID independently.

A bare severity adjective with **no** accompanying vector string or
numeric score no longer satisfies the check — this directly closes the
audit's literal finding.

### 1b. Path matching / absolute-path normalization

Current: `finding-gate.sh:44-67` conditions root discovery on the
untrusted `file_path` itself (`_under("$CLAUDE_PROJECT_DIR", "$_target")`)
before any validation, and falls back to `git -C "$(dirname "$_target")"`
— both keyed off attacker/session-supplied input (survey §2, defect 1a).

Fix: root resolution moves entirely into `gate_lib::resolve_root()`
(section 3) — a single function with **no** parameter derived from the
tool-call payload. It resolves purely from `CLAUDE_PROJECT_DIR` (validated
independently: must be an absolute, existing directory containing `.git`
or the canon-manifest marker file) or, failing that, `git rev-parse
--show-toplevel` run from the *hook script's own* working directory /
`$PWD` at invocation time — never from a directory derived by `dirname`-ing
the tool-supplied path. Once `root` is fixed, `gate_lib::resolve_path(root,
raw_path)` normalizes `raw_path` (backslash-to-slash, repeated-slash
collapse, `.`/`..` segment resolution, then `realpath`) and the caller
compares the normalized absolute path against the *already-fixed* `root`
via string prefix match — the order is root-first, then normalize-and-compare,
never the reverse. Both `level-gate.sh` and `finding-gate.sh` adopt the
same call, closing the asymmetry the survey found between them (only
`level-gate.sh` avoided this pattern before).

### 1c. Fail-closed: trap-at-top (confirm, extend)

Current: both scripts already trap at the top (survey §2, defect 1b) —
already correct. Fix here is test-only (section 4): add a case that
verifies `__fc`/the equivalent `gate_lib::fail_closed_trap` actually fires
and denies (rc≠0,2 forced) rather than merely asserting the trap line's
presence in source.

Also closes the found asymmetry: `finding-gate.sh:33-40`'s bash-level
JSON pre-extraction (`_target="$(... python3 -c '... except Exception:
sys.exit(0) ...')`) silently swallows a parse error before the real,
deny-on-malformed-JSON check runs later (survey §2, defect 1c). Fix:
delete this separate bash-level pre-extraction entirely; both gates call
`gate_lib::parse_tool_call(payload)` exactly once, which either returns
the parsed `(tool, tool_input, file_path)` tuple or denies immediately —
one JSON-parse call site per gate invocation, one error-handling policy
(deny), not two independent parses with two different policies.

### 1d. Fail-closed: kill-switch unrecognized value = active (confirmed live bug)

Current: `level-gate.sh:27-30` and `finding-gate.sh:23-26` both disable
the gate (`exit 0`) for any env-var value not in `""|0|false|no|off` —
i.e. an unrecognized/garbage value silently disables the gate, the
opposite of fail-closed (survey §2, defect 1d, confirmed present in both
scripts today).

Fix: replace the case statement in both scripts with
`gate_lib::kill_switch_engaged(varname)`, whose contract is inverted from
today's: it returns "disabled" **only** on an exact, case-insensitive match
against a small explicit enable-list (`1`, `true`, `yes`, `on`) and
returns "active" (gate keeps running) for the empty value, `0`/`false`/
`no`/`off`, AND any unrecognized value. This is the literal audit ask
("킬스위치 비인식 값=활성"): unknown input always means "gate stays on."

### 1e. Edit/MultiEdit/`replace_all` full reconstruction

Current: both gates' Edit branch (`level-gate.sh:112-119`,
`finding-gate.sh`'s equivalent) call `current.replace(o, n, 1)`
unconditionally, ignoring `tool_input.get("replace_all")` — when a real
`Edit` call sets `replace_all: true`, the gate's simulated "resulting
document" only replaces the first occurrence, diverging from the actual
write (survey §2, defect 1e, confirmed present in both scripts, including
MultiEdit's per-edit `replace_all`).

Fix: `gate_lib::reconstruct_write(tool, tool_input, current_text)` is the
single reconstruction function both gates call, with this contract:

```
reconstruct_write(tool, tool_input, current_text) -> (new_text | None, reason_if_none)

Write:      new_text = tool_input["content"]  (if str)
Edit:       old, new = tool_input["old_string"], tool_input["new_string"]
            replace_all = bool(tool_input.get("replace_all", False))
            if old not in current_text: -> (None, "old_string not found")
            new_text = current_text.replace(old, new)  if replace_all
                       else current_text.replace(old, new, 1)
MultiEdit:  fold each edits[i] through the same Edit rule above,
            sequentially, each edit item's own replace_all read
            independently (an edits array MAY mix replace_all=true and
            replace_all=false entries; each entry's own flag governs only
            that entry's substitution)
```

Both `level-gate.sh` and `finding-gate.sh` delete their local
reconstruction code and call this one function.

### 1f. Deny-reason to stderr (confirm, no change needed)

Current: both `deny()` helpers already write to stderr and `exit 2`
(survey §2, defect 1f) — already correct; `gate_lib::deny(plugin_name,
message)` centralizes this so future plugins inherit the same format
(`"<plugin_name>: refused — <message>"`) without re-typing it, but no
behavior changes for the two existing gates.

## 2. Semantic upgrade: substring → section/adjacency/structural checks

Current gap (survey §2, defect group 3): all four checks in
`level-gate.sh` and both checks in `finding-gate.sh` operate over the flat
document string with no heading/section awareness, and two of the four
(`level-before-requirements`, `asvs-checklist`) stop at the *first* match
rather than validating every occurrence.

Design: `gate-lib.sh` gains a small Markdown-structure helper layer that
both this rulebook's gates and any future rulebook's gates can build
section-aware checks on top of, instead of flat `re.search`.

### 2.1 `gate_lib::parse_sections(doc_text) -> list[Section]`

Splits `doc_text` into a list of `Section(heading_text, heading_level,
start_offset, end_offset, body_text)` records, one per Markdown ATX
heading (`^#{1,6}\s+.+$`) — `end_offset` is the offset of the next heading
at the same or shallower level, or end-of-document. A "preamble" pseudo-
section (before the first heading) is included as `Section(None, 0, 0,
first_heading_offset, preamble_text)`.

### 2.2 `gate_lib::find_in_section(sections, heading_pattern, token_pattern) -> Match | None`

Finds `token_pattern` only within the body of a section whose heading
matches `heading_pattern` (case-insensitive substring or regex on the
heading text) — or within the preamble if `heading_pattern` is `None`.
Returns the match plus which section it was found in, or `None`.

### 2.3 Concrete re-specification of the four `asvs-verification` checks

- **`level-named`**: must be found via
  `find_in_section(sections, r"verification\s*level|^level\b", LEVEL_RE)`
  — i.e. the level token must live in a section/preamble line whose
  governing heading or line-prefix is literally about the verification
  level (matching this proposal's own "Verification Level: L2" preamble
  line, and `docs/issue-1/proposals/*`'s existing "(ii) verification
  level" heading convention) — not any `L[123]` token anywhere in the
  document (closes survey's "footnote token" gap).
- **`level-before-requirements`**: unchanged offset-ordering rule, but
  computed only from the `level-named` match found above (the *governing*
  statement) against the *first* `REQID_RE` match — so an incidental level
  token elsewhere no longer satisfies ordering by accident.
- **`survey-reference`**: must be found via
  `find_in_section(sections, None, SURVEY_RE)` performed at the document
  level (any section, since a citation can legitimately appear anywhere)
  BUT `SURVEY_RE` is tightened to require the phrase to be adjacent (same
  line, or within one Markdown link/citation construct — e.g.
  `` `docs/issue-\d+/reports/secure-coding/[\w./-]+\.md` `` or the literal
  phrase `current-state survey` immediately followed by a path or a
  backtick-quoted file reference within 80 characters) — a bare
  mention of the word "survey" with no adjacent path/citation no longer
  passes (closes the "quotes the phrase without citing" gap).
- **`asvs-checklist`**: iterate **every** `REQID_RE` match in the
  document (not `break` on the first), and require **every one** to have
  a pass/fail token within its own table-row or list-item boundary — i.e.
  compute the boundary as "from this requirement ID's line start to the
  next blank line or next list-item/table-row marker," not a fixed
  200-character window. All matched requirement rows must pass, else deny
  naming the specific unlabeled requirement ID(s) (closes the
  "one row satisfies the whole document" gap).

### 2.4 Concrete re-specification of `cwe-cvss-findings`'s check

- **`cvss-labeled-severity`**: replace the fixed 300-character trailing
  window with a finding-block boundary: from the `CWE-\d+` match's line
  start to the next blank line, the next list-item marker (`^[-*]\s`), or
  the next table row, whichever comes first — mirroring
  `asvs-checklist`'s row-boundary approach above. A CVSS label belonging
  to the *next* finding's block can no longer satisfy an earlier,
  genuinely-unlabeled finding, and a long single finding write-up is no
  longer penalized just for exceeding a fixed character count.

## 3. `gate-lib.sh` function contracts this proposal depends on

(For phase-2 review against the real landed `gate-lib.sh` — see section 0.
Shapes given as Python-callable contracts since both existing gates
already do their content-judgment work in an embedded Python heredoc;
`gate-lib.sh` is expected to expose these as a small importable Python
module the heredocs `import`, plus the shared bash-level pieces —
`resolve_root`, `kill_switch_engaged`, `deny` — as sourced bash functions.)

| Function | Contract |
|---|---|
| `gate_lib::resolve_root()` (bash) | Resolves project root independent of any tool-call-supplied path (§1b). Denies (prints to stderr, returns 2) if no root determinable. |
| `gate_lib::kill_switch_engaged(value)` (bash or python) | Returns disabled only on exact match of an explicit enable-list; unrecognized/empty/negative values → gate active (§1d). |
| `gate_lib::parse_tool_call(payload)` (python) | One JSON-parse call site; denies on malformed JSON or non-object payload; returns `(tool, tool_input, file_path)` (§1c). |
| `gate_lib::resolve_path(root, raw_path)` (python) | Normalizes and resolves `raw_path` against an already-fixed `root`; returns absolute real path or `None` (§1b). |
| `gate_lib::reconstruct_write(tool, tool_input, current_text)` (python) | Full Write/Edit/MultiEdit reconstruction respecting `replace_all` per-edit (§1e). |
| `gate_lib::parse_sections(doc_text)` (python) | Markdown heading-based section split (§2.1). |
| `gate_lib::find_in_section(sections, heading_pattern, token_pattern)` (python) | Section-scoped token search (§2.2). |
| `gate_lib::cvss_label_present(window)` (python) | CVSS vector-string or band-consistent-numeric-score check, not bare adjective match (§1a). |
| `gate_lib::deny(plugin_name, message)` (bash or python) | Centralized stderr-format deny helper (§1f). |

## 4. Mandatory test cases (phase-2 implementation must satisfy all)

One test per audit defect at minimum, both positive and negative, added
to `asvs-verification/hooks/tests/run-level-gate-tests.sh` and
`cwe-cvss-findings/hooks/tests/run-finding-gate-tests.sh` as applicable.
Existing cases from `docs/issue-10/proposals/enforcement-machine.md`
§(vii) remain and must stay green.

**Severity / CVSS (`cwe-cvss-findings`) — requirement V1.1.1 (finding
severity must be machine-checkable, not prose-only):**
1. CWE-ID + bare adjective only ("this is a high severity bug") → FAIL.
2. CWE-ID + full CVSS vector string → PASS.
3. CWE-ID + numeric base score consistent with a stated band word (e.g.
   "7.5, High") → PASS.
4. CWE-ID + numeric score inconsistent with the stated band word (e.g.
   "2.0, Critical") → FAIL.

**Path matching / root resolution — requirement V2.1.1 (root resolution
must not be attacker/session-path-derived):**
5. `file_path` containing `..` segments that would otherwise escape root
   after naive normalization → FAIL (denied, resolved path outside root).
6. `file_path` pointing into a nested `.git` working tree distinct from
   the intended project root → root resolution still yields the true
   project root (unaffected by the target path) → gate still evaluates
   against the true root's `docs/issue-<n>/...` pattern.
7. Ordinary in-root relative and absolute path variants (both forms of
   the same real file) → both resolve to the same normalized path and the
   same allow/deny verdict.

**Fail-closed: trap-at-top — requirement V3.1.1:**
8. Simulated internal crash (forced non-0/non-2 exit inside the script)
   → the trap fires, prints a `fail-closed` message, and the process exit
   code is 2.

**Fail-closed: malformed JSON — requirement V3.1.2:**
9. Payload is not valid JSON at all → deny (rc 2), single deny message
   (no earlier silent swallow).
10. Payload is valid JSON but not an object (e.g. a bare JSON array or
    string) → deny (rc 2).

**Fail-closed: kill switch unrecognized value — requirement V3.1.3:**
11. Kill-switch env var unset → gate active (baseline, already covered).
12. Kill-switch env var set to a recognized disable token (`1`, `true`,
    `yes`, `on`, case-insensitive) → gate disabled, allow regardless of
    content (already covered).
13. Kill-switch env var set to an **unrecognized** value (e.g. `maybe`,
    `2`, a stray empty-but-quoted string with whitespace, `TRUE!`) → gate
    stays **active** and evaluates content normally (NEW — this is the
    literal fix for the confirmed live bug in survey §2 defect 1d).

**Edit/MultiEdit/`replace_all` reconstruction — requirement V4.1.1:**
14. `Edit` with `replace_all: false` (or omitted) and `old_string`
    appearing twice in current content → only the first occurrence is
    replaced in the reconstructed text; a required token that survives
    only in the *first* occurrence still allows; a required token that
    only exists in the *second* occurrence and gets clobbered by the
    *first* occurrence's replacement is evaluated correctly (unaffected
    by this fix — regression guard).
15. `Edit` with `replace_all: true` and `old_string` appearing multiple
    times, where a later occurrence's replacement would delete a required
    token → gate denies (previously would have allowed under the
    first-occurrence-only simulation) — this is the literal regression
    test proving the bug in survey §2 defect 1e is fixed.
16. `MultiEdit` whose `edits` array mixes one entry with `replace_all:
    true` and one entry with `replace_all: false` (or omitted) → each
    entry's own flag governs only that entry's substitution; final
    reconstructed text matches applying the real tool semantics
    sequentially.

**Section/adjacency/structural semantic checks — requirement V5.1.1:**
17. `level-named` token present only in an unrelated code block /
    footnote, no "Verification Level"-headed line anywhere → FAIL (was
    PASS under the old flat substring check).
18. `level-named` token present in a proper "Verification Level: L2"
    preamble line → PASS.
19. `survey-reference` phrase "current-state survey" present as a bare
    mention with no adjacent path/citation → FAIL (was PASS under the old
    check).
20. `survey-reference` present as an actual path citation to
    `docs/issue-<n>/reports/secure-coding/...` → PASS.
21. `asvs-checklist`: nine requirement IDs listed, only the first has a
    pass/fail token attached, the other eight do not → FAIL, naming the
    eight unlabeled IDs (was PASS under the old first-match-only check).
22. `asvs-checklist`: all listed requirement IDs each have their own
    pass/fail token in-row → PASS.
23. `cvss-labeled-severity`: two findings written as adjacent short list
    items, only the second has a CVSS label, the first's block does not —
    FAIL naming the first CWE-ID (was previously at risk of a false PASS
    if the second finding's label fell inside the first's fixed 300-char
    window; must FAIL under block-boundary scoping regardless of finding
    length).
24. `cvss-labeled-severity`: a single very long finding write-up (>300
    characters of prose) whose CVSS label appears after character 300 but
    still within the same finding's block → PASS (was a false FAIL risk
    under the old fixed-window check; must not regress under the new
    block-boundary check).

**README ↔ reality parity — requirement V6.1.1 (documentation, not a
gate test, but a phase-2 completion checklist item):**
25. Both `README.md`s' "How it works" sections are updated to name the
    actual `gate_lib::*` functions called, with no residual description of
    the deleted local reimplementation left behind.

## 5. Full-suite-green requirement

Per issue #13's 요구 3 ("배송 상태에서 전 스위트 green"), phase-2
execution must run both `run-level-gate-tests.sh` and
`run-finding-gate-tests.sh` (extended per section 4) to a fully green
result before the phase-2 record is considered complete — this is a
phase-2 execution gate, not something evaluable in this phase-1 proposal
commit.

## Files touched (phase 1, this commit)

- Add: `docs/issue-13/reports/secure-coding/survey.md`
- Add: `docs/issue-13/proposals/gate-a-plus.md` (this file)

## Files touched (phase 2, post-Approve — not in this commit)

- Confirm landed: `core/hooks/lib/gate-lib.sh`,
  `docs/handbooks/gate-house-standard.md` (core issue #72 precondition;
  block phase-2 execution if not yet landed).
- Edit: `asvs-verification/hooks/level-gate.sh` — delete local root
  resolution / kill-switch / JSON-parse / reconstruction code, call into
  `gate_lib::*`; re-specify the four checks per section 2.3.
- Edit: `cwe-cvss-findings/hooks/finding-gate.sh` — same, plus the
  severity check per section 1a and 2.4.
- Edit: `asvs-verification/hooks/tests/run-level-gate-tests.sh`,
  `cwe-cvss-findings/hooks/tests/run-finding-gate-tests.sh` — add the
  section-4 cases; existing cases must remain green.
- Edit: `asvs-verification/README.md`, `cwe-cvss-findings/README.md` —
  bring "How it works" in line with the `gate_lib::*`-calling
  implementation (section 4, case 25).

## Not in scope

- Any code change to `asvs-verification/hooks/*`, `cwe-cvss-findings/hooks/*`,
  `core/`, or `.claude-plugin/*` in this commit — phase 1 is proposal-only
  per contract v3 s19.
- Creating or landing `core/hooks/lib/gate-lib.sh` or
  `docs/handbooks/gate-house-standard.md` themselves — that is core issue
  #72's own deliverable, outside this role's scope; this proposal only
  specifies the contract this rulebook's gates need from it.
- Re-deciding the ASVS/CWE-CVSS methodology adopted in issue-1 — this
  proposal only hardens the enforcement machine's implementation quality,
  not the methodology it enforces.
- APPROVE-ing this proposal — exclusively a human act by an approvers.md
  account (`JiwonJung94`), per contract v3 s19; this session never
  approves its own or another role's work.
