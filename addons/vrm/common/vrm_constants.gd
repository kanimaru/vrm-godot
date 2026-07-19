@tool
class_name VrmConstants
extends Node

## Shared constants for VRM 0.0 and 1.0 logic.

# Common bone names (Humanoid)
const BONE_HIPS = "hips"
const BONE_SPINE = "spine"
const BONE_CHEST = "chest"
const BONE_NECK = "neck"
const BONE_HEAD = "head"
const BONE_LEFT_EYE = "leftEye"
const BONE_RIGHT_EYE = "rightEye"
const BONE_JAW = "jaw"

# Extension keys
const EXT_VRM0 = "VRM"
const EXT_VRM1_CORE = "VRMC_vrm"
const EXT_VRMC_MATERIALS_MTOON = "VRMC_materials_mtoon"
const EXT_VRMC_SPRINGBONE = "VRMC_springBone"
const EXT_VRMC_NODE_CONSTRAINT = "VRMC_node_constraint"
const EXT_VRMC_VRM_ANIMATION = "VRMC_vrm_animation"

## VRM 1.0 preset expression name -> VRM 0.x-style Vrm0ExpressionController property name.
## VRM 1.0 renamed several presets from VRM 0.x (see docs/VRMC_vrm-1.0/expressions.md,
## "Emotions" table): joy -> happy, sorrow -> sad, fun -> relaxed. Lip sync presets were
## also renamed: a/i/u/e/o -> aa/ih/ou/ee/oh. Entries absent from this map (blink,
## blink_left, blink_right, neutral) already use the same name in both generations, so
## callers should fall back to the VRM1 name unchanged: `EXPRESSION_VRM1_TO_VRM0.get(name, name)`.
##
## Known gaps when retargeting a VRM1 expression onto a VRM0 avatar via this map:
## - "surprised" has no VRM 0.x spec equivalent (added new in VRM 1.0). It's omitted here
##   and falls through to the identity fallback, which happens to work only because
##   Vrm0ExpressionController exposes a non-spec "surprised" property for convenience.
## - "look_up"/"look_down"/"look_left"/"look_right" have no target at all: VRM 0.x's spec
##   does define lookup/lookdown/lookleft/lookright blend shape presets, but
##   Vrm0ExpressionController does not expose properties for any of them. Retargeted gaze
##   expressions silently no-op on VRM0 avatars rather than erroring.
const EXPRESSION_VRM1_TO_VRM0: Dictionary[String, String] = {
	"happy": "joy",
	"sad": "sorrow",
	"relaxed": "fun",
	"aa": "a",
	"ih": "i",
	"ou": "u",
	"ee": "e",
	"oh": "o",
}
