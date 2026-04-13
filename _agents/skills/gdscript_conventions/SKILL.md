---
name: GDScript Project Conventions
description: Rules and conventions for writing GDScript 2.0 and Godot 4 structures in this project, based on the official Godot Style Guide.
---

# GDScript Coding Standards & Godot Rules

When writing or modifying GDScript for this project, you must adhere strictly to these conventions. These rules are based on the [Official Godot GDScript Style Guide](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_styleguide.html).

## 1. Naming Conventions

| Type | Convention | Example |
| :--- | :--- | :--- |
| **File Names** | `snake_case` | `vrm_tracker.gd` |
| **Classes / Nodes** | `PascalCase` | `class_name StateMachine` |
| **Functions / Variables** | `snake_case` | `var movement_speed`, `func load_avatar()` |
| **Signals** | `snake_case` (past tense) | `signal state_changed`, `signal avatar_loaded` |
| **Constants** | `CONSTANT_CASE` | `const MAX_SPEED = 200` |
| **Enums (Name)** | `PascalCase` (singular) | `enum State` |
| **Enums (Members)** | `CONSTANT_CASE` | `{IDLE, WALKING}` |
| **Private Members** | Prefix with underscore `_` | `var _internal_timer`, `func _private_method()` |

- **Loading classes**: Use `PascalCase` when loading a class into a variable: `const Weapon = preload("res://weapon.gd")`.

## 2. Formatting & Whitespace

- **Indentation**: Use **Tabs** (not spaces).
- **Line Length**: Keep lines under 100 characters (aim for 80).
- **Blank Lines**: 
  - **Two** blank lines between functions and class definitions.
  - **One** blank line inside functions to separate logical sections.
- **Whitespace**:
  - One space around operators and after commas.
  - No spaces for vertical alignment.
  - Single-line dictionaries: `{ key = "value" }` (space after `{` and before `}`).
- **Quotes**: Prefer **double quotes** `"string"` unless single quotes `'` avoid character escaping.
- **Numbers**:
  - Always use leading/trailing zeros for floats: `0.5`, `10.0` (not `.5`, `10.`).
  - Lowercase hex: `0xfb8c0b`.
  - Large numbers with underscores: `1_000_000`.

## 3. Multiline Statements

- Use **parentheses** for wrapping (favored over backslashes).
- Folders/Arrays/Dicts: Use **1 indent level** for continuation.
- Expressions (if, ternary, etc.): Use **2 indent levels** for continuation.
- Place `and`/`or` at the **beginning** of the continuation line.
- Use **trailing commas** for multiline arrays, dictionaries, and enums.

## 4. Static Typing

- **Declaration**: Use `<variable>: <type> = <value>`.
- **Avoid Redundancy**: Don't use `var direction: Vector3 = Vector3()`.
- **Function Return**: Always declare return types: `func get_speed() -> float:`.
- **Explicit Type**: Use always explicit types (e.g., `@onready var timer: Timer = $Timer`).

## 5. Boolean Operators
- Favor plain English: `and`, `or`, `not` (instead of `&&`, `||`, `!`).

## 6. Standardized Code Order

Organize script content in this specific order:

1.  `@tool`, `@icon`, `@static_unload`
2.  `class_name`
3.  `extends`
4.  `## doc comment`
5.  `signals`
6.  `enums`
7.  `constants`
8.  `static variables`
9.  `@export variables`
10. Public variables
11. Private variables (`_` prefix)
12. `@onready` variables
13. `_static_init()` and static methods
14. Overridden built-in virtual methods:
    - `_init()`
    - `_enter_tree()`
    - `_ready()`
    - `_process(delta)`
    - `_physics_process(delta)`
    - Other virtual methods (`_input`, `_unhandled_input`, etc.)
15. Overridden custom methods
16. Remaining methods (Public first, then Private)
17. Inner classes

## 7. Node & Scene Management

- Use `@onready` for caching node paths.
- Prefer `@export` over hardcoding node paths.
- Prefer explicit signal connections in code: `button.pressed.connect(_on_button_pressed)`.
- Use unique names for nodes referenced in scripts.
- Declare local variables as close as possible to their first use.
