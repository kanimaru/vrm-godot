extends SceneTree
func _init():
    var methods = ClassDB.class_get_method_list("EditorSceneFormatImporter")
    for m in methods:
        var args = ""
        for a in m.args:
            args += a.name + ": " + str(a.type) + ", "
        print(m.name + "(" + args + ")")
    quit()

