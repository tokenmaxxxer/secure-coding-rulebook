# asvs-verification level-gate

`asvs-verification/hooks/level-gate.sh` is a `PreToolUse` gate
(Write|Edit|MultiEdit) that fires only on writes resolving to
`docs/issue-<n>/proposals/*secure-coding*.md` (phase-1) or
`docs/issue-<n>/reports/secure-coding.md` (phase-2); every other path is
allowed without content evaluation. It reconstructs the resulting document
from the tool input (Write's `content`, or Edit/MultiEdit's `old_string`→
`new_string` applied to the current file) and fails closed (exit 2) if that
reconstruction is not possible.

Phase-1 requires, in order: an ASVS level token (`L1`/`L2`/`L3`) before the
first ASVS requirement ID (`V\d+(\.\d+){1,3}`), at least one requirement ID,
and a reference to the current-state survey. Phase-2 requires the level
carried over, at least one requirement ID with a pass/fail token within 200
characters, and a scope-covered summary phrase.

Kill switch: `export ASVS_VERIFICATION_OFF=1`.

Run its tests directly, no setup required:

    bash asvs-verification/hooks/tests/run-level-gate-tests.sh

Basis: `docs/issue-10/proposals/enforcement-machine.md` section (iv).
