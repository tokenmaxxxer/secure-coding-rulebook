# issue-13 current-state survey — gate-house enforcement machine (Gate A → A+)

Subject: issue-13. Phase-1 survey (role-handoff contract v3 s19) — no code
changes in this commit. Basis: `gh issue view 13` (2026-08-01 실물 코드 감사
결과, 등급: A), and direct inspection of the two live gate scripts this
repo actually ships:

- `asvs-verification/hooks/level-gate.sh` (ASVS phase-split gate)
- `cwe-cvss-findings/hooks/finding-gate.sh` (CWE/CVSS finding gate)

as landed by issue-10 phase 2 (`docs/issue-10/proposals/enforcement-machine.md`).

## 0. What does NOT exist yet in this repo (important precondition)

The task brief and issue #13 both reference `core/hooks/lib/gate-lib.sh`
and `docs/handbooks/gate-house-standard.md` as the shared standard to
reference-adopt. Neither path exists in this working tree today:

```
$ find . -iname "gate-lib*" -o -iname "gate-house*"
(no results)
```

Issue #13's own text names the precondition explicitly:

> ## 선행 조건
> core issue #72(게이트 하우스 표준)가 랜딩된 뒤 그 공유 라이브러리를
> 참조해 구현(자체 재구현 금지).

That is, core issue #72 — the gate-house standard landing in
`tokenmaxxxer-core` — has **not yet landed** as of this survey. The two
gates that exist today (`level-gate.sh`, `finding-gate.sh`) are
free-standing, self-contained bash+python scripts with no shared library
dependency at all: each re-implements its own root resolution, JSON
parsing, path normalization, and reconstruction logic independently (see
§1 below). This is itself the root cause the phase-2 design in
`docs/issue-13/proposals/gate-a-plus.md` must design around: once
`gate-lib.sh` lands, these two gates' duplicated logic is exactly what
should collapse into calls against it — but that extension cannot be
implemented in this phase, and the phase-2 implementer must re-check this
precondition before writing code.

## 1. Inventory of gate/hook mechanisms actually present

| Path | Fires on | What it checks | Semantic depth |
|---|---|---|---|
| `asvs-verification/hooks/level-gate.sh` | `PreToolUse` for `Write`\|`Edit`\|`MultiEdit`, path-filtered to `docs/issue-<n>/proposals/*secure-coding*.md` (phase-1) or `docs/issue-<n>/reports/secure-coding.md` (phase-2) | phase-1: `level-named`, `external-id-present`, `level-before-requirements`, `survey-reference`; phase-2: `level-carried-over`, `asvs-checklist`, `scope-covered-summary` | Whole-document regex search (`re.search`), not section-scoped — see §2 |
| `cwe-cvss-findings/hooks/finding-gate.sh` | `PreToolUse` for `Write`\|`Edit`\|`MultiEdit`, path-filtered to `docs/issue-<n>/reports/secure-coding.md` only | `finding-list-or-na` (CWE-ID token or explicit N/A marker); `cvss-labeled-severity` (a CVSS/severity-band token within 300 chars after each CWE-ID) | Block-scoped by a fixed 300-char window after each `CWE-\d+` match, not a real finding-block boundary — see §2 |
| `asvs-verification/hooks/tests/run-level-gate-tests.sh` | test harness | subprocess-driven allow/deny assertions | shape-check coverage only, current cases enumerated in §3 |
| `cwe-cvss-findings/hooks/tests/run-finding-gate-tests.sh` | test harness | subprocess-driven allow/deny assertions | shape-check coverage only, current cases enumerated in §3 |
| `core/hooks/lib/gate-lib.sh` | — | does not exist yet (see §0) | n/a |
| `docs/handbooks/gate-house-standard.md` | — | does not exist yet (see §0) | n/a |

Both gate scripts are duplicated implementations of the same skeleton:
trap-at-top fail-closed wrapper (`level-gate.sh:2-3`, `finding-gate.sh:2-3`),
a bash-level kill-switch case statement (`level-gate.sh:26-30`,
`finding-gate.sh:23-26`), a `deny()` helper that writes to stderr and exits
2 (`level-gate.sh:32`, `finding-gate.sh:21`), independent root-resolution
logic (`level-gate.sh:44-51`, `finding-gate.sh:56-67`), and independent
Python-side path normalization / JSON parsing / Write-Edit-MultiEdit
reconstruction (`level-gate.sh:60-150`, `finding-gate.sh:100-170`). None of
this is shared code today — every future plugin in this rulebook would
duplicate it again absent `gate-lib.sh`.

## 2. Mapping each 2026-08-01 audit defect to the current-state gap

The issue's audit result line: "severity가 산문 'high'로 만족(벡터 문자열
미검증) — 그 외 조직 최고 수준" plus four numbered requirements. Each is
mapped below to the exact current-state code that causes it.

### Defect group 1 — audit finding: severity satisfied by bare prose ("high"), no CVSS vector validated

`cwe-cvss-findings/hooks/finding-gate.sh:157` (`sev_re = re.compile(r'\b(?:cvss|critical|high|medium|low)\b', re.I)`)
matches the bare word `high`, `critical`, `medium`, or `low` anywhere in
the 300-char window after a `CWE-\d+` token (`finding-gate.sh:150-171`). It
never requires an actual CVSS vector string (e.g.
`CVSS:3.1/AV:N/AC:L/PR:N/UI:N/S:U/C:H/I:H/A:H`) or a numeric base score. A
record can pass `cvss-labeled-severity` by writing prose like "this is a
high severity issue" with no CVSS metric at all. This is the literal
audit line ("벡터 문자열 미검증") — the gap is that the regex treats a
severity-adjective word as equivalent to a CVSS-scored severity.

### Defect group 2 — 요구 1: fail-closed hardening

**1a. Path matching / absolute-path normalization.**
`cwe-cvss-findings/hooks/finding-gate.sh:56-67` resolves the project root
by first trying `CLAUDE_PROJECT_DIR` gated on `_plausible()` AND
`_under("$CLAUDE_PROJECT_DIR", "$_target")` (`finding-gate.sh:44-55`) —
i.e. root selection is itself conditioned on the untrusted tool-supplied
`file_path` (`_target`, extracted at `finding-gate.sh:33-40` straight from
`tool_input.file_path` before any validation). If that check fails, it
falls back to `git -C "$(dirname "$_target")" rev-parse --show-toplevel`
(`finding-gate.sh:63-64`) — again keyed off the attacker/session-supplied
path, not a fixed trusted root. A `file_path` pointing into a *different*
git working tree (e.g. a nested checkout, a symlinked directory, or any
path containing a stray `.git`) can cause `root` to resolve to a directory
the caller does not intend, before the `RECORD_RE` match is even
evaluated. `level-gate.sh` avoids this specific pattern (it resolves root
from `CLAUDE_PROJECT_DIR`/git-toplevel independent of the target path,
`level-gate.sh:44-51`) but neither script normalizes a possible trailing
slash, repeated slashes, or `.`/`..` segments in `file_path` before the
first `_plausible`/`_under` decision — normalization only happens inside
the Python `resolve()` helper, after the bash-level root has already been
chosen from unnormalized input in `finding-gate.sh`.

**1b. Fail-closed: trap-at-top.** Present in both scripts
(`level-gate.sh:2-3`, `finding-gate.sh:2-3`) — this part of the audit
requirement is already satisfied structurally, but neither script's test
harness (§3) asserts on it directly (no test kills the gate script
mid-run to confirm `__fc` fires and denies).

**1c. Fail-closed: malformed-JSON deny.** Present
(`level-gate.sh:69-72`, mirrored in `finding-gate.sh`'s embedded PY block)
— `json.loads` failure calls `deny(...)`. Already correct in the Python
layer. Gap: the *bash-level* JSON pre-extraction in
`finding-gate.sh:33-40` (`_target="$(... python3 -c '... except Exception:
sys.exit(0) ...')`) silently swallows a JSON parse error and prints
nothing, falling through with `_target` empty rather than denying — a
malformed payload at this stage does not fail closed until the second,
independent JSON parse later in the embedded PY heredoc. Two independent
JSON-parse call sites with two different error-handling policies (silent
swallow vs. deny) is itself a defect: the first one is a fail-open path if
`_target` ends up empty because of a parse error rather than a genuinely
absent `file_path`.

**1d. Fail-closed: kill-switch unrecognized value = active.** This is a
concrete, currently-present bug, in **both** scripts:

```
level-gate.sh:27-30
case "$__av_off" in
  ""|0|false|no|off) ;;
  *) exit 0 ;;
esac

finding-gate.sh:23-26
case "${CWE_CVSS_FINDINGS_OFF:-}" in
  ""|0|false|no|off) ;;
  *) exit 0 ;;
esac
```

The comment at `level-gate.sh:24-25` even states the intended semantics
("only ""/0/false/no/off ... keep the gate active; anything else disables
it") — but that is the *opposite* of fail-closed. Today, setting
`ASVS_VERIFICATION_OFF` (or `CWE_CVSS_FINDINGS_OFF`) to **any** value not
in the tiny allow-list — including a typo, an unrelated truthy string, or
garbage from a misconfigured CI variable — silently disables the gate
(`exit 0`, allow unconditionally) instead of keeping it active. A
fail-closed kill switch must default to **active** (denying nothing
changes; the gate keeps running) unless the value is an *exact*,
explicitly-recognized "disable" token (e.g. `1`/`true`/`yes`/`on`); any
unrecognized value must be treated as "kill switch not engaged," not "kill
switch engaged." This is precisely audit item "킬스위치 비인식 값=활성":
an unrecognized value should mean the gate is active, but the current code
means an unrecognized value turns the gate off.

**1e. Edit/MultiEdit/`replace_all` full reconstruction.**
`level-gate.sh:112-119` (Edit branch):

```python
elif tool == "Edit":
    o, n = ti.get("old_string"), ti.get("new_string")
    if isinstance(o, str) and isinstance(n, str) and current is not None and o in current:
        new_text = current.replace(o, n, 1)
```

This always reconstructs as if `replace_all` were `false` (`.replace(o, n,
1)` — first occurrence only), regardless of whether `tool_input.replace_all`
is `true`. The Claude Code `Edit` tool's actual contract replaces **every**
occurrence of `old_string` when `replace_all: true` is set. If a session
calls `Edit` with `replace_all: true` to, say, replace a `CWE-79` token
with a made-up one everywhere in the document, `level-gate.sh`'s
reconstruction only simulates replacing the *first* occurrence — the
gate's view of "the resulting document" diverges from what the real tool
call will actually produce, so a write that would in reality strip a
required token from a later occurrence is invisible to the gate (the
gate approves based on a text that keeps the original later occurrence,
while the real filesystem write removes it). `finding-gate.sh` has the
identical bug (`finding-gate.sh`'s Edit branch, same one-line-replace
call, `.replace(o, n, 1)`). `ti.get("replace_all")` is never read in
either script.

MultiEdit (`level-gate.sh:121-135`) applies each edit sequentially with
the same `.replace(o, n, 1)` semantics and has the identical
`replace_all`-blindness per sub-edit (a MultiEdit edit item can itself
carry `replace_all: true`, per the Edit tool's own schema which MultiEdit
edits reuse).

**1f. Deny-reason to stderr.** Already correctly implemented in both
scripts' `deny()` helpers (`level-gate.sh:32`, `finding-gate.sh:21`) —
this part of the audit line is satisfied.

### Defect group 3 — 요구 2: substring → section/adjacency/structural checks

`level-gate.sh:100-118` (`LEVEL_RE`, `REQID_RE` match) and
`finding-gate.sh:150-171` (`cwe_re`, `sev_re` match) both operate over the
**entire reconstructed document as one flat string**, with no concept of
Markdown heading/section boundaries:

- `level-before-requirements` (`level-gate.sh:104-107`) only compares the
  *character offset* of the first `L[123]` match against the first
  `V\d+(\.\d+){1,3}` match anywhere in the document — a level token
  appearing in an unrelated footnote, a code comment, or the title before
  a real "Verification Level" statement satisfies this check just as well
  as a properly placed one. There is no requirement that the level
  statement live in a specific section (e.g. an "## ASVS Level" heading)
  or that it be the *governing* level statement rather than an incidental
  mention.
- `survey-reference` (`level-gate.sh:129-133`) is a bare substring/regex
  search for `"current-state-survey"` or a `docs/issue-\d+/reports/secure-coding/`
  path fragment *anywhere* in the document — text that merely quotes or
  discusses the phrase "current-state-survey" without it functioning as an
  actual citation passes.
- `asvs-checklist` (`level-gate.sh:139-146`) treats any `pass`/`fail`
  token within 200 chars after **any** requirement-ID occurrence as
  satisfying the whole document's checklist requirement — one single
  correctly-formatted checklist row makes the entire phase-2 record pass,
  even if nine other requirement IDs mentioned elsewhere have no verdict
  attached at all (the loop `for m in REQID_RE.finditer(...)` breaks on
  the *first* match, `level-gate.sh:141-145`).
- `cvss-labeled-severity` (`finding-gate.sh:161-171`) is closer to
  block-scoped (it iterates *every* CWE-ID match, not just the first) but
  still uses a fixed 300-character trailing window rather than an actual
  finding-block boundary (e.g. a Markdown list item, a table row, or a
  `###`-level finding subsection) — a document whose findings are written
  as short entries separated by blank lines can have one finding's CVSS
  label bleed into the next finding's 300-char window and mask a genuinely
  unlabeled finding, or conversely a long finding write-up can push a
  legitimate label outside the fixed window and false-deny.

None of the four checks are section-aware (tied to a specific heading), and
none validate document *structure* (heading presence/order) at all — every
one is a flat-document regex/offset comparison. This is the literal audit
line "판단이 '단어 언급'으로 통과되지 않게" (a judgment must not pass on
mere word-mention) — today, every one of these four checks passes on
word/token mention alone.

### Defect group 4 — 요구 3: mandatory test cases

`asvs-verification/hooks/tests/run-level-gate-tests.sh` and
`cwe-cvss-findings/hooks/tests/run-finding-gate-tests.sh` exist and were
scoped in `docs/issue-10/proposals/enforcement-machine.md` section (vii)
to: phase-1 allow/deny variants, phase-2 allow/deny variants, non-matching
path allow, malformed-JSON deny, unmatchable `Edit.old_string` deny, and
kill-switch-set allow. Grepping both test files for the specific cases the
audit now requires as mandatory:

```
$ grep -ncE "replace_all" asvs-verification/hooks/tests/run-level-gate-tests.sh cwe-cvss-findings/hooks/tests/run-finding-gate-tests.sh
0  (each file)
$ grep -ncE "MultiEdit" asvs-verification/hooks/tests/run-level-gate-tests.sh cwe-cvss-findings/hooks/tests/run-finding-gate-tests.sh
(present for the plain-MultiEdit path per (vii), but no replace_all-flagged case)
```

There is no test in either harness that (a) sets `replace_all: true` on an
`Edit` and asserts the gate's reconstruction matches real `Edit` semantics,
(b) sets `replace_all: true` on one edit inside a `MultiEdit.edits` array,
(c) supplies an absolute `file_path` crafted to point outside the intended
root (path-normalization defeat), or (d) sets the kill-switch env var to an
*unrecognized garbage value* and asserts the gate stays **active** (the
current tests, per (vii)'s own description, only assert "kill-switch env
var set → allow regardless of content" using a recognized disable value —
they do not test the fail-closed-on-unrecognized-value behavior at all,
consistent with defect group 2's 1d bug going undetected).

### Defect group 5 — 요구 4: README ↔ reality parity

`asvs-verification/README.md` and `cwe-cvss-findings/README.md` describe
the gates' phase-1/phase-2 checks accurately at the shape-check level
(their own "Caveats" sections already disclose the substring-check
limitation in prose — e.g. cwe-cvss-findings/README.md's closing
paragraph: "It does not verify that the CWE ID actually classifies the
described weakness correctly ... It catches an omitted finding shape, not
a wrong one."). No currently-nonexistent file is referenced by either
README (no "ghost file" reference to `gate-lib.sh` or
`gate-house-standard.md` appears in either README today — the
"gate-house standard" precondition is only named in the issue text and
this repo's forthcoming design, not yet in any shipped README). The
concrete README gap once phase 2 lands: once `gate-lib.sh` exists and
these gates are refactored to call into it, the README's "How it works"
sections must be updated to name the shared library functions actually
invoked, or they will describe a reimplementation that no longer matches
the code (a *future* ghost-file risk this survey flags pre-emptively for
the phase-2 implementer, not a currently-present defect).

## 3. Existing test coverage (baseline for phase-2 gap-fill)

Current cases per `docs/issue-10/proposals/enforcement-machine.md`
section (vii), confirmed present in both `run-level-gate-tests.sh` and
`run-finding-gate-tests.sh`: phase-1/phase-2 allow, phase-1/phase-2 deny
per missing element, non-matching path allow, malformed-JSON deny,
unmatchable-`Edit.old_string` deny, kill-switch-recognized-value allow.
None of the defect-group-4 cases above exist yet. The design proposal
(`docs/issue-13/proposals/gate-a-plus.md`) specifies these as mandatory
additions.

## Files touched (phase 1, this commit)

- Add: `docs/issue-13/reports/secure-coding/survey.md` (this file)
- Add: `docs/issue-13/proposals/gate-a-plus.md`

## Not in scope

- Any code change to `asvs-verification/hooks/*`, `cwe-cvss-findings/hooks/*`,
  or any `core/` path — phase 1 is proposal-only per contract v3 s19.
- Creating `core/hooks/lib/gate-lib.sh` or
  `docs/handbooks/gate-house-standard.md` — those land under core issue
  #72, outside this role's write scope; this survey only documents that
  they do not exist yet and that issue #13 itself names their landing as
  a precondition for phase-2 execution here.
- APPROVE-ing anything — exclusively a human act by an approvers.md
  account, per contract v3 s19.
