@tool
extends RefCounted
class_name VrmInspectorUi

## Static utility methods for building consistent read-only VRM inspector UI controls.

const COLOR_HEADER_VRM0 := Color(0.18, 0.52, 0.44)  # Teal-green
const COLOR_HEADER_VRM1 := Color(0.25, 0.40, 0.70)  # Blue
const COLOR_HEADER_SECTION := Color(0.20, 0.20, 0.24)  # Dark neutral
const COLOR_ALLOWED := Color(0.3, 0.75, 0.3)
const COLOR_DENIED := Color(0.80, 0.28, 0.28)


## Creates a top-level panel header button that toggles the visibility of [content].
static func make_panel_header(title: String, color: Color, content: Control, initially_open: bool = true) -> Button:
	var btn := Button.new()
	btn.text = ("▼ " if initially_open else "▶ ") + title
	btn.flat = false
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_color_override("font_pressed_color", Color.WHITE)
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn.toggle_mode = true
	btn.button_pressed = initially_open
	content.visible = initially_open
	
	var sx := StyleBoxFlat.new()
	sx.bg_color = color.darkened(0.2)
	sx.corner_radius_top_left = 4
	sx.corner_radius_top_right = 4
	sx.corner_radius_bottom_left = 4
	sx.corner_radius_bottom_right = 4
	sx.content_margin_left = 6
	sx.content_margin_right = 6
	sx.content_margin_top = 4
	sx.content_margin_bottom = 4
	btn.add_theme_stylebox_override("normal", sx)
	btn.add_theme_stylebox_override("pressed", sx)
	btn.add_theme_stylebox_override("hover", sx)
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	
	btn.toggled.connect(func(pressed: bool) -> void:
		content.visible = pressed
		btn.text = ("▼ " if pressed else "▶ ") + title
	)
	return btn


## Creates a collapsible section header — smaller, used for spring/expression entries.
static func make_entry_header(title: String, content: Control, initially_open: bool = false) -> Button:
	var btn := Button.new()
	btn.text = ("▼ " if initially_open else "▶ ") + title
	btn.flat = true
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.toggle_mode = true
	btn.button_pressed = initially_open
	btn.add_theme_font_size_override("font_size", 12)
	
	btn.toggled.connect(func(pressed: bool) -> void:
		content.visible = pressed
		btn.text = ("▼ " if pressed else "▶ ") + title
	)
	return btn


## Creates a single property row with a label and a right-aligned read-only value label.
static func make_row(label_text: String, value_text: String) -> HBoxContainer:
	var hbox := HBoxContainer.new()
	
	var lbl := Label.new()
	lbl.text = label_text
	lbl.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.custom_minimum_size = Vector2(90, 0)
	
	var val := Label.new()
	val.text = value_text if not value_text.is_empty() else "—"
	val.add_theme_font_size_override("font_size", 11)
	val.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	val.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	
	hbox.add_child(lbl)
	hbox.add_child(val)
	return hbox


## Creates a full-width value-only label (for multi-value lists).
static func make_value_label(text: String, indent: int = 0) -> Label:
	var lbl := Label.new()
	lbl.text = "  ".repeat(indent) + text
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return lbl


## Creates a colored boolean badge (allowed/denied).
static func make_bool_row(label_text: String, value: bool, true_label: String = "Yes", false_label: String = "No") -> HBoxContainer:
	var hbox := HBoxContainer.new()
	
	var lbl := Label.new()
	lbl.text = label_text
	lbl.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.custom_minimum_size = Vector2(90, 0)
	
	var badge := Label.new()
	badge.text = ("✔ " + true_label) if value else ("✘ " + false_label)
	badge.add_theme_color_override("font_color", COLOR_ALLOWED if value else COLOR_DENIED)
	badge.add_theme_font_size_override("font_size", 11)
	
	hbox.add_child(lbl)
	hbox.add_child(badge)
	return hbox


## Adds a thin horizontal separator.
static func make_separator() -> HSeparator:
	var sep := HSeparator.new()
	sep.add_theme_constant_override("separation", 2)
	return sep


## Creates a container for child items with a subtle background and indentation.
static func make_group_container(indent_px: int = 14) -> PanelContainer:
	var pc := PanelContainer.new()
	var sx := StyleBoxFlat.new()
	sx.bg_color = Color(1.0, 1.0, 1.0, 0.03)  # Very subtle tint
	sx.draw_center = true
	sx.border_width_left = 2
	sx.border_color = Color(1.0, 1.0, 1.0, 0.1)
	sx.content_margin_left = indent_px
	sx.content_margin_top = 4
	sx.content_margin_bottom = 4
	pc.add_theme_stylebox_override("panel", sx)
	
	var v_box := VBoxContainer.new()
	v_box.add_theme_constant_override("separation", 2)
	pc.add_child(v_box)
	
	# Return the PanelContainer, content should be added to the first child (VBox)
	return pc


## Returns the VBoxContainer inside a container created by make_group_container.
static func get_group_content(container: PanelContainer) -> VBoxContainer:
	return container.get_child(0) as VBoxContainer
