---
description: Run Godot GUT unit tests
---

# Run GUT Unit Tests

This workflow handles the execution of the Godot Unit Test (GUT) add-on.

// turbo
1. Run the GUT command in headless mode
```powershell
godot --headless -s addons/gut/gut_cmdln.gd
```

2. Review the printed results in the terminal.
3. If there are failures, immediately analyze the failing scripts to identify the cause.
