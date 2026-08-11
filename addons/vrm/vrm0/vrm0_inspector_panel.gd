@tool
extends VBoxContainer
class_name Vrm0InspectorPanel

## Read-only inspector panel for displaying VRM 0.0 model metadata.

const UI = preload("res://addons/vrm/common/vrm_inspector_ui.gd")


func build(data: Vrm0TopLevel) -> void:
	# Clear any previous content
	for child in get_children():
		child.queue_free()
	
	add_theme_constant_override("separation", 4)
	
	# Top banner
	var banner := Label.new()
	banner.text = "VRM 0.0 Model"
	banner.add_theme_font_size_override("font_size", 13)
	banner.add_theme_color_override("font_color", Color(0.55, 0.88, 0.76))
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(banner)
	
	add_child(UI.make_separator())
	
	_build_meta_section(data.meta)
	_build_expressions_section(data.blend_shape_master)
	_build_spring_bones_section(data.secondary_animation)
	
	add_child(UI.make_separator())


## --- Model Info + License ---

func _build_meta_section(meta: Vrm0Meta) -> void:
	if meta == null:
		return
	
	# Info content
	var info_group := UI.make_group_container()
	var info_content := UI.get_group_content(info_group)
	if meta.thumbnail_texture != null:
		info_content.add_child(UI.make_thumbnail(meta.thumbnail_texture))
	info_content.add_child(UI.make_row("Title", meta.title))
	info_content.add_child(UI.make_row("Author", meta.author))
	info_content.add_child(UI.make_row("Version", meta.version))
	if not meta.contact_information.is_empty():
		info_content.add_child(UI.make_row("Contact", meta.contact_information))
	if not meta.reference.is_empty():
		info_content.add_child(UI.make_row("Reference", meta.reference))
	
	var info_header := UI.make_panel_header("  ℹ  Model Info", UI.COLOR_HEADER_SECTION, info_group)
	add_child(info_header)
	add_child(info_group)
	
	# License content
	var lic_group := UI.make_group_container()
	var lic_content := UI.get_group_content(lic_group)
	lic_content.add_child(UI.make_row("License", meta.license_name))
	lic_content.add_child(UI.make_row("Allowed Users", meta.allowed_user_name))
	lic_content.add_child(UI.make_bool_row("Violent Usage", meta.violent_ussage_name == "Allow", "Allow", meta.violent_ussage_name))
	lic_content.add_child(UI.make_bool_row("Sexual Usage", meta.sexual_ussage_name == "Allow", "Allow", meta.sexual_ussage_name))
	lic_content.add_child(UI.make_bool_row("Commercial", meta.commercial_ussage_name == "Allow", "Allow", meta.commercial_ussage_name))
	if not meta.other_permission_url.is_empty():
		lic_content.add_child(UI.make_row("Permission URL", meta.other_permission_url))
	if not meta.other_license_url.is_empty():
		lic_content.add_child(UI.make_row("License URL", meta.other_license_url))
	
	var lic_header := UI.make_panel_header("  ⚖  License", UI.COLOR_HEADER_SECTION, lic_group)
	add_child(lic_header)
	add_child(lic_group)


## --- Expressions ---

func _build_expressions_section(blend_shape_master: Vrm0BlendShape) -> void:
	if blend_shape_master == null or blend_shape_master.blend_shape_groups.is_empty():
		return
	
	var groups := blend_shape_master.blend_shape_groups
	var outer_group := UI.make_group_container(8)
	var outer_content := UI.get_group_content(outer_group)
	
	for grp: Vrm0BlendShapeGroup in groups:
		var entry_group := UI.make_group_container()
		var entry_content := UI.get_group_content(entry_group)
		entry_group.visible = false
		
		entry_content.add_child(UI.make_row("Preset", grp.preset_name if not grp.preset_name.is_empty() else "custom"))
		entry_content.add_child(UI.make_bool_row("Binary", grp.is_binary))
		
		if not grp.binds.is_empty():
			entry_content.add_child(UI.make_value_label("Morph Binds:"))
			for b: Vrm0BlendShapeBind in grp.binds:
				entry_content.add_child(UI.make_value_label(
					"Mesh %d  •  Shape %d  •  W: %.2f" % [b.mesh, b.index, b.weight], 1
				))
		
		if not grp.material_binds.is_empty():
			entry_content.add_child(UI.make_value_label("Material Binds: %d" % grp.material_binds.size()))
		
		var display_name := grp.name if not grp.name.is_empty() else ("(unnamed)")
		var bind_count := grp.binds.size() + grp.material_binds.size()
		var entry_title := "%s  [%d binds]" % [display_name, bind_count]
		var entry_header := UI.make_entry_header(entry_title, entry_group)
		
		outer_content.add_child(entry_header)
		outer_content.add_child(entry_group)
	
	var section_header := UI.make_panel_header(
		"  😀  Expressions (%d)" % groups.size(),
		UI.COLOR_HEADER_SECTION, outer_group, false
	)
	add_child(section_header)
	add_child(outer_group)


## --- Spring Bones ---

func _build_spring_bones_section(secondary_animation: Vrm0SecondaryAnimation) -> void:
	if secondary_animation == null or secondary_animation.bone_groups.is_empty():
		return
	
	var springs := secondary_animation.bone_groups
	var outer_group := UI.make_group_container(8)
	var outer_content := UI.get_group_content(outer_group)
	
	for spring: Vrm0Spring in springs:
		var entry_group := UI.make_group_container()
		var entry_content := UI.get_group_content(entry_group)
		entry_group.visible = false
		
		entry_content.add_child(UI.make_row("Stiffness", "%.3f" % spring.stiffness))
		entry_content.add_child(UI.make_row("Drag Force", "%.3f" % spring.drag_force))
		entry_content.add_child(UI.make_row("Hit Radius", "%.4f" % spring.hit_radius))
		entry_content.add_child(UI.make_row("Gravity Power", "%.3f" % spring.gravity_power))
		entry_content.add_child(UI.make_row("Gravity Dir", "%.1f, %.1f, %.1f" % [
			spring.gravity_dir.x, spring.gravity_dir.y, spring.gravity_dir.z
		]))
		
		if spring.bones.size() > 0:
			entry_content.add_child(UI.make_value_label(
				"Bones: [%s]" % ", ".join(Array(spring.bones).map(func(b: int) -> String: return str(b)))
			))
		if spring.collider_groups.size() > 0:
			entry_content.add_child(UI.make_value_label(
				"Collider Groups: [%s]" % ", ".join(Array(spring.collider_groups).map(func(c: int) -> String: return str(c)))
			))
		
		var label := spring.comment if not spring.comment.is_empty() else ("Group %d" % springs.find(spring))
		var entry_title := "%s  [%d bones]" % [label, spring.bones.size()]
		var entry_header := UI.make_entry_header(entry_title, entry_group)
		
		outer_content.add_child(entry_header)
		outer_content.add_child(entry_group)
	
	var collider_count := secondary_animation.collider_groups.size()
	var section_title := "  🌿  Spring Bones (%d groups, %d collider groups)" % [
		springs.size(), collider_count
	]
	var section_header := UI.make_panel_header(section_title, UI.COLOR_HEADER_SECTION, outer_group, false)
	add_child(section_header)
	add_child(outer_group)
