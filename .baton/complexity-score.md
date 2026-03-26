# Complexity Score

## Request
DeepL 기반 번역을 Claude Haiku 기반 번역으로 변경

## Detected Stacks
- Jekyll (Ruby): github-pages gem (source: Gemfile)
- Bash scripting: sync-patch-notes.sh, test-sync-patch-notes.sh (source: scripts/)
- GitHub Actions CI/CD: sync-patch-notes.yml (source: .github/workflows/)

## File -> Stack Mapping
| File | Stack | Change Type |
|------|-------|-------------|
| scripts/sync-patch-notes.sh | Bash | modify |
| scripts/test-sync-patch-notes.sh | Bash | modify |
| .github/workflows/sync-patch-notes.yml | GitHub Actions | modify |

## Multi-Stack Status
- Multi-stack: NO (single cohesive Jekyll site with Bash automation)
- API contract test required: NO

## Impact Analysis

### Current DeepL Integration
The translation functionality lives entirely in `scripts/sync-patch-notes.sh` and is used during the automated patch notes sync pipeline:

1. **API URL detection** (lines 6-11): The script auto-detects whether to use the free or paid DeepL API endpoint based on the `DEEPL_API_KEY` suffix (`:fx` = free tier).
2. **Translation call** (lines 47-67): When `DEEPL_API_KEY` is set, the script:
   - Splits the release body into individual lines via `jq`
   - Sends a POST request to DeepL's `/v2/translate` endpoint with `target_lang: "KO"`
   - Uses `DeepL-Auth-Key` authorization header
   - Parses the JSON response to extract `.translations[].text`
   - Falls back to English original if translation fails
3. **Post-processing** (lines 75-85): After translation, sed replaces English section headers (Added, Fixed, Changed, etc.) with Korean equivalents.
4. **CI/CD secret** (workflow line 68): `DEEPL_API_KEY` is passed from GitHub Actions secrets to the script.
5. **Test coverage** (test script lines 136-152): TC6 tests the fallback behavior when `DEEPL_API_KEY` is unset.

### What Needs to Change
- Replace DeepL API call with Anthropic Claude Haiku API call (different endpoint, auth header, request/response format)
- Change environment variable from `DEEPL_API_KEY` to `ANTHROPIC_API_KEY` (or similar)
- Restructure the translation request: DeepL uses a simple text-array + target_lang format; Claude Haiku uses a messages-based chat completion API with a system prompt instructing translation
- Update the response parsing: DeepL returns `.translations[].text`; Claude returns `.content[0].text`
- Update GitHub Actions workflow to pass the new API key secret
- Update test script to reference the new API key variable name and test the new fallback logic
- The sed-based header replacement (lines 75-85) can likely be removed if the Claude prompt handles header translation directly

## Scoring
| Criterion | Score | Reason |
|-----------|-------|--------|
| Files to change | 3 | scripts/sync-patch-notes.sh, scripts/test-sync-patch-notes.sh, .github/workflows/sync-patch-notes.yml |
| Cross-service dependency | 3 | Switching external API provider (DeepL -> Anthropic Claude API); different auth, endpoint, request/response schema |
| New feature | 0 | Modifying existing translation feature, not adding a new one |
| Architectural decisions | 0 | Straightforward API provider swap within existing architecture |
| Security/auth/payment | 0 | Only changing which API key is used; no auth/payment logic changes |
| DB schema change | 0 | No database involved |
| **Total** | **6** | |

## Tier: 2

## Notes
- The core change is in `scripts/sync-patch-notes.sh` where the DeepL HTTP call must be replaced with a Claude Haiku Messages API call.
- Claude Haiku API requires a different request structure: `POST https://api.anthropic.com/v1/messages` with `x-api-key` header, `anthropic-version` header, and a messages array with a system prompt for translation instructions.
- The translation quality may differ; Claude Haiku can be instructed to preserve markdown formatting and translate section headers directly, potentially eliminating the need for the sed-based header replacement post-processing.
- GitHub Actions secrets will need to be updated: remove `DEEPL_API_KEY`, add `ANTHROPIC_API_KEY` (this is a manual step in the repository settings).
- The `ANTHROPIC_API_KEY` may already exist in the repository secrets if other workflows use Claude; this should be verified.
- Consider adding a translation system prompt that instructs Haiku to: translate to Korean, preserve markdown formatting, translate section headers (Added -> 추가, Fixed -> 수정, etc.), and keep code/technical terms unchanged.
- Rate limits and token costs differ between DeepL and Claude Haiku; patch notes are typically small (under 2000 tokens) so this should not be an issue.
