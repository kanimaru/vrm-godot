extends GutTest

## Regression coverage for spring bone import against real, messily-authored VRM files -
## the synthetic wiring tests (test_vrm0/1_spring_bone_simulator.gd) can't catch issues that
## only show up against real hierarchy complexity: many springs, shared collider groups,
## multi-root groups, deep chains. Uses add_child_autofree (not autofree) so the imported
## scene actually enters the live tree and _ready() fires - test_vrm_expressions.gd's asset
## tests use autofree() alone, which never triggers _ready(), so this is the only place the
## spring bone simulators' setup code runs against real files at all.

var doc: GLTFDocument


func before_each() -> void:
	doc = GLTFDocument.new()


func test_vrm0_temptic_spring_bones_import_without_errors() -> void:
	var path: String = "res://assets/temptic/model.vrm"
	if not FileAccess.file_exists(path):
		pending("Temptic VRM is a licensed asset kept locally only (gitignored) - not present here")
		return

	var vrm0 = load("res://addons/vrm/vrm0/vrm0_extension.gd").new()
	GLTFDocument.register_gltf_document_extension(vrm0)
	var state := GLTFState.new()
	assert_eq(doc.append_from_file(path, state), OK)

	var root: Node = doc.generate_scene(state)
	add_child_autofree(root)

	# find_children may see more than one simulator if other test files in the same suite
	# run registered their own GLTFDocumentExtension instances without unregistering them
	# (a pre-existing, unrelated test-isolation gap) - assert presence, not an exact count.
	var sims: Array[Node] = root.find_children("", "SpringBoneSimulator3D", true, false)
	assert_gt(sims.size(), 0, "Temptic should have a spring bone simulator attached")
	if sims.is_empty():
		return

	var sim: Node = sims[0]
	assert_gt(sim.get_setting_count(), 0, "at least one chain setting should have been created")
	for i: int in range(sim.get_setting_count()):
		assert_false(sim.get_root_bone_name(i).is_empty(), "setting %d should have a resolved root bone name" % i)
		assert_false(sim.get_end_bone_name(i).is_empty(), "setting %d should have a resolved end bone name" % i)


func test_vrm1_luna_spring_bones_import_without_errors() -> void:
	var path: String = "res://assets/luna/luna.vrm"
	if not FileAccess.file_exists(path):
		pending("Luna VRM is a licensed asset kept locally only (gitignored) - not present here")
		return

	var vrm1 = load("res://addons/vrm/vrm1/vrm1_extension.gd").new()
	GLTFDocument.register_gltf_document_extension(vrm1)
	var state := GLTFState.new()
	assert_eq(doc.append_from_file(path, state), OK)

	var root: Node = doc.generate_scene(state)
	add_child_autofree(root)

	var sims: Array[Node] = root.find_children("", "SpringBoneSimulator3D", true, false)
	assert_gt(sims.size(), 0, "Luna should have a spring bone simulator attached")
	if sims.is_empty():
		return

	var sim: Node = sims[0]
	assert_gt(sim.get_setting_count(), 0, "at least one spring setting should have been created")

	var total_collisions := 0
	for i: int in range(sim.get_setting_count()):
		assert_true(sim.is_config_individual(i), "VRM1 springs should always use per-joint config")
		assert_false(sim.get_root_bone_name(i).is_empty(), "setting %d should have a resolved root bone name" % i)
		total_collisions += sim.get_collision_count(i)
	assert_gt(total_collisions, 0, "at least some springs should have collisions registered against real collider data")
