#!/usr/bin/env bash
# run_planning_session.sh — Launch or resume the AIDLC planning runner
#
# Usage:
#   ./scripts/run_planning_session.sh                    # Start new run (foreground)
#   ./scripts/run_planning_session.sh --background       # Start new run (background)
#   ./scripts/run_planning_session.sh --resume            # Resume latest run
#   ./scripts/run_planning_session.sh --dry-run           # Dry run (no Claude calls)
#   ./scripts/run_planning_session.sh --smoke             # Quick smoke test
#   ./scripts/run_planning_session.sh --background --resume  # Resume in background
#
# Logs:
#   tools/aidlc/runs/<run_id>/<run_id>.log
#   tools/aidlc/runs/<run_id>/<run_id>.errors.log
#
# State:
#   tools/aidlc/runs/<run_id>/state.json
#
# Reports:
#   tools/aidlc/reports/<run_id>/

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$PROJECT_ROOT"

CONFIG="mall_sim_planning_40h.json"
EXTRA_ARGS=()
BACKGROUND=false

for arg in "$@"; do
    case "$arg" in
        --background|-bg)
            BACKGROUND=true
            ;;
        --smoke)
            CONFIG="mall_sim_planning_smoke.json"
            ;;
        --soak)
            CONFIG="mall_sim_planning_soak.json"
            ;;
        --dry-run)
            EXTRA_ARGS+=("--dry-run")
            ;;
        --resume)
            EXTRA_ARGS+=("--resume")
            ;;
        --verbose|-v)
            EXTRA_ARGS+=("--verbose")
            ;;
        *)
            echo "Unknown argument: $arg"
            echo "Usage: $0 [--background] [--resume] [--dry-run] [--smoke] [--soak] [--verbose]"
            exit 1
            ;;
    esac
done

CMD="python3 -m tools.aidlc.runner --config $CONFIG ${EXTRA_ARGS[*]:-}"

echo "=== AIDLC Planning Runner ==="
echo "Project: $PROJECT_ROOT"
echo "Config:  $CONFIG"
echo "Args:    ${EXTRA_ARGS[*]:-none}"
echo "Mode:    $(if $BACKGROUND; then echo 'background'; else echo 'foreground'; fi)"
echo ""

if $BACKGROUND; then
    LOG_FILE="tools/aidlc/runs/background_$(date +%Y%m%d_%H%M%S).log"
    mkdir -p "$(dirname "$LOG_FILE")"
    echo "Starting in background..."
    echo "Background log: $LOG_FILE"
    echo "To follow: tail -f $LOG_FILE"
    echo "To stop: kill \$(cat tools/aidlc/runs/.pid)"
    nohup $CMD > "$LOG_FILE" 2>&1 &
    BG_PID=$!
    echo "$BG_PID" > tools/aidlc/runs/.pid
    echo "PID: $BG_PID"
    echo "Started."
else
    echo "Starting in foreground (Ctrl+C to pause and save state)..."
    echo ""
    $CMD
fi
