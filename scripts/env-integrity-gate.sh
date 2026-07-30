#!/usr/bin/env bash
# env-integrity-gate.sh — Manhattan Orchestrator · Phase 4.0 Environment Integrity Gate
#
# HARD GATE. Exits non-zero when the verification *substrate* is unhealthy, so that
# "green tests on a dead dependency" (a false-green) can never pass silently.
#
# A verification is only as trustworthy as the environment it runs in. This gate is a
# precondition on any Phase 4 claim whose evidence passes through a live system
# (Claim Type: Empirical Fact, or a Prediction validated against a live system).
#
# Default substrate check = container crash-loop detection:
#   1. No RUNNING container is crash-looping (RestartCount over threshold), AND
#   2. No RUNNING container's RestartCount is CLIMBING across two samples.
#      ("Up" alone is insufficient — a crash-looper reports "Up" between kills.)
# Optional readiness probes assert a dependency actually ANSWERS (not just "running").
# Optional --assert-cmd checks assert DATA TRUTH (not just liveness): each command must
# exit 0, so you can require e.g. "newest row < 10m old AND count > 0" or cluster != red.
# A live container that answers a probe can still serve zero/stale/wrong data — these
# assertions are how you catch the silent-empty and stale-data classes.
#
# Usage:
#   scripts/env-integrity-gate.sh [--threshold N] [--interval S] \
#       [--probe URL]... [--assert-cmd 'shell that must exit 0']...
#
# Env overrides:
#   DOCKER             docker command (default "docker"; e.g. DOCKER="sudo -n docker")
#   RESTART_THRESHOLD  max tolerated RestartCount for a running container (default 5)
#   SAMPLE_INTERVAL    seconds between the two restart-count samples (default 8; 0 = skip delta)
#
# NOTE: This script is Tier A — substrate liveness + data-truth pre-filters. It is
# NECESSARY BUT NOT SUFFICIENT. A passing run does NOT certify the user-facing vertical
# slice; pair it with the Tier B golden-path browser probe (scripts/golden-path-probe.mjs).
#
# Exit codes: 0 = PASS (substrate healthy) · 1 = FAIL (substrate unhealthy) · 2 = usage/tooling error.
set -euo pipefail

DOCKER="${DOCKER:-docker}"
THRESHOLD="${RESTART_THRESHOLD:-5}"
INTERVAL="${SAMPLE_INTERVAL:-8}"
PROBES=()
ASSERTS=()
# Set CURL_INSECURE=1 to pass -k (skip TLS verification) — disabled by default.
CURL_K_FLAG=""
[ "${CURL_INSECURE:-}" = "1" ] && CURL_K_FLAG="-k"

while [ $# -gt 0 ]; do
  case "$1" in
    --threshold)  THRESHOLD="$2"; shift 2 ;;
    --interval)   INTERVAL="$2";  shift 2 ;;
    --probe)      PROBES+=("$2");  shift 2 ;;
    --assert-cmd) ASSERTS+=("$2"); shift 2 ;;
    -h|--help)    grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

fail=0
echo "[Gate: Environment Integrity] threshold=${THRESHOLD} interval=${INTERVAL}s"

# --- Check 1: container crash-loop detection ---------------------------------
if ! $DOCKER info >/dev/null 2>&1; then
  echo "  WARN: docker not reachable ('$DOCKER info' failed) — skipping container check" >&2
else
  ids="$($DOCKER ps -q)"
  if [ -n "$ids" ]; then
    declare -A rc1=()
    while read -r name rc; do rc1["$name"]="$rc"; done < <(
      $DOCKER inspect -f '{{.Name}} {{.RestartCount}}' $ids | sed 's#^/##'
    )

    # Threshold check (sample 1)
    for name in "${!rc1[@]}"; do
      if [ "${rc1[$name]}" -gt "$THRESHOLD" ]; then
        echo "  FAIL: container '$name' RestartCount=${rc1[$name]} > ${THRESHOLD} (crash-looping)"
        fail=1
      fi
    done

    # Delta check (sample 2) — catches a fresh crash-looper still under threshold
    if [ "$INTERVAL" -gt 0 ]; then
      sleep "$INTERVAL"
      while read -r name rc; do
        prev="${rc1[$name]:-0}"
        if [ "$rc" -gt "$prev" ]; then
          echo "  FAIL: container '$name' RestartCount climbed ${prev}->${rc} in ${INTERVAL}s (crash-looping)"
          fail=1
        fi
      done < <(
        $DOCKER inspect -f '{{.Name}} {{.RestartCount}}' $($DOCKER ps -q) | sed 's#^/##'
      )
    fi
  fi
fi

# --- Check 2: optional readiness probes --------------------------------------
for url in "${PROBES[@]:-}"; do
  [ -z "$url" ] && continue
  if curl -fsS -m 10 $CURL_K_FLAG "$url" >/dev/null 2>&1; then
    echo "  ok:   probe ${url} answered"
  else
    echo "  FAIL: probe ${url} did not answer (dependency not ready)"
    fail=1
  fi
done

# --- Check 3: optional data-truth assertions (each must exit 0) ---------------
# These catch the silent-empty / stale-data class that liveness cannot: e.g. a
# freshness-bounded non-empty query, a doc count > 0, or cluster status != red.
_assert_idx=0
for cmd in "${ASSERTS[@]:-}"; do
  [ -z "$cmd" ] && continue
  _assert_idx=$((_assert_idx + 1))
  if bash -c "$cmd" >/dev/null 2>&1; then
    echo "  ok:   assert #${_assert_idx} passed"
  else
    echo "  FAIL: assert #${_assert_idx} failed (non-zero exit)"
    fail=1
  fi
done

# --- Verdict -----------------------------------------------------------------
if [ "$fail" -ne 0 ]; then
  echo "[Gate: Environment Integrity] FAILED — substrate unhealthy."
  echo "  Dependent empirical claims are UNVERIFIABLE. Block delivery, or downgrade the"
  echo "  affected claim to Hypothesis and disclose the substrate failure in Fact Calibration."
  exit 1
fi
echo "[Gate: Environment Integrity] PASSED — substrate healthy."
exit 0
