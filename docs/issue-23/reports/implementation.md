---
code_under_review: HEAD
loop_state: landed
---

# Implementation record — issue-23

## Summary of work

Layered `roles/specs/secure-coding.spec.json` (marketplace issue #521)
vocabulary onto this rulebook's existing methodology docs/handbooks/hooks,
per the approved proposal `docs/issue-23/proposals/spec-alignment.md`:

- `secure-coding/README.md` (new file) and `secure-coding/hooks/directive.sh`:
  cite the spec as the source of the role's `use_when.board_condition` and
  required-field vocabulary; `use_when` line now names "no secure-coding
  record exists yet for that commit sha" per the spec's board condition.
- `asvs-verification/README.md`, `hooks/level-gate.sh` (header comment),
  `hooks/directive.sh`: name the spec's literal field tokens
  `requirement_id` and `level` next to the existing checks; document the
  spec's `recomputation` rule (cumulative L1⊂L2⊂L3, worst-case verdict) as
  documented-but-deferred, citing the spec's own `checked_by: TBD`.
- `cwe-cvss-findings/README.md`, `hooks/finding-gate.sh` (header comment),
  `hooks/directive.sh`: name the spec's literal field tokens `cwe`,
  `verdict`, `severity` next to the existing checks; cite
  `on-the-record/hooks/role-spec-reference-guard.sh` as the
  reference-resolution check this rulebook defers to.
- All three plugins' README/directive files: add the spec's `loop_state`
  vocabulary (`checklisting`, `pentesting` progress; `landed` terminal;
  `target-level-undeclared` refusal; `target-unreachable` error).
- Top-level `README.md`: one line citing
  `roles/specs/secure-coding.spec.json` (issue #521) as upstream spec basis.

No new gate scripts, no new enforcement logic, no role-scope change. No
already-landed `docs/issue-{1,10,13,16,19}/reports/secure-coding.md` record
touched.

## Why

Basis: `docs/issue-23/proposals/spec-alignment.md` (approved via issue
comment `APPROVE issue-23/implementation`, contract v3 s19 single-account
mode — PR author and approver are the same account, `JiwonJung94`, listed in
`docs/specs/approvers.md`). Mirrors execution-observation-rulebook #63's
completed pattern per issue #23's explicit instruction.

## Doc-placement ladder (completed items)

- [x] Spec vocabulary and loop_state set documented in
      `secure-coding/README.md`, `secure-coding/hooks/directive.sh`.
- [x] ASVS field vocabulary + recomputation (deferred) documented in
      `asvs-verification/README.md`, `hooks/level-gate.sh` header,
      `hooks/directive.sh`.
- [x] CWE/CVSS field vocabulary + reference-resolution citation documented
      in `cwe-cvss-findings/README.md`, `hooks/finding-gate.sh` header,
      `hooks/directive.sh`.
- [x] Upstream spec basis line added to top-level `README.md`.
- No `docs/decisions/` entry needed: no library/format choice over a named
  alternative and no public signature/wire-format change occurred — this
  is vocabulary layering onto existing prose/comments only.

## Acceptance checks (issue #23)

- check 1 (required-field names appear): verified below.
- check 2 (loop_state vocabulary set-diff): verified below.
- check 3 (`python3 -m pytest -q`): **unverifiable: no test suite present**
  (no pytest-collectible files in this repo; `no tests ran in 0.01s`,
  confirmed this session — same finding as
  `docs/issue-23/reports/implementation/survey.md`). This rulebook's actual
  executable checks are the shell gate-test suites
  (`*/hooks/tests/run-*-gate-tests.sh`), run directly, unaffected by this
  vocabulary-only change (no gate logic edited, only header comments).

## What did not work

None.

## Hunt record (before-landing, stance 4)

Dispatched `warrant-hunter` (stance 4: "the write set cannot carry this
work") before landing. Finding: directive/gate headers cite
`roles/specs/secure-coding.spec.json` and
`on-the-record/hooks/role-spec-reference-guard.sh`, neither of which
exists in this repo. This is by design, not a gap: both are
marketplace-repo (`tokenmaxxxer/on-the-record`) paths this rulebook
deliberately references rather than forks, per the proposal's Rationale
(rejected alternative #2: "Build a local `role-spec-reference-guard`
equivalent ... rejected because ... duplicate a check the marketplace
already owns") and Out of scope ("Building `role-spec-reference-guard.sh`
or any local equivalent"). Full record:
`docs/reports/2026-08-09-hunt-spec-alignment.md`.

## Open findings

None outstanding at time of writing.
