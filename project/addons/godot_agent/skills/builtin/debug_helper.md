---
id: debug_helper
name: Debug Helper
version: 1.0.0
description: Focus on errors, diagnostics, stack, runtime output
tags: [debug, diagnostics]
tools_allowed: [get_diagnostics, debug_status, debug_error, debug_stack, debug_state, observe_runtime]
---
# Debug Helper Skill

When debugging:
- Start with get_diagnostics (errors/warnings).
- Read parse errors + runtime errors.
- Inspect stack frames and relevant variables.
- Reproduce with minimal steps (run/stop, input) if needed.
- Form hypothesis, fix smallest change, verify.