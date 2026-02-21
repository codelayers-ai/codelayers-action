#!/bin/bash
# Test mode detection logic from entrypoint.sh in isolation.
# Simulates three scenarios without needing Docker or a real GitHub environment.

set -euo pipefail

PASS=0
FAIL=0

run_test() {
  local name="$1"
  local expected_mode="$2"
  local expected_exit="${3:-0}"

  # The mode detection block extracted from entrypoint.sh
  actual_exit=0
  MODE=$(bash -c '
    CODELAYERS_API_KEY="${CODELAYERS_API_KEY:-}"
    IS_PRIVATE="${IS_PRIVATE:-true}"
    PR_NUMBER="${PR_NUMBER:-}"

    if [ -n "${CODELAYERS_API_KEY:-}" ]; then
      echo "share"
    elif [ "$IS_PRIVATE" = "false" ] && [ -n "$PR_NUMBER" ]; then
      echo "explore"
    else
      echo "error"
      exit 1
    fi
  ' 2>/dev/null) || actual_exit=$?

  if [ "$actual_exit" -ne "$expected_exit" ]; then
    echo "FAIL: $name — expected exit=$expected_exit, got exit=$actual_exit"
    FAIL=$((FAIL + 1))
    return
  fi

  if [ "$expected_exit" -eq 0 ] && [ "$MODE" != "$expected_mode" ]; then
    echo "FAIL: $name — expected mode=$expected_mode, got mode=$MODE"
    FAIL=$((FAIL + 1))
    return
  fi

  if [ "$expected_exit" -ne 0 ] && [ "$MODE" = "error" ]; then
    echo "PASS: $name (correctly errored)"
    PASS=$((PASS + 1))
    return
  fi

  echo "PASS: $name (mode=$MODE)"
  PASS=$((PASS + 1))
}

echo "=== GitHub Action Mode Detection Tests ==="
echo

# Test 1: API key set → share mode (regardless of repo visibility)
CODELAYERS_API_KEY="sk-test-key" IS_PRIVATE="false" PR_NUMBER="42" \
  run_test "API key + public repo → share" "share"

CODELAYERS_API_KEY="sk-test-key" IS_PRIVATE="true" PR_NUMBER="42" \
  run_test "API key + private repo → share" "share"

# Test 2: No API key + public repo + PR → explore mode
CODELAYERS_API_KEY="" IS_PRIVATE="false" PR_NUMBER="42" \
  run_test "No API key + public repo + PR → explore" "explore"

# Test 3: No API key + private repo → error
CODELAYERS_API_KEY="" IS_PRIVATE="true" PR_NUMBER="42" \
  run_test "No API key + private repo → error" "error" 1

# Test 4: No API key + public repo + no PR number → error
CODELAYERS_API_KEY="" IS_PRIVATE="false" PR_NUMBER="" \
  run_test "No API key + public repo + no PR → error" "error" 1

# Test 5: No API key + private=true (default) → error
CODELAYERS_API_KEY="" IS_PRIVATE="true" PR_NUMBER="" \
  run_test "No API key + private + no PR → error" "error" 1

echo
echo "=== Results: $PASS passed, $FAIL failed ==="

# --- Test CLI args construction ---
echo
echo "=== CLI Args Construction Tests ==="

# Test share mode args
SHARE_ARGS=$(bash -c '
  MODE="share"
  GITHUB_WORKSPACE="/workspace"
  MERGE_BASE="abc123"
  INPUT_EXPIRES_DAYS="7"
  INPUT_MAX_VIEWS="100"
  INPUT_LINK_TO_PR="true"
  GITHUB_REPOSITORY="owner/repo"
  PR_NUMBER="42"
  PR_TITLE="Fix the bug"
  GITHUB_EVENT_PATH="/dev/null"

  ARGS=(share "$GITHUB_WORKSPACE"
    --base "$MERGE_BASE"
    --head HEAD
    --format json
    --expires "${INPUT_EXPIRES_DAYS:-7}"
  )
  if [ -n "${INPUT_MAX_VIEWS:-}" ]; then
    ARGS+=(--max-views "$INPUT_MAX_VIEWS")
  fi
  if [ "${INPUT_LINK_TO_PR:-true}" = "true" ]; then
    ARGS+=(--github-repo "$GITHUB_REPOSITORY")
    if [ -n "$PR_NUMBER" ]; then
      ARGS+=(--github-pr "$PR_NUMBER")
    fi
    if [ -n "$PR_TITLE" ]; then
      ARGS+=(--github-pr-title "$PR_TITLE")
    fi
  fi
  echo "${ARGS[*]}"
')
EXPECTED_SHARE="share /workspace --base abc123 --head HEAD --format json --expires 7 --max-views 100 --github-repo owner/repo --github-pr 42 --github-pr-title Fix the bug"
if [ "$SHARE_ARGS" = "$EXPECTED_SHARE" ]; then
  echo "PASS: Share mode CLI args correct"
  PASS=$((PASS + 1))
else
  echo "FAIL: Share mode CLI args"
  echo "  expected: $EXPECTED_SHARE"
  echo "  got:      $SHARE_ARGS"
  FAIL=$((FAIL + 1))
fi

# Test explore mode args
EXPLORE_ARGS=$(bash -c '
  MODE="explore"
  GITHUB_WORKSPACE="/workspace"
  GITHUB_REPOSITORY="owner/repo"
  PR_NUMBER="42"
  INPUT_EXPIRES_DAYS="7"

  PR_URL="https://github.com/$GITHUB_REPOSITORY/pull/$PR_NUMBER"
  ARGS=(explore "$PR_URL"
    --path "$GITHUB_WORKSPACE"
    --format json
    --expires "${INPUT_EXPIRES_DAYS:-7}"
    --force
  )
  echo "${ARGS[*]}"
')
EXPECTED_EXPLORE="explore https://github.com/owner/repo/pull/42 --path /workspace --format json --expires 7 --force"
if [ "$EXPLORE_ARGS" = "$EXPECTED_EXPLORE" ]; then
  echo "PASS: Explore mode CLI args correct"
  PASS=$((PASS + 1))
else
  echo "FAIL: Explore mode CLI args"
  echo "  expected: $EXPECTED_EXPLORE"
  echo "  got:      $EXPLORE_ARGS"
  FAIL=$((FAIL + 1))
fi

# --- Test JSON output normalization ---
echo
echo "=== JSON Output Normalization Tests ==="

# Test share output parsing
SHARE_JSON='{"share_url":"https://app.codelayers.ai/s/abc#k=xyz","share_id":"abc-123","node_count":100,"changed_file_count":5}'
PARSED_URL=$(echo "$SHARE_JSON" | jq -r '.share_url // .explore_url')
PARSED_ID=$(echo "$SHARE_JSON" | jq -r '.share_id // .explore_id')
if [ "$PARSED_URL" = "https://app.codelayers.ai/s/abc#k=xyz" ] && [ "$PARSED_ID" = "abc-123" ]; then
  echo "PASS: Share JSON normalized correctly"
  PASS=$((PASS + 1))
else
  echo "FAIL: Share JSON normalization (url=$PARSED_URL, id=$PARSED_ID)"
  FAIL=$((FAIL + 1))
fi

# Test explore output parsing
EXPLORE_JSON='{"explore_url":"https://app.codelayers.ai/e/def-456","explore_id":"def-456","node_count":200,"changed_file_count":10}'
PARSED_URL=$(echo "$EXPLORE_JSON" | jq -r '.share_url // .explore_url')
PARSED_ID=$(echo "$EXPLORE_JSON" | jq -r '.share_id // .explore_id')
if [ "$PARSED_URL" = "https://app.codelayers.ai/e/def-456" ] && [ "$PARSED_ID" = "def-456" ]; then
  echo "PASS: Explore JSON normalized correctly"
  PASS=$((PASS + 1))
else
  echo "FAIL: Explore JSON normalization (url=$PARSED_URL, id=$PARSED_ID)"
  FAIL=$((FAIL + 1))
fi

echo
echo "=== Final Results: $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
