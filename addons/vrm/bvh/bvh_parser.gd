class_name BvhParser
extends RefCounted

class BvhNode:
	var name: String = ""
	var offset: Vector3 = Vector3.ZERO
	var channels: Array[String] = []
	var children: Array = [] # Array of BvhNode
	var parent = null # BvhNode
	var is_end_site: bool = false
	var channel_start_index: int = -1

class BvhData:
	var root: BvhNode = null
	var nodes: Array = [] # Array of BvhNode
	var num_frames: int = 0
	var frame_time: float = 0.0
	var motion_data: Array = [] # Array of PackedFloat32Array

static func parse_file(path: String) -> BvhData:
	var f = FileAccess.open(path, FileAccess.READ)
	if f == null:
		printerr("BvhParser: Failed to open BVH file: ", path)
		return null
	var content = f.get_as_text()
	return parse(content)

static func parse(content: String) -> BvhData:
	var data = BvhData.new()
	
	# Pre-process content to space out brackets and normalize whitespace
	content = content.replace("{", " { ").replace("}", " } ")
	
	var tokens: PackedStringArray = []
	var regex = RegEx.new()
	regex.compile("\\S+")
	var results = regex.search_all(content)
	for res in results:
		tokens.append(res.get_string())
	
	var i: int = 0
	var state = "EXPECT_HIERARCHY"
	var current_node: BvhNode = null
	var channel_index: int = 0
	
	while i < tokens.size():
		var token = tokens[i]
		if state == "EXPECT_HIERARCHY":
			if token == "HIERARCHY":
				state = "HIERARCHY"
			i += 1
		elif state == "HIERARCHY":
			if token == "ROOT" or token == "JOINT":
				var node = BvhNode.new()
				node.name = tokens[i+1]
				i += 2
				if current_node == null:
					data.root = node
				else:
					current_node.children.append(node)
					node.parent = current_node
				data.nodes.append(node)
				current_node = node
			elif token == "End":
				if i + 1 < tokens.size() and tokens[i+1] == "Site":
					var node = BvhNode.new()
					node.name = current_node.name + "_End"
					node.is_end_site = true
					current_node.children.append(node)
					node.parent = current_node
					data.nodes.append(node)
					current_node = node
					i += 2
				else:
					i += 1
			elif token == "{":
				i += 1
			elif token == "}":
				if current_node != null:
					current_node = current_node.parent
				i += 1
			elif token == "OFFSET":
				if current_node != null and i + 3 < tokens.size():
					current_node.offset = Vector3(tokens[i+1].to_float(), tokens[i+2].to_float(), tokens[i+3].to_float())
				i += 4
			elif token == "CHANNELS":
				if current_node != null and i + 1 < tokens.size():
					var count = tokens[i+1].to_int()
					current_node.channel_start_index = channel_index
					i += 2
					for c in range(count):
						if i < tokens.size():
							current_node.channels.append(tokens[i])
							channel_index += 1
							i += 1
			elif token == "MOTION":
				state = "MOTION"
				i += 1
			else:
				i += 1 # Skip unknown token
		elif state == "MOTION":
			if token == "Frames:":
				data.num_frames = tokens[i+1].to_int()
				i += 2
			elif token == "Frame":
				if i + 2 < tokens.size() and tokens[i+1] == "Time:":
					data.frame_time = tokens[i+2].to_float()
					i += 3
					state = "MOTION_DATA"
				else:
					i += 1
			else:
				i += 1
		elif state == "MOTION_DATA":
			break # Handled below
			
	if state == "MOTION_DATA":
		# Read all floats
		var floats_per_frame = channel_index
		if floats_per_frame > 0:
			var remaining_tokens = tokens.size() - i
			var frames_to_read = min(data.num_frames, remaining_tokens / floats_per_frame)
			for f in range(frames_to_read):
				var frame_data = PackedFloat32Array()
				frame_data.resize(floats_per_frame)
				for j in range(floats_per_frame):
					frame_data[j] = tokens[i + f * floats_per_frame + j].to_float()
				data.motion_data.append(frame_data)
			
	return data
