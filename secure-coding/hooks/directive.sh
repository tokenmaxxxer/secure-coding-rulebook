#!/usr/bin/env bash
. "${CLAUDE_PLUGIN_ROOT_CORE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../core" && pwd -P)}/hooks/lib/role-directive.sh"
you_decide="YOU DECIDE: 구현이 공격에 견디는가"
use_when="USE_WHEN: 인증/입력처리 코드 랜딩 후, AND no secure-coding record exists yet for that commit sha (roles/specs/secure-coding.spec.json, issue #521, use_when.board_condition)"
produces="PRODUCES: verification level + ASVS checklist (requirement_id, level, verdict) per asvs-verification plugin; CWE-tagged, CVSS-scored finding list (cwe, verdict, severity) per cwe-cvss-findings plugin; scope-covered summary. loop_state: checklisting/pentesting (progress), landed (terminal), target-level-undeclared (refusal), target-unreachable (error) — per roles/specs/secure-coding.spec.json (issue #521)."
hand_off=$'WRITE_SCOPE: [] (report-only role — no code/doc write outside the record itself)\nHAND-OFF: 설계 단계 위협표면 재검토가 필요하면 → security-threat-model'
core_role_directive "$you_decide" "$use_when" "$produces" "$hand_off"
