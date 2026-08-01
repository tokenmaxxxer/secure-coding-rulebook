# issue-16 phase-1 proposal — Gate A+ final closeout (conservative repair)

Subject: issue-16. Verification level: **L2** (standard) — same rationale
as issue-13/`gate-a-plus.md`: this hardens process-integrity PreToolUse
gates guarding a phase-split enforcement boundary, not a crypto/
multi-tenant/regulated-data boundary. Stated before any ASVS requirement
ID below.

Basis: `docs/issue-16/reports/secure-coding/survey.md` (current-state
survey, this proposal's direct evidence base) and the confirmed-landed
`core/hooks/lib/gate-lib.sh` usage-comment / `docs/handbooks/
gate-house-standard.md` from `tokenmaxxxer-core` `main` (core issue #75,
PR #77, commit `52bdc15`).

**Design constraint — reference-adopt, do not reimplement.** Every fix
below is a mechanical re-application of a form core issue #75 already
fixed and documented; this proposal invents no new guard shape, kill-switch
semantics, or test harness idiom. Phase 2 execution copies the exact
guarded source line from `core/hooks/lib/gate-lib.sh`'s own usage comment
and the exact `missing-core` test shape from
`core/hooks/tests/run-gate-lib-tests.sh` group 7 (survey §1, §4),
substituting only the gate name and env var references. **This proposal
does not APPROVE anything — phase 1 only, per role-handoff contract v3
s19.**

## 1. `||`-guard + `CLAUDE_PLUGIN_ROOT_CORE` rename (survey §2)

Files: `asvs-verification/hooks/level-gate.sh`,
`cwe-cvss-findings/hooks/finding-gate.sh`,
`secure-coding/hooks/directive.sh`.

Replace, in each:

```sh
. "${CORE_PLUGIN_ROOT:-$CLAUDE_PLUGIN_ROOT/../core}/hooks/lib/gate-lib.sh"
```

with the landed canon form (gate name substituted per file):

```sh
. "${CLAUDE_PLUGIN_ROOT_CORE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../core" && pwd -P)}/hooks/lib/gate-lib.sh" || { echo "level-gate.sh: cannot source gate-lib.sh" >&2; exit 2; }
```

(`finding-gate.sh` → same, message names `finding-gate.sh`.)

For `secure-coding/hooks/directive.sh`, same rename/guard applied to its
existing `role-directive.sh` source line — relative fallback path stays
`../../core` since `directive.sh` lives one directory shallower
(`secure-coding/hooks/` vs. `asvs-verification/hooks/`), matching the
depth already present in that file's fallback today (confirmed by
reading the current line — it already uses `../../core`, only the guard
is missing).

No other line in either gate changes: root resolution
(`CLAUDE_PROJECT_DIR`/`git rev-parse --show-toplevel`), the kill-switch
call, the JSON parse, and the structural checks are all already
correctly wired to `gate_lib.*` (confirmed in issue-13's delivery,
re-confirmed in survey §2) — only the source line itself is defective.

`compliance-check.sh`'s own external-invocation `CORE_PLUGIN_ROOT`
variable (used by `run-level-gate-tests.sh`/`run-finding-gate-tests.sh`
to locate a core checkout for testing, and by any operator invoking
`compliance-check.sh` directly) is a distinct, correctly-named variable
for a distinct purpose (survey §1) — **not touched** by this fix; renaming
it would itself introduce a house mismatch against core's own
`compliance-check.sh`/`stub-check.sh` invocation convention.

## 2. Missing-core mandatory test case (survey §4, group 7)

Add one case to each of `asvs-verification/hooks/tests/
run-level-gate-tests.sh` and `cwe-cvss-findings/hooks/tests/
run-finding-gate-tests.sh`, adapted from `core/hooks/tests/
run-gate-lib-tests.sh`'s own `mark missing-core` group (lines 230-246 in
the landed core suite): invoke the gate as a subprocess with
`CLAUDE_PLUGIN_ROOT_CORE` pointed at a nonexistent path (a fresh
`mktemp -d`-based path that is guaranteed absent) and no valid relative
`../../core` fallback reachable from the invocation cwd (run from a
scratch tempdir, not the repo tree) — assert the gate **denies** (exit 2)
with a message naming the source failure, not the pre-fix silent-allow.
This is the direct regression test for the confirmed bug fixed in §1 —
it must fail against the current unguarded source line and pass once §1
lands, proving the fix rather than merely asserting the new source text.

Group 6 (Bash-tool coverage / `gate_bash_write_targets` parity) is
confirmed not applicable to either suite (survey §4) — neither gate has a
Bash-tool code path, matching core's own `record-fields-gate.sh`
precedent for content-diffing gates. No case added for group 6; this
absence is a design fact, not a gap, and should not be papered over with
a vacuous test.

## 3. hooks.json matcher / tool-coverage parity (survey §3)

**No fix required.** The survey traced both gates' `hooks.json` matcher
(`"Write|Edit|MultiEdit"`) against their Python payload's tool dispatch
(`tool in ("Write", "Edit", "MultiEdit")`, `sys.exit(0)` otherwise) and
confirmed exact parity in both. Phase 2 re-confirms this by re-reading
both files unchanged after the §1 edits (the source-line fix touches
nothing in the dispatch logic) and states so explicitly in the phase-2
record rather than silently assuming it holds.

## 4. README ghost text (survey §5)

`README.md` (root):

- Delete line 5's "생성됨 as skeleton scaffolding by issue-170" clause
  (rewrite the sentence to state what the rulebook actually is: the
  `secure-coding` role split per `docs/issue-160/proposals/
  role-taxonomy.md`'s round-3 promotion — drop only the stale
  scaffolding claim, keep the accurate split-provenance sentence).
- Delete the closing "This is scaffolding, not a finished rulebook..."
  paragraph (lines 39-41) in full — the rulebook now has a landed,
  tested methodology-plugin set (issue-1/5/10/13), so the disclaimer is
  false, not merely dated.
- Extend `## Layout` to list `asvs-verification/` and
  `cwe-cvss-findings/` alongside the existing `secure-coding/` items —
  each plugin's manifest, `hooks.json`, its `hooks/*-gate.sh` PreToolUse
  gate, its `hooks/directive.sh` UserPromptSubmit reminder, and its
  `hooks/tests/run-*-gate-tests.sh` suite, mirroring the level of detail
  already given for `secure-coding/`.

No other README/manifest file needs a change — survey §5 found no ghost
role names or ghost file references in `asvs-verification/README.md`,
`cwe-cvss-findings/README.md`, or any of the three
`.claude-plugin/plugin.json` manifests.

## 5. Phase-2 delivery evidence requirements (issue-16 requirement 3)

Phase 2 must run `compliance-check.sh` (by reference, never vendored,
per `docs/handbooks/canon-scripts.md`) against both
`asvs-verification/hooks` and `cwe-cvss-findings/hooks` after the §1 fix
and record clean output — the same evidence pattern
`docs/issue-13/reports/secure-coding.md`'s "Compliance detector evidence"
section already used. Phase 2 must also re-run both gate test suites
full-green with the new case count (missing-core case added, §2) and
state the new totals.

## Files touched (phase 2)

- `asvs-verification/hooks/level-gate.sh` (source line only)
- `cwe-cvss-findings/hooks/finding-gate.sh` (source line only)
- `secure-coding/hooks/directive.sh` (source line only)
- `asvs-verification/hooks/tests/run-level-gate-tests.sh` (+1 case)
- `cwe-cvss-findings/hooks/tests/run-finding-gate-tests.sh` (+1 case)
- `README.md` (root) — scaffolding text removed, Layout extended
- `docs/issue-16/reports/secure-coding.md` — phase-2 record (written only
  after Approve)

## Not in scope

- Re-deciding the ASVS/CWE-CVSS methodology itself (issue-1, unchanged).
- Any change to `asvs-verification/README.md`, `cwe-cvss-findings/
  README.md`, or any `.claude-plugin/plugin.json` — survey §5 found no
  defect in any of them.
- hooks.json matcher changes or new Bash-tool coverage — survey §3/§4
  confirmed no gap exists to fix.
- Landing `core/hooks/lib/gate-lib.sh` / `gate-lib.py` /
  `compliance-check.sh` themselves, or `on-the-record`'s `spawn.py` —
  both are already-landed, out-of-repo deliverables (core issue #75,
  on-the-record issue #182) this proposal only references.
- **APPROVE** — this is phase 1 only; phase 2 opens strictly through the
  role-handoff contract v3 s19 approval paths.
