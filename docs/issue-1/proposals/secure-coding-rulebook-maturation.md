# issue-1 proposal — secure-coding rulebook maturity norms

Subject: issue-1. Phase-1 proposal (role-handoff contract v3 s19) — no
plugin changes in this commit; execution starts only after Approve. Basis:
`docs/issue-1/reports/secure-coding/current-state-survey.md` and
`docs/issue-1/reports/secure-coding/scout-brief.md`.

## (a) Phase-1 proposal norms — methodology, required sections, evidence form

Every future phase-1 proposal this role writes (not just this one) must:

1. **Decide a verification level before scoping the ask**, ASVS-style:
   state which of L1 (opportunistic/automatable), L2 (standard,
   most business logic), or L3 (critical/high-value) applies to the target
   code, and why — before enumerating requirements. This mirrors ASVS's
   "pick the level first" methodology (scout-brief must-be 1) and prevents
   scope creep or under-scoping decided ad hoc mid-review.
2. **Required sections, in order**: (i) current-state survey reference,
   (ii) verification level + justification, (iii) the requirement/finding
   set proposed for phase 2, each tagged with a stable external ID
   (ASVS requirement number for requirements, CWE ID for known-weakness
   findings), (iv) rationale tying the chosen scope back to the survey's
   gap line, (v) plugin reflection plan (directive/record-field/gate
   changes), (vi) "Files touched (phase 2)" and "Not in scope" lists (house
   style already established by issue-2/issue-5's proposals).
3. **Evidence form**: every adopted requirement or finding class cites its
   external source (ASVS chapter/requirement number, CWE ID + CWE page
   URL) — no un-sourced "best practice" assertions, matching the scout
   directive's source-or-assumption-labeled rule.

## (b) Phase-2 deliverable norms — methodology, required components

Every phase-2 secure-coding record (`docs/issue-<n>/reports/secure-coding.md`)
must be produced by:

1. **Methodology**: ASVS-checklist verification against the level chosen in
   phase 1, plus CWE/CVSS-scored finding capture for anything found broken
   — not open-ended manual review with no taxonomy. This is the
   "Adopt" pairing from the scout brief: ASVS for the requirements side,
   CWE Top 25's frequency×severity model for the findings side.
2. **Required components** (record must contain all, or explicitly mark
   "N/A — none found" for the findings list; a missing section, not an
   empty one, fails the gate):
   - Verification level carried over from the phase-1 proposal (no
     re-litigating scope mid-execution).
   - ASVS checklist: each item = requirement ID + pass/fail + one-line
     evidence (command run, code line, or test result).
   - Finding list: each finding = CWE ID + CVSS (or CVSS-derived
     Low/Med/High/Critical) severity + reproduction (exact command/input
     and the wrong output it produces) + remediation status.
   - A one-line summary of scope actually covered vs. proposed (catches
     silent scope-shrink between phase-1 proposal and phase-2 execution).
3. **What is explicitly NOT required** (per scout brief Skip): a full
   STRIDE data-flow diagram, a PASTA 7-stage business-risk writeup, or a
   SAMM maturity scorecard. Those belong to `security-threat-model`
   (already the stated hand-off target in `secure-coding/hooks/directive.sh`);
   requiring them here would duplicate that role's job and inflate this
   role's record past what "구현이 공격에 견디는가" calls for.

## (c) Rationale for each adoption

- **ASVS over a from-scratch checklist**: the existing directive already
  names "ASVS checklist" — adopting the real ASVS numbering (rather than
  inventing role-specific items) means findings are portable, auditable
  against a public standard, and level-scoped without this rulebook having
  to invent its own maturity scale. Logical fit: this role's own
  `you_decide` string ("구현이 공격에 견디는가") is exactly ASVS's stated
  purpose — verifying an already-built implementation, not designing one.
- **CWE ID + CVSS over a free-text severity label**: a free-text
  "high/medium/low" is not reproducible or comparable across findings or
  across time; CWE Top 25's frequency×severity formula is the industry's
  own answer to "how do you rank code-level weaknesses objectively," and a
  CWE ID is what lets a future reader (or a future automated gate) look the
  weakness class up externally instead of trusting this role's own
  wording.
- **Verification-level-first over listing findings and scoping after**:
  ASVS's own methodology puts level selection before requirement
  enumeration because otherwise proposal scope silently drifts to "whatever
  was easy to check" instead of "what the risk exposure actually calls
  for." This directly serves the role's `use_when` ("인증/입력처리 코드
  랜딩 후") — auth/input-handling code is exactly the kind of surface
  where under-scoping the level is the most costly mistake.
- **Excluding STRIDE/PASTA/SAMM as mandatory**: this role's own directive
  already hands off design-stage threat-surface work to
  `security-threat-model`; requiring a full design-stage framework here
  would make two roles produce overlapping artifacts for the same code
  change, contradicting the contract's role-separation principle. Adopting
  their one transferable idea (target-level-before-enumeration, from SAMM;
  reproducible severity, from STRIDE's "elevation of privilege"-style
  categorization folded into CVSS impact) without adopting the whole
  framework keeps this role's phase-2 output proportionate to its stated
  scope.
- **warrant-hunter stays a core-canon reference, never vendored**: per the
  issue's own constraint and `docs/handbooks/canon-scripts.md` in
  `tokenmaxxxer-core` ("Canon scripts are referenced, never copied"), this
  proposal's plugin reflection plan below adds no `secure-coding/agents/`
  copy of `warrant-hunter.md`.

## (d) Plugin reflection plan (phase 2, post-Approve)

1. **`secure-coding/hooks/directive.sh`** — extend the `produces` string
   to name the required-field schema explicitly, e.g.:
   `produces="PRODUCES (required record fields): verification level
   (ASVS L1/L2/L3 + justification), ASVS checklist (requirement ID +
   pass/fail + evidence), CWE-tagged finding list (CWE ID + CVSS severity +
   repro + remediation status), scope-covered summary"` — replacing the
   current one-line "ASVS checklist, pentest finding list w/ severity"
   with the concrete schema this proposal defines, so the directive itself
   is the enforceable contract a session reads at SessionStart.
2. **Record required fields** — no dedicated `record-fields.sh`/schema file
   exists in this plugin today (confirmed by survey); phase 2 either adds
   one under `secure-coding/hooks/` (if core canon's role-directive
   pattern supports a schema file — to be confirmed against core canon at
   phase-2 time, referenced not vendored if it already exists as a canon
   script) or encodes the required-field list directly in the directive
   string per item 1, whichever core canon's current pattern actually
   supports — this decision is deferred to phase 2 execution, not decided
   here, since it depends on core canon state at that time.
3. **Gate**: phase 2 must confirm — before the phase-2 record is accepted
   as complete — that every one of the (b)-2 required components is
   present in `docs/issue-<n>/reports/secure-coding.md`; a section marked
   missing (not explicitly "N/A — none found") fails the record. This
   mirrors the two existing sibling proposals' pattern of stating an exact
   post-Approve checklist rather than leaving verification to memory.
4. **No `secure-coding/agents/warrant-hunter.md` vendoring** — if phase 2
   determines this role should invoke warrant-hunter at all, it must do so
   via the core-canon reference path (resolved against the core plugin's
   install root), never a copy — same clause `docs/issue-5` already
   established for `stub-check.sh`.

## Files touched (phase 1, this commit)

- Add: `docs/issue-1/reports/secure-coding/current-state-survey.md`
- Add: `docs/issue-1/reports/secure-coding/scout-brief.md`
- Add: `docs/issue-1/proposals/secure-coding-rulebook-maturation.md` (this
  file)

## Files touched (phase 2, post-Approve — not in this commit)

- Edit: `secure-coding/hooks/directive.sh` (produces string, per (d)-1)
- Possibly add: a record-field schema file under `secure-coding/hooks/`
  (per (d)-2, contingent on core canon's current pattern)
- Add: `docs/issue-1/reports/secure-coding.md` (the phase-2 record itself,
  written against the (b) required components)

## Not in scope

- Any code change to `secure-coding/hooks/directive.sh` or any other
  plugin file — phase 1 is proposal-only per contract v3 s19.
- APPROVE-ing this proposal — that is exclusively a human act by an
  approvers.md account (JiwonJung94), per contract v3 s19; this session
  never approves its own or another role's work.
- A full STRIDE/PASTA/SAMM implementation — explicitly excluded per (b)-3
  and (c) above, not merely deferred.
