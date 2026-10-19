extends "res://scripts/core/test_tutorial_redesign.gd"

class WithoutReplication extends SimulationEngine:
	func _simulate_replicators(_snap: GridWorld, _result: TickResult) -> void: pass
class WithoutRotation extends SimulationEngine:
	func _simulate_rotators(_snap: GridWorld, _result: TickResult) -> void: pass
class WithoutPushing extends SimulationEngine:
	func _simulate_pushers(_snap: GridWorld, _result: TickResult) -> Dictionary: return {}
class WithoutInhibition extends SimulationEngine:
	func _simulate_inhibitors(_snap: GridWorld, _result: TickResult) -> void: pass
class WithoutDestruction extends SimulationEngine:
	func _simulate_destroyers(_snap: GridWorld, _result: TickResult, _attacked: Dictionary = {}) -> void: pass

func run_tests() -> void:
	for id in ["00", "01", "02", "03", "04", "05", "06"]:
		var root_level := SaveManager.load_level("tutorial_" + id)
		for level in [root_level, LevelData.from_dict(root_level.tutorial.followup)]:
			verify(wins(level, level.tutorial.reference, level.tutorial.group_reference), id + " reference wins")
			verify(not wins(level, []), id + " no automatic win")
		var level := LevelData.from_dict(root_level.tutorial.followup)
		var reference: Array = level.tutorial.reference
		var world := make_world(level, reference, level.tutorial.group_reference)
		var area := level.player_build_area
		verify(area.get_area() - level.blocks_data.size() >= 30, id + " open construction space")
		var sim: SimulationEngine
		match id:
			"00":
				sim = SimulationEngine.new(make_world(level, []), area)
				sim.construction_inspection = true
			"01": sim = WithoutDestruction.new(world, area)
			"02": sim = WithoutPushing.new(world, area)
			"03": sim = WithoutReplication.new(world, area)
			"04": sim = WithoutRotation.new(world, area)
			"05": sim = WithoutInhibition.new(world, area)
			"06": sim = SimulationEngine.new(make_world(level, reference), area)
		var won := false
		for tick in range(48):
			if sim.step_tick().is_victory: won = true
		verify(not won, id + " new mechanism disabled cannot win")
		if id == "00":
			verify(wins(level, [[0,-2,1,0,0],[0,-1,1,0,0],[0,0,1,0,0],[0,1,1,0,0],[0,2,1,0,0]]), "ordinary accepts a bent alternative route")
			verify(not wins(level, [[0,-1,1,0,0],[0,0,0,0,0],[0,1,1,0,0]]), "diagonal gaps fail inspection")
		if id == "04":
			var alternate := reference.duplicate(true)
			alternate[1][4] = 1
			verify(wins(level, alternate), "rotation accepts both directions")
		if id == "05":
			verify(wins(level, [[1,0,1,1,0],[0,0,2,0,0],[1,5,1,0,0],[0,6,1,0,0]]), "inhibitors may be arranged below the gates")
		if id == "06":
			for offset in [-2, -1, 1]:
				var shifted := reference.duplicate(true)
				for part in shifted: part[1] += offset
				verify(wins(level, shifted, true), "assembly allows different starting positions")
	print("LOGIC CHECKS: ", checks, "; FAILURES: ", failures)
	quit(0 if failures.is_empty() else 1)
