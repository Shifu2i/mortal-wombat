class_name CharacterStateMachine
extends RefCounted

# Lightweight finite-state machine for a fighter. States are enum ints, not
# strings, so transitions are cheap and serialisable. Owned by character_base.
#
# State logic itself (per-tick behaviour, transition conditions) lives in
# character_base — this class just tracks current/previous state, frame the
# state was entered, and exposes a transition helper.

enum State {
	IDLE,
	RUN,
	JUMP_RISE,
	FALL,
	ATTACK_BITE,
	ATTACK_KICK,
	ROLL,
	BLOCK,
	HITSTUN,
}

var state: int = State.IDLE
var prev_state: int = State.IDLE
var entered_on_frame: int = 0


func transition_to(new_state: int, current_frame: int) -> void:
	if new_state == state:
		return
	prev_state = state
	state = new_state
	entered_on_frame = current_frame


func frames_in_state(current_frame: int) -> int:
	return current_frame - entered_on_frame


static func state_name(s: int) -> String:
	match s:
		State.IDLE: return "IDLE"
		State.RUN: return "RUN"
		State.JUMP_RISE: return "JUMP"
		State.FALL: return "FALL"
		State.ATTACK_BITE: return "BITE"
		State.ATTACK_KICK: return "KICK"
		State.ROLL: return "ROLL"
		State.BLOCK: return "BLOCK"
		State.HITSTUN: return "HITSTUN"
	return "?"
