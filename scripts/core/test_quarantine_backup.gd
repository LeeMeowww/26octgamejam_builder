extends SceneTree

const LEVEL_PATH = "res://assets/levels/custom_level_quarantine_backup.json"
# type, x, y, direction, optional structure group
const SOLUTION = [[2,-11,-6,0],[4,-10,-6,0],[3,-11,-5,0],[3,-10,-5,0],[1,-11,-7,3],[0,-11,-8,0],[5,-12,-5,0],[5,-9,-5,2],[3,-1,0,2,1],[2,-2,1,0,1],[3,-1,3,2,2],[2,-2,4,0,2],[4,-3,0,0],[4,-3,3,0]]
var checks := 0
var failures: Array[String] = []
func _initialize() -> void:
	create_timer(15.0).timeout.connect(func(): printerr("TEST WATCHDOG TIMEOUT!"); quit(1))
	call_deferred("run")
func verify(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)
	print(message, " = ", ok)
func simulate(seed_value: int, omit: Array = []) -> Dictionary:
	var level := SaveManager.load_level_from_path(LEVEL_PATH)
	var world := GridWorld.new()
	for data in level.blocks_data: world.add_block(BlockData.from_dict(data))
	for i in range(SOLUTION.size()):
		if i in omit: continue
		var s: Array = SOLUTION[i]
		var block := BlockData.new(s[0], Vector2i(s[1],s[2]), s[3])
		if s.size() > 4: block.structure_id = s[4]
		verify(level.player_build_area.has_point(block.grid_pos) and world.add_block(block), "Legal module " + str(i))
	var engine := SimulationEngine.new(world, level.player_build_area)
	engine.rng.seed = seed_value
	var saved_at_two := 0
	var won := false
	for tick in range(180):
		var result := engine.step_tick()
		if tick == 1: saved_at_two = engine.get_collected_treasure_lineage_count()
		if result.is_victory:
			won = true
			break
	var summary := {"seed":seed_value,"win":won,"ticks":engine.step_count,"saved_at_two":saved_at_two,"lineages":engine.get_collected_treasure_lineage_count(),"protected":engine.get_remaining_protected(),"protected_destroyed":engine.destroyed_protected_count,"pollution":engine.get_remaining_pollution()}
	print("RESULT ", summary)
	return summary
func run() -> void:
	if not FileAccess.file_exists(LEVEL_PATH):
		print("custom_level_quarantine_backup not present, skipping legacy test")
		quit(0)
		return
	for seed_value in range(1,21):
		var r := simulate(seed_value)
		verify(r.win and r.pollution == 0 and r.lineages == 2 and r.protected == 2 and r.protected_destroyed == 0, "Full solution seed " + str(seed_value))
		verify(r.saved_at_two == 2, "Both backups collected by tick 2")
	var no_rescue := simulate(1,[8,9,10,11])
	verify(not no_rescue.win and no_rescue.lineages == 0, "Firepower alone cannot win")
	var one_rescue := simulate(1,[10,11])
	verify(not one_rescue.win and one_rescue.lineages == 1, "One lineage cannot replace two")
	var no_guard := simulate(1,[12,13])
	verify(not no_guard.win and no_guard.protected_destroyed > 0, "Unprotected cores cause permanent failure")
	var no_cannon := simulate(1,[0,1,2,3,4,5,6,7])
	verify(not no_cannon.win and no_cannon.pollution > 0, "Rescue alone cannot win")
	print("QUARANTINE CHECKS=",checks," FAILURES=",failures)
	quit(0 if failures.is_empty() else 1)
