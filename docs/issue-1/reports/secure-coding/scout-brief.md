# issue-1 scout brief — secure-coding domain methodology sweep

Mode: parallel sweep, 3 Agent-tool subagents in one batched message
(stage 1). Angles: (A) OWASP ASVS/SAMM, (B) CWE Top 25 / STRIDE / PASTA,
(C) NIST SSDF / BSIMM. Judge point after stage 1: all three angles
converged independently on the same shape (see must-bes below) — no
build decision would change with another round, so deepening stopped at
stage 1 (within the 5-stage/3-min budget).

## Must-bes (Kano) — every strong exemplar assumes these

- **Risk/level-based scoping decided up front**, before requirements are
  enumerated (ASVS picks L1-L3 by risk exposure before verification;
  SSDF PW.7 first decides review scope/type). Source:
  https://www.aikido.dev/learn/compliance/compliance-frameworks/owasp-asvs,
  https://www.cisa.gov/resources-tools/resources/nist-sp-800-218-secure-software-development-framework-v11-recommendations-mitigating-risk-software
- **Every requirement/finding carries a stable ID mapped to an external
  taxonomy** (ASVS requirement number, CWE ID) — never free-text-only.
  Source: https://www.aikido.dev/learn/compliance/compliance-frameworks/owasp-asvs,
  https://cwe.mitre.org/top25/archive/2024/2024_cwe_top25.html
- **Findings carry a reproducible/quantified severity**, not a subjective
  label — CVSS score or CVSS-derived rank. Source:
  https://cwe.mitre.org/top25/archive/2024/2024_cwe_top25.html
- **Every practice/task maps to a recorded, checkable output** (SSDF ties
  each Task to a Notional Output; PASTA ties each of its 7 stages to named
  artifacts: DFD, asset list, risk profile). Source:
  https://edu.chainguard.dev/software-security/secure-software-development/ssdf/,
  https://versprite.com/cybersecurity-listings/devsecops/pasta-threat-modeling/

## Performance axes (where strong exemplars visibly compete)

1. **Structural decomposition before enumeration** — STRIDE/PASTA require
   a data-flow/trust-boundary diagram before threats are listed, not an
   ad hoc bug list. Source: https://www.microsoft.com/en-us/securityengineering/sdl/threatmodeling
2. **Maturity-target explicitness** — SAMM scores current vs. target
   maturity per stream rather than demanding max-everywhere; BSIMM is
   descriptive (measures what orgs actually do) vs. prescriptive. Source:
   https://owasp.org/www-project-samm/, https://www.synopsys.com/content/dam/synopsys/bsimm/datasheets/BSIMM-activities-at-a-glance.pdf
3. **Gate integration** — secure code review is treated as a release-gate
   condition wired into the pipeline, not a bolt-on report. Source:
   https://www.blackduck.com/blog/infuse-security-into-your-software-development-life-cycle.html

## Adopt / skip

- **Adopt**: CWE-ID + CVSS-style severity per finding (CWE Top 25 model) —
  matches this role's existing directive wording ("pentest finding list w/
  severity") and is the lightest-weight of the surveyed schemes to enforce
  as required record fields.
- **Adopt**: ASVS-style leveled/numbered checklist for the requirements
  side (directive already says "ASVS checklist") — numbered, level-tagged
  items map directly to a "required fields" gate.
- **Skip**: full PASTA 7-stage business-risk process and full STRIDE
  data-flow-diagram-first decomposition as a MANDATORY phase-2 step — this
  role is a post-landing code-level gate ("구현이 공격에 견디는가", "인증/
  입력처리 코드 랜딩 후"), not a design-stage threat-modeling role; that
  role is explicitly handed off already (`security-threat-model`). Adopting
  full STRIDE/PASTA here would duplicate the hand-off role's job.
- **Skip**: SAMM's full 15-practice/30-stream maturity model as a mandatory
  phase-2 artifact — disproportionate to a single-role rulebook; its one
  useful idea (explicit current-vs-target level, not max-everywhere) is
  folded into the ASVS level field instead of adopting the whole model.

## Segment fit

This role sits at the "implementation verification" stage of the SDLC
(SSDF's "Produce Well-Secured Software" / PW.7-PW.8), scoped to code
already landed — closest fit is ASVS (verification-level checklist) +
CWE/CVSS (finding taxonomy + severity), not the design-stage frameworks
(STRIDE/PASTA/SAMM), which fit `security-threat-model` better.

## Gap line

Current state (see current-state-survey.md) already gestures at this shape
in one directive string ("ASVS checklist, pentest finding list w/
severity") but has no: (1) required-field schema for either artifact, (2)
level-scoping step before proposal work starts, (3) documented rationale,
(4) a gate that fails when fields are missing. This proposal supplies all
four against the must-bes above; the STRIDE/PASTA/SAMM-shaped gaps are
knowingly left unfilled (see Skip) because they belong to a different,
already-designated role.

Sources consulted:
- https://www.aikido.dev/learn/compliance/compliance-frameworks/owasp-asvs
- https://owasp.org/www-project-samm/
- https://devguide.owasp.org/en/03-requirements/05-asvs/
- https://cwe.mitre.org/top25/archive/2024/2024_cwe_top25.html
- https://www.microsoft.com/en-us/securityengineering/sdl/threatmodeling
- https://versprite.com/cybersecurity-listings/devsecops/pasta-threat-modeling/
- https://www.cisa.gov/resources-tools/resources/nist-sp-800-218-secure-software-development-framework-v11-recommendations-mitigating-risk-software
- https://edu.chainguard.dev/software-security/secure-software-development/ssdf/
- https://www.synopsys.com/content/dam/synopsys/bsimm/datasheets/BSIMM-activities-at-a-glance.pdf
- https://www.blackduck.com/blog/infuse-security-into-your-software-development-life-cycle.html
