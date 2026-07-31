# asvs-verification

The ASVS methodology plugin for the `secure-coding` role, per
`docs/issue-10/proposals/enforcement-machine.md` section (iii) row 1. One
of two independent methodology plugins in this rulebook's plugin set (the
other is `cwe-cvss-findings`); `secure-coding` itself stays the umbrella
role-directive plugin that enables both.

## What the plugin decides

ASVS (OWASP Application Security Verification Standard) requires two
choices, in order, before a piece of work can be called ASVS-verified:

1. **Pick a verification level** — L1, L2, or L3 — before enumerating any
   requirement. The level bounds which requirements even apply; naming
   requirement IDs before the level is chosen is out of order.
2. **Produce a level-scoped requirement checklist** — once the level is
   fixed, the checklist enumerates the ASVS requirement IDs (e.g.
   `V2.1.1`) that level pulls in, and later (phase 2) records a pass/fail
   verdict against each.

This plugin does not re-decide L1/L2/L3 or the checklist rows themselves
— it enforces that the shape exists at the right phase, per the phase
norms in `docs/issue-10/proposals/enforcement-machine.md` section (iv).

## How it works

- `hooks/level-gate.sh` — a `PreToolUse` gate registered in
  `hooks/hooks.json` for `Write|Edit|MultiEdit`. It fires only on writes
  whose resolved path matches one of two surfaces:
  - phase-1 (기획서): `docs/issue-<n>/proposals/*secure-coding*.md`
  - phase-2 (산출물): `docs/issue-<n>/reports/secure-coding.md`

  Any other path passes through untouched — the gate exits 0 without even
  reading the write's content.

  On a matching path, the gate reconstructs the resulting document text
  (from `Write.content`, or by applying `Edit`/`MultiEdit`'s
  `old_string`/`new_string` against the file currently on disk) and
  checks it:

  **phase-1** — all four required, else deny:
  - `level-named` — an ASVS level (`L1`/`L2`/`L3`, case-insensitive) is
    stated somewhere.
  - `external-id-present` — at least one ASVS requirement ID
    (`V<n>.<n>...`, e.g. `V2.1.1`) is present.
  - `level-before-requirements` — when both of the above are present, the
    level statement's offset in the document must precede the first
    requirement ID's offset.
  - `survey-reference` — the document cites `current-state-survey` or a
    path under `docs/issue-<n>/reports/secure-coding/`.

  **phase-2** — all three required, else deny:
  - `level-carried-over` — an ASVS level is still present somewhere.
  - `asvs-checklist` — at least one requirement ID has a pass/fail token
    (`pass`/`fail`/`passed`/`failed`, case-insensitive) within 200
    characters after it.
  - `scope-covered-summary` — the document contains a "scope ... covered"
    style summary (matched loosely: `scope.{0,20}covered`,
    `scope-covered`, or `coverage summary`, case-insensitive).

  A denied write exits 2 and prints `asvs-verification: refused — ...` to
  stderr, naming exactly which slug(s) were missing and citing
  `docs/issue-10/proposals/enforcement-machine.md`.

- `hooks/tests/run-level-gate-tests.sh` — a standalone bash 3.2-compatible
  test harness exercising the gate as a real subprocess over stdin JSON
  payloads.

## Install

    claude plugin marketplace add tokenmaxxxer-secure-coding
    claude plugin install asvs-verification@tokenmaxxxer-secure-coding

## Temporarily disable

    export ASVS_VERIFICATION_OFF=1

## Caveats / scope of evidence

This is a **shape check** — string and regex presence over the
reconstructed document text — not a semantic ASVS correctness check. It
can confirm that a level is named, that requirement IDs and pass/fail
tokens exist in the right relative positions, and that a survey or scope
summary is cited. It **cannot** verify that the chosen level is the right
one for the work, that the enumerated requirement IDs are the correct
ones for that level, that a "pass" verdict is actually true, or that the
scope-covered summary is accurate. Those judgments stay with the human
approver and the acting role; this gate only enforces that the required
fields are present at all, at the phase they belong to.
