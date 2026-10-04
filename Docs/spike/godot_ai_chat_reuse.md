# Reuse Analysis: unxsist/godot-ai-chat vs GodotAgent V1

**Subject:** [unxsist/godot-ai-chat](https://github.com/unxsist/godot-ai-chat) (`addons/ai_copilot/`, MIT, 100% GDScript, Godot 4.7)  
**Against:** `Docs/godot_ai_agent_v1_prd.md` — Plan/Observe/Reason/Verify loop, approvals, diffs, runtime errors, compaction, persistent sessions, provider abstraction, Godot dock UI, budgets, cancellation, verification semantics  
**Architecture lock:** Agent Core stays independent; Godot bridges are pluggable via adapters. **Do not** fork godot-ai-chat as the product core.  
**Evidence date:** 2026-10-03  
**Method:** README + recursive source tree review (readonly clone of `main`). No product fork, no `agent_core` scaffolding, no MCP bridge evaluation.

**Status legend:** `present` | `partial` | `missing`

---

## Verdict (top recommendation)

1. **Do not fork early.** Treat godot-ai-chat as a *reference UX + patterns library*, not as Agent Core or the product skeleton.
2. **Own** Plan/Observe/Reason/Verify, budgets, verification semantics, task state, and provider interfaces in our independent Agent Core (language-agnostic / non-GDScript-locked).
3. **Adapt** dock UI patterns (chat stream, tool pills, inline approve diffs, todo plan strip) after bridge spike proves tool surfaces; copy UX, not the monolithic `chat_panel` ↔ `agent_loop` wiring.
4. **Study first, reuse second:** `run_and_capture` error parsing, approve/diff flow, compaction heuristic, OpenAI-compat provider registry — extract ideas or small helpers, not the plugin as a dependency.
5. **Phase 3 timing:** start Agent Executor *after* bridge spike (Phase 1–2 surfaces stable); use this plugin as a UI/loop reference during Phase 3 design, and only then selectively port UI modules.

---

## 1. Feature map vs PRD

| PRD need | Status | Evidence in godot-ai-chat | Gap vs GodotAgent |
|---|---|---|---|
| **Plan** | **partial** | `todowrite` tool + live todo strip in dock (`plan_tools.gd`, `chat_panel.gd`). Prompt nudges multi-step plans. | No structured planner module, no plan object in task state, no Observe→plan refresh semantics. Plan is LLM-side todos, not executor-owned. |
| **Observe** | **partial** | FS inspect (`read_file`/`grep`/`glob`), `get_project_info`, `get_open_scenes`, `viewport_screenshot` (vision only), `run_and_capture` stdout/stderr. | No SceneTree/node/property/resource/animation observe APIs; no runtime state inspect; no gameplay input/wait/observe. Editor viewport ≠ game viewport. |
| **Reason** | **partial** | Implicit in multi-round `agent_loop.gd` (LLM + tool results). Streams reasoning tokens when provider sends them. | No explicit reasoner stage, hypotheses, or decision records in memory. Loop is “call LLM until no tools,” not PORV. |
| **Verify** | **partial** | Prompt-mandated `check_scripts` after edits; `run_and_capture` for runtime errors; mutating tools return success/error strings. | No verifier module, no success-criteria checks, no “don’t trust edits” gate in the executor. Done = model stops calling tools (after compile check prompt), not verified task completion. |
| **Approvals** | **present** | Approve mode; mutating tools await Accept/Reject; `_needs_approval` allowlist (`agent_loop.gd`). | Coarser than PRD autonomy levels (ask-all / normal / all + always-ask destructive). Binary mode only. |
| **Diffs** | **present** | Inline line diff in `tool_call_view.gd`; full before/after dialog `diff_dialog.gd` for `write_file`/`edit_file`. | Scene/node/resource diffs absent; change ledger / Changes tab not modeled. |
| **Runtime errors** | **present** (narrow) | `run_and_capture`: separate Godot process + `--quit-after`, parse ERROR/WARNING/SCRIPT ERROR + backtrace (`godot_tools.gd`). | No live debugger bridge, no interactive playtest errors while agent drives input; timeboxed passive run only (1–30s). |
| **Compaction** | **partial** | `compactor.gd`: char/4 token estimate, threshold × context window, LLM summarize + keep last 6 msgs + preserve write/edit tool lines. | Does not preserve PRD working memory (plan, hypotheses, verification results, checkpoints) as first-class fields—only chat history. |
| **Persistent sessions** | **partial** | `session_store.gd` → `user://ai_copilot/session.json`; survives editor restart. | Single global session; no per-task checkpoints; images stripped; no task lifecycle persistence. |
| **Provider abstraction** | **partial** | `providers.gd`: 15+ OpenAI-compatible profiles; `llm_client.gd` + SSE; fetch `/models`. | Locked to OpenAI chat-completions shape in GDScript. No native Anthropic/Google APIs; not a portable Agent Core provider interface. |
| **Godot dock UI** | **present** | Right dock: toolbar, streaming chat, markdown/code highlight, tool call groups, todo panel, composer, settings (`ui/*`, `plugin.gd`). | Missing PRD panes: Activity / Changes / Tests as first-class tabs; UI owns agent loop (tight coupling). |
| **Budgets** | **partial** | Hard `SAFETY_STEP_CAP` (50); last-step “summarize, no tools” prompt; `max_tokens` setting. | No PRD budgets: max_iterations / tool_calls / mutations / playtests / runtime_minutes as configurable task limits with user intervention. |
| **Cancellation** | **partial** | Stop button → `request_stop()`; checked between steps/tools; approval wait aborts on stop. | Does not cancel in-flight HTTP/SSE or blocking `OS.execute` (`run_and_capture`/`run_command`). Incomplete PRD cancel chain. |
| **Verification semantics** | **missing** | Prompt heuristics only (“check_scripts then done”; run_and_capture optional by model). | No executor-enforced verify stage, criteria, rollback-on-fail, or iterate-until-verified. |
| **Agent Core independence** | **missing** (anti-pattern) | Loop, tools, LLM, UI, sessions all live in one EditorPlugin package. | Forking would embed product core inside Godot GDScript UI—violates architecture lock. |
| **Pluggable Godot bridges** | **missing** | Tools call `EditorInterface` / `ProjectSettings` / `OS.execute` directly from tool modules. | No adapter boundary; tools *are* the bridge. |

### Built-in tools (inventory)

`read_file` · `list_files` · `glob` · `grep` · `write_file` · `edit_file` · `delete_file` · `rename_file` · `run_command` · `create_scene` · `add_node` · `run_scene` · `run_project` · `stop_project` · `run_and_capture` · `open_script` · `get_open_scenes` · `check_scripts` · `viewport_screenshot` · `project_get_setting` · `project_set_setting` · `project_add_input_action` · `get_project_info` · `todowrite`

Useful for ideas; insufficient vs PRD bridge surface (scene hierarchy, node props, animation, playtest input, runtime inspect).

---

## 2. Own / Reuse / Adapt

| Area | Decision | Rationale |
|---|---|---|
| **Plan → Observe → Reason → Verify executor** | **Own** | Their loop is tool-call-until-text. PRD needs staged iteration, verification gates, budgets, and failure policies owned by Agent Core—not a GDScript chat plugin. |
| **Task state / memory / checkpoints** | **Own** | Session JSON is chat history only. PRD memory must survive compaction with plan, decisions, verification results. |
| **Budgets & cancellation policy** | **Own** | Extend beyond step cap + soft stop. Need multi-axis budgets and cancel through LLM + tools + runtime. Study their stop flag as a *pattern*. |
| **Verification semantics** | **Own** | Must be executor-enforced. Their prompt + `check_scripts` is a useful *prompt pattern*, not product semantics. |
| **Provider interface (Agent Core)** | **Own** | Define portable provider API (streaming, tools, multimodal, usage). Their OpenAI-compat registry is inspiration only. |
| **Godot bridge adapters** | **Own** (pluggable) | Keep bridges outside Agent Core. Do not absorb their direct `EditorInterface` tool bodies as the bridge architecture. |
| **Approve + inline diff UX** | **Adapt** | Strong product-fit UX. Port behavior (approve gate + before/after for mutations) into our dock; reimplement against our tool gateway events, not their `ToolCall` types. |
| **Chat dock / streaming / tool pills / plan strip** | **Adapt** | Best-in-class reference for Godot EditorPlugin dock feel. Rebuild against our event model after Phase 3 starts; avoid copying `chat_panel.gd`’s all-in-one orchestration. |
| **`run_and_capture` error parsing** | **Adapt** (or extract algorithm) | High-value for early runtime diagnostics. Reimplement behind `runtime_bridge` / diagnostics adapter; keep `--quit-after` + stderr parse as a *bridge strategy*, not Agent Core. |
| **`check_scripts` compile diagnostics** | **Adapt** | Good Phase 2 verification primitive. Wire through diagnostics bridge; executor mandates verify, not only system prompt. |
| **Compaction (summarize + preserve edits)** | **Adapt** | Threshold + tail-keep + preserve mutations is a solid heuristic. Reimplement to preserve PRD structured memory fields. |
| **Provider catalog / settings UX** | **Adapt** | `providers.gd` + settings Connection/Advanced tabs are good UX references for multi-provider setup. |
| **`tool_registry` + public register API** | **Adapt** | Clean registration pattern (`api.gd` / `Engine` meta). Mirror as Tool Gateway registration in our design—without binding Core to GDScript Callables. |
| **FS sandbox (`res://`, self-block plugin path)** | **Adapt** | Good safety defaults to mirror in mutation policy. |
| **Monolithic plugin as product base** | **Do not reuse / do not fork** | Couples UI + loop + tools + LLM into one EditorPlugin. Conflicts with independent Agent Core + pluggable bridges. |
| **Scene/node/animation/playtest depth** | **Own** (via bridges) | Largely absent here; covered by our bridge roadmap / other spikes—not by forking this repo. |

---

## 3. Coupling risks if we fork early

| Risk | Why it bites |
|---|---|
| **Core trapped in GDScript EditorPlugin** | Agent loop, providers, compaction, and sessions live under `addons/ai_copilot/core/` and are constructed by `chat_panel.gd`. Forking makes “Agent Core” an editor UI concern. |
| **Tools = bridges = product semantics** | `godot_tools.gd` / `editor_tools.gd` call engine APIs directly. No adapter seam → hard to swap MCP/native bridges or test Core headlessly. |
| **False PORV confidence** | README “plans, acts, checks” maps to todowrite + optional tools, not executor Verify. Forking early freezes weak verification into the product spine. |
| **Budget/cancel incomplete under load** | Blocking `OS.execute` and uncancellable HTTP mean Stop feels safe but isn’t. Inherited as product debt. |
| **Provider lock-in** | Everything assumes OpenAI tool-call JSON. Native provider features and non-GDScript Core clients become awkward. |
| **UI owns orchestration** | Approvals, compaction, session save, registry, and loop lifecycle are UI responsibilities. Refactoring to Core↔UI events becomes a rewrite anyway—cost of fork with little leverage. |
| **Shallow Godot model** | File-centric tools + thin scene helpers won’t satisfy PRD observe/mutate depth; fork creates parallel rewrites while carrying unused coupling. |
| **License is fine (MIT); architecture is not** | Legal reuse is easy; structural reuse as core is the real hazard. |

---

## 4. Recommendation for Phase 3 timing (after bridge spike)

PRD phases: Phase 1–2 = bridges + script/diagnostics; **Phase 3 = Agent Executor** (plan/observe/reason/tool/verify/iteration/budgets/cancellation); Phase 4 = runtime/playtest.

| When | Action toward godot-ai-chat |
|---|---|
| **Now → end of bridge spike** | Reference only. Do **not** vendor/fork into the product tree. Keep studying modules below; align bridge spike tool events so a future dock can show approve/diff/activity. |
| **Bridge spike exit criteria** | Stable adapter surface for inspect/mutate/diagnostics (at least script + scene basics). Then Phase 3 can define tool gateway contracts without inheriting this plugin’s tool list. |
| **Phase 3 kickoff** | Design our executor (PORV, budgets, cancel, verify). Use godot-ai-chat as **UX/loop reference**. Prototype dock wiring to *our* Core events—optionally port UI patterns (diff, tool pills, todo strip). |
| **Phase 3 mid** | Selectively **adapt** compaction + approval UX; implement providers in Core (inspired by `providers.gd`, not copied as Core). |
| **Phase 4** | Reimplement `run_and_capture`-class diagnostics behind runtime bridge; add true playtest observe (beyond this plugin). |
| **Never** | Replace Agent Core with `agent_loop.gd` or ship `addons/ai_copilot` as the product. |

**Phase 3 gate:** After bridge spike, not before—otherwise we either fork their tools as a fake bridge or build an executor with no real Observe/Verify surfaces.

---

## 5. Concrete modules worth studying first

Priority order for reading (paths relative to repo root):

| Priority | Path | Why study |
|---|---|---|
| 1 | `addons/ai_copilot/core/agent_loop.gd` | Approve wait, stop flag, max-steps behavior, tool result → history. Contrast with PORV; steal control-flow ideas only. |
| 2 | `addons/ai_copilot/ui/tool_call_view.gd` | Inline approve + line diff UX (highest UI reuse value). |
| 3 | `addons/ai_copilot/ui/diff_dialog.gd` | Full before/after presentation. |
| 4 | `addons/ai_copilot/core/tools/godot_tools.gd` | `run_and_capture` + `_parse_runtime_errors` — best runtime-error recipe in-repo. |
| 5 | `addons/ai_copilot/core/tools/editor_tools.gd` | `check_scripts` compile diagnostics pattern. |
| 6 | `addons/ai_copilot/core/compactor.gd` | Threshold, summarize, preserve mutation tools. |
| 7 | `addons/ai_copilot/core/providers.gd` + `core/llm_client.gd` + `core/sse_stream.gd` | Multi-provider OpenAI-compat + streaming edge cases. |
| 8 | `addons/ai_copilot/ui/chat_panel.gd` | How dock wires loop/session/compact/approve (know what **not** to copy wholesale). |
| 9 | `addons/ai_copilot/core/tools/plan_tools.gd` + todo UI in `chat_panel.gd` | Lightweight plan strip UX. |
| 10 | `addons/ai_copilot/core/session_store.gd` + `core/settings.gd` + `core/salt.gd` | Persistence and settings hygiene (XOR’d key storage). |
| 11 | `addons/ai_copilot/core/tool_registry.gd` + `api.gd` | Extensible tool registration API. |
| 12 | `addons/ai_copilot/core/repo_context.gd` | System-prompt scaffolding (verify-after-edit instructions). |
| 13 | `addons/ai_copilot/core/tools/fs_tools.gd` | Sandboxed edit/write semantics. |
| 14 | `addons/ai_copilot/plugin.gd` | Minimal EditorPlugin dock bootstrap. |

### Source layout (reference)

```text
addons/ai_copilot/
├── plugin.gd / plugin.cfg / api.gd
├── compat/streaming_strategy.gd
├── core/
│   ├── agent_loop.gd, compactor.gd, session_store.gd
│   ├── llm_client.gd, llm_types.gd, providers.gd, sse_stream.gd
│   ├── tool_registry.gd, repo_context.gd, settings.gd, constants.gd
│   ├── syntax/ (md_to_bbcode, gdscript_highlighter)
│   └── tools/ (fs, shell, editor, godot, project, plan)
└── ui/ (chat_panel, chat_message, tool_call_view, diff_dialog,
         composer, toolbar, settings_dialog)
```

---

## Appendix: Architecture lock check

| Lock | godot-ai-chat posture | Our stance |
|---|---|---|
| Agent Core independent | Violated if forked as core | **Own Core**; consume UI/bridge patterns only |
| Godot bridges pluggable via adapters | Tools hard-wired to editor APIs | **Own adapters**; optionally reimplement their algorithms behind adapters |
| Not blindly forking as product core | N/A | **Confirmed: no fork into product yet** |

---

*End of spike deliverable. No product code or `agent_core` scaffold produced.*
