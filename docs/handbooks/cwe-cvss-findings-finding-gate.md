# cwe-cvss-findings finding-gate

`cwe-cvss-findings/hooks/finding-gate.sh` is a `PreToolUse` gate
(Write|Edit|MultiEdit) that fires only on writes resolving to
`docs/issue-<n>/reports/secure-coding.md` (phase-2 only — this methodology
never gates phase-1 proposals); every other path is allowed without content
evaluation. It reconstructs the resulting document the same way
`asvs-verification/hooks/level-gate.sh` does, and fails closed the same way
on an unreconstructable write.

Requires either an explicit "N/A — none found" (or equivalent no-findings
phrase), or every `CWE-<n>` token in the document to have a CVSS/severity-
band label (`CVSS`, or `critical`/`high`/`medium`/`low`) within 300
characters after it — block-scoped, so a document with several findings
where only some carry a label still fails.

Kill switch: `export CWE_CVSS_FINDINGS_OFF=1`.

Run its tests directly, no setup required:

    bash cwe-cvss-findings/hooks/tests/run-finding-gate-tests.sh

Basis: `docs/issue-10/proposals/enforcement-machine.md` section (iv).
