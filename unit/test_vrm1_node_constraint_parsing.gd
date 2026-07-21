extends GutTest

## Unit tests for Vrm1Extension._parse_node_constraint() and its wiring into
## _import_post_parse's per-node VRMC_node_constraint scan.

var _ext: Vrm1Extension


func before_each() -> void:
	_ext = Vrm1Extension.new()


func after_each() -> void:
	_ext = null


func test_parse_roll_constraint() -> void:
	var d: Dictionary = {
		"constraint": {
			"roll": {"source": 3, "rollAxis": "Y", "weight": 0.75},
		},
	}
	var nc: Vrm1NodeConstraint = _ext.call("_parse_node_constraint", 5, d)
	assert_not_null(nc, "Should parse a roll constraint")
	assert_eq(nc.node, 5)
	assert_eq(nc.type, "roll")
	assert_eq(nc.source, 3)
	assert_eq(nc.roll_axis, "Y")
	assert_almost_eq(nc.weight, 0.75, 0.0001)


func test_parse_aim_constraint() -> void:
	var d: Dictionary = {
		"constraint": {
			"aim": {"source": 7, "aimAxis": "NegativeZ", "weight": 0.5},
		},
	}
	var nc: Vrm1NodeConstraint = _ext.call("_parse_node_constraint", 2, d)
	assert_not_null(nc, "Should parse an aim constraint")
	assert_eq(nc.type, "aim")
	assert_eq(nc.source, 7)
	assert_eq(nc.aim_axis, "NegativeZ")
	assert_almost_eq(nc.weight, 0.5, 0.0001)


func test_parse_rotation_constraint() -> void:
	var d: Dictionary = {
		"constraint": {
			"rotation": {"source": 1},
		},
	}
	var nc: Vrm1NodeConstraint = _ext.call("_parse_node_constraint", 4, d)
	assert_not_null(nc, "Should parse a rotation constraint")
	assert_eq(nc.type, "rotation")
	assert_eq(nc.source, 1)


func test_rotation_constraint_defaults_weight_to_one() -> void:
	var d: Dictionary = {
		"constraint": {
			"rotation": {"source": 1},
		},
	}
	var nc: Vrm1NodeConstraint = _ext.call("_parse_node_constraint", 4, d)
	assert_almost_eq(nc.weight, 1.0, 0.0001, "weight should default to 1.0 per spec")


func test_missing_constraint_key_returns_null() -> void:
	var d: Dictionary = {}
	var nc: Vrm1NodeConstraint = _ext.call("_parse_node_constraint", 0, d)
	assert_null(nc, "Should return null when the extension dict has no 'constraint' key")


func test_constraint_with_none_of_roll_aim_rotation_returns_null() -> void:
	var d: Dictionary = {"constraint": {}}
	var nc: Vrm1NodeConstraint = _ext.call("_parse_node_constraint", 0, d)
	assert_null(nc, "Should return null when constraint has none of roll/aim/rotation")


func test_import_post_parse_builds_sparse_node_constraint_map() -> void:
	var json: Dictionary = {
		"extensions": {
			"VRMC_vrm": {"specVersion": "1.0"},
		},
		"nodes": [
			{"name": "NodeWithoutConstraint"},
			{
				"name": "Twist1",
				"extensions": {
					"VRMC_node_constraint": {
						"specVersion": "1.0",
						"constraint": {"roll": {"source": 0, "rollAxis": "X"}},
					},
				},
			},
			{"name": "AnotherNodeWithoutConstraint"},
		],
	}

	var state := GLTFState.new()
	state.json = json

	_ext.call("_import_post_parse", state)

	var node_constraints: Variant = state.get_additional_data("vrm1_node_constraints")
	assert_true(node_constraints is Dictionary, "vrm1_node_constraints should be a Dictionary")
	assert_true(node_constraints.has(1), "Node index 1 carries the extension and should be present")
	assert_false(node_constraints.has(0), "Node index 0 has no extension and should be absent (sparse, not null-padded)")
	assert_false(node_constraints.has(2), "Node index 2 has no extension and should be absent")

	var nc: Vrm1NodeConstraint = node_constraints[1]
	assert_eq(nc.type, "roll")
	assert_eq(nc.node, 1)
