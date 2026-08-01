---
loop_state: landed
---

# issue-13 phase-2 record — gate-house Gate A+ hardening (asvs-verification + cwe-cvss-findings)

Subject: issue-13. Phase-2 record (role-handoff contract v3 s19), written
after the approver's `APPROVE issue-13/secure-coding` comment on the issue.
Verification level: **L2** (standard) — stated here before any ASVS
requirement ID below, carried over from
`docs/issue-13/proposals/gate-a-plus.md` (same rationale: this hardens
process-integrity gates guarding a human-approval boundary, not a
crypto/multi-tenant/regulated-data boundary).

## What was done

Precondition confirmed first, per `gate-a-plus.md` section 0: core issue
#72 ("gate-house standard") is merged to `tokenmaxxxer-core`'s `main`
(`22a7cad`, PR #74) and its canon files exist —
`core/hooks/lib/gate-lib.sh`, `core/hooks/lib/gate-lib.py`,
`docs/handbooks/gate-house-standard.md`,
`core/hooks/tests/compliance-check.sh`. Phase-2 execution proceeded on
that basis (it would otherwise have been blocked, per the proposal's own
"do not self-reimplement" clause).

- `asvs-verification/hooks/level-gate.sh` — rewritten to source
  `${CORE_PLUGIN_ROOT:-$CLAUDE_PLUGIN_ROOT/../core}/hooks/lib/gate-lib.sh`
  for the fail-closed EXIT trap, kill switch, JSON parse, path
  normalization, and full Write/Edit/MultiEdit reconstruction (all local
  hand-rolled versions of these deleted). Root resolution (not part of the
  core-canon contract) stays local but unchanged — it already resolved
  independent of the tool-supplied `file_path`. Semantic checks upgraded
  from flat substring search to adjacency/row-boundary checks: `level-named`
  now requires the level token within 60 characters of the word "level" on
  the same line (not an isolated token anywhere); `survey-reference` now
  requires either the canonical artifact-name token `current-state-survey`
  / an explicit path citation, or an adjacent backtick/path citation for a
  generic phrase mention; `asvs-checklist` now validates **every**
  requirement-ID occurrence's own row/list-item boundary, not just the
  first.
- `cwe-cvss-findings/hooks/finding-gate.sh` — same core-canon migration.
  Root resolution fixed: previously kept `_target` (the untrusted
  tool-supplied `file_path`) in scope for a `git -C "$(dirname
  "$_target")"` fallback before any validation (`gate-a-plus.md` section
  1b's confirmed defect); now resolves purely from `CLAUDE_PROJECT_DIR` or
  `git rev-parse --show-toplevel`, symmetric with `level-gate.sh`. The
  bash-level pre-extraction JSON parse (which silently swallowed a parse
  error via `except Exception: sys.exit(0)`, section 1c's confirmed
  asymmetry) is deleted; the gate has exactly one JSON-parse call site now
  (`gate_lib.gate_parse_json_or_deny`). Severity check upgraded from a
  bare-adjective substring match to `cvss_label_present`: a CWE-ID
  occurrence's own finding block (line start to next blank line/list
  item/table row) must carry a real CVSS vector string or a numeric base
  score consistent with its stated CVSS v3.1 band — a bare adjective with
  no vector/score no longer satisfies the check (closes the literal audit
  finding: severity was prose-only-satisfiable).
- Both gates: kill switch is now `gate_kill_switch_active` — an
  unrecognized value stays **active** (fixes the confirmed live fail-open
  bug where any unrecognized value silently disabled the gate). Edit/
  MultiEdit reconstruction is now `gate_lib.gate_reconstruct_write`,
  honoring `replace_all` per-edit (previously always
  `current.replace(o, n, 1)`, ignoring `replace_all` entirely). Deny
  reasons were already stderr-only in both gates (confirmed unchanged, no
  fix needed — `gate_deny`/local `deny()` wrapper both still write to
  stderr and exit 2).
- `asvs-verification/hooks/tests/run-level-gate-tests.sh` — 30 cases
  (was 12), all passing. Added: absolute-path/relative-path parity,
  Edit `replace_all:true` multi-occurrence, MultiEdit mixed
  `replace_all`, malformed-JSON non-object variant, kill-switch
  unrecognized-value-stays-active, trap-at-top forced-crash, and
  structural per-row `asvs-checklist` cases (only-first-row-labeled must
  deny; every-row-labeled must allow).
- `cwe-cvss-findings/hooks/tests/run-finding-gate-tests.sh` — 21 cases
  (was 9), all passing. Added the same six mandatory-shape cases plus the
  four severity-shape cases (bare-adjective-only deny, full-vector allow,
  score-consistent-with-band allow, score-inconsistent-with-band deny) and
  two block-boundary cases (adjacent list-item findings deny naming the
  unlabeled one; a single long finding whose label sits past 300
  characters still allows).
- `asvs-verification/README.md`, `cwe-cvss-findings/README.md` — "How it
  works" rewritten to name the actual `gate_lib::*` functions called and
  the upgraded check semantics; no residual description of the deleted
  local reimplementation left behind.
- `core/hooks/tests/compliance-check.sh` run by reference (never
  vendored) against both gates' hooks directories: **clean** on both
  after migration (see Evidence below; both were flagged before).

## Why

Per issue #13's audit (2026-08-01, "code audit result: grade A"): severity
was satisfiable by prose alone, path matching lacked absolute-path
normalization, the kill switch inverted fail-closed semantics on any
unrecognized value, `Edit`/`MultiEdit` reconstruction ignored
`replace_all`, and the semantic checks were flat substring search
satisfiable by an incidental word mention anywhere in the document. Issue
#13's own precondition required fixing this via core issue #72's shared
gate-house library, not a self-reimplementation — `gate-a-plus.md` section
0 makes that a hard phase-2 gate. This record demonstrates the reference
migration and the fixes it enabled.

## Upstream basis

- `docs/issue-13/proposals/gate-a-plus.md` (this record's direct basis —
  every fix and check name above traces to a numbered section of that
  proposal).
- `docs/issue-13/reports/secure-coding/survey.md` (current-state-survey,
  phase-1 research this proposal built on).
- `docs/handbooks/gate-house-standard.md` and `core/hooks/lib/gate-lib.sh`
  / `gate-lib.py` (tokenmaxxxer-core, core issue #72, merged `main` commit
  `22a7cad` / PR #74) — the canon this migration references, never
  vendors.
- `docs/handbooks/canon-scripts.md` — the reference-not-copy rule this
  migration follows (no `gate-lib.sh`/`gate-lib.py`/`compliance-check.sh`
  copy exists anywhere in this repo's tree).
- The prior issue-10 phase-2 record (this rulebook's own earlier
  delivery) — the path-validation finding it opened is re-assessed below.

## ASVS checklist

| Requirement ID | Control | pass/fail | Evidence |
|---|---|---|---|
| V2.1.1 | Path/target resolution is not derived from untrusted, tool-call-supplied input before validation | pass | `finding-gate.sh`'s root resolution no longer keeps the tool-supplied `file_path` (`_target`) in scope for its git-toplevel fallback; both gates resolve root from `CLAUDE_PROJECT_DIR` or `git rev-parse --show-toplevel` only, verified by `absolute-path-same-verdict-as-relative` in both suites (21/21, 30/30 passing). |
| V3.1.1 | The application fails closed / securely on an unhandled internal error | pass | `trap-at-top-forces-fail-closed` in both suites: a forced non-0/non-2 exit inside a script sourcing `gate_trap_fail_closed` is remapped to exit 2 with a "fail-closed" message on stderr. |
| V3.1.2 | Malformed or non-object input is rejected rather than best-effort parsed | pass | `deny-malformed-json` and `deny-malformed-json-non-object` (new) pass in both suites — `gate_lib.gate_parse_json_or_deny` denies on both a JSON syntax error and a non-dict top level. |
| V3.1.3 | A kill switch's unrecognized value does not silently disable the control | pass | `kill-switch-unrecognized-value-stays-active` (new, both suites): `ASVS_VERIFICATION_OFF=maybe` / `CWE_CVSS_FINDINGS_OFF=maybe` still deny non-conforming content — this is the literal fix for the confirmed live bug (previously any unrecognized value disabled the gate). |
| V5.1.1 | Input is validated using positive/allow-list validation before being trusted | pass | Both gates parse the PreToolUse JSON payload via `gate_lib.gate_parse_json_or_deny`, one call site, deny-on-anything-else. |
| V5.2.1 | `Edit`/`MultiEdit` content reconstruction reflects the tool's real documented semantics, including per-edit flags | pass | `edit-replace-all-true-both-occurrences` and `multiedit-mixed-replace-all` (new, both suites): `gate_lib.gate_reconstruct_write` honors `replace_all` per-edit; a MultiEdit mixing `true`/`false` entries reconstructs each independently. |
| V7.4.1 | A generic error handler is defined that fails securely | pass | Both gates' python judge is wrapped in `try/except Exception` denying (exit 2), plus the bash-level `gate_trap_fail_closed` EXIT trap as a second layer — both layers exercised by the test suites (51/51 passing). |
| V12.3.1 | The application does not permit path traversal outside an authorized target directory | pass | `gate_lib.gate_normalize_path(root, path)` normalizes and confirms the resolved path stays under the already-fixed root, root-first-then-normalize (never the reverse), in both gates. |
| V14.2.1 | A methodology's severity/finding shape check cannot be satisfied by prose alone where a structured signal is required | pass | `deny-bare-adjective-only` (new): a CWE-ID with only the prose word "high" and no vector/score denies; `allow-full-cvss-vector` and `allow-score-consistent-with-band` (new) pass on a real vector or a band-consistent numeric score; `deny-score-inconsistent-with-band` (new) denies a numerically inconsistent pair (e.g. score 2.0 paired with the Critical band word). |

## Scope-covered summary

Scope proposed in `gate-a-plus.md` section "Files touched (phase 2)": core
canon precondition confirmed; both gate scripts migrated to `gate-lib.sh`/
`gate-lib.py`; both test suites extended with the mandatory cases from
section 4; both READMEs re-synced; `compliance-check.sh` run by reference
and recorded clean. All of it is covered by this delivery — no item from
the proposal's phase-2 file list was dropped. Not in scope, per the
proposal's own "Not in scope" section and unchanged here: landing
`gate-lib.sh`/`gate-house-standard.md` themselves (core issue #72's own,
already-merged deliverable) and re-deciding the ASVS/CWE-CVSS methodology.

## Compliance detector evidence (reference execution, never vendored)

```
$ "${CORE_PLUGIN_ROOT}/hooks/tests/compliance-check.sh" asvs-verification/hooks
compliance-check: ok — asvs-verification/hooks/level-gate.sh

$ "${CORE_PLUGIN_ROOT}/hooks/tests/compliance-check.sh" cwe-cvss-findings/hooks
compliance-check: ok — cwe-cvss-findings/hooks/finding-gate.sh
```

Both were `FAIL` (hand-rolled kill switch, hand-rolled `.replace(...)`
reconstruction) against the pre-migration gates, confirmed as the baseline
before this delivery's edits.

## Open findings

- **CWE-22 (CVSS 3.1: 3.1, Low, vector `AV:L/AC:H/PR:H/UI:N/S:U/C:L/I:N/A:N`)**
  — Improper Limitation of a Pathname to a Restricted Directory. Carried
  forward from the prior issue-10 phase-2 record's original finding,
  re-assessed here: both gates' `_plausible()` check on
  `CLAUDE_PROJECT_DIR` still only confirms it is a non-empty existing
  directory (`level-gate.sh`) or additionally requires a `.git`/contract
  marker (`finding-gate.sh`), neither ports `record-fields-gate.sh`'s
  stronger `_under()`-style validation that the resolved write target
  itself lives inside that candidate root before the root is trusted.
  This is a narrower, separate gap from issue #13's audit scope (which
  targeted root resolution being derived from the tool-supplied path —
  now fixed, see the checklist row on that control above) —
  `CLAUDE_PROJECT_DIR` is harness-set, not
  attacker-controlled input in the normal flow, which is why severity
  stays Low. Remediation status: **not fixed in this delivery** — still
  tracked as a follow-up; `gate-lib.sh` does not provide a
  `CLAUDE_PROJECT_DIR`-trustworthiness check (it operates on an
  already-resolved `root`), so this would need its own local fix or a
  future core-canon addition.
- No other CWE-classed findings — every defect item from issue #13's
  audit (severity-prose, path-matching-root-from-untrusted-path,
  fail-closed trap/malformed-JSON/kill-switch, Edit/MultiEdit
  reconstruction, semantic-check substring-satisfiability) was
  structurally fixed and is covered by a green regression test above; no
  further weakness was found in this review pass.

## Not in scope (unchanged from proposal)

Landing `core/hooks/lib/gate-lib.sh` / `docs/handbooks/gate-house-standard.md`
themselves (core issue #72's own deliverable); re-deciding the ASVS/
CWE-CVSS methodology adopted in issue-1; a third STRIDE/PASTA/SAMM plugin;
a persisted cross-call ordering state machine — see
`docs/issue-13/proposals/gate-a-plus.md`'s own "Not in scope" section,
unchanged by this delivery.
