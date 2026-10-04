# AI Godot Development Agent — V1 Product Requirements Document

**Status:** Draft / V1 Scope Lock  
**Document Type:** Product Requirements Document  
**Target Engine:** Godot 4.x  
**Primary Experience:** Cursor-like autonomous AI development workflow inside Godot  
**Version:** 1.0

---

## 1. Executive Summary

The AI Godot Development Agent is an in-editor autonomous development assistant for Godot projects.

Its purpose is not simply to generate GDScript. The agent should be able to understand a Godot project, inspect its scene hierarchy and resources, modify the project, run the game, playtest it, observe the result, diagnose problems, make further changes, and continue iterating until the requested task is completed or the agent determines that human intervention is required.

The V1 experience is modeled around the following loop:

```text
USER TASK
   ↓
PLAN
   ↓
OBSERVE
   ↓
REASON
   ↓
TOOL-CALL SEQUENCE
   ↓
VERIFY
   ↓
TASK COMPLETE?
   ├── YES → FINAL RESPONSE
   └── NO  → NEXT ITERATION
                 ↓
              OBSERVE
```

The central product principle is:

> **The agent should not trust its own modifications as proof of success. It should verify the resulting state and, where appropriate, test the actual running game.**

Godot remains the source of truth for project state. Agent memory stores task context, reasoning state, decisions, hypotheses, recent changes, and verification results rather than attempting to become a second representation of the entire project.

---

# 2. Product Vision

Build an AI development agent that can work on a Godot project in a manner similar to an experienced developer:

- understand an unfamiliar project,
- inspect the relevant scene and code,
- determine what needs to change,
- make coordinated changes,
- run the game,
- interact with it,
- inspect runtime state,
- diagnose failures,
- consult documentation when necessary,
- iterate,
- and report what was actually completed.

The desired experience is:

> **"Tell the agent what you want to build or fix, then let it investigate, implement, test, and iterate."**

---

# 3. Problem Statement

Current AI coding assistants are generally optimized around text/code.

Godot development contains substantially more state than source code:

- SceneTree hierarchy
- Nodes
- Node properties
- Resources
- PackedScenes
- AnimationPlayer
- AnimationTree
- Project Settings
- Input Map
- runtime state
- viewport state
- physics state
- errors and warnings
- instantiated runtime objects

An agent that only edits scripts cannot reliably understand or test the game.

V1 therefore needs a unified interface between the AI and Godot's:

1. **Editor state**
2. **Project state**
3. **Runtime state**
4. **Gameplay state**
5. **Documentation**

---

# 4. Goals

## 4.1 Primary Goals

V1 must allow an agent to:

1. Understand the current Godot project.
2. Inspect scenes and SceneTrees.
3. Inspect nodes and their properties.
4. Inspect and modify resources.
5. Create, delete, rename, duplicate, and reparent nodes.
6. Modify project settings and Input Map.
7. Read and patch scripts.
8. Inspect and edit AnimationPlayer.
9. Inspect and edit AnimationTree.
10. Run and stop the game.
11. Inspect runtime state.
12. Read runtime/editor diagnostics.
13. Send gameplay input.
14. Wait and observe gameplay.
15. Capture the game viewport.
16. Search official Godot documentation and the web.
17. Verify modifications.
18. Iterate automatically after failed or incomplete verification.
19. Maintain useful working memory across context compaction.
20. Provide a clear record of changes and test results.

## 4.2 Secondary Goals

- Minimize unnecessary context usage.
- Minimize unnecessary tool calls.
- Prevent destructive uncontrolled mutations.
- Make tool execution observable.
- Support multiple LLM providers.
- Make the architecture extensible for V2.

---

# 5. Non-Goals

The following are explicitly outside V1:

- Full visual manipulation of the Godot editor UI.
- Autonomous mouse-driven editor automation.
- Arbitrary direct modification of raw `.tscn` serialization.
- Full visual level design through pixel-perfect editor interaction.
- Automatic 3D asset generation.
- Automatic texture/model generation.
- Multiplayer autonomous testing.
- Full CI/CD integration.
- Full project-wide semantic refactoring.
- Autonomous Git branch management.
- Persistent vector database containing the entire project.
- Autonomous publishing to stores.
- Autonomous cloud deployment.
- Replacing the Godot editor itself.

These may be considered for later versions.

---

# 6. Target User

Primary user:

- Godot developer
- Indie developer
- Solo developer
- Small game development team
- Technical game designer

The V1 experience assumes the user owns and controls the Godot project and wants the AI to work directly on it.

---

# 7. Core User Experience

A user should be able to say:

> "Add a dash ability to the player. Use Shift, play the dash animation, and make sure it works."

The agent should:

1. Understand the task.
2. Inspect the player scene.
3. Find the player script.
4. Inspect existing animation setup.
5. Inspect Input Map.
6. Form an implementation plan.
7. Modify the script.
8. Add/configure required nodes/resources.
9. Configure input.
10. Configure animation behavior.
11. Verify editor state.
12. Run the game.
13. Press the dash input.
14. Observe runtime behavior.
15. Detect failures.
16. Fix failures.
17. Retest.
18. Finish with a factual summary.

---

# 8. Product Architecture

```text
┌─────────────────────────────────────────────────────────┐
│                       USER                              │
└──────────────────────────┬──────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────┐
│                    AGENT UI                             │
│  Chat │ Plan │ Activity │ Changes │ Tests │ Approval   │
└──────────────────────────┬──────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────┐
│                   AGENT EXECUTOR                        │
│                                                         │
│ Plan → Observe → Reason → Tool Sequence → Verify       │
│                         ↑                     │         │
│                         └──── Next Iteration ─┘         │
└───────────────┬───────────────────────┬─────────────────┘
                │                       │
                ▼                       ▼
       ┌────────────────┐       ┌──────────────────┐
       │ Context/Memory │       │ Model Provider   │
       └────────────────┘       └──────────────────┘
                │
                ▼
┌─────────────────────────────────────────────────────────┐
│                    TOOL GATEWAY                         │
│ Inspection │ Editing │ Runtime │ Playtest │ Knowledge │
└──────────────────────────┬──────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────┐
│                  GODOT BRIDGE                           │
│ EditorPlugin │ Debugger │ Runtime │ Viewport │ Project │
└──────────────────────────┬──────────────────────────────┘
                           │
              ┌────────────┴─────────────┐
              ▼                          ▼
        GODOT EDITOR               RUNNING GAME
```

---

# 9. Module Architecture

## 9.1 Agent Module

Responsible for autonomous execution.

```text
agent/
├── executor
├── planner
├── reasoner
├── verifier
├── task_state
├── context_manager
├── memory
├── compaction
└── checkpoints
```

### Responsibilities

- Maintain task lifecycle.
- Execute iterations.
- Maintain working state.
- Invoke the model.
- Process tool calls.
- Aggregate tool results.
- Decide whether another iteration is required.
- Stop when the task is complete.
- Stop on budget exhaustion.
- Handle cancellation.

---

# 10. Agent Loop

The V1 loop is intentionally simple.

## 10.1 Initial Plan

The agent receives:

- user request,
- project metadata,
- available capabilities,
- relevant existing context.

It generates a working plan.

Example:

```text
Task: Add dash ability.

Plan:
1. Inspect Player.
2. Inspect movement script.
3. Inspect input configuration.
4. Inspect animation setup.
5. Implement dash.
6. Configure animation/input.
7. Run game.
8. Playtest.
9. Verify.
10. Fix if required.
```

The plan is guidance, not a rigid predetermined execution graph.

---

## 10.2 Iteration

Each iteration consists of:

```text
OBSERVE
    ↓
REASON
    ↓
TOOL CALL SEQUENCE
    ↓
VERIFY
```

A single iteration may contain multiple tool calls.

Example:

```text
node_inspect(Player)
script_read(player.gd)
property_inspect(Player)
animation_inspect(Player/AnimationPlayer)
```

Then:

```text
script_patch(player.gd)
property_set(...)
animation_edit(...)
```

Then verification:

```text
node_inspect(...)
script_read(...)
```

---

## 10.3 Next Iteration

If verification is incomplete:

```text
Iteration 1 → partial
Iteration 2 → partial
Iteration 3 → success
```

The agent carries forward:

- task goal,
- relevant findings,
- changes,
- failures,
- hypotheses,
- unresolved issues,
- verification results.

---

# 11. Completion Criteria

The agent may declare success only when:

1. The requested changes have been applied.
2. Relevant editor state is valid.
3. No blocking errors remain.
4. Runtime testing has been performed when required.
5. The observed behavior satisfies the task's success criteria.
6. No known unresolved blocker remains.

For purely structural tasks, runtime testing may not be necessary.

For gameplay tasks, runtime verification should normally be required.

---

# 12. Agent Memory

## 12.1 Principle

Godot is the source of truth.

The agent should not attempt to remember the entire project.

```text
Godot:
"What is true?"

Agent memory:
"What am I trying to accomplish?"
```

## 12.2 Working Memory

```json
{
  "goal": "Add dash ability",
  "plan": [],
  "relevant_files": [],
  "relevant_nodes": [],
  "recent_changes": [],
  "hypotheses": [],
  "test_results": [],
  "known_issues": [],
  "next_action": ""
}
```

## 12.3 Compaction

When context approaches its budget:

```text
Raw conversation
       ↓
Compaction
       ↓
Task summary
       ↓
Working state
       ↓
Continue
```

Compaction must preserve:

- current goal,
- completed work,
- important project facts,
- important decisions,
- recent changes,
- failed approaches,
- current hypothesis,
- unresolved issues,
- next objective.

Raw observations and redundant tool output may be discarded.

---

# 13. Context Strategy

The agent must use progressive disclosure.

Bad:

```text
Entire project
+ every scene
+ every property
+ every script
+ every resource
```

Good:

```text
Project metadata
      ↓
Relevant scene
      ↓
Relevant node
      ↓
Relevant properties
      ↓
Relevant script
      ↓
Relevant runtime state
```

The agent should inspect only what is necessary.

---

# 14. Godot Bridge

The Godot Bridge is the native integration layer.

```text
godot/
├── editor_bridge
├── scene_bridge
├── node_bridge
├── property_bridge
├── resource_bridge
├── animation_bridge
├── runtime_bridge
├── debugger_bridge
├── viewport_bridge
├── project_bridge
└── diagnostics_bridge
```

The bridge must not contain LLM reasoning.

It provides controlled, deterministic operations.

---

# 15. Project Inspection

The agent must be able to inspect:

- project name
- Godot version
- renderer
- main scene
- current scene
- project settings
- Input Map
- available capabilities
- relevant project files

Example:

```json
{
  "project": "MyGame",
  "godot_version": "4.x",
  "current_scene": "res://world/test.tscn",
  "main_scene": "res://main.tscn",
  "renderer": "Forward+"
}
```

---

# 16. SceneTree Inspection

The agent must be able to inspect:

- current scene
- scene hierarchy
- node names
- node types
- node paths
- parent/child relationships
- scripts
- groups
- metadata
- scene ownership/instance information where applicable

Depth-limited inspection is required.

Example:

```text
scene_inspect(
    scene="current",
    depth=3
)
```

This prevents excessive context usage.

---

# 17. Node Inspection

`node_inspect` must support selective information.

Possible sections:

```text
identity
properties
children
script
groups
signals
metadata
resources
```

Default responses should be compact.

---

# 18. Property System

Godot properties must be normalized into an AI-readable representation.

Supported categories include:

- primitive values
- enums
- Vector2
- Vector3
- Vector4
- Color
- Transform2D
- Transform3D
- NodePath
- Resource
- arrays
- dictionaries
- typed arrays
- exported script variables

Example:

```json
{
  "name": "motion_mode",
  "type": "enum",
  "value": "GROUNDED",
  "options": [
    "GROUNDED",
    "FLOATING"
  ],
  "editable": true
}
```

---

# 19. Scene Editing

V1 structural operations:

```text
create
delete
duplicate
rename
reparent
```

Example:

```json
{
  "operation": "create",
  "parent": "Player",
  "type": "RayCast2D",
  "name": "GroundRay"
}
```

Every mutation must return:

- success/failure
- affected path
- operation
- resulting state where practical
- error details if failed

---

# 20. Scene Instancing

Support:

```text
instantiate scene
```

V1 should support adding a PackedScene/scene instance into the active scene.

More advanced scene ownership manipulation can be deferred.

---

# 21. Resource System

The agent must be able to inspect and modify resources.

Examples:

```text
CollisionShape2D
  → Shape2D
      → RectangleShape2D
          → size

Sprite2D
  → Texture2D

Material
  → shader/material properties
```

Resource references must be represented safely.

---

# 22. Script Module

The agent must be able to:

### Read

```text
script_read
```

### Search

```text
script_search
```

### Patch

```text
script_patch
```

The preferred editing mechanism is targeted patching.

The agent should avoid rewriting an entire script when a small localized modification is sufficient.

Every patch must be followed by validation.

---

# 23. Script Diagnostics

After a script mutation:

```text
patch
 ↓
parse/diagnostic check
 ↓
if failure
    return diagnostics
```

Diagnostics should include, where available:

- message
- severity
- file
- line
- column

This allows the agent to repair its own mistakes.

---

# 24. AnimationPlayer

V1 must support:

- inspect animations
- create animation
- delete animation
- rename animation
- inspect tracks
- create tracks
- remove tracks
- modify track paths
- insert keys
- remove keys
- playback control

Animation data should be summarized rather than dumping every key by default.

---

# 25. AnimationTree

AnimationTree gets a dedicated semantic interface.

V1 should support the structures required for common gameplay animation workflows:

- inspect tree
- inspect root
- state machine inspection
- add/remove states
- transitions
- transition properties
- blend configuration
- relevant parameters

The agent should not be required to understand every internal Godot resource representation.

---

# 26. Project Settings

Dedicated settings tools:

```text
settings_inspect
settings_get
settings_set
```

V1 should cover common development settings, especially:

- Input Map
- display/window
- rendering settings
- physics-related settings
- autoload information
- project/application settings

Input Map is particularly important for gameplay agents.

Example:

```text
settings_set:
    input action = dash
    key = Shift
```

---

# 27. Runtime Bridge

Runtime controls:

```text
run
stop
pause
resume
restart
status
```

Runtime inspection must operate on the actual running SceneTree.

This is distinct from editor SceneTree inspection.

---

# 28. Runtime Inspection

The agent must be able to inspect:

- runtime nodes
- runtime properties
- children
- active scene
- relevant state
- runtime-created objects

Example:

```json
{
  "path": "/root/Main/Player",
  "type": "CharacterBody2D",
  "properties": {
    "position": {"x": 421, "y": 288},
    "velocity": {"x": 180, "y": 0}
  }
}
```

---

# 29. Diagnostics

The diagnostics system should collect:

```text
parse errors
runtime errors
warnings
tool errors
game crashes
timeouts
```

The agent should be able to query diagnostics without requesting a full runtime observation.

---

# 30. Playtest System

The playtest system is a defining V1 feature.

The agent must be able to:

```text
input
wait
observe
```

V1 inputs:

- keyboard keys
- mouse
- Godot InputMap actions

Examples:

```text
press W
hold W for 1.5 seconds
press dash action
click at position
release key
```

---

# 31. Playtest Observation

An observation can contain:

```text
screenshot
runtime state
errors
FPS
relevant node state
active animation
```

Example:

```json
{
  "screenshot": "<image>",
  "runtime": {
    "fps": 59,
    "player": {
      "position": [421, 288],
      "velocity": [180, 0],
      "animation": "run"
    }
  },
  "errors": []
}
```

The agent should request only the observation components it needs.

---

# 32. Viewport

V1 prioritizes the running game viewport.

```text
game viewport → screenshot → multimodal model
```

Editor viewport vision is not a V1 dependency.

Runtime screenshots should be paired with structured runtime state wherever possible.

---

# 33. Documentation and Web Search

The agent must be able to seek external knowledge.

Tool categories:

```text
docs_search
docs_open
web_search
web_open
```

Search priority:

```text
Official Godot documentation
        ↓
Godot source/reference material
        ↓
Reliable third-party technical sources
        ↓
General web
```

The agent should search when:

- it encounters an unfamiliar API,
- documentation may have changed,
- it needs exact engine behavior,
- it needs a current Godot API reference,
- its internal knowledge is uncertain.

Documentation search is part of the agent loop, not a separate user-only feature.

---

# 34. Capability Registry

At initialization the bridge reports:

```json
{
  "godot_version": "4.x",
  "capabilities": {
    "scene_editing": true,
    "property_editing": true,
    "resource_editing": true,
    "script_editing": true,
    "animation_player": true,
    "animation_tree": true,
    "runtime_debugger": true,
    "viewport_capture": true,
    "project_settings": true,
    "playtest": true,
    "documentation_search": true
  }
}
```

The model must not assume unsupported capabilities.

---

# 35. Tool Architecture

V1 tools are semantic tools.

They should not expose arbitrary Godot API calls or arbitrary code execution.

## Inspection

```text
project_inspect
scene_inspect
node_inspect
property_inspect
resource_inspect
animation_inspect
runtime_inspect
```

## Editing

```text
node_edit
property_set
resource_edit
scene_instance
script_patch
animation_edit
animation_tree_edit
```

## Project

```text
file_search
file_read
settings_inspect
settings_set
```

## Runtime

```text
runtime_control
runtime_errors
playtest_input
playtest_wait
playtest_observe
```

## Knowledge

```text
docs_search
docs_open
web_search
web_open
```

---

# 36. Tool Execution

Every tool invocation passes through:

```text
LLM
 ↓
Tool Validator
 ↓
Permission Check
 ↓
Godot Operation
 ↓
Result Normalizer
 ↓
Verification State
 ↓
LLM
```

The model should never directly manipulate internal Godot objects.

---

# 37. Tool Risk Levels

Tools should be classified.

## Read

```text
project_inspect
scene_inspect
node_inspect
property_inspect
resource_inspect
runtime_inspect
```

## Write

```text
property_set
node_edit
resource_edit
script_patch
animation_edit
settings_set
```

## Execute

```text
runtime_control
playtest_input
```

## Destructive

Examples:

```text
node_delete
file_delete
resource replacement
scene destruction
```

Permissions should be configurable.

---

# 38. Verification

Verification is a first-class module.

Verification can include:

### Structural

```text
node exists
property value correct
resource assigned
animation exists
setting exists
```

### Code

```text
script parses
no relevant diagnostics
```

### Runtime

```text
game launches
no blocking errors
runtime state matches expectation
```

### Gameplay

```text
input produces expected behavior
animation changes
player moves
collision occurs
etc.
```

The verification mechanism should use evidence from Godot rather than the agent's assumptions.

---

# 39. Change Tracking

Every mutation should produce a normalized change record.

Example:

```json
{
  "iteration": 3,
  "changes": [
    {
      "type": "script",
      "file": "res://player/player.gd",
      "operation": "patch"
    },
    {
      "type": "node",
      "path": "Player/DashTimer",
      "operation": "create"
    },
    {
      "type": "setting",
      "path": "input/dash",
      "operation": "create"
    }
  ]
}
```

The UI can use these records to display an agent-generated change summary.

---

# 40. Undo and Rollback

Mutating operations must be safely recoverable.

Preferred flow:

```text
mutation
 ↓
capture previous state
 ↓
apply
 ↓
verify
 ↓
commit
```

If a critical operation fails:

```text
rollback
```

V1 should integrate with Godot's editor undo/redo mechanisms where appropriate rather than creating an entirely independent undo implementation.

---

# 41. Permissions

User settings should include autonomy controls.

Example:

```text
Agent autonomy

○ Ask before every change
● Allow normal changes automatically
○ Allow all changes automatically

Always ask before:
☑ Delete files
☑ Delete nodes
☑ Replace resources
☑ Destructive scene operations
```

The exact UI can evolve, but the underlying permission model must exist.

---

# 42. Cancellation

The user must be able to stop an active task.

Cancellation must propagate through:

```text
Agent Executor
 ↓
LLM request
 ↓
Tool Executor
 ↓
Godot operation
 ↓
Runtime/playtest
```

A cancelled task must leave the project in a valid state.

---

# 43. Failure Recovery

Common failure policies:

| Failure | Response |
|---|---|
| Invalid tool call | Return structured error |
| Invalid property | Inspect schema and retry |
| Script parse error | Diagnose and patch |
| Runtime crash | Collect diagnostics and restart |
| Tool timeout | Retry according to policy |
| Documentation uncertainty | Search docs |
| Repeated failure | Stop and report |
| Context overflow | Compact |
| Network/model failure | Retry or stop safely |

The executor, not the LLM alone, should enforce these policies.

---

# 44. Model Provider Layer

The agent must be model-agnostic.

```text
Agent
 ↓
Model Interface
 ├── Provider A
 ├── Provider B
 ├── Provider C
 └── Local Model
```

Required model capabilities:

- text generation
- tool calls
- multimodal input
- streaming where supported
- token/context accounting

The agent architecture must not be coupled to one provider.

---

# 45. Agent UI

The primary UI should be a dock/panel inside Godot.

Example:

```text
┌─────────────────────────────────────┐
│ AI Agent                            │
├─────────────────────────────────────┤
│ Add a dash ability to Player.       │
│                                     │
│ Plan                                │
│ ✓ Inspect Player                    │
│ ✓ Inspect movement                  │
│ ✓ Configure input                   │
│                                     │
│ Iteration 2                         │
│ ✓ Patched player.gd                 │
│ ✓ Added DashTimer                   │
│ ▶ Running game                      │
│                                     │
│ Playtest                            │
│ ✓ Dash activated                    │
│ ⚠ Animation did not recover         │
│                                     │
│ Fixing animation...                 │
└─────────────────────────────────────┘
```

The user should be able to see:

- current task
- plan
- iteration
- tool activity
- changes
- errors
- screenshots
- verification
- final result

---

# 46. Tool Activity UI

Each tool call should be inspectable.

Example:

```text
✓ node_inspect Player
✓ script_read player.gd
✓ settings_inspect input
✓ script_patch player.gd
✓ runtime_control run
▶ playtest_input dash
✓ playtest_observe
```

This provides transparency without requiring the user to read raw model reasoning.

---

# 47. Security

V1 must avoid exposing unrestricted execution.

Avoid a generic tool such as:

```text
execute_arbitrary_godot_code()
```

unless explicitly sandboxed and approved.

Similarly, arbitrary filesystem operations should be controlled.

The semantic tool layer exists partly to constrain what the agent can do.

---

# 48. Performance Requirements

The agent should avoid unnecessary calls.

Targets:

- Scene inspection should be depth-limited.
- Property inspection should be selective.
- Runtime observations should be selective.
- Screenshots should not be captured continuously by default.
- Large files should be read selectively.
- Documentation results should be summarized before entering the main context where practical.
- Tool results should be compact and structured.

The system should expose token and tool-call usage to internal telemetry.

---

# 49. Agent Budgets

Each task should have configurable limits.

Example:

```json
{
  "max_iterations": 30,
  "max_tool_calls": 100,
  "max_mutations": 50,
  "max_playtests": 10,
  "max_runtime_minutes": 10
}
```

The executor must terminate or request user intervention when limits are reached.

---

# 50. Observability

The system must record:

```text
task
iteration
model request
context size
tool calls
tool latency
Godot latency
errors
verification
compaction
token usage
runtime duration
```

This is primarily for development/debugging in V1 and can later become an advanced analytics system.

---

# 51. Example End-to-End Task

## User

> Add a double jump to the player and test it.

### Plan

```text
1. Inspect Player.
2. Inspect movement script.
3. Inspect input/state implementation.
4. Implement double-jump state.
5. Run game.
6. Perform two jumps.
7. Verify third jump is blocked.
8. Fix if necessary.
```

### Iteration 1

Observe:

```text
scene_inspect
node_inspect
script_read
```

Reason:

```text
Player uses CharacterBody2D.
Jump logic exists in player.gd.
```

Tool sequence:

```text
script_patch
```

Verify:

```text
script_read
runtime_errors
```

Result:

```text
Implementation structurally valid.
```

### Iteration 2

Run:

```text
runtime_control(run)
```

Playtest:

```text
playtest_input(jump)
playtest_wait(.2)
playtest_input(jump)
playtest_wait(.2)
playtest_input(jump)
playtest_observe()
```

Verification:

```text
First jump: success
Second jump: success
Third jump: blocked
```

Task complete.

---

# 52. Example Failure Loop

Task:

> Make the player dash and play the dash animation.

Iteration 1:

```text
Implementation complete.
```

Verification:

```text
Dash movement works.
Animation remains idle.
```

Result:

```text
FAIL / PARTIAL
```

Iteration 2:

```text
animation_tree_inspect
```

Agent discovers missing transition.

Tool sequence:

```text
animation_tree_edit
animation_tree_edit
```

Iteration 2 verification:

```text
Dash animation activates.
```

Iteration 3:

```text
playtest_observe
```

Agent verifies dash returns to normal animation.

Task complete.

---

# 53. V1 Acceptance Criteria

V1 is considered functional when the agent can complete representative tasks involving:

### Scene manipulation

- Create a node.
- Delete a node.
- Rename a node.
- Reparent a node.
- Modify a property.
- Assign a resource.

### Code

- Find a relevant script.
- Read it.
- Patch it.
- Detect parse errors.
- Correct a failed patch.

### Project configuration

- Inspect settings.
- Add/change an Input Map action.

### Animation

- Inspect AnimationPlayer.
- Modify an animation.
- Inspect AnimationTree.
- Modify a basic state-machine/blend configuration.

### Runtime

- Launch the game.
- Stop the game.
- Inspect runtime nodes.
- Detect runtime errors.

### Playtesting

- Send input.
- Wait.
- Capture viewport.
- Inspect runtime state.
- Determine whether expected behavior occurred.

### Agent behavior

- Plan a task.
- Execute multiple tool calls within an iteration.
- Verify results.
- Start another iteration after failure.
- Compact context when required.
- Stop after completion.
- Stop safely after budget exhaustion.
- Produce a factual final summary.

---

# 54. V1 Quality Bar

The agent should prioritize:

1. **Correctness**
2. **Verification**
3. **Project safety**
4. **Efficient context usage**
5. **Tool efficiency**
6. **Clear user visibility**

A shorter successful execution is preferable to a long sequence of unnecessary exploration.

---

# 55. Development Phases

## Phase 1 — Godot Bridge

Build:

```text
EditorPlugin
SceneTree inspection
Node inspection
Property inspection
Basic mutations
Project settings
```

Deliverable:

> AI can inspect and modify a Godot project.

---

## Phase 2 — Script and Diagnostics

Build:

```text
script_read
script_search
script_patch
diagnostics
diff/change tracking
```

Deliverable:

> AI can implement and repair gameplay code.

---

## Phase 3 — Agent Executor

Build:

```text
plan
observe
reason
tool sequence
verify
iteration
budgets
cancellation
```

Deliverable:

> Autonomous multi-step task execution.

---

## Phase 4 — Runtime and Playtest

Build:

```text
run
stop
runtime inspection
runtime diagnostics
input
wait
viewport capture
observation
```

Deliverable:

> AI can actually test the game.

---

## Phase 5 — Animation

Build:

```text
AnimationPlayer
AnimationTree
```

Deliverable:

> AI can build common animation workflows.

---

## Phase 6 — Documentation

Build:

```text
Godot documentation search
web search
source opening
```

Deliverable:

> AI can research unfamiliar APIs during development.

---

## Phase 7 — UI / Productization

Build:

```text
Agent dock
task display
tool activity
diffs
approvals
settings
```

Deliverable:

> Usable Cursor-like Godot experience.

---

# 56. V1 Folder Structure

Recommended implementation structure:

```text
godot-agent/
│
├── agent/
│   ├── executor/
│   ├── planner/
│   ├── context/
│   ├── memory/
│   ├── compaction/
│   ├── verifier/
│   └── state/
│
├── godot/
│   ├── bridge/
│   ├── scene/
│   ├── node/
│   ├── properties/
│   ├── resources/
│   ├── animation/
│   ├── runtime/
│   ├── debugger/
│   ├── viewport/
│   ├── project/
│   └── diagnostics/
│
├── tools/
│   ├── inspection/
│   ├── editing/
│   ├── scripts/
│   ├── animation/
│   ├── project/
│   ├── runtime/
│   ├── playtest/
│   └── knowledge/
│
├── search/
│   ├── godot_docs/
│   ├── web/
│   └── sources/
│
├── transport/
│   ├── mcp/
│   └── protocol/
│
├── model/
│   ├── interface/
│   ├── providers/
│   └── multimodal/
│
├── security/
│   ├── permissions/
│   ├── validation/
│   └── sandbox/
│
├── ui/
│   ├── agent_panel/
│   ├── activity/
│   ├── changes/
│   ├── approvals/
│   └── settings/
│
└── tests/
    ├── bridge/
    ├── tools/
    ├── executor/
    ├── playtest/
    └── scenarios/
```

---

# 57. V1 Success Metric

The primary success metric is not:

> How much code can the model generate?

It is:

> **How reliably can the agent take a natural-language Godot development task from request → implementation → actual verification?**

A useful evaluation should measure:

```text
Task completion rate
Successful verification rate
Human intervention rate
Iterations per task
Tool calls per task
Token consumption
Runtime testing success
Incorrect mutation rate
Recovery success rate
```

---

# 58. Future V2 Directions

After V1 proves the core loop, potential extensions include:

- editor viewport understanding
- visual scene editing
- autonomous asset generation
- shader development
- particle systems
- terrain generation
- navigation debugging
- advanced animation graphs
- automated performance profiling
- automated visual regression testing
- Git-aware change management
- multi-agent workflows
- project-wide refactoring
- autonomous issue/task management
- multiplayer playtesting
- CI integration
- persistent project knowledge
- specialized game-design agents

These should not complicate the V1 implementation.

---

# 59. Final V1 Definition

The V1 product is a **Godot-native autonomous development agent** that can:

```text
UNDERSTAND
    ↓
Inspect project
    ↓
Inspect scenes/nodes/properties/resources/code
    ↓
RESEARCH
    ↓
Search Godot documentation/web when needed
    ↓
PLAN
    ↓
REASON
    ↓
MODIFY
    ↓
Edit nodes/properties/resources/code/settings/animations
    ↓
RUN
    ↓
PLAYTEST
    ↓
OBSERVE
    ↓
VERIFY
    ↓
FIX
    ↓
ITERATE
    ↓
COMPLETE
```

The fundamental V1 loop is therefore:

```text
┌─────────────────────────────────────────────┐
│                                             │
│                  PLAN                       │
│                   ↓                         │
│                OBSERVE                      │
│                   ↓                         │
│                REASON                       │
│                   ↓                         │
│          TOOL CALL SEQUENCE                 │
│                   ↓                         │
│                VERIFY                       │
│                   │                         │
│          ┌────────┴────────┐                │
│          │                 │                │
│       COMPLETE          NOT COMPLETE        │
│          │                 │                │
│          ▼                 └───────┐        │
│        DONE                        │        │
│                                    ▼        │
│                                ITERATE      │
│                                    │        │
│                                    └──→ OBSERVE
│                                             │
└─────────────────────────────────────────────┘
```

**V1 is successful when the agent can reliably make a change to a real Godot project, run the resulting game, test the behavior, observe what actually happened, correct itself when necessary, and stop only when the requested task has been verified.**
