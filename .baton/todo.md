# Task List

## Task 1: Replace DeepL API call with Claude Haiku API in sync script
- **Stack**: Bash
- **Model**: sonnet
- **Files**: [scripts/sync-patch-notes.sh]
- **Depends**: (none)
- **Description**:
  1. Delete lines 6-11: DeepL URL auto-detection block (`DEEPL_URL` variable and `:fx` suffix logic)
  2. Replace lines 47-67: Replace entire DeepL API call block with Claude Haiku Messages API call
     - Change env var from `DEEPL_API_KEY` to `ANTHROPIC_API_KEY`
     - POST to `https://api.anthropic.com/v1/messages` with `x-api-key`, `anthropic-version: 2023-06-01`, `content-type: application/json` headers
     - Build request body using `jq -n` with system prompt (translation instructions from plan.md) + user message (`$BODY`)
     - Model: `claude-haiku-4-5-20251001`, max_tokens: 4096
     - Parse response: `.content[0].text` (replaces `.translations[].text`)
     - Maintain fallback: skip translation if `ANTHROPIC_API_KEY` unset, use English original on API failure
  3. Delete lines 75-85: Remove `sed`-based header Korean conversion (handled by Claude prompt)
  4. Use the exact system prompt and API call structure specified in plan.md
- **Status**: pending

## Task 2: Update GitHub Actions workflow env var
- **Stack**: GitHub Actions
- **Model**: sonnet
- **Files**: [.github/workflows/sync-patch-notes.yml]
- **Depends**: (none)
- **Description**:
  1. Line 68: Change `DEEPL_API_KEY: ${{ secrets.DEEPL_API_KEY }}` to `ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}`
  2. No other changes to the workflow file
- **Status**: pending

## Task 3: Update test script for Claude Haiku API
- **Stack**: Bash
- **Model**: sonnet
- **Files**: [scripts/test-sync-patch-notes.sh]
- **Depends**: task-1
- **Description**:
  1. Delete TC2 (lines 27-69): Remove the sed header conversion test -- this functionality is no longer in the script; header translation is handled by the Claude prompt
  2. Update TC6 (currently lines 136-152): Change all `DEEPL_API_KEY` references to `ANTHROPIC_API_KEY` -- update variable name in `unset`, condition check, and pass/fail messages
  3. Renumber test cases sequentially after TC2 removal: TC3->TC2, TC4->TC3, TC5->TC4, TC6->TC5
  4. Update test case echo labels to match new numbering
- **Status**: pending

## Task 4: Add missing test cases for Claude API integration (TDD improvement)
- **Stack**: Bash
- **Model**: sonnet
- **Files**: [scripts/test-sync-patch-notes.sh]
- **Depends**: task-3
- **Description**: Three untested code paths identified in TDD review (WARNING severity):
  1. TC6 — Claude API happy path: mock a valid Claude response JSON (`{"content":[{"text":"번역됨"}]}`), assign to `CLAUDE_RESPONSE`, assert `jq -e '.content[0].text'` succeeds and `TRANSLATED_BODY` is populated, assert `FINAL_BODY` equals the translated text (not the original)
  2. TC7 — Claude API failure path: mock an error response or invalid JSON, assign to `CLAUDE_RESPONSE`, assert `jq -e` fails, assert `TRANSLATED_BODY` stays empty, assert `FINAL_BODY` falls back to `$BODY`
  3. TC8 — HTML_URL front matter rendering: extend TC3 to include `HTML_URL` variable in the `cat` heredoc and assert the `원문:` link line is present in the output file; also test the `html_url = "null"` edge case
- **Status**: pending
