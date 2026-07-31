# issue-10 proposal — enforce the adopted ASVS/CWE-CVSS methodology as a plugin set (revision)

Subject: issue-10. Phase-1 proposal (role-handoff contract v3 s19) — no
plugin changes in this commit; execution starts only after Approve. Basis:
`docs/issue-10/reports/secure-coding/current-state-survey.md`,
`docs/issue-10/reports/secure-coding/scout-brief.md`, the norms already
adopted in `docs/issue-1/proposals/secure-coding-rulebook-maturation.md`
(parts a–d), and the approver's 요구 정정 comment on issue #10 (quoted in
full below). This proposal does not re-decide the methodology — it turns
the already-adopted methodology into a **plugin set**, one independent
plugin per adopted methodology, at the completeness bar set by
`tokenmaxxxer-core`'s `freelunch` plugin.

## Revision note — why this supersedes the prior version of this file

The approver reviewed the first version of this proposal (a single
`secure-coding/hooks/methodology-gate.sh` script deepening one plugin's
directive) and returned this correction on issue #10:

> ## 요구 정정 (승인자, proposal은 반드시 이 구조로)
> 단일 게이트/디렉티브 심화가 아니라 **플러그인 세트**로 체계화한다:
> - 채택 방법론 각각을 **독립 플러그인**으로 (core의 freelunch/scout처럼 —
>   룰북당 여러 개, freelunch 수준의 완성도).
> - **기획서(phase 1) 규범**과 **산출물(phase 2) 규범**도 각각을 플러그인
>   조합으로 풀어낸다 — 어떤 플러그인들이 조합되어 그 규범이 성립하는지가
>   설계의 본체.
> - 각 플러그인 = 자기 완결(디렉티브/게이트/에이전트/테스트 포함 가능),
>   marketplace.json 등록, 명확한 단일 방법론 담당.
> - proposal에는 플러그인 목록(이름·담당 방법론·구성요소·조합 관계)이
>   필수.

The same requirement was repeated as a FEEDBACK review comment on PR #11.
This revision replaces the single-script design end to end. Every section
below is new or rewritten against that structure; nothing from the single
`methodology-gate.sh` design carries forward as-is.

## (i) Verification level

L2 (standard) — unchanged from the prior version. The deliverable (a
plugin set of machine-verified gates guarding a phase-gated approval
workflow with a human sign-off boundary) is standard-rigor process
enforcement: not L1 (this is the load-bearing enforcement a human approval
depends on), not L3 (no cryptographic primitive, no multi-tenant isolation
boundary, no regulated-data handling in scope).

## (ii) Completeness bar — what "freelunch 수준" means, made concrete

Inspected `tokenmaxxxer-core/freelunch` (source of the bar the approver
named) and `tokenmaxxxer-core/scout` (the second named example) directly.
Both share this shape, adopted here as the per-plugin minimum:

- `.claude-plugin/plugin.json` — name, description, author. One plugin =
  one `name`, matching the single methodology it owns.
- `README.md` — what the plugin decides, how it works (mechanism list),
  install line, disable/kill-switch line, caveats/scope-of-evidence
  section. `freelunch`'s README is the template followed below.
- `hooks/` — the plugin's own directive fragment and/or gate script(s),
  registered via `hooks/hooks.json` (`scout`'s and `freelunch`'s pattern:
  a `PreToolUse` or `UserPromptSubmit` hook entry pointing at a script
  under the same plugin's `hooks/`).
  - Fail-closed shape carried from the prior version's `methodology-gate.sh`
    design: trap-at-top, a documented per-plugin kill switch env var,
    `CLAUDE_PROJECT_DIR` + git-toplevel root resolution, target-path
    narrowing before content work, `Write`/`Edit`/`MultiEdit` new-content
    reconstruction, `exit 2` with a message naming the missing element(s)
    and citing this proposal.
- `hooks/tests/` — a parse-check / gate-test script per plugin (`scout`
  and `freelunch` both ship one), not a single shared test file for the
  whole rulebook.
- Registration in `.claude-plugin/marketplace.json` at repo root — one
  entry per plugin, `source` pointing at the plugin's own top-level
  directory, sibling to the existing `secure-coding` entry (this repo's
  marketplace currently lists exactly one plugin; phase 2 adds the two
  named below as additional entries, keeping `secure-coding` itself as
  the umbrella/role-directive plugin it already is).
- Optional per `freelunch`'s own precedent (not required of every plugin,
  but available where the methodology needs it): `agents/` for a
  reusable worker/checklist asset, `workflows/*.js` for reusable
  multi-step scripts.

A plugin that ships only `plugin.json` + a bare hook script does **not**
meet this bar; README + tests are required, matching what `freelunch` and
`scout` both actually ship.

## (iii) Plugin inventory (필수)

Two methodologies were adopted in issue-1 (parts a–d): **ASVS**
(requirement-level verification) and **CWE + CVSS** (weakness-finding
capture). Per the correction, each becomes one independent plugin —
neither folded into the other, and neither folded into the existing
`secure-coding` role-directive plugin, which stays the umbrella that
enables both.

| # | Plugin name | Methodology owned | Components | `marketplace.json` entry |
|---|---|---|---|---|
| 1 | `asvs-verification` | ASVS: pick a verification level (L1/L2/L3) before enumerating requirements; produce a level-scoped requirement checklist | `hooks/directive.sh` (contributes the level-selection directive fragment), `hooks/level-gate.sh` (`PreToolUse` gate — phase-1: level named + level-before-requirement-IDs; phase-2: level carried over + checklist has requirement-ID + pass/fail + evidence per row), `hooks/hooks.json`, `hooks/tests/run-level-gate-tests.sh`, `README.md`, `.claude-plugin/plugin.json` | `source: "./asvs-verification"`, `description` names ASVS only |
| 2 | `cwe-cvss-findings` | CWE Top 25 + CVSS: every weakness finding is CWE-ID-tagged and CVSS-severity-scored, with reproduction and remediation status, or an explicit "N/A — none found" | `hooks/directive.sh` (contributes the finding-shape directive fragment), `hooks/finding-gate.sh` (`PreToolUse` gate — phase-2 only: CWE-ID present or explicit N/A; CVSS/band label attached per finding block, not just anywhere in the doc), `hooks/hooks.json`, `hooks/tests/run-finding-gate-tests.sh`, `README.md`, `.claude-plugin/plugin.json` | `source: "./cwe-cvss-findings"`, `description` names CWE/CVSS only |
| — | `secure-coding` (existing, unchanged in kind) | none of its own — umbrella role directive (`you_decide`/`use_when`/`hand_off`) that names ASVS-verification and CWE-CVSS-findings as the methodologies this role runs, and enables both plugins | `hooks/directive.sh` (edited, phase 2, to reference the two plugins by name instead of inlining their schemas), `.claude-plugin/plugin.json` | already registered |

No third plugin is proposed for STRIDE/PASTA/SAMM — unchanged from the
prior version's rationale: those stay out of scope, handed off to
`security-threat-model` (issue-1 (b)-3, (c)).

## (iv) Combination — how 기획서(phase 1) and 산출물(phase 2) 규범 are plugin combinations, not prose

This is the design's core, per the correction's second bullet: the phase
norms are not written as free-standing prose requirements anywhere in this
rulebook. They are the union of what the two plugins' gates check, split
by which phase's write target the gate matched.

**기획서 규범 (phase-1 proposal norm)** = `asvs-verification`'s phase-1
gate branch, alone. `cwe-cvss-findings` does not fire on phase-1 writes at
all (findings are a phase-2-only artifact — a proposal enumerates
requirements, not findings, per issue-1 (a)-2). Concretely, a proposal
under `docs/issue-<n>/proposals/*secure-coding*.md` must satisfy:
- `level-named` — L1/L2/L3 stated (asvs-verification).
- `level-before-requirements` — the level statement's offset precedes the
  first ASVS-requirement-ID token's offset in the reconstructed document
  (asvs-verification).
- `external-id-present` — at least one ASVS requirement ID present
  (asvs-verification).
- `survey-reference` — cites `current-state-survey` or a path under
  `docs/issue-<n>/reports/secure-coding/` (asvs-verification; carried
  from issue-1 (a)-2 item i).

**산출물 규범 (phase-2 record norm)** = `asvs-verification`'s phase-2
branch **combined with** `cwe-cvss-findings`'s phase-2 branch, both firing
independently on the same write to `docs/issue-<n>/reports/secure-coding.md`
(same additive-gates pattern this role already uses relative to core's
`record-fields-gate.sh` — see (vi)). Concretely:
- From `asvs-verification`: `level-carried-over`, `asvs-checklist`
  (requirement ID + pass/fail co-occurring), `scope-covered-summary`
  (issue-1 (b)-2 item 4 — assigned to this plugin because "scope proposed
  vs. covered" is a level/requirement-set concept, not a finding concept).
- From `cwe-cvss-findings`: `finding-list-or-na` (CWE-ID token, or the
  explicit N/A branch per issue-1 (b)-2 parenthetical), `cvss-labeled-
  severity` (a CVSS/band label attached to the same finding block that
  carries the CWE-ID — block-scoped, not whole-document, matching the
  prior version's `coding-progress-gate.sh`-style block-splitting
  technique).

Neither plugin alone can produce a passing phase-2 record; the record
norm exists only as their combination. This is the literal answer to
"어떤 플러그인들이 조합되어 그 규범이 성립하는지가 설계의 본체": the norm
*is* {asvs-verification phase-2 branch} ∧ {cwe-cvss-findings phase-2
branch}, not a third document describing them.

## (v) Directive text (phase 2 execution; text finalized here)

`secure-coding/hooks/directive.sh`'s `produces` string is replaced with a
short reference to the two plugins by name (mirrors how `core`'s
marketplace description references `freelunch`/`scout`/`warrant` by name
rather than inlining their rules):

    produces="PRODUCES: verification level + ASVS checklist per
    asvs-verification plugin; CWE-tagged, CVSS-scored finding list per
    cwe-cvss-findings plugin; scope-covered summary"

Each plugin's own `hooks/directive.sh` contributes the deeper, phase-split
steps/criteria/prohibitions text (the content drafted in the prior version
of this proposal, section (ii), is reassigned unchanged in substance:
level-selection steps and criteria go to `asvs-verification`; finding-
capture steps and criteria go to `cwe-cvss-findings`) via whatever
multi-fragment directive-composition mechanism core canon's
`role-directive.sh` supports at phase-2 time — to be confirmed against
core canon's current signature at execution, same deferral the prior
version already flagged for the single-plugin case.

## (vi) Relationship to core-canon gates

Unchanged from the prior version's finding: both new gates are additive to
`record-fields-gate.sh` (core canon, §20 generic fields), never a
replacement — one checks role-agnostic contract shape, the two plugin
gates check this role's own ASVS/CWE-CVSS methodology shape.
`record-fields-gate.sh` stays referenced from core, never vendored, per
`docs/handbooks/canon-scripts.md`; neither new plugin adds a copy of it or
of any other canon-manifest script.

## (vii) Gate tests (per plugin)

`asvs-verification/hooks/tests/run-level-gate-tests.sh` — minimum cases
(carried from the prior version's set 1–5, 9–10, 11–14, re-scoped to this
plugin's own gate only): phase-1 allow (all four present, ordered);
phase-1 deny × ordering violation, missing level, missing external ID,
missing survey reference; phase-2 allow (level + checklist + scope
summary present); phase-2 deny × missing level-carried-over, missing
pass/fail token, missing scope-covered summary; non-matching path → allow,
gate exits 0 without evaluating content; malformed JSON → deny,
fail-closed; unmatchable `Edit.old_string` → deny; kill-switch env var set
→ allow regardless of content.

`cwe-cvss-findings/hooks/tests/run-finding-gate-tests.sh` — minimum cases
(carried from the prior version's set 6–8, re-scoped): phase-2 allow, one
CWE finding with CVSS/band label; phase-2 allow, explicit "N/A — none
found", no CWE token; phase-2 deny, CWE ID present but no CVSS/band label
in that finding's block; non-matching path → allow; malformed JSON →
deny; unmatchable `Edit.old_string` → deny; kill-switch env var set →
allow regardless of content.

Each case: a JSON payload piped into the plugin's own gate script via
stdin, asserting exit code (0 = allow, 2 = deny) and, for deny cases, that
stderr names the expected missing-element slug — same harness shape
`scout/hooks/tests/parse-check.sh` and `freelunch`'s test already use.

## Not needed: persisted-state ordering machine

Unchanged finding from the prior version, re-homed to `asvs-verification`:
the level-before-requirements ordering constraint is checkable from a
single reconstructed document (both required strings live in the same
phase-1 document by (iv) above), so no cross-call lock file is warranted.

## Not needed: a third plugin for STRIDE/PASTA/SAMM, or a `secure-coding/agents/` checklist asset

Unchanged from the prior version's rationale (see prior "Not needed:
`secure-coding/agents/`" section): the ASVS checklist references the
public ASVS document rather than shipping a frozen snapshot of it, so no
plugin needs an `agents/` checklist asset; `warrant-hunter.md` stays
core-canon-referenced, never vendored, in either new plugin.

## Files touched (phase 1, this commit)

- Edit: `docs/issue-10/proposals/enforcement-machine.md` (this file,
  revised to the plugin-set structure)
- (unchanged) `docs/issue-10/reports/secure-coding/current-state-survey.md`,
  `docs/issue-10/reports/secure-coding/scout-brief.md` — no new research
  claims required; the freelunch/scout structure inspected for (ii) is
  cited directly above rather than duplicated into a separate report.

## Files touched (phase 2, post-Approve — not in this commit)

- Add: `asvs-verification/.claude-plugin/plugin.json`,
  `asvs-verification/README.md`, `asvs-verification/hooks/directive.sh`,
  `asvs-verification/hooks/level-gate.sh`,
  `asvs-verification/hooks/hooks.json`,
  `asvs-verification/hooks/tests/run-level-gate-tests.sh`.
- Add: `cwe-cvss-findings/.claude-plugin/plugin.json`,
  `cwe-cvss-findings/README.md`, `cwe-cvss-findings/hooks/directive.sh`,
  `cwe-cvss-findings/hooks/finding-gate.sh`,
  `cwe-cvss-findings/hooks/hooks.json`,
  `cwe-cvss-findings/hooks/tests/run-finding-gate-tests.sh`.
- Edit: `.claude-plugin/marketplace.json` — add the two plugin entries
  from (iii), sibling to the existing `secure-coding` entry.
- Edit: `secure-coding/hooks/directive.sh` — replace `produces` per (v).
- Add: `docs/issue-10/reports/secure-coding.md` (the phase-2 record,
  itself required to pass both new gates it is written under —
  dogfooding, unchanged from the prior version's approach).

## Not in scope

- Any code change to `secure-coding/hooks/*`, any new plugin directory,
  or `.claude-plugin/marketplace.json` — phase 1 is proposal-only per
  contract v3 s19; nothing beyond this file is written in this commit.
- APPROVE-ing this proposal — exclusively a human act by an approvers.md
  account (`JiwonJung94`), per contract v3 s19; this session never
  approves its own or another role's work.
- Re-deciding the ASVS/CWE-CVSS methodology itself — already adopted in
  `docs/issue-1/proposals/secure-coding-rulebook-maturation.md`; this
  proposal only mechanizes it, now as a plugin set instead of a single
  script.
- A third plugin for STRIDE/PASTA/SAMM, a persisted cross-call ordering
  state machine, or a vendored `agents/` checklist asset — explicitly not
  needed, see above.
