@tool
extends Resource
class_name VrmMaterialVariantMapping

## One surface's resolved KHR_materials_variants mapping: which live (post-MToon-swap)
## material to switch to for each variant index. Built once at import time by
## VrmSceneComposer.build_material_variant_entries() and consumed by
## VrmMaterialVariantController at runtime.
##
## A Resource with stored fields, and the mesh addressed by path, because the editor
## importer saves the scene after building these: a RefCounted with plain vars was
## dropped on save, and a node reference taken at import would point at the
## ImporterMeshInstance3D that the importer replaces with a MeshInstance3D.

## The mesh node, relative to the VrmMaterialVariantController (a child of the avatar
## root, so paths start with "../").
@export var mesh_path: NodePath
@export var surface: int = -1
@export var variant_materials: Dictionary[int, Material] = {}
