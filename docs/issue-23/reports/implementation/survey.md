# Current-state survey — issue-23

Scope: align this rulebook's methodology docs/handbooks/hooks with
`roles/specs/secure-coding.spec.json` as landed in `tokenmaxxxer/on-the-record`
issue #521 (read via `gh api repos/tokenmaxxxer/on-the-record/contents/roles/specs/secure-coding.spec.json`).

## Spec content (issue #521, as landed)

```json
{
  "role": "secure-coding",
  "source_standard": "OWASP ASVS",
  "required_fields": [
    { "name": "requirement_id", "type": "ref", "required": true },
    { "name": "level", "type": "enum", "enum": ["L1","L2","L3"], "required": true },
    { "name": "cwe", "type": "ref", "required": false },
    { "name": "verdict", "type": "enum", "enum": ["pass","fail"], "required": true },
    { "name": "severity", "type": "string", "required": false }
  ],
  "reference_resolution": { "rule": "requirement_id must resolve to an actual ASVS clause; cwe, when present, must resolve to a real CWE identifier — no orphan references (issue-515 invariant 2).", "checked_by": "on-the-record/hooks/role-spec-reference-guard.sh" },
  "recomputation": { "rule": "level is cumulative per ASVS (L2 implies L1, L3 implies L1+L2); overall pass/fail is the worst-case verdict across cited requirement_id checks at the declared level, never a standalone summary field (issue-515 invariant 4).", "checked_by": "TBD (issue-521 out-of-scope note)" },
  "write_scope": ["docs/issue-<n>/reports/secure-coding.md"],
  "loop_state": { "progress": ["checklisting","pentesting"], "terminal": ["landed"], "refusal": ["target-level-undeclared"], "error": ["target-unreachable"] },
  "use_when": { "board_condition": "authentication or input-handling code landed on the branch AND no secure-coding record exists yet for that commit sha" }
}
```

## This rulebook's write set for the field (what phase 1 will touch)

- `secure-coding/README.md`, `secure-coding/hooks/directive.sh` — role directive.
- `asvs-verification/README.md`, `asvs-verification/hooks/level-gate.sh`,
  `asvs-verification/hooks/directive.sh` — the ASVS methodology plugin.
- `cwe-cvss-findings/README.md`, `cwe-cvss-findings/hooks/finding-gate.sh`,
  `cwe-cvss-findings/hooks/directive.sh` — the CWE/CVSS methodology plugin.
- `docs/handbooks/*` (methodology handbooks referencing loop_state/use_when).
- Top-level `README.md` (role summary table).

## What already matches the spec

- **`level` enum** — `asvs-verification/hooks/level-gate.sh` already enforces
  `L1`/`L2`/`L3` as the only accepted verification levels
  (`level-named`, `level-before-requirements` checks).
- **`verdict` enum** — `cwe-cvss-findings` and `asvs-verification` gates already
  require a `pass`/`fail`(`passed`/`failed`) token per requirement row
  (`asvs-checklist` check), matching the spec's closed `pass`/`fail` enum
  in substance, even though the literal field name `verdict` is never used.
- **`severity` (as CVSS band)** — `cwe-cvss-findings/hooks/finding-gate.sh`
  requires a CVSS vector or a CVSS v3.1 severity band per finding
  (`cvss-labeled-severity` check) — spec's optional `severity: string` is
  covered in substance.
- **`requirement_id` (as ASVS ID pattern)** — the gates already require an
  ASVS requirement-ID-shaped token (`V<n>.<n>...`) per
  `external-id-present`/`asvs-checklist`, matching the spec's `requirement_id`
  field in substance.
- **`cwe` (as CWE-ID pattern)** — `finding-list-or-na` already requires a
  `CWE-<digits>` token or an explicit N/A, matching the spec's optional `cwe`
  field in substance.
- **loop_state mechanism** — every existing secure-coding record in this repo
  (`docs/issue-{1,10,13,16,19}/reports/secure-coding.md`) carries
  `loop_state: landed`, sourced from core canon's generic terminal-state
  default (`docs/issue-2/reports/implementation/current-state-survey.md:51`
  records "Terminal `loop_state` values default to `{"landed"}`").

## Confirmed mismatches (grep-verified, this session)

1. **No literal required-field names.** Grepping this repo for the spec's
   literal field-name tokens (`requirement_id`, `verdict`) returns zero
   hits outside this survey. Issue #23's acceptance check #1 requires every
   required-field name from the spec to appear at least once in this
   rulebook's methodology/handbook docs (`grep` per field exits 0) — this
   currently fails for `requirement_id` and `verdict`. `level`, `cwe`, and
   `severity` do appear as bare words in prose/README text but never
   anchored to the spec's field vocabulary.

2. **No role-specific `loop_state` vocabulary.** The spec declares
   `progress: [checklisting, pentesting]`, `terminal: [landed]`,
   `refusal: [target-level-undeclared]`, `error: [target-unreachable]` for
   `secure-coding` — a full 4-state loop_state model. This rulebook has
   never recorded anything but the bare terminal `landed` (core canon's
   generic default); `checklisting`, `pentesting`,
   `target-level-undeclared`, and `target-unreachable` appear nowhere in
   the repo. Issue #23's acceptance check #2 (grep set-diff of loop_state
   vocabulary) currently shows the full spec set on one side and only
   `{landed}` on this rulebook's side.

3. **No reference-resolution enforcement.** The spec's
   `reference_resolution` rule (no orphan `requirement_id`/`cwe` references)
   names `on-the-record/hooks/role-spec-reference-guard.sh` as the
   checking script. This rulebook has no equivalent gate, and no doc
   mentions the marketplace gate by name — `role-spec-reference-guard`
   returns zero hits in this repo. Issue #23 asks to "reference marketplace
   gates rather than forking rule logic," i.e. cite the marketplace script,
   not reimplement orphan-reference checking locally.

4. **No `recomputation` rule stated.** The spec's cumulative-level,
   worst-case-verdict recomputation rule is undocumented here. The spec
   itself marks its `checked_by` as `TBD` (issue-521 out-of-scope,
   deferred as a follow-up) — so this rulebook only needs to document the
   rule's *existence* and defer enforcement the same way the spec does,
   not build a recomputation gate.

5. **No `use_when.board_condition` cross-reference.** The spec's board
   condition ("authentication or input-handling code landed AND no
   secure-coding record exists yet for that commit sha") is more specific
   than this rulebook's current `use_when` text ("인증/입력처리 코드 랜딩
   후" in `README.md`, `secure-coding/.claude-plugin/plugin.json`,
   `secure-coding/hooks/directive.sh`) — substantively close but doesn't
   name "no record exists yet for that commit sha" as part of the
   trigger condition, and never cites the spec/marketplace as the source.

## Prior pattern to mirror (execution-observation-rulebook #63 / PR #66)

Not directly readable from this checkout (different repo), but issue #23
names the pattern explicitly: "layer the spec's per-claim evidence
vocabulary onto existing structures, no role scope change, reference
marketplace gates rather than forking rule logic." This survey's mismatch
list #1–#5 is scoped to exactly that: add vocabulary and cross-references
to existing README/directive/gate-comment text, add zero new gates, add
zero new enforcement logic, and change no plugin's decided scope.

## Test suite check (acceptance check #3)

`python3 -m pytest -q` — checked this session: `no tests ran in 0.01s`
(no `pytest`-collectible test files in this repo; the gate suites are
shell scripts under `*/hooks/tests/run-*-gate-tests.sh`, run directly,
not via pytest). This rulebook's phase-2 record should state
`unverifiable: no test suite present` per the issue's acceptance check #3
wording, and separately note the shell gate-test scripts as the actual
executable check this rulebook has.

