---
status: proposed
files:
  - secure-coding/README.md
  - secure-coding/hooks/directive.sh
  - asvs-verification/README.md
  - asvs-verification/hooks/directive.sh
  - asvs-verification/hooks/level-gate.sh
  - cwe-cvss-findings/README.md
  - cwe-cvss-findings/hooks/directive.sh
  - cwe-cvss-findings/hooks/finding-gate.sh
  - README.md
  - docs/issue-23/reports/implementation.md
---

# Align rulebook with marketplace secure-coding.spec.json (issue #521)

## Request

Mirror execution-observation-rulebook #63's completed pattern: layer the
marketplace's landed `roles/specs/secure-coding.spec.json` (issue #521 —
required fields, closed enums, reference-resolution + recomputation
rules, 4-state `loop_state`, board-decidable `use_when`) onto this
rulebook's existing methodology docs, handbooks, and hooks as evidence
vocabulary — no role-scope change, no forked rule logic; cross-reference
the marketplace's own gate script instead.

## Constraints

- No new gate scripts, no new enforcement logic. Everything the spec asks
  for that this rulebook already enforces in substance (ASVS level enum,
  pass/fail verdict, CVSS severity, requirement/CWE ID patterns) gets its
  literal spec vocabulary added to existing comments/README text — it is
  not re-implemented.
- `reference_resolution` and `recomputation` are documented, not
  mechanically enforced here: the spec itself defers `recomputation`
  enforcement as a follow-up (`checked_by: "TBD"`), and
  `reference_resolution` is checked by a marketplace-side script
  (`on-the-record/hooks/role-spec-reference-guard.sh`) this rulebook
  should cite, not fork.
- `loop_state` vocabulary must be added without touching any existing
  landed record (`docs/issue-{1,10,13,16,19}/reports/secure-coding.md`
  keep `loop_state: landed` — no rewriting history).
- Stay inside the write set above; `docs/issue-23/reports/implementation.md`
  is this session's own phase-2 record, not a target doc edit.

## Rationale

Two ways to close the mismatch existed:

1. **(chosen) Layer vocabulary onto existing structures.** Add the spec's
   literal field names (`requirement_id`, `verdict`, plus explicit ties
   for `level`/`cwe`/`severity`), the spec's 4-state `loop_state` set, and
   a citation of the marketplace's `role-spec-reference-guard.sh`, into
   the READMEs and gate-script header comments that already own this
   subject matter. Zero new files, zero new gates, follows the issue's
   explicit instruction and the #63 precedent it names.

2. **(rejected) Build a local `role-spec-reference-guard` equivalent and a
   recomputation gate in this rulebook.** Rejected because the spec's own
   `checked_by` fields point at marketplace-side scripts
   (`on-the-record/hooks/...`) or mark enforcement `TBD` — forking that
   logic here would duplicate a check the marketplace already owns (or
   build a check the spec itself says isn't ready to exist yet), directly
   contradicting the issue's "reference marketplace gates rather than
   forking rule logic" instruction.

## What will be done

- `secure-coding/README.md`, `secure-coding/hooks/directive.sh`: cite
  `roles/specs/secure-coding.spec.json` (issue #521) as the source of the
  role's `use_when.board_condition` and required-field vocabulary; tighten
  the `use_when` line to name "no secure-coding record exists yet for
  that commit sha" per the spec's board condition.
- `asvs-verification/README.md`, `asvs-verification/hooks/level-gate.sh`
  (header comment only), `asvs-verification/hooks/directive.sh`: name the
  spec's literal field tokens `requirement_id` and `level` next to the
  existing `external-id-present`/`level-named` check descriptions, and add
  a paragraph documenting the spec's `recomputation` rule (cumulative
  L1⊂L2⊂L3, worst-case verdict) as a documented-but-deferred rule, citing
  the spec's own `checked_by: TBD` status.
- `cwe-cvss-findings/README.md`, `cwe-cvss-findings/hooks/finding-gate.sh`
  (header comment only), `cwe-cvss-findings/hooks/directive.sh`: name the
  spec's literal field tokens `cwe`, `verdict`, `severity` next to the
  existing `finding-list-or-na`/`cvss-labeled-severity` check
  descriptions; cite `on-the-record/hooks/role-spec-reference-guard.sh` as
  the reference-resolution check this rulebook defers to (no orphan
  `cwe`/`requirement_id` — not locally enforced).
- All three plugins' README/directive files: add the spec's `loop_state`
  vocabulary (`progress: checklisting, pentesting`; `terminal: landed`;
  `refusal: target-level-undeclared`; `error: target-unreachable`) as the
  role's documented loop_state set, superseding the bare-`landed`-only
  documentation that exists today. Existing landed records are untouched.
- Top-level `README.md`: add one line under the role summary pointing at
  `roles/specs/secure-coding.spec.json` (issue #521) as this rulebook's
  upstream spec basis.

## Out of scope

- Any change to what ASVS/CWE/CVSS content the role decides or produces
  (no role-scope change, per the issue).
- Building `role-spec-reference-guard.sh` or any local equivalent.
- Building recomputation enforcement (the spec marks it `TBD`/follow-up).
- Rewriting any already-landed `docs/issue-*/reports/secure-coding.md`
  record.
- Phase-2 implementation itself — this PR is the phase-1 proposal only,
  per contract v3 s19; execution starts after human Approve.

## How you'll know it worked

- `grep` for each of the spec's required-field names
  (`requirement_id`, `level`, `cwe`, `verdict`, `severity`) across this
  rulebook's methodology/handbook docs exits 0 for every field (issue's
  acceptance check #1).
- A grep set-diff of this rulebook's documented `loop_state` vocabulary
  against `{checklisting, pentesting, landed, target-level-undeclared,
  target-unreachable}` shows no missing state (issue's acceptance check
  #2).
- `python3 -m pytest -q` — recorded as `unverifiable: no test suite
  present` (confirmed this session — see
  `docs/issue-23/reports/implementation/survey.md`), alongside a note on
  the shell gate-test scripts as this rulebook's actual executable check
  (issue's acceptance check #3).
