#!/usr/bin/env bash
# UserPromptSubmit hook: reminds the acting role of this plugin's own
# methodology shape. Enforcement itself lives in hooks/finding-gate.sh
# (PreToolUse); this directive is steering only, same split scout/freelunch
# use between their UserPromptSubmit directive and their gate/observe script.
# Kill switch: export CWE_CVSS_FINDINGS_OFF=1

# Off means off: `X_OFF=0` and `X_OFF=false` read as "not off" to a user and to
# most tooling, but any non-empty value used to disable the hook — the kill switch
# silently killed it on exactly the spelling meant to keep it alive.
case "${CWE_CVSS_FINDINGS_OFF:-}" in
  ""|0|false|no|off) ;;
  *) exit 0 ;;
esac

cat <<'EOF'
[cwe-cvss-findings] CWE/CVSS methodology (enforced by hooks/finding-gate.sh):
phase-2 record (docs/issue-<n>/reports/secure-coding.md) only — every
weakness finding needs a CWE-ID token and a CVSS/severity-band label in the
same block, or an explicit "N/A — none found" when there are no findings.
See docs/issue-10/proposals/enforcement-machine.md.
Field vocabulary: cwe, verdict, severity per
roles/specs/secure-coding.spec.json (issue #521); reference_resolution
(no orphan cwe) checked_by on-the-record/hooks/role-spec-reference-guard.sh.
loop_state: checklisting/pentesting (progress), landed (terminal),
target-level-undeclared (refusal), target-unreachable (error).
EOF
exit 0
