extends GutTest

## Shared base class for GUT tests that need to assert two Quaternions represent
## approximately the same rotation. extend this instead of GutTest directly when a test
## needs assert_eq_relative_rotation().


func assert_eq_relative_rotation(q1: Quaternion, q2: Quaternion, msg: String = "") -> void:
	var diff := q1.inverse() * q2
	var angle := 2.0 * acos(clampf(absf(diff.w), -1.0, 1.0))
	assert_lt(rad_to_deg(angle), 1.0, msg + " (diff angle: %f deg)" % rad_to_deg(angle))
