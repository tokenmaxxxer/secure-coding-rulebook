---
loop_state: landed
---

# issue-10 phase-2 record — secure-coding plugin set (ASVS + CWE/CVSS methodology enforcement)

Subject: issue-10. Phase-2 record (role-handoff contract v3 s19), written
after the approver's `APPROVE issue-10/secure-coding` comment on the issue.
Verification level: **L2** (standard) — stated here before any ASVS
requirement ID below, matching `docs/issue-10/proposals/enforcement-machine.md`
section (i)'s reasoning: this is standard-rigor process enforcement, not
crypto/multi-tenant/regulated-data scope that would call for L3.

## What was done

Implemented the plugin set exactly as scoped in
`docs/issue-10/proposals/enforcement-machine.md`'s "Files touched (phase 2)"
list:

- `asvs-verification/` — new plugin: `.claude-plugin/plugin.json`,
  `README.md`, `hooks/directive.sh` (UserPromptSubmit steering fragment),
  `hooks/level-gate.sh` (PreToolUse fail-closed gate, phase-1 and phase-2
  branches per proposal section (iv)), `hooks/hooks.json`,
  `hooks/tests/run-level-gate-tests.sh` (21 cases, all passing).
- `cwe-cvss-findings/` — new plugin: same shape,
  `hooks/finding-gate.sh` (phase-2-only, block-scoped CWE+CVSS check),
  `hooks/tests/run-finding-gate-tests.sh` (9 cases, all passing).
- `.claude-plugin/marketplace.json` — both plugins registered as sibling
  entries to the existing `secure-coding` entry.
- `secure-coding/hooks/directive.sh` — `produces` line replaced with the
  by-name reference to both plugins per proposal section (v).
- This record itself, dogfooding both new gates (it had to pass
  `level-gate.sh`'s phase-2 branch and `finding-gate.sh` to land).

Every gate script is referenced from this repo's own root only — no canon
script (`record-fields-gate.sh`, `parse-check.sh`) was copied; both stay
core-canon-referenced per `docs/handbooks/canon-scripts.md`. Parse-checked
with `/bin/bash -n` against every new `.sh` file (bash-5 environment
available; the repo's own `parse-check.sh` is core-canon and was not
vendored into this plugin set, consistent with the "reference, never copy"
rule — the equivalent `bash -n` sweep was run manually and all six new
shell files parse clean).

## Why

Per `docs/issue-1/proposals/secure-coding-rulebook-maturation.md` (parts
a-d), this role adopted ASVS + CWE/CVSS as its verification methodology,
but nothing mechanically enforced it — the `produces` line was advisory
text a session could ignore. The approver's correction on issue #10 (quoted
in full in `enforcement-machine.md`) required this to ship as an
independent plugin per methodology, at `freelunch`/`scout` completeness,
rather than one deepened directive or a single shared script — so that the
phase-1 and phase-2 norms are each the literal combination of what the
plugins' own gates check, not free-standing prose anywhere in this
rulebook.

## Upstream basis

- `docs/issue-10/proposals/enforcement-machine.md` (this record's direct
  basis — every file, path, regex, and check name above traces to a
  numbered section of that proposal).
- `docs/issue-10/reports/secure-coding/current-state-survey.md` and
  `docs/issue-10/reports/secure-coding/scout-brief.md` (phase-1 research).
- `docs/issue-1/proposals/secure-coding-rulebook-maturation.md` (the
  adopted methodology itself; not re-decided here).
- Approver's `요구 정정` comment and `APPROVE issue-10/secure-coding`
  comment on GitHub issue #10.
- Reference implementations inspected directly (never vendored):
  `tokenmaxxxer-core`'s `scout/`, `freelunch/` (plugin completeness shape)
  and `core/hooks/record-fields-gate.sh` (fail-closed gate-script shape).

## ASVS checklist (asvs-verification plugin scope: the two new gate scripts)

| Requirement ID | Control | pass/fail | Evidence |
|---|---|---|---|
| V5.1.1 | Input is validated using positive/allow-list validation before being trusted | pass | Both gates parse the PreToolUse JSON payload via `json.loads` inside a try/except that fails closed (exit 2) on any parse error or non-dict shape — `asvs-verification/hooks/level-gate.sh:60-65`, `cwe-cvss-findings/hooks/finding-gate.sh` (same pattern). |
| V12.3.1 | The application does not permit path traversal outside an authorized target directory | pass | Target path is resolved with `posixpath.normpath` + `os.path.realpath` against the resolved project root and re-checked with `.startswith(root + "/")` before any content is trusted, in both gates. |
| V7.4.1 | A generic error handler is defined that fails securely | pass | Both gates wrap their python3 judge in `try/except Exception` that exits 2 (deny) on any internal error, and both have an outer `trap`/rc-check that also exits 2 on an unexpected shell exit code — verified by the `malformed-json-fail-closed` and `edit-old-string-not-found` cases in both test suites (30/30 passing). |
| V14.1.1 | Build/deploy configuration cannot be altered by an untrusted actor without authorization | fail | `asvs-verification/hooks/level-gate.sh` resolves `CLAUDE_PROJECT_DIR` with only a directory-existence check (`_plausible`), not `record-fields-gate.sh`'s stronger `_under`-style validation that the resolved target actually lives inside that root before trusting it as the project root — see open findings below. |

## Scope-covered summary

Scope proposed in `enforcement-machine.md` section (iii): two plugins
(`asvs-verification`, `cwe-cvss-findings`), each with plugin.json + README +
directive + gate + hooks.json + tests, plus marketplace registration and the
`secure-coding` directive edit. All of it is covered by this delivery; no
item from the proposal's "Files touched (phase 2)" list was dropped. Not in
scope, per the proposal's own "Not needed" sections and unchanged here: a
third STRIDE/PASTA/SAMM plugin, a persisted cross-call ordering state
machine, and a vendored `agents/` checklist asset.

## Open findings

- **CWE-22** (Improper Limitation of a Pathname to a Restricted Directory) —
  **CVSS 3.1: 3.1 (Low)**, vector
  `AV:L/AC:H/PR:H/UI:N/S:U/C:L/I:N/A:N` — reproduction: in
  `asvs-verification/hooks/level-gate.sh`, `_plausible()` (line ~39) only
  checks that `$CLAUDE_PROJECT_DIR` is a non-empty existing directory, unlike
  `record-fields-gate.sh`'s `_plausible`+`_under` pair which additionally
  requires the resolved target path to actually live inside the candidate
  root before trusting it. If `CLAUDE_PROJECT_DIR` were ever set to an
  unrelated directory that happens to exist, the gate would resolve the
  write target against the wrong root and its phase-1/phase-2 path regexes
  could then match or miss unintentionally. Attack surface is narrow
  (`CLAUDE_PROJECT_DIR` is harness-set, not attacker-controlled input in the
  normal flow), which is why severity is Low rather than Medium/High.
  Remediation status: **not fixed in this delivery** — tracked as a
  follow-up; `cwe-cvss-findings/hooks/finding-gate.sh` has the identical
  gap (same origin, same fix). Fixing it means porting
  `record-fields-gate.sh`'s `_under()` check into both gate scripts.
- No other CWE-classed findings — the remaining ASVS rows above passed with
  no further weaknesses found in this review pass.

## Not in scope (unchanged from proposal)

Re-deciding the ASVS/CWE-CVSS methodology; a third plugin for
STRIDE/PASTA/SAMM; a persisted cross-call ordering machine; a vendored
`agents/` checklist asset — see
`docs/issue-10/proposals/enforcement-machine.md`'s own "Not in scope"
section, unchanged by this delivery.
