# Legal and Ethical Use

This toolkit is intended **only** for authorized digital forensic triage.
"Authorized" means at least one of the following applies to the device
you intend to triage:

1. A **lawful order** (warrant, subpoena, court order, lawful police
   power) that names the device or covers the device.
2. **Documented written consent** from the device owner.
3. The device is **owned by your employer** and you are operating
   within the bounds of a documented Acceptable Use / Monitoring policy
   that the user has acknowledged.
4. The device is **your own** and you are practicing or training.

If none of these applies, **stop**. Do not run any collector script
against the device.

## What this toolkit is NOT

This toolkit does **not** include and will not accept contributions for:

- Lock-screen / passcode / PIN bypass.
- Jailbreak / root exploits.
- Credential theft (LSASS / SAM / Keychain / browser secret extraction).
- Remote-access / persistence / anti-forensic / evasion tooling.
- Any tool whose primary purpose is offensive.

The collectors deliberately avoid extracting secrets, even when the
operator has authority. If your investigation legitimately requires that
data, use the dedicated, vetted tools your organization has approved
for that purpose, under the appropriate legal framework, and document
the chain of custody accordingly.

## Operator obligations

- **Document authority.** Record the legal basis (warrant number,
  consent form, ticket reference) in the case file before touching the
  device. The [`CHAIN_OF_CUSTODY_TEMPLATE.md`](CHAIN_OF_CUSTODY_TEMPLATE.md)
  covers this.
- **Minimize.** Collect what you need for the question being asked. Do
  not exfiltrate user files when metadata answers the question.
- **Preserve.** Hash everything (the scripts do this for you). Avoid
  modifying the source device. Use a hardware write-blocker for raw
  imaging.
- **Report.** Note every command run, every error, and any deviation
  from the standard procedure.
- **Secure.** Treat collected data as evidence. Encrypt the evidence
  drive. Restrict access. Retain only as long as policy/law requires.

## Privacy

Even when collection is lawful, you are responsible for:

- Limiting collection to what is necessary and proportionate.
- Filtering or redacting personal data not relevant to the matter.
- Following any data-protection regime that applies (e.g. GDPR,
  state-level US privacy laws, sectoral law) — including data subject
  notice requirements where they apply.
- Securely destroying data at the end of the lawful retention period.

## Reference

- NIST Digital Evidence: <https://www.nist.gov/digital-evidence>
- Amnesty International Security Lab MVT — explicit guidance that MVT
  is for *consensual* forensic analysis: <https://docs.mvt.re/>
- Kroll KAPE: <https://www.kroll.com/en/services/cyber/incident-response-recovery/kroll-artifact-parser-and-extractor-kape>
