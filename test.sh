#!/bin/bash
set -euo pipefail

BINARY="./build/ClaudeNotifier.app/Contents/MacOS/claude-notifier"

PASSED=0
FAILED=0
TOTAL=0

GREEN='\033[0;32m'
RED='\033[0;31m'
BOLD='\033[1m'
RESET='\033[0m'

pass() {
    PASSED=$((PASSED + 1))
    TOTAL=$((TOTAL + 1))
    echo -e "  ${GREEN}PASS${RESET} $1"
}

fail() {
    FAILED=$((FAILED + 1))
    TOTAL=$((TOTAL + 1))
    echo -e "  ${RED}FAIL${RESET} $1"
}

echo ""
echo -e "${BOLD}Claude Notifier - Test Suite${RESET}"
echo "=============================="
echo ""

# Test: Binary exists
if [ -f "$BINARY" ]; then
    pass "Binary exists at $BINARY"
else
    fail "Binary not found at $BINARY"
    echo "  Run ./build.sh first."
    exit 1
fi

# Test: -help flag
echo ""
echo "Flag tests:"
HELP_OUTPUT=$($BINARY -help 2>&1 || true)
if echo "$HELP_OUTPUT" | grep -qi "Usage"; then
    pass "-help flag prints usage information"
else
    fail "-help flag output does not contain 'Usage'"
fi

# Test: -version flag
VERSION_OUTPUT=$($BINARY -version 2>&1 || true)
if echo "$VERSION_OUTPUT" | grep -qE "[0-9]+\.[0-9]+"; then
    pass "-version flag prints version number"
else
    fail "-version flag output does not contain a version number"
fi

# Test: Basic notification
echo ""
echo "Notification tests:"
if $BINARY -title "Test" -message "Basic notification test" 2>/dev/null; then
    pass "Basic notification (title + message)"
else
    fail "Basic notification returned non-zero exit code"
fi

# Test: Pipe input
if echo "Piped message" | $BINARY -title "Pipe Test" 2>/dev/null; then
    pass "Pipe input notification"
else
    fail "Pipe input notification returned non-zero exit code"
fi

# Test: Group replacement
if $BINARY -title "Group Test" -message "First notification" -group test-group 2>/dev/null; then
    pass "Group notification (first)"
else
    fail "Group notification (first) returned non-zero exit code"
fi

if $BINARY -title "Group Test" -message "Replacement notification" -group test-group 2>/dev/null; then
    pass "Group notification (replacement)"
else
    fail "Group notification (replacement) returned non-zero exit code"
fi

# Test: -open flag
if $BINARY -message "Click to open" -open "https://claude.ai" 2>/dev/null; then
    pass "-open flag with URL"
else
    fail "-open flag returned non-zero exit code"
fi

# Summary
echo ""
echo "=============================="
if [ "$FAILED" -eq 0 ]; then
    echo -e "${GREEN}${BOLD}All $TOTAL tests passed.${RESET}"
else
    echo -e "${RED}${BOLD}$FAILED of $TOTAL tests failed.${RESET}"
fi
echo ""

exit "$FAILED"
