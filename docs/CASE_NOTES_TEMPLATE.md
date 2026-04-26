# Case Notes — &lt;CASE-ID&gt;

> Plain-language record of what was done, why, and what was found.
> Pair with `CHAIN_OF_CUSTODY_TEMPLATE.md` for each evidence item.

## 1. Authority and scope

- Authority: (warrant / subpoena / consent form / employer policy)
- Scope: (devices, custodians, time window, questions to answer)
- Limitations: (what is *not* in scope)

## 2. Custodians and devices

| Custodian | Role | Device(s) | Identifiers |
|-----------|------|-----------|-------------|
|           |      |           |             |

## 3. Timeline of investigative actions

| When (UTC) | Operator | Action | Output reference |
|------------|----------|--------|------------------|
|            |          |        |                  |
|            |          |        |                  |

## 4. Tools used

| Tool | Version | Source URL | Run on |
|------|---------|------------|--------|
| Autopsy |       | <https://www.sleuthkit.org/autopsy/> |        |
| KAPE    |       | <https://www.kroll.com/en/services/cyber/incident-response-recovery/kroll-artifact-parser-and-extractor-kape> |        |
| Plaso   |       | <https://plaso.readthedocs.io/> |        |
| MVT     |       | <https://github.com/mvt-project/mvt> |        |

## 5. Live response collection summary

- Windows: see `windows_live_response/` and `logs/sha256.txt`
- macOS:   see `macos_live_response/`   and `logs/sha256.txt`
- Android: see `android_adb/`           and `logs/sha256.txt`
- iOS:     see `ios_backup/` + `ios_metadata/` and `logs/sha256.txt`

## 6. Findings

### 6.1 Question: …

- Observation:
- Evidence reference (file path, hash):
- Reasoning:

### 6.2 Question: …

- Observation:
- Evidence reference:
- Reasoning:

## 7. Cross-validation

For each finding that depends on a single tool, list the second tool /
method used to confirm the result (e.g., KAPE Amcache parsed by KAPE
*and* by `AmcacheParser.exe` from EZ Tools; both produced the same
hash for entry X).

| Finding | Primary tool | Secondary tool/method | Match? |
|---------|--------------|----------------------|--------|
|         |              |                      |        |

## 8. Limitations and caveats

- (e.g., "Security event log was filtered; some events older than N
  days had been overwritten by retention policy.")

## 9. Conclusions

…

## 10. Appendices

- A. Hash catalog for collected outputs (`logs/sha256.txt`)
- B. Command logs (`logs/commands.tsv`, `logs/collector.log`)
- C. Screenshots and photos
- D. Chain-of-custody forms
