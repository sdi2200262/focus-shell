#!/bin/bash
# test_focus.sh - isolated unit tests for focus logic
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FOCUS_BIN="$DIR/focus"

SANDBOX="$(mktemp -d /tmp/focus_test.XXXXXX)"
trap 'rm -rf "$SANDBOX"' EXIT

export FOCUS_HOSTS="$SANDBOX/hosts"
export FOCUS_CONF="$SANDBOX/focus.conf"
export FOCUS_TEST_MODE=1

cat << 'HOSTS_EOF' > "$FOCUS_HOSTS"
127.0.0.1 localhost
::1 localhost
HOSTS_EOF

export FOCUS_SOURCE_ONLY=1
# shellcheck source=/dev/null
source "$FOCUS_BIN"

failed=0

assert_eq() {
  local expected="$1"
  local actual="$2"
  local msg="$3"
  if [[ "$expected" != "$actual" ]]; then
    echo "FAIL: $msg (expected '$expected', got '$actual')" >&2
    failed=$((failed + 1))
  else
    echo "PASS: $msg"
  fi
}

assert_fails() {
  local msg="$1"
  shift
  if "$@" >/dev/null 2>&1; then
    echo "FAIL: $msg (expected command to fail, but it succeeded)" >&2
    failed=$((failed + 1))
  else
    echo "PASS: $msg"
  fi
}

echo "=== Test: parse_duration ==="
assert_eq "1800" "$(parse_duration "30m")" "parse 30m"
assert_eq "7200" "$(parse_duration "2h")" "parse 2h"
assert_eq "5400" "$(parse_duration "1h30m")" "parse 1h30m"
assert_eq "5400" "$(parse_duration "90m")" "parse 90m"
assert_eq "10800" "$(parse_duration "3h")" "parse 3h"
assert_fails "reject invalid duration 'abc'" parse_duration "abc"
assert_fails "reject empty duration ''" parse_duration ""
assert_fails "reject negative duration '-1h'" parse_duration "-1h"
assert_fails "reject raw seconds '30s'" parse_duration "30s"

echo "=== Test: parse_time (12-hour am/pm) ==="
assert_eq "0" "$(parse_time "12am")" "parse 12am (midnight)"
assert_eq "540" "$(parse_time "9am")" "parse 9am"
assert_eq "720" "$(parse_time "12pm")" "parse 12pm (noon)"
assert_eq "1020" "$(parse_time "5pm")" "parse 5pm"
assert_eq "1260" "$(parse_time "9pm")" "parse 9pm"
assert_eq "510" "$(parse_time "8:30am")" "parse 8:30am"
assert_eq "1290" "$(parse_time "9:30pm")" "parse 9:30pm"
assert_eq "1439" "$(parse_time "11:59pm")" "parse 11:59pm"
assert_fails "reject 24h format '21:00'" parse_time "21:00"
assert_fails "reject invalid '13am'" parse_time "13am"
assert_fails "reject invalid 'random'" parse_time "random"

echo "=== Test: parse_window ==="
assert_eq "540 1020" "$(parse_window "9am-5pm")" "parse window 9am-5pm"
assert_eq "1260 0" "$(parse_window "9pm-12am")" "parse window 9pm-12am"
assert_eq "1260 1380" "$(parse_window "9pm-11pm")" "parse window 9pm-11pm"
assert_fails "reject bad separator '9am to 5pm'" parse_window "9am to 5pm"

echo "=== Test: is_time_in_window ==="
# Daytime window: 9am (540) to 5pm (1020)
assert_eq "1" "$(is_time_in_window 540 1020 600)" "10am in 9am-5pm"
assert_eq "1" "$(is_time_in_window 540 1020 540)" "9am start edge in 9am-5pm"
assert_eq "0" "$(is_time_in_window 540 1020 1020)" "5pm end edge in 9am-5pm (exclusive)"
assert_eq "0" "$(is_time_in_window 540 1020 480)" "8am outside 9am-5pm"
assert_eq "0" "$(is_time_in_window 540 1020 1080)" "6pm outside 9am-5pm"

# Midnight-spanning window: 9pm (1260) to 12am (0)
assert_eq "1" "$(is_time_in_window 1260 0 1300)" "9:40pm in 9pm-12am"
assert_eq "0" "$(is_time_in_window 1260 0 100)" "1:40am outside 9pm-12am"
assert_eq "0" "$(is_time_in_window 1260 0 1200)" "8:00pm outside 9pm-12am"

# Cross-midnight window: 9pm (1260) to 6am (360)
assert_eq "1" "$(is_time_in_window 1260 360 1300)" "9:40pm in 9pm-6am"
assert_eq "1" "$(is_time_in_window 1260 360 120)" "2:00am in 9pm-6am"
assert_eq "0" "$(is_time_in_window 1260 360 500)" "8:20am outside 9pm-6am"

echo "=== Test: schedule flags (--allow and --block) ==="
# Test --allow 9pm-11pm
cmd_schedule --allow 9pm-11pm >/dev/null
load_state
assert_eq "schedule" "$STATE_MODE" "schedule mode set"
assert_eq "allow" "$STATE_SCHEDULE_TYPE" "schedule type is allow"
assert_eq "9pm-11pm" "$STATE_SCHEDULE_WINDOW" "schedule window is 9pm-11pm"

# Test --block 9am-5pm --days 7
cmd_schedule --block 9am-5pm --days 7 >/dev/null
load_state
assert_eq "block" "$STATE_SCHEDULE_TYPE" "schedule type is block"
assert_eq "9am-5pm" "$STATE_SCHEDULE_WINDOW" "schedule window is 9am-5pm"
if ((STATE_SCHEDULE_DAYS_UNTIL > 0)); then
  echo "PASS: days limit set"
else
  echo "FAIL: days limit not set" >&2
  failed=$((failed + 1))
fi

echo "=== Test: hostfile manipulation ==="
apply_hosts_block 9999999999
if grep -q "instagram.com" "$FOCUS_HOSTS"; then
  echo "PASS: hosts file has block"
else
  echo "FAIL: hosts file missing block" >&2
  failed=$((failed + 1))
fi

strip_hosts_block
if grep -q "instagram.com" "$FOCUS_HOSTS"; then
  echo "FAIL: hosts file block was not stripped" >&2
  failed=$((failed + 1))
else
  echo "PASS: hosts file block stripped"
fi

echo "=== Test: state file read/write ==="
save_state "timer" 12345 "allow" "9pm-11pm" 0 0 9999
load_state
assert_eq "timer" "$STATE_MODE" "mode matches"
assert_eq "12345" "$STATE_TIMER_UNTIL" "timer deadline matches"
assert_eq "allow" "$STATE_SCHEDULE_TYPE" "schedule type matches"
assert_eq "9pm-11pm" "$STATE_SCHEDULE_WINDOW" "schedule window matches"
assert_eq "9999" "$STATE_DAEMON_PID" "daemon pid matches"

echo "=== Test: break & resume logic ==="
now=$(date +%s)
timer_end=$((now + 3600))
save_state "timer" "$timer_end" "allow" "9pm-11pm" 0 0 1111

FOCUS_TEST_MODE=1 cmd_break "30m" >/dev/null
load_state
assert_eq "$((timer_end + 1800))" "$STATE_TIMER_UNTIL" "timer deadline extended by break duration"
break_diff=$((STATE_BREAK_UNTIL - (now + 1800)))
if (( break_diff >= -1 && break_diff <= 1 )); then
  echo "PASS: break until set"
else
  echo "FAIL: break until set (got $STATE_BREAK_UNTIL, expected $((now + 1800)))" >&2
  failed=$((failed + 1))
fi

FOCUS_TEST_MODE=1 cmd_resume >/dev/null
load_state
assert_eq "0" "$STATE_BREAK_UNTIL" "break cleared on resume"
assert_eq "$((timer_end + 1800))" "$STATE_TIMER_UNTIL" "timer deadline retained on resume"

if [[ $failed -gt 0 ]]; then
  echo "Tests finished with $failed failures." >&2
  exit 1
fi

echo "All tests passed successfully!"
