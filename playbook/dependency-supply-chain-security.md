---
axis: dependency-supply-chain-security
rule_count_floor: 8
---

# Dependency & supply-chain security

Decision rules for accepting, patching, and retiring third-party
dependencies. Research trail: layer 1 (OWASP Vulnerable Dependency
Management Cheat Sheet) plus layer 2 (ASVS V14/V1 dependency chapter,
CWE-1104 Use of Unmaintained Third-Party Components).

## Rules

1. When a project starts, wire automated dependency vulnerability
   scanning into CI from the first commit rather than adding it later —
   "it's highly recommended to perform automated analysis of the
   dependencies from the birth of the project," because unscanned
   dependencies accumulate unknown risk the longer scanning is
   deferred. source:
   https://cheatsheetseries.owasp.org/cheatsheets/Vulnerable_Dependency_Management_Cheat_Sheet.html

2. When a scanner reports a patch is available for a vulnerable
   dependency, update it in a testing environment and validate through
   the existing automated test suite before promoting — this is the
   default path ("update the version of the dependency in the project
   on a testing environment") and should not require a special-case
   process. source:
   https://cheatsheetseries.owasp.org/cheatsheets/Vulnerable_Dependency_Management_Cheat_Sheet.html

3. When no patch exists yet but the vulnerable code path is reachable
   from untrusted input, apply a protective workaround (WAF rule,
   parameter validation at the boundary) as a stopgap, not as the
   permanent fix — "security devices, such as the Web Application
   Firewall (WAF), can handle such issues by protecting applications
   through parameter validation," pending the real patch. source:
   https://cheatsheetseries.owasp.org/cheatsheets/Vulnerable_Dependency_Management_Cheat_Sheet.html

4. When accepting a known vulnerability's risk instead of patching, route
   that decision to the accountable risk owner (e.g. CRO-equivalent),
   not the implementing engineer alone — "this decision must be taken
   by the Chief Risk Officer... based on technical feedback... as well
   as the CVE's CVSS score indicators." An engineer silently deferring a
   patch is not the same decision as an accountable owner accepting the
   risk. source:
   https://cheatsheetseries.owasp.org/cheatsheets/Vulnerable_Dependency_Management_Cheat_Sheet.html

5. When a dependency has no fix forthcoming and is open source,
   consider patching it directly (contribute/fork) before falling back
   to full replacement — "if the impacted dependency is an open source
   library then we... can create a patch," which the cheat sheet treats
   as a lighter-weight option than component replacement. source:
   https://cheatsheetseries.owasp.org/cheatsheets/Vulnerable_Dependency_Management_Cheat_Sheet.html

6. When no fix exists and patching is infeasible, treat replacement or
   defensive coding around the dependency as the last resort, not the
   first response — the cheat sheet frames this path as "really complex
   and time consuming and is generally used as last resort," so a
   faster mitigation (rule 3/5) should be exhausted first. source:
   https://cheatsheetseries.owasp.org/cheatsheets/Vulnerable_Dependency_Management_Cheat_Sheet.html

7. When a dependency scan or manual audit finds a package that is no
   longer imported/referenced by any code path, **REMOVE** it from the
   manifest rather than leave it "in case it's needed" — an unused
   dependency still ships in the build/attack surface and still needs
   patching under CWE-1104's unmaintained-component risk even though it
   contributes nothing to the product. source:
   https://cwe.mitre.org/data/definitions/1104.html

8. When a dependency has had no maintainer activity (releases, security
   advisories addressed) for an extended period while the project still
   depends on it for security-relevant functionality (crypto, auth,
   parsing), flag it for replacement proactively rather than waiting
   for a CVE to be filed against it — CWE-1104 names "use of
   unmaintained third-party components" itself as the weakness, not
   only a component's individual vulnerabilities. source:
   https://cwe.mitre.org/data/definitions/1104.html

9. When a NEW dependency is about to be added, check its maintenance
   posture and any known-open vulnerabilities' actual exploitability
   before it enters the manifest, rather than relying solely on the
   post-acceptance scan/patch ladder (rules 1-8) to catch problems
   later — a health check run at the moment of addition keeps an
   already-risky component from becoming the project's problem in the
   first place, and prioritizing by exploitability/reachability rather
   than a flat CVSS-sorted list keeps the check from stalling on noise.
   ASVS V14.2.1.
</content>
