@tool
extends VBoxContainer
class_name Vrm1InspectorPanel

## Read-only inspector panel for displaying VRM 1.0 model metadata.

const UI = preload("res://addons/vrm/common/vrm_inspector_ui.gd")


func build(data: Vrm1TopLevel) -> void:
	for child in get_children():
		child.queue_free()
	
	add_theme_constant_override("separation", 4)
	
	# Top banner
	var banner := Label.new()
	banner.text = "VRM 1.0 Model"
	banner.add_theme_font_size_override("font_size", 13)
	banner.add_theme_color_override("font_color", Color(0.60, 0.79, 1.0))
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(banner)
	
	add_child(UI.make_separator())
	
	_build_meta_section(data.meta)
	_build_expressions_section(data.expressions)
	_build_spring_bones_section(data.spring_bone)
	
	add_child(UI.make_separator())


## --- Model Info + License ---

func _build_meta_section(meta: Vrm1Meta) -> void:
	if meta == null:
		return
	
	var info_group := UI.make_group_container()
	var info_content := UI.get_group_content(info_group)
	info_content.add_child(UI.make_row("Name", meta.name))
	info_content.add_child(UI.make_row("Version", meta.version))
	
	if meta.authors.size() > 0:
		info_content.add_child(UI.make_row("Authors", ", ".join(meta.authors)))
	if not meta.copyright_information.is_empty():
		info_content.add_child(UI.make_row("Copyright", meta.copyright_information))
	if not meta.contact_information.is_empty():
		info_content.add_child(UI.make_row("Contact", meta.contact_information))
	if meta.references.size() > 0:
		info_content.add_child(UI.make_row("References", ", ".join(meta.references)))
	if not meta.third_party_licenses.is_empty():
		info_content.add_child(UI.make_row("3rd Party", meta.third_party_licenses))
	
	var info_header := UI.make_panel_header("  ℹ  Model Info", UI.COLOR_HEADER_SECTION, info_group)
	add_child(info_header)
	add_child(info_group)
	
	# License content
	var lic_group := UI.make_group_container()
	var lic_content := UI.get_group_content(lic_group)
	lic_content.add_child(UI.make_row("License URL", meta.license_url))
	if not meta.other_license_url.is_empty():
		lic_content.add_child(UI.make_row("Other License URL", meta.other_license_url))
	lic_content.add_child(UI.make_row("Avatar Permission", meta.avatar_permission))
	lic_content.add_child(UI.make_row("Commercial Usage", meta.commercial_usage))
	lic_content.add_child(UI.make_row("Modification", meta.modification))
	lic_content.add_child(UI.make_row("Credit Notation", meta.credit_notation))
	lic_content.add_child(UI.make_bool_row("Redistribution", meta.allow_redistribution))
	lic_content.add_child(UI.make_bool_row("Violent Usage", meta.allow_excessively_violent_usage))
	lic_content.add_child(UI.make_bool_row("Sexual Usage", meta.allow_excessively_sexual_usage))
	lic_content.add_child(UI.make_bool_row("Political/Religious", meta.allow_political_or_religious_usage))
	lic_content.add_child(UI.make_bool_row("Antisocial/Hate", meta.allow_antisocial_or_hate_usage))
	
	var lic_header := UI.make_panel_header("  ⚖  License", UI.COLOR_HEADER_SECTION, lic_group)
	add_child(lic_header)
	add_child(lic_group)


## --- Expressions ---

func _build_expressions_section(expressions: Vrm1Expressions) -> void:
	if expressions == null:
		return
	
	var all_exprs: Dictionary = {}
	for key: String in expressions.preset:
		all_exprs[key] = expressions.preset[key]
	for key: String in expressions.custom:
		all_exprs["[custom] " + key] = expressions.custom[key]
	
	if all_exprs.is_empty():
		return
	
	var outer_group := UI.make_group_container(8)
	var outer_content := UI.get_group_content(outer_group)
	
	for expr_name: String in all_exprs:
		var expr: Vrm1ExpressionData = all_exprs[expr_name]
		
		var entry_group := UI.make_group_container()
		var entry_content := UI.get_group_content(entry_group)
		entry_group.visible = false
		
		# Flags
		var flags := ["Binary: %s" % ("yes" if expr.is_binary else "no")]
		if expr.override_blink != "none":
			flags.append("Blink: %s" % expr.override_blink)
		if expr.override_look_at != "none":
			flags.append("LookAt: %s" % expr.override_look_at)
		if expr.override_mouth != "none":
			flags.append("Mouth: %s" % expr.override_mouth)
		entry_content.add_child(UI.make_value_label("  ".join(flags)))
		
		# Morph binds
		if not expr.morph_binds.is_empty():
			entry_content.add_child(UI.make_value_label("Morph Binds:"))
			for mb: Vrm1ExpressionMorphBind in expr.morph_binds:
				entry_content.add_child(UI.make_value_label(
					"Node %d  •  Shape %d  •  W: %.2f" % [mb.node, mb.index, mb.weight], 1
				))
		
		# Material color binds
		if not expr.material_color_binds.is_empty():
			entry_content.add_child(UI.make_value_label("Material Color Binds:"))
			for cb: Vrm1ExpressionMaterialColorBind in expr.material_color_binds:
				entry_content.add_child(UI.make_value_label(
					"Mat %d  •  %s" % [cb.material, cb.type], 1
				))
		
		# Texture transform binds
		if not expr.texture_transform_binds.is_empty():
			entry_content.add_child(UI.make_value_label("Texture Transform Binds:"))
			for tb: Vrm1ExpressionTextureTransformBind in expr.texture_transform_binds:
				entry_content.add_child(UI.make_value_label(
					"Mat %d  •  Scale: %.2f,%.2f  •  Off: %.2f,%.2f" % [
						tb.material, tb.scale.x, tb.scale.y, tb.offset.x, tb.offset.y
					], 1
				))
		
		var total_binds := expr.morph_binds.size() + expr.material_color_binds.size() + expr.texture_transform_binds.size()
		var entry_title := "%s  [%d binds]" % [expr_name, total_binds]
		var entry_header := UI.make_entry_header(entry_title, entry_group)
		
		outer_content.add_child(entry_header)
		outer_content.add_child(entry_group)
	
	var section_header := UI.make_panel_header(
		"  😀  Expressions (%d)" % all_exprs.size(),
		UI.COLOR_HEADER_SECTION, outer_group, false
	)
	add_child(section_header)
	add_child(outer_group)


## --- Spring Bones ---

func _build_spring_bones_section(spring_bone: Vrm1SpringBone) -> void:
	if spring_bone == null:
		return
	if spring_bone.springs.is_empty() and spring_bone.colliders.is_empty():
		return

	var outer_group := UI.make_group_container(8)
	var outer_content := UI.get_group_content(outer_group)

	# --- Colliders overview ---
	if not spring_bone.colliders.is_empty():
		var col_group := UI.make_group_container()
		var col_content := UI.get_group_content(col_group)
		col_group.visible = false

		for ci: int in range(spring_bone.colliders.size()):
			var col: Vrm1SpringBoneCollider = spring_bone.colliders[ci]
			var shape_type := "?"
			var shape_desc := ""
			if col.shape != null:
				var s: Vrm1SpringBoneShape = col.shape
				match s.type:
					"sphere":
						shape_type = "inside-sphere" if s.inside else "sphere"
						shape_desc = "r=%.3f  off=(%.2f,%.2f,%.2f)" % [
							s.radius, s.offset.x, s.offset.y, s.offset.z
						]
					"capsule":
						shape_type = "inside-capsule" if s.inside else "capsule"
						shape_desc = "r=%.3f  off=(%.2f,%.2f,%.2f)  tail=(%.2f,%.2f,%.2f)" % [
							s.radius,
							s.offset.x, s.offset.y, s.offset.z,
							s.tail.x, s.tail.y, s.tail.z,
						]
					"plane":
						shape_type = "plane"
						shape_desc = "off=(%.2f,%.2f,%.2f)  n=(%.2f,%.2f,%.2f)" % [
							s.offset.x, s.offset.y, s.offset.z,
							s.normal.x, s.normal.y, s.normal.z,
						]

			col_content.add_child(UI.make_value_label(
				"[%d]  node %d  •  %s  %s" % [ci, col.node, shape_type, shape_desc]
			))

		var col_header := UI.make_panel_header(
			"  ⬡  Colliders (%d)" % spring_bone.colliders.size(),
			UI.COLOR_HEADER_SECTION, col_group, false
		)
		outer_content.add_child(col_header)
		outer_content.add_child(col_group)

	# --- Collider Groups ---
	if not spring_bone.collider_groups.is_empty():
		var cg_inner_group := UI.make_group_container()
		var cg_outer_content := UI.get_group_content(cg_inner_group)
		cg_inner_group.visible = false

		for gi: int in range(spring_bone.collider_groups.size()):
			var grp: Vrm1SpringBoneColliderGroup = spring_bone.collider_groups[gi]
			
			var grp_entry_group := UI.make_group_container()
			var grp_content := UI.get_group_content(grp_entry_group)
			grp_entry_group.visible = false

			# List each collider index + its shape type for quick reference.
			for raw_idx in grp.colliders:
				var ci: int = int(raw_idx)
				var ctype := "?"
				if ci >= 0 and ci < spring_bone.colliders.size():
					var shape: Vrm1SpringBoneShape = spring_bone.colliders[ci].shape
					if shape != null:
						ctype = ("inside-" if shape.inside else "") + shape.type
				grp_content.add_child(UI.make_value_label(
					"Collider [%d]  •  %s" % [ci, ctype]
				))

			var grp_label := (
				"[%d] %s  [%d colliders]" % [gi, grp.name, grp.colliders.size()]
				if not grp.name.is_empty()
				else "[%d]  [%d colliders]" % [gi, grp.colliders.size()]
			)
			var grp_header := UI.make_entry_header(grp_label, grp_entry_group)
			cg_outer_content.add_child(grp_header)
			cg_outer_content.add_child(grp_entry_group)

		var cg_section_header := UI.make_panel_header(
			"  ◎  Collider Groups (%d)" % spring_bone.collider_groups.size(),
			UI.COLOR_HEADER_SECTION, cg_inner_group, false
		)
		outer_content.add_child(cg_section_header)
		outer_content.add_child(cg_inner_group)

	# --- Springs ---
	for i: int in range(spring_bone.springs.size()):
		var spring: Vrm1SpringBoneSpring = spring_bone.springs[i]

		var entry_group := UI.make_group_container()
		var entry_content := UI.get_group_content(entry_group)
		entry_group.visible = false

		if spring.center >= 0:
			entry_content.add_child(UI.make_row("Center Node", str(spring.center)))

		# Collider groups — resolve indices to names.
		if spring.collider_groups.size() > 0:
			var cg_parts: Array[String] = []
			for raw_idx in spring.collider_groups:
				var gi: int = int(raw_idx)
				var label := str(gi)
				if gi >= 0 and gi < spring_bone.collider_groups.size():
					var grp_name := spring_bone.collider_groups[gi].name
					if not grp_name.is_empty():
						label = "%d:%s" % [gi, grp_name]
				cg_parts.append(label)
			entry_content.add_child(UI.make_value_label(
				"Collider Groups: [%s]" % ", ".join(cg_parts)
			))

		# Joints sub-section.
		if not spring.joints.is_empty():
			entry_content.add_child(UI.make_value_label("Joints (%d):" % spring.joints.size()))
			for ji: int in range(spring.joints.size()):
				var jt: Vrm1SpringBoneJoint = spring.joints[ji]
				
				var jt_entry_group := UI.make_group_container()
				var jt_content := UI.get_group_content(jt_entry_group)
				jt_entry_group.visible = false
				jt_content.add_child(UI.make_row("Stiffness", "%.3f" % jt.stiffness))
				jt_content.add_child(UI.make_row("Hit Radius", "%.4f" % jt.hit_radius))
				jt_content.add_child(UI.make_row("Drag", "%.3f" % jt.drag_force))
				jt_content.add_child(UI.make_row("Gravity", "%.3f" % jt.gravity_power))
				jt_content.add_child(UI.make_row("Grav Dir", "%.1f,%.1f,%.1f" % [
					jt.gravity_dir.x, jt.gravity_dir.y, jt.gravity_dir.z
				]))

				var jt_label := "Joint %d  [node %d]" % [ji, jt.node]
				var jt_header := UI.make_entry_header(jt_label, jt_entry_group)
				entry_content.add_child(jt_header)
				entry_content.add_child(jt_entry_group)

		var spring_name := spring.name if not spring.name.is_empty() else ("Spring %d" % i)
		var entry_title := "%s  [%d joints]" % [spring_name, spring.joints.size()]
		var entry_header := UI.make_entry_header(entry_title, entry_group)

		outer_content.add_child(entry_header)
		outer_content.add_child(entry_group)

	var section_title := "  🌿  Spring Bones (%d springs, %d colliders)" % [
		spring_bone.springs.size(), spring_bone.colliders.size()
	]
	var section_header := UI.make_panel_header(
		section_title, UI.COLOR_HEADER_SECTION, outer_group, false
	)
	add_child(section_header)
	add_child(outer_group)
