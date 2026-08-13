---
axis: cryptography-secrets-management
rule_count_floor: 10
---

# Cryptography & secrets management

Decision rules for choosing algorithms/key sizes and handling secret
material through its lifecycle. Research trail: layer 1 (OWASP
Cryptographic Storage / Secrets Management Cheat Sheets) plus layer 2
(ASVS V6/V7 crypto chapters, CWE-798 Hard-coded Credentials, CWE-327
Broken/Risky Crypto).

## Rules

1. When encrypting data at rest with a symmetric cipher, choose AES
   with a key of at least 128 bits, 256 preferred — "for symmetric
   encryption AES with a key that's at least 128 bits (ideally 256
   bits) and a secure mode should be used as the preferred algorithm."
   source: https://cheatsheetseries.owasp.org/cheatsheets/Cryptographic_Storage_Cheat_Sheet.html

2. When public-key cryptography is required, choose ECC with Curve25519
   as the default; if RSA must be used instead, require a key of at
   least 2048 bits. source:
   https://cheatsheetseries.owasp.org/cheatsheets/Cryptographic_Storage_Cheat_Sheet.html

3. When selecting a symmetric cipher mode, prefer an authenticated mode
   (GCM, CCM); CTR or CBC are acceptable only paired with a separate
   Encrypt-then-MAC step. **REMOVE** ECB mode wherever found outside a
   narrow documented exception — ECB leaks plaintext structure by
   design. source:
   https://cheatsheetseries.owasp.org/cheatsheets/Cryptographic_Storage_Cheat_Sheet.html

4. When a proposal surfaces a custom/home-grown cryptographic algorithm,
   **REMOVE** it before it lands — the cheat sheet's guidance is
   unqualified: "don't do this." Use a vetted standard algorithm and
   library instead. source:
   https://cheatsheetseries.owasp.org/cheatsheets/Cryptographic_Storage_Cheat_Sheet.html

5. When storing passwords, do not use reversible encryption — "passwords
   should not be stored using reversible encryption; secure password
   hashing algorithms should be used instead" (Argon2id/bcrypt/scrypt
   class, not a general-purpose cipher). source:
   https://cheatsheetseries.owasp.org/cheatsheets/Cryptographic_Storage_Cheat_Sheet.html

6. When code needs randomness for a token, key, or nonce, use the
   language's CSPRNG (`SecureRandom`, `crypto.randomBytes()`, the
   `secrets` module) and **REMOVE** any use of `Math.random()`/`rand()`
   in that path — non-cryptographic PRNGs are predictable and defeat
   the token's purpose even when every other control is correct.
   source: https://cheatsheetseries.owasp.org/cheatsheets/Cryptographic_Storage_Cheat_Sheet.html

7. When a secret needs to reach a running process, prefer a vault/secret
   manager (sidecar injection, mounted volume, remote fetch) over an
   environment variable — env vars are "generally accessible to all
   processes and may be included in logs or system dumps... therefore
   not recommended unless the other methods are not possible." source:
   https://cheatsheetseries.owasp.org/cheatsheets/Secrets_Management_Cheat_Sheet.html

8. When a secret is currently baked into a Docker image via `ENV`/`ARG`,
   **REMOVE** it from the image build and inject it at runtime instead —
   "secrets themselves should never be hardcoded using docker ENV or
   docker ARG commands, as these can easily leak with the container
   definitions." source:
   https://cheatsheetseries.owasp.org/cheatsheets/Secrets_Management_Cheat_Sheet.html

9. When a secret's function is high-risk (API signing key, database
   root credential), schedule automated rotation on a short cycle;
   ordinary user credentials are the exception — "user credentials are
   excluded from regular rotation. These should only be rotated if
   there is suspicion or evidence that they have been compromised."
   Rotation policy is therefore per secret-class, not one blanket
   interval. source:
   https://cheatsheetseries.owasp.org/cheatsheets/Secrets_Management_Cheat_Sheet.html

10. When a secret value appears in application logs (captured
    accidentally by a debug statement or error dump), **REMOVE** it
    from the log while preserving log integrity for the surrounding
    entries — "secrets in logs must have a process for removing the
    secret while maintaining log integrity"; silently leaving it
    is treated as an unresolved exposure, not a low-priority cleanup.
    source: https://cheatsheetseries.owasp.org/cheatsheets/Secrets_Management_Cheat_Sheet.html
</content>
