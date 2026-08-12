@tool
extends RefCounted
class_name VrmMaterialVariantMapping

## One surface's resolved KHR_materials_variants mapping: which live (post-MToon-swap)
## material to switch to for each variant index. Built once at import time by
## VrmSceneComposer.build_material_variant_entries() and consumed by
## VrmMaterialVariantController at runtime.

var mesh_instance: MeshInstance3D
var surface: int = -1
var variant_materials: Dictionary[int, Material] = {}
