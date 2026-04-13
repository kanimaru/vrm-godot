extends SceneTree
func _init():
    var methods = ClassDB.class_get_method_list("EditorPlugin")
    for m in methods:
        if m.name.find("importer") != -1 or m.name.find("import_plugin") != -1:
            var args = ""
            for a in m.args:
                args += a.name + ": " + str(a.type) + ", "
            print(m.name + "(" + args + ")")
    quit()

