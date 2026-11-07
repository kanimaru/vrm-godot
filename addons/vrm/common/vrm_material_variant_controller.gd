@tool
extends Node
class_name VrmMaterialVariantController

## Runtime controller for glTF's core KHR_materials_variants extension - switches mesh
## surfaces between authored material variants (e.g. VRoid/Booth-style outfit swaps).
## Godot's built-in glTF importer has no native concept of this extension: it always shows
## whichever material a primitive's plain `material` index points to, with no way to
## switch. This plugin attaches one instance of this controller per imported avatar that
## declares KHR_materials_variants, exposing a small index/name-based API for game code.

## Stored with the scene: the editor importer saves the avatar after attaching this
## controller, and plain vars came back empty, so imported avatars had no variants.
@export_storage var variant_names: Array[String] = []
@export_storage var mappings: Array[VrmMaterialVariantMapping] = []

var _current_variant: int = -1


func get_variant_names() -> Array[String]:
	return variant_names


func get_current_variant() -> int:
	return _current_variant


## Switches every mapped surface to variant_index's material. A surface with no mapping
## for this particular variant is left untouched - the spec has no fallback rule beyond
## "the primitive's own default material" for variants that don't cover every surface, and
## that default is already what's showing before any variant is selected.
func set_variant(variant_index: int) -> void:
	if variant_index < 0 or variant_index >= variant_names.size():
		push_warning("VrmMaterialVariantController: variant index %d out of range (have %d variants)" % [variant_index, variant_names.size()])
		return
	for mapping: VrmMaterialVariantMapping in mappings:
		if not mapping.variant_materials.has(variant_index):
			continue
		var mesh_inst := get_node_or_null(mapping.mesh_path) as MeshInstance3D
		if mesh_inst == null:
			push_warning("VrmMaterialVariantController: no MeshInstance3D at '%s'" % mapping.mesh_path)
			continue
		mesh_inst.set_surface_override_material(mapping.surface, mapping.variant_materials[variant_index])
	_current_variant = variant_index


## Convenience wrapper around set_variant() that looks the index up by name. Returns false
## (and does nothing) if no variant with that name exists.
func set_variant_by_name(variant_name: String) -> bool:
	var idx: int = variant_names.find(variant_name)
	if idx == -1:
		return false
	set_variant(idx)
	return true
