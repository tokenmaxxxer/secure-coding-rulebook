# issue-10 proposal — enforce the adopted ASVS/CWE-CVSS methodology mechanically

Subject: issue-10. Phase-1 proposal (role-handoff contract v3 s19) — no
plugin changes in this commit; execution starts only after Approve. Basis:
`docs/issue-10/reports/secure-coding/current-state-survey.md`,
`docs/issue-10/reports/secure-coding/scout-brief.md`, and the norms already
adopted in `docs/issue-1/proposals/secure-coding-rulebook-maturation.md`
(parts a–d). This proposal does not re-decide the methodology — it turns
the already-adopted methodology into the four enforcement artifacts
issue-10 item 1–4 name.

## (i) Verification level

L2 (standard). The target of this proposal is the plugin's own hook/gate
code and its test suite — not auth/input-handling business logic, so the
role's own `use_when` doesn't fire on itself — but the *deliverable*
(machine-verified gates guarding a phase-gated approval workflow with a
human sign-off boundary) is exactly the class of control ASVS L2 targets:
standard rigor, not opportunistic (L1: these gates are the load-bearing
enforcement of a process boundary a human approval depends on, so
"probably fine" isn't enough) and not L3 (no cryptographic primitives, no
multi-tenant isolation boundary, no regulated-data handling in scope).

## (ii) Directive deepening — phase 1 / phase 2, per facet

The current `produces` string in `secure-coding/hooks/directive.sh` is a
one-line field list. Issue-10 item 1 asks for staged, criterion-bearing,
prohibition-bearing text per phase, not a longer one-liner. Proposed
replacement content for `directive.sh` (phase 2 execution; text finalized
here so phase 2 is a mechanical edit, not a fresh design):

**Phase 1 (proposal) facet:**
- Steps: (1) name the current-state survey this proposal is based on; (2)
  choose a verification level (L1/L2/L3) *before* naming any requirement
  or finding — ASVS's own level-first methodology, adopted in issue-1
  (a)-1; (3) enumerate the requirement/finding set, each item tagged with
  an external ID (ASVS requirement number or CWE ID); (4) tie scope back
  to the survey's gap line.
- Judgment criteria: L1 applies only to opportunistic/automatable checks
  with no auth or input-handling surface in scope; L2 is the default for
  business logic touching auth/input handling; L3 applies only when
  crypto primitives, multi-tenant isolation, or regulated data are in
  scope. A proposal that names L3 without one of those three triggers
  present in its own stated scope is over-scoped per this directive.
- Prohibitions: no un-sourced "best practice" requirement (every adopted
  item cites an ASVS requirement number or a CWE ID + CWE page URL); no
  requirement/finding enumerated before the verification level is stated;
  no STRIDE data-flow diagram, PASTA business-risk writeup, or SAMM
  maturity scorecard (hand off to `security-threat-model` instead, per
  the existing `hand_off` line — issue-1 (b)-3 and (c)).

**Phase 2 (record) facet:**
- Steps: (1) carry the verification level over from phase 1 verbatim (no
  re-litigating scope mid-execution — issue-1 (b)-2); (2) produce an ASVS
  checklist scoped to that level, each item = requirement ID + pass/fail +
  one-line evidence (command run, code line, or test result); (3) produce
  a CWE-tagged finding list, each finding = CWE ID + CVSS (or CVSS-derived
  Low/Med/High/Critical) severity + reproduction (exact command/input +
  wrong output) + remediation status, or an explicit "N/A — none found";
  (4) a one-line scope-covered-vs-proposed summary.
- Judgment criteria: a finding with no reproducible command/input is not
  an admissible finding — restate as an open question or drop it, mirroring
  the scout directive's source-or-assumption-labeled rule applied to this
  role's own findings.
- Prohibitions: a missing required component fails the record — an
  *empty* section is not the same as an *explicit* "N/A — none found",
  and only the latter is acceptable for a genuinely-empty finding list
  (issue-1 (b)-2 parenthetical, carried forward verbatim); no severity
  label without a CVSS score or CVSS-derived band backing it (a bare
  "high/medium/low" is refused, matching the pricing gate's
  numbers-must-carry-a-label pattern from the scout brief must-be 6/7).

## (iii) Methodology gate — mechanical verification of produces elements

New file, phase 2: `secure-coding/hooks/methodology-gate.sh`. Structural
shape (per scout brief "Adopt"): a `PreToolUse` gate on `Write|Edit|
MultiEdit`, mirroring `pricing/hooks/methodology-gate.sh` byte-for-shape
(fail-closed trap-at-top, kill switch `SECURE_CODING_METHODOLOGY_GATE_OFF`,
`CLAUDE_PROJECT_DIR` + git-toplevel root resolution, target-path narrowing
before content work, Write/Edit/MultiEdit new-content reconstruction,
`exit 2` with a message naming the missing element(s) and citing
`docs/issue-1/proposals/secure-coding-rulebook-maturation.md`).

Target regexes (this role's own write surfaces, per survey):
- `PROPOSAL_RE = ^docs/issue-[0-9]+/proposals/.*secure-coding.*\.md$`
- `RECORD_RE = ^docs/issue-[0-9]+/reports/secure-coding\.md$`

Required elements checked, **phase split** (unlike pricing's single
undifferentiated element list — this role's (a)/(b) norms genuinely
differ by phase, per survey unknown #2, resolved here: two element sets,
one script, branching on which regex matched):

Phase-1 write (`PROPOSAL_RE` match):
1. `level-named` — one of `l1`/`l2`/`l3` (case-insensitive, as a
   standalone token near "verification level" / "asvs level") is present.
2. `level-before-requirements` — the character offset of the matched
   level mention is strictly less than the character offset of the first
   ASVS-requirement-ID-shaped token (`\bASVS[- ]?\d` or similar) or CWE-ID
   token (`\bCWE-\d+\b`) in the document. Resolves survey unknown #1: this
   is a **single-document reconstructed-content check**, not persisted
   cross-call state — the gate already reconstructs the full proposed
   content (must-be 5), and both the level statement and the requirement
   list are required to exist in the *same* document by (ii) above, so
   their relative order is recoverable from one `new_text` string with no
   lock file. (A session that writes the level in one `Edit` and the
   requirement list in a later separate `Edit` is still caught: the gate
   re-evaluates the *reconstructed full file* on every qualifying write,
   so the second `Edit`'s reconstructed content contains both, in
   whichever order they now appear.)
3. `external-id-present` — at least one `\bASVS[- ]?\d` or `\bCWE-\d+\b`
   token exists (a proposal naming zero external IDs has not enumerated a
   sourced requirement/finding set).
4. `survey-reference` — the string `current-state-survey` or a path under
   `docs/issue-<n>/reports/secure-coding/` is present (issue-1 (a)-2 item
   i).

Phase-2 write (`RECORD_RE` match):
1. `level-carried-over` — same `level-named` check as phase-1 item 1.
2. `asvs-checklist` — at least one `\bASVS[- ]?\d` token AND at least one
   of `pass`/`fail` (case-insensitive) co-occurring in the document.
3. `finding-list-or-na` — either at least one `\bCWE-\d+\b` token, or the
   literal case-insensitive string `n/a` / `none found` co-occurring near
   "finding" — matches issue-1 (b)-2's explicit-N/A-not-empty-section
   rule.
4. `cvss-labeled-severity` — when a CWE-tagged finding is present (item 3
   matched via CWE, not the N/A branch), require `cvss` (case-insensitive)
   or one of `low`/`medium`/`high`/`critical` co-occurring within the same
   finding block (reuses `coding-progress-gate.sh`'s block-splitting
   technique — split on a finding-marker regex — rather than a whole-
   document keyword check, because severity must attach to *a* finding,
   not just appear anywhere in the record).
5. `scope-covered-summary` — the phrase `scope` co-occurring with `cover`
   or `covered` (issue-1 (b)-2 item 4).

Deny message format matches the exemplars: names every missing element by
its short slug (e.g. `level-before-requirements, asvs-checklist`) and
cites the norms doc section it comes from.

This is genuinely **additive** to `record-fields-gate.sh` (core canon,
§20 generic fields — what-was-done/why/upstream/loop_state/open-findings),
never a replacement: both gates fire independently on the same write, one
checking role-agnostic contract shape, the other checking this role's own
ASVS/CWE methodology shape. `record-fields-gate.sh` is referenced from
core, never copied, per `docs/handbooks/canon-scripts.md` — this proposal
adds no copy of it and no copy of any other canon-manifest file.

## (iv) Gate tests

New file, phase 2: repo-root `tests/run-methodology-gate-tests.sh`
(this repo currently has no `tests/` directory at all — survey finding —
so phase 2 also creates the directory, matching
`implementation-rulebook`'s `tests/run-gate-tests.sh` convention rather
than inventing a new layout). Minimum case set (pass/deny pairs, one per
required element, plus the ordering constraint and the phase-split
routing):

1. Phase-1 write, all four elements present, level-before-requirements →
   **allow**.
2. Phase-1 write, level present but stated *after* the first ASVS/CWE
   token → **deny** (`level-before-requirements`).
3. Phase-1 write, no level token at all → **deny** (`level-named`).
4. Phase-1 write, level + survey reference but zero ASVS/CWE tokens →
   **deny** (`external-id-present`).
5. Phase-1 write, all elements but no current-state-survey reference →
   **deny** (`survey-reference`).
6. Phase-2 write, all five elements present (one CWE finding, CVSS-
   labeled) → **allow**.
7. Phase-2 write, findings list explicitly "N/A — none found", no CWE
   token → **allow** (explicit-N/A branch).
8. Phase-2 write, finding block has a CWE ID but no CVSS/band label →
   **deny** (`cvss-labeled-severity`).
9. Phase-2 write, ASVS checklist present but no pass/fail token → **deny**
   (`asvs-checklist`).
10. Phase-2 write, missing scope-covered summary → **deny**
    (`scope-covered-summary`).
11. Write outside both regexes (e.g. a different role's proposal, or this
    role's own `docs/issue-<n>/reports/secure-coding/scout-brief.md`) →
    **allow**, gate exits 0 immediately without evaluating content
    (must-be 4 — "not this gate's business").
12. Malformed/unparseable JSON payload on stdin → **deny**, fail-closed
    message, not a silent pass.
13. `Edit` whose `old_string` does not match current file content →
    **deny**, "cannot determine resulting content" message (must-be 5).
14. `SECURE_CODING_METHODOLOGY_GATE_OFF=1` set → **allow** regardless of
    content (kill switch verified live).

Each case implemented as a JSON payload piped into
`secure-coding/hooks/methodology-gate.sh` via stdin, asserting exit code
(0 = allow, 2 = deny) and, for deny cases, that stderr names the expected
missing-element slug — same harness shape as
`implementation-rulebook/tests/run-gate-tests.sh` invokes its gates with.

## Not needed: persisted-state ordering machine

Resolves survey unknown #1 directly (see (iii) item 2 above): the
"level before requirements" ordering constraint is checkable from a
single reconstructed document, because both the level statement and the
requirement/finding list are required, by this same proposal's (ii), to
live in the *same* proposal document. A `hunt-guard.sh`/`hunt-state.sh`-
style lock+count file exists in `implementation-rulebook` to bound a
resource *across separate tool calls in a session* (concurrent/cumulative
subagent spawns) — a different problem shape than checking one
document's internal section order. Introducing persisted state here would
add a stateful failure mode (a stale lock surviving a crashed session,
exactly the bug class `hunt-state.sh`'s own header describes fixing)
for a constraint that a stateless re-derive-from-content check already
covers completely. If a future round of this role's methodology adds a
genuinely cross-call ordering constraint (e.g. "the phase-2 record's ASVS
checklist must reference a specific commit sha from a phase-1-approved
requirement list, and that mapping can't be recovered by re-reading
either document alone"), that would warrant revisiting this decision —
not before.

## Not needed: `secure-coding/agents/`

Resolves survey unknown #3: no reusable ASVS-L1/L2/L3 requirement
checklist *asset* is proposed. The record's own required "ASVS checklist"
section (iii, phase-2 item 2) already is the checklist — a session
producing it references the public ASVS document (external, versioned
elsewhere) for the requirement catalogue itself; shipping a frozen
snapshot of ASVS requirement IDs inside this plugin would create a second
copy of an external standard that drifts from upstream ASVS revisions,
the same class of problem `canon-scripts.md` names for internal scripts
applied to an external standard instead. No repeated *procedure* (per
issue-10 item 4) beyond "write the checklist, following the directive's
now-explicit steps" was found in the adopted norms that would need an
`agents/` subagent definition or a separate checklist file — the directive
text itself, deepened per (ii), is the checklist. `warrant-hunter.md`
stays out of scope entirely (issue-1 (d)-4, unchanged).

## Files touched (phase 1, this commit)

- Add: `docs/issue-10/reports/secure-coding/current-state-survey.md`
- Add: `docs/issue-10/reports/secure-coding/scout-brief.md`
- Add: `docs/issue-10/proposals/enforcement-machine.md` (this file)

## Files touched (phase 2, post-Approve — not in this commit)

- Edit: `secure-coding/hooks/directive.sh` — replace `produces`/expand
  directive text per (ii) (may also need `hand_off`/new variables if
  `core_role_directive`'s four-string shape can't hold the full staged
  text — to be confirmed against core canon's current signature at
  phase-2 time; if it can't, a fifth argument or a role-local heredoc
  appended after `core_role_directive` returns is the fallback, decided
  at execution time against whatever core canon's `role-directive.sh`
  looks like then).
- Edit: `secure-coding/hooks/hooks.json` — register the new
  `PreToolUse` hook for `methodology-gate.sh`.
- Add: `secure-coding/hooks/methodology-gate.sh` per (iii).
- Add: `tests/run-methodology-gate-tests.sh` (and `tests/` directory
  itself) per (iv).
- Add: `docs/issue-10/reports/secure-coding.md` (the phase-2 record,
  itself required to pass the new gate it is written under — dogfooding).

## Not in scope

- Any code change to `secure-coding/hooks/*` or any new file under
  `secure-coding/` or `tests/` — phase 1 is proposal-only per contract v3
  s19; nothing beyond the three files listed above is written in this
  commit.
- APPROVE-ing this proposal — exclusively a human act by an approvers.md
  account (`JiwonJung94`), per contract v3 s19; this session never
  approves its own or another role's work.
- Re-deciding the ASVS/CWE-CVSS methodology itself — already adopted in
  `docs/issue-1/proposals/secure-coding-rulebook-maturation.md`; this
  proposal only mechanizes it.
- A persisted cross-call state machine for the level-before-requirements
  ordering constraint — explicitly not needed, see above.
- A `secure-coding/agents/` checklist asset or any vendored copy of a
  canon-manifest-listed script — explicitly not needed / explicitly
  prohibited, see above and `docs/handbooks/canon-scripts.md`.
