# issue-1 phase-2 record — secure-coding rulebook maturity reflection

## What was done

Reflected the approved phase-1 proposal
(`docs/issue-1/proposals/secure-coding-rulebook-maturation.md`) into the
plugin, per contract v3 s19 phase 2:

- `secure-coding/hooks/directive.sh` — the `produces` string now states the
  concrete required-field schema instead of a one-line gesture at ASVS:
  verification level (ASVS L1/L2/L3 + justification), ASVS checklist
  (requirement ID + pass/fail + evidence), CWE-tagged finding list (CWE ID
  + CVSS severity + repro + remediation status), scope-covered summary.
- No new record-field schema file was added under `secure-coding/hooks/`.
  Confirmed against core canon (`core/hooks/record-fields-gate.sh`,
  wired globally via core's own `hooks/hooks.json` PreToolUse chain) that
  the generic §20 record-fields gate already enforces this role's own
  record file (`docs/issue-<n>/reports/secure-coding.md`) for the baseline
  fields (what-was-done, why, upstream-basis, loop_state, open-findings);
  the role-specific ASVS/CWE schema from item 1 is the layer on top of
  that baseline, and per proposal (d)-2 it is encoded in the directive
  string rather than a new schema file, since core canon's pattern does
  not use a per-role schema file for this.
- No `secure-coding/agents/warrant-hunter.md` was added — confirmed no
  warrant-hunter invocation is introduced by this reflection; the
  reference-never-vendor constraint (`docs/handbooks/canon-scripts.md` in
  `tokenmaxxxer-core`) stays satisfied by there being nothing to vendor.
- No STRIDE/PASTA/SAMM component was added, per proposal (b)-3 / (c).

## Why

The phase-1 proposal's rationale ((c) in
`docs/issue-1/proposals/secure-coding-rulebook-maturation.md`) established
that ASVS (requirements) + CWE/CVSS (findings) is the methodology this
role's own directive already gestures at, and that verification-level
selection must precede requirement enumeration to prevent scope drift on
auth/input-handling code. This reflection makes that schema the literal
contract text a session reads at SessionStart, closing the gap the issue-1
survey identified: the old `produces` line named ASVS/severity but did not
say what fields a record must actually carry.

## Upstream basis

- `docs/issue-1/proposals/secure-coding-rulebook-maturation.md` (approved
  via issue comment `APPROVE issue-1/secure-coding` by `JiwonJung94`, an
  account listed in `docs/specs/approvers.md`; single-account mode, PR #8
  author and approver are the same account).
- `docs/issue-1/reports/secure-coding/current-state-survey.md` and
  `scout-brief.md` (phase-1 evidence base).
- `core/hooks/record-fields-gate.sh` and
  `docs/handbooks/role-gates-tests.md` in `tokenmaxxxer-core` (confirmed
  the generic record-fields gate is already wired globally; no per-role
  schema file exists or is needed).

## Scope covered vs. proposed

Matches the phase-1 "Files touched (phase 2)" list exactly: directive.sh
edited, no record-field schema file added (contingency resolved to "not
needed"), this record added. No scope shrink or expansion.

## Open findings

None — this record documents a plugin-reflection task, not a code
security review; there is no target implementation in scope for this
issue to find ASVS/CWE findings against.

loop_state: landed
