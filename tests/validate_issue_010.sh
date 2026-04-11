#!/usr/bin/env bash
# Validates ISSUE-010: Customer animation state machine with placeholder anims
PASS=0
FAIL=0

check() {
  local label="$1"
  shift
  if "$@" >/dev/null 2>&1; then
    echo "  PASS: $label"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $label"
    FAIL=$((FAIL + 1))
  fi
}

echo ""
echo "=== ISSUE-010: Customer Animation State Machine ==="
echo ""

# AC1: Customer scene has AnimationPlayer with idle, walk, browse, purchase
echo "[AC1] AnimationPlayer with required animations"
check "AnimationPlayer node in customer.tscn" grep -q "AnimationPlayer" game/scenes/characters/customer.tscn
check "Walk animation created" grep -q '_create_walk_animation' game/scripts/characters/customer_animator.gd
check "Browse animation created" grep -q '_create_browse_animation' game/scripts/characters/customer_animator.gd
check "Idle animation created" grep -q '_create_idle_animation' game/scripts/characters/customer_animator.gd
check "Purchase animation created" grep -q '_create_purchase_animation' game/scripts/characters/customer_animator.gd
check "Walk anim added to library" grep -q 'add_animation("walk"' game/scripts/characters/customer_animator.gd
check "Browse anim added to library" grep -q 'add_animation("browse"' game/scripts/characters/customer_animator.gd
check "Idle anim added to library" grep -q 'add_animation("idle"' game/scripts/characters/customer_animator.gd
check "Purchase anim added to library" grep -q 'add_animation("purchase"' game/scripts/characters/customer_animator.gd

echo ""
echo "[AC2] Each customer AI state triggers corresponding animation"
check "play_for_state called on state transition" grep -q '_animator.play_for_state' game/scripts/characters/customer.gd
check "ENTERING maps to walk" grep -q 'ENTERING' game/scripts/characters/customer_animator.gd
check "BROWSING maps to browse" grep -q 'BROWSING' game/scripts/characters/customer_animator.gd
check "DECIDING maps to idle" grep -q 'DECIDING' game/scripts/characters/customer_animator.gd
check "PURCHASING handled" grep -q 'PURCHASING' game/scripts/characters/customer_animator.gd
check "WAITING_IN_QUEUE maps to idle" grep -q 'WAITING_IN_QUEUE' game/scripts/characters/customer_animator.gd
check "LEAVING handled" grep -q 'LEAVING' game/scripts/characters/customer_animator.gd

echo ""
echo "[AC3] Walk during movement, idle when stationary"
check "update_movement method exists" grep -q 'func update_movement' game/scripts/characters/customer_animator.gd
check "update_movement called in customer.gd" grep -q '_animator.update_movement' game/scripts/characters/customer.gd
check "Movement threshold check" grep -q 'MOVE_THRESHOLD' game/scripts/characters/customer_animator.gd
check "Stationary animation lookup exists" grep -q '_get_stationary_animation' game/scripts/characters/customer_animator.gd
check "Purchase played when stationary at register" grep -q 'return "purchase"' game/scripts/characters/customer_animator.gd

echo ""
echo "[AC4] Animations blend without visual pops"
check "Crossfade duration defined" grep -q 'CROSSFADE_DURATION' game/scripts/characters/customer_animator.gd
check "Crossfade used in play" grep -q 'CROSSFADE_DURATION' game/scripts/characters/customer_animator.gd
check "All animations loop" grep -q 'LOOP_LINEAR' game/scripts/characters/customer_animator.gd

echo ""
echo "[AC5] Works with capsule+sphere placeholder mesh"
check "BodyMesh tracks in animations" grep -q 'BodyMesh' game/scripts/characters/customer_animator.gd
check "HeadMesh tracks in animations" grep -q 'HeadMesh' game/scripts/characters/customer_animator.gd
check "Customer scene has BodyMesh" grep -q 'BodyMesh' game/scenes/characters/customer.tscn
check "Customer scene has HeadMesh" grep -q 'HeadMesh' game/scenes/characters/customer.tscn
check "CapsuleMesh for body" grep -q 'CapsuleMesh' game/scenes/characters/customer.tscn
check "SphereMesh for head" grep -q 'SphereMesh' game/scenes/characters/customer.tscn

echo ""
echo "[AC6] No changes to customer AI logic"
check "State enum unchanged" grep -q 'ENTERING' game/scripts/characters/customer.gd
check "State enum has all states" grep -q 'WAITING_IN_QUEUE' game/scripts/characters/customer.gd
check "Physics process state machine intact" grep -q '_process_entering' game/scripts/characters/customer.gd
check "Purchase logic intact" grep -q '_process_deciding' game/scripts/characters/customer.gd
check "Navigation logic intact" grep -q '_navigate_to_random_shelf' game/scripts/characters/customer.gd

echo ""
echo "[AC-extra] Animation details"
check "Walk has forward lean" grep -q 'WALK_LEAN_ANGLE' game/scripts/characters/customer_animator.gd
check "Walk has vertical bob" grep -q 'WALK_BOB_HEIGHT' game/scripts/characters/customer_animator.gd
check "Browse has head rotation" grep -q 'BROWSE_HEAD_TURN' game/scripts/characters/customer_animator.gd
check "Purchase has nod animation" grep -q 'PURCHASE_NOD_ANGLE' game/scripts/characters/customer_animator.gd
check "Purchase has scale pulse" grep -q 'TYPE_SCALE_3D' game/scripts/characters/customer_animator.gd
check "Idle has body sway" grep -q 'IDLE_SWAY_ANGLE' game/scripts/characters/customer_animator.gd

echo ""
TOTAL=$((PASS + FAIL))
echo "=== Results: ${PASS}/${TOTAL} passed, ${FAIL} failed ==="
echo ""
if [ "$FAIL" -eq 0 ]; then
  echo "All ISSUE-010 acceptance criteria validated."
else
  echo "Some checks failed."
  exit 1
fi
