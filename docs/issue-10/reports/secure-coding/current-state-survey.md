# issue-10 current-state survey — secure-coding plugin enforcement gap

Subject: issue-10. Phase-1 survey (role-handoff contract v3 s19), ahead of
the scout sweep and proposal below.

## What exists today

- `secure-coding/hooks/directive.sh` (7 lines): sources core canon's
  `role-directive.sh` and calls `core_role_directive` with four strings.
  `produces` already carries the schema adopted in issue-1 phase 2 (commit
  `3d1da38`): "verification level (ASVS L1/L2/L3 + justification), ASVS
  checklist (requirement ID + pass/fail + evidence), CWE-tagged finding
  list (CWE ID + CVSS severity + repro + remediation status), scope-covered
  summary". This is a one-line PRODUCES summary printed at SessionStart —
  advisory text a session reads, not a check anything runs.
- `secure-coding/hooks/hooks.json`: registers exactly one hook —
  `SessionStart` -> `directive.sh`. No `PreToolUse` hook, no gate script, no
  state file, no test.
- `secure-coding/.claude-plugin/plugin.json`: plugin manifest only, no
  agents/, no checklist assets.
- Core canon (`tokenmaxxxer-core/core/hooks/`) already ships
  `record-fields-gate.sh`, a **generic**, role-token-driven PreToolUse gate
  that fires on any write to `docs/issue-<n>/reports/${CLAUDE_ROLE}.md` and
  requires contract §20's role-agnostic minimum (what-was-done, why,
  upstream basis, `loop_state`, open-findings, and — when `loop_state` is
  non-terminal — next-steps + resolution path). This role already inherits
  that generic gate for free (it is core canon, applied by role-token
  substitution, not something this plugin has to write). It does **not**
  know about ASVS/CWE/CVSS — it has no concept of this role's own
  methodology fields.
- No `secure-coding/hooks/methodology-gate.sh` or equivalent exists. No
  file anywhere in this plugin mechanically checks for "ASVS L1/L2/L3",
  "CWE-", "CVSS", or a verification-level-before-requirements ordering
  constraint.
- No `tests/` directory exists in this repo root at all (contrast:
  `implementation-rulebook` ships `tests/run-gate-tests.sh` at repo root
  plus per-hook test scripts; `pricing-rulebook` ships
  `pricing/hooks/methodology-gate.sh` with matching gate tests).
- No `secure-coding/agents/` directory exists. The adopted norms
  (`docs/issue-1/proposals/secure-coding-rulebook-maturation.md`, part (d)
  point 4) explicitly ruled out ever vendoring `warrant-hunter.md` here —
  reference-only if invoked at all — so an agents/ directory is not
  self-evidently required by prior decisions; whether this round's adopted
  methodology needs a repeated-procedure checklist is a fresh question, not
  inherited.

## The gap this issue names

`implementation-rulebook`'s `coding/` plugin enforces its own methodology
mechanically: `coding-progress-gate.sh` (a PreToolUse gate on `git commit`,
~180 lines) blocks a commit when a blocking finding from `verify.md`
addressed to `coding` is unresolved, cross-referencing `loop_state` across
two records. `pricing-rulebook`'s `pricing/hooks/methodology-gate.sh` (a
PreToolUse gate on Write|Edit|MultiEdit targeting this role's own proposal/
record write surfaces, ~200 lines) requires six methodology elements be
textually present before the write is allowed to land, mirroring
`record-fields-gate.sh`'s fail-closed pattern exactly. `secure-coding` has
neither: the ASVS/CWE-CVSS methodology adopted in issue-1 lives only in the
`produces` string and in `docs/issue-1/proposals/`. A session can write a
phase-1 proposal or a phase-2 record that omits the verification level,
skips CWE tagging, or reports findings as free-text severity, and nothing
in the plugin refuses the write. The directive is instructional; nothing
is a gate.

## Write surfaces this role actually owns (from `hooks/directive.sh`
`hand_off` line: `WRITE_SCOPE: []` — report-only)

- `docs/issue-<n>/proposals/*secure-coding*.md` (or an issue-scoped
  proposal filename containing this role's name — phase-1 proposals,
  matching the `pricing` gate's `PROPOSAL_RE` shape).
- `docs/issue-<n>/reports/secure-coding.md` (phase-2 record — already
  covered generically by `record-fields-gate.sh`, but not for the
  ASVS/CWE-specific fields).
- `docs/issue-<n>/reports/secure-coding/*.md` (phase-1 survey/scout-brief
  homes — free-form, not methodology-gated in either sibling rulebook's
  pattern, and not proposed as a gate target here either: the methodology
  fields belong on the proposal/record, not the raw research notes).

## Ordering constraint named by the adopted norms

Part (a)-1 of `docs/issue-1/proposals/secure-coding-rulebook-maturation.md`:
"Decide a verification level before scoping the ask." This is a
sequencing rule (level → requirement/finding enumeration), the same shape
issue-10's own text names ("조사→근거→채택" pattern) as needing state
tracking when a methodology has an order constraint. Whether this specific
constraint is checkable by simple within-document ordering (verification
level text must appear before the requirement/finding list — a
single-write judgment, no state file needed) or needs a persisted-state
machine across turns (like `hunt-guard.sh`/`hunt-state.sh`'s lock+count
pair, which exists because the constraint spans *separate tool calls*
across a session, not one document's internal order) is a design decision
this survey defers to the proposal below — see the scout brief's gap line.

## Unknowns going into the scout sweep

1. Does a within-single-write ordering check (regex: level-section index <
   requirement-list-section index) suffice, or does the "decide before
   scoping" rule need cross-call state because a session could write the
   level in one Edit and the requirement list in a later, separate Edit
   that the gate cannot see the combined result of?
2. Should the methodology gate be one script (mirroring pricing's single
   `methodology-gate.sh` covering both phase-1 proposal and phase-2
   record) or two (phase-1 vs phase-2 have different required-field sets
   per (a)/(b) in the issue-1 proposal)?
3. Does this role's adopted methodology have any *repeated procedure*
   (per issue-10 item 4, "체크리스트") beyond writing the ASVS checklist
   itself — i.e., is there a reusable ASVS-L1/L2/L3 requirement checklist
   asset worth shipping, or does the record's own checklist section already
   satisfy that without a separate file?
