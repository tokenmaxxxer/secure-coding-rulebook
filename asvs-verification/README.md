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

## Upstream spec vocabulary

Per `roles/specs/secure-coding.spec.json` (marketplace issue #521), the
requirement ID and level checks above correspond to the spec's required
fields `requirement_id` (type `ref`) and `level` (enum `L1`/`L2`/`L3`); a
pass/fail row corresponds to the spec's `verdict` (enum `pass`/`fail`).
This plugin's `level-named`/`external-id-present`/`asvs-checklist` checks
already enforce these in substance; this section only anchors the literal
field names.

The spec also states a `recomputation` rule: `level` is cumulative
(L2 implies L1, L3 implies L1+L2), and overall pass/fail is the worst-case
`verdict` across cited `requirement_id` checks at the declared level, never
a standalone summary field. This rulebook documents that rule but does not
enforce it — the spec's own `checked_by` for `recomputation` is `TBD`
(issue-521 out-of-scope note), so this plugin defers the same way the spec
does rather than forking a local recomputation gate.

## How it works

- `hooks/level-gate.sh` — a `PreToolUse` gate registered in
  `hooks/hooks.json` for `Write|Edit|MultiEdit`. It sources core canon's
  `gate-lib.sh`/`gate-lib.py` (`${CLAUDE_PLUGIN_ROOT_CORE:-$CLAUDE_PLUGIN_ROOT/../core}/hooks/lib/gate-lib.sh`,
  core issue #72) for the fail-closed EXIT trap (`gate_trap_fail_closed`),
  the kill switch (`gate_kill_switch_active`), malformed-JSON deny
  (`gate_parse_json_or_deny`), path normalization (`gate_normalize_path`),
  and full `Write`/`Edit`/`MultiEdit` reconstruction honoring `replace_all`
  per-edit (`gate_reconstruct_write`) — this gate does not re-derive any of
  that machinery locally. Root resolution stays local (not part of the
  core canon contract): `CLAUDE_PROJECT_DIR` if set and a real directory,
  else `git rev-parse --show-toplevel` — never derived from the tool
  call's own `file_path`.

  It fires only on writes whose resolved path matches one of two surfaces:
  - phase-1 (기획서): `docs/issue-<n>/proposals/*secure-coding*.md`
  - phase-2 (산출물): `docs/issue-<n>/reports/secure-coding.md`

  Any other path passes through untouched — the gate exits 0 without even
  reading the write's content.

  On a matching path, the gate checks the reconstructed resulting document
  text with section/adjacency checks, not flat substring search:

  **phase-1** — all four required, else deny:
  - `level-named` — an ASVS level (`L1`/`L2`/`L3`) sits within 60
    characters of the word "level" on the same line (a governing
    statement such as "Verification Level: L2"), not a bare token
    isolated in an unrelated footnote or code block.
  - `external-id-present` — at least one ASVS requirement ID
    (`V<n>.<n>...`, e.g. `V2.1.1`) is present.
  - `level-before-requirements` — when both of the above are present, the
    level token's offset in the document must precede the first
    requirement ID's offset.
  - `survey-reference` — the document cites the artifact-name token
    `current-state-survey` or a path under
    `docs/issue-<n>/reports/secure-coding/` outright, or — for a generic
    "current-state survey" prose mention — an adjacent backtick/path
    citation within 80 characters; a bare mention of the phrase with
    nothing cited does not satisfy this.

  **phase-2** — all three required, else deny:
  - `level-carried-over` — an ASVS level is still present somewhere.
  - `asvs-checklist` — **every** requirement ID occurrence in the document
    has its own pass/fail token (`pass`/`fail`/`passed`/`failed`,
    case-insensitive) within its own row/list-item boundary (from the
    requirement ID to the next blank line or the next
    table-row/list-item marker) — not just the first occurrence in the
    document.
  - `scope-covered-summary` — the document contains a "scope ... covered"
    style summary (matched loosely: `scope.{0,20}covered`,
    `scope-covered`, or `coverage summary`, case-insensitive).

  A denied write exits 2 and prints `asvs-verification: refused — ...` to
  stderr, naming exactly which slug(s) were missing (and, for
  `asvs-checklist`, which specific requirement ID(s) are unlabeled) and
  citing `docs/issue-10/proposals/enforcement-machine.md`.

- `hooks/tests/run-level-gate-tests.sh` — a standalone bash 3.2-compatible
  test harness exercising the gate as a real subprocess over stdin JSON
  payloads, including the Edit/MultiEdit `replace_all`, malformed-JSON,
  kill-switch-unrecognized-value, absolute-path, and trap-at-top cases
  from `docs/issue-13/proposals/gate-a-plus.md` section 4. It runs the
  gate with no Claude Code plugin context, so it resolves
  `CLAUDE_PLUGIN_ROOT_CORE` itself against a local core canon checkout
  (`CORE_PLUGIN_ROOT` is a back-compat alias, honored only when
  `CLAUDE_PLUGIN_ROOT_CORE` is unset — see the script header) — the gate's
  own runtime fallback is `$CLAUDE_PLUGIN_ROOT/../core`.

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
