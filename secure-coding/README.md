# secure-coding

The umbrella role-directive plugin for the `secure-coding` role (contract v3
role-handoff protocol). Enables the two independent methodology plugins in
this rulebook's plugin set — `asvs-verification` and `cwe-cvss-findings` —
per `docs/issue-10/proposals/enforcement-machine.md` section (iii).

## Upstream spec

This role's required-field vocabulary and board condition are defined by
the marketplace's `roles/specs/secure-coding.spec.json` (issue #521,
`tokenmaxxxer/on-the-record`): required fields `requirement_id`, `level`,
`cwe`, `verdict`, `severity`; `loop_state` progress states `checklisting`,
`pentesting`, terminal state `landed`, refusal state
`target-level-undeclared`, error state `target-unreachable`;
`use_when.board_condition`: "authentication or input-handling code landed
on the branch AND no secure-coding record exists yet for that commit sha".

This rulebook does not fork the spec's `reference_resolution` or
`recomputation` rules: `reference_resolution` (no orphan `requirement_id`/
`cwe` references) is checked by the marketplace's own
`on-the-record/hooks/role-spec-reference-guard.sh`; `recomputation`
(cumulative ASVS level, worst-case verdict) is documented as a rule but its
own `checked_by` is `TBD` (issue-521 out-of-scope note) — this rulebook
enforces neither locally, only the field vocabulary in substance, via
`asvs-verification` and `cwe-cvss-findings`.

## Layout

- `hooks/hooks.json` — SessionStart wiring.
- `hooks/directive.sh` — SessionStart role directive (canon stub form,
  sources `core/hooks/lib/role-directive.sh`).

See the top-level `README.md` for the full plugin-set layout.
