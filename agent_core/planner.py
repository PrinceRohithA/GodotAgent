"""Planner — produces an initial working plan (not a rigid graph).

Model provider is intentionally not wired; callers inject a plan builder
or use the heuristic stub for scaffolding / tests.
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import Optional, Protocol, Sequence

from agent_core.state import AgentState, PlanStep
from tools.registry import CapabilityRegistry


class PlanBuilder(Protocol):
    def __call__(
        self,
        goal: str,
        *,
        capabilities: CapabilityRegistry,
        project_hints: Sequence[str] = (),
    ) -> Sequence[str]: ...


def default_gdscript_plan(goal: str, *, capabilities: CapabilityRegistry, project_hints: Sequence[str] = ()) -> Sequence[str]:
    """Heuristic GDScript-first plan skeleton used until an LLM is plugged in."""
    del project_hints  # reserved for future context
    steps = [
        "Inspect project structure and relevant scenes",
        "Inspect target nodes and GDScript sources",
        "Inspect InputMap / project settings if gameplay input is involved",
        "Form implementation approach (GDScript-first)",
        "Apply coordinated edits (scripts, nodes, properties)",
    ]
    if capabilities.tool_available("animation_inspect"):
        steps.append("Inspect/configure AnimationPlayer or AnimationTree if needed")
    steps.extend(
        [
            "Verify editor/project state via Godot evidence (do not trust mutations alone)",
        ]
    )
    if capabilities.tool_available("run_game"):
        steps.extend(
            [
                "Run the game and playtest the change",
                "Observe runtime / diagnostics; fix and re-verify if needed",
            ]
        )
    steps.append(f"Confirm success criteria for: {goal}")
    return steps


@dataclass
class Planner:
    """Builds and refreshes ``AgentState.plan``."""

    plan_builder: PlanBuilder = default_gdscript_plan

    def create_plan(
        self,
        state: AgentState,
        capabilities: CapabilityRegistry,
        project_hints: Sequence[str] = (),
    ) -> AgentState:
        descriptions = list(
            self.plan_builder(
                state.goal,
                capabilities=capabilities,
                project_hints=project_hints,
            )
        )
        state.plan = [
            PlanStep(index=i, description=desc) for i, desc in enumerate(descriptions, start=1)
        ]
        if state.plan:
            state.next_action = state.plan[0].description
        return state

    def mark_step_done(self, state: AgentState, index: int, notes: str = "") -> None:
        for step in state.plan:
            if step.index == index:
                step.done = True
                if notes:
                    step.notes = notes
                break
        pending = next((s for s in state.plan if not s.done), None)
        state.next_action = pending.description if pending else "verify and finalize"

    def revise(
        self,
        state: AgentState,
        new_steps: Sequence[str],
        *,
        replace_from: Optional[int] = None,
    ) -> AgentState:
        """Append or replace trailing plan steps after a failed verification."""
        if replace_from is None:
            start = len(state.plan) + 1
            for i, desc in enumerate(new_steps):
                state.plan.append(PlanStep(index=start + i, description=desc))
        else:
            kept = [s for s in state.plan if s.index < replace_from]
            for i, desc in enumerate(new_steps):
                kept.append(PlanStep(index=replace_from + i, description=desc))
            state.plan = kept
        pending = next((s for s in state.plan if not s.done), None)
        state.next_action = pending.description if pending else "verify and finalize"
        return state
