#!/usr/bin/env bash
# UserPromptSubmit hook: reminds the acting role of this plugin's own
# methodology shape. Enforcement itself lives in hooks/level-gate.sh
# (PreToolUse); this directive is steering only, same split scout/freelunch
# use between their UserPromptSubmit directive and their gate/observe script.
# Kill switch: export ASVS_VERIFICATION_OFF=1

# Off means off: `X_OFF=0` and `X_OFF=false` read as "not off" to a user and to
# most tooling, but any non-empty value used to disable the hook — the kill switch
# silently killed it on exactly the spelling meant to keep it alive.
case "${ASVS_VERIFICATION_OFF:-}" in
  ""|0|false|no|off) ;;
  *) exit 0 ;;
esac

cat <<'EOF'
[asvs-verification] ASVS methodology (enforced by hooks/level-gate.sh):
phase-1 proposal (docs/issue-<n>/proposals/*secure-coding*.md) must state a
verification level (L1/L2/L3) BEFORE the first ASVS requirement ID, and cite
the current-state survey. phase-2 record (docs/issue-<n>/reports/secure-coding.md)
must carry the level, an ASVS checklist (requirement ID + pass/fail per row),
and a scope-covered summary. See docs/issue-10/proposals/enforcement-machine.md.
EOF
exit 0
