#!/usr/bin/env bash
. "${CLAUDE_PLUGIN_ROOT_CORE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../core" && pwd -P)}/hooks/lib/role-directive.sh"
you_decide="YOU DECIDE: 구현이 공격에 견디는가"
use_when="USE_WHEN: 인증/입력처리 코드 랜딩 후"
produces="PRODUCES (required record fields): ASVS checklist, pentest finding list w/ severity"
hand_off=$'WRITE_SCOPE: [] (report-only role — no code/doc write outside the record itself)\nHAND-OFF: 설계 단계 위협표면 재검토가 필요하면 → security-threat-model'
core_role_directive "$you_decide" "$use_when" "$produces" "$hand_off"
