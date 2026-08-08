---
proposal: docs/issue-23/proposals/spec-alignment.md
---

# Hunt record — spec-alignment

## before-landing — stance 4: assume the write set cannot carry this work — find the path the build will need that the proposal does not list

Verdict: FINDING — directive/gate headers reference roles/specs/secure-coding.spec.json and on-the-record/hooks/role-spec-reference-guard.sh, but the phase-2 write set never creates either path, so the "checked_by" enforcement it names cannot exist.
Kind: design-error
Seed: secure-coding/hooks/directive.sh, asvs-verification/hooks/directive.sh, asvs-verification/hooks/level-gate.sh, cwe-cvss-findings/hooks/directive.sh, cwe-cvss-findings/hooks/finding-gate.sh (all changed in this dispatch's diff)
cap_seconds: 120
tier: default
diff_stat_lines: 64 insertions, 2 deletions across 8 files
started_at: 2026-08-09T00:00:00Z
ended_at: 2026-08-09T00:10:00Z

### Reproduce
```
cd /home/jwjung/.tokenmaxxxer/work/secure-coding-rulebook-issue-23-implementation
grep -n "role-spec-reference-guard\|secure-coding.spec.json" cwe-cvss-findings/hooks/finding-gate.sh asvs-verification/hooks/level-gate.sh
find . -iname "secure-coding.spec.json" -o -iname "role-spec-reference-guard.sh"
```

### Observed
The grep shows `finding-gate.sh` and `level-gate.sh` header comments naming `roles/specs/secure-coding.spec.json` as the field-vocabulary source and `on-the-record/hooks/role-spec-reference-guard.sh` as the thing that is `checked_by` for reference resolution (cwe-cvss-findings) — but the `find` returns nothing: neither file exists anywhere in the repository. `asvs-verification/hooks/level-gate.sh` explicitly says `checked_by: TBD`, confirming the enforcement was never wired up, yet the directive scripts and README docs across all three plugins now assert this vocabulary/guard as if it is a real, checkable reference.

### Expected
Either `roles/specs/secure-coding.spec.json` and `on-the-record/hooks/role-spec-reference-guard.sh` should exist (created as part of this phase-2 landing, since the header text presents them as authoritative sources being referenced/checked), or the directive/gate text should not claim a checked_by enforcement path that the write set never produced.
