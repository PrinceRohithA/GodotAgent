"""Configurable per-task budgets (PRD §49)."""

from __future__ import annotations

from dataclasses import dataclass


@dataclass
class AgentBudgets:
    max_iterations: int = 30
    max_tool_calls: int = 100
    max_mutations: int = 50
    max_playtests: int = 10
    max_runtime_minutes: float = 10.0

    # Counters (mutated by the executor).
    iterations_used: int = 0
    tool_calls_used: int = 0
    mutations_used: int = 0
    playtests_used: int = 0
    runtime_seconds_used: float = 0.0

    def record_iteration(self) -> None:
        self.iterations_used += 1

    def record_tool_call(self, *, is_mutation: bool = False, is_playtest: bool = False) -> None:
        self.tool_calls_used += 1
        if is_mutation:
            self.mutations_used += 1
        if is_playtest:
            self.playtests_used += 1

    def record_runtime(self, seconds: float) -> None:
        self.runtime_seconds_used += max(0.0, seconds)

    def exhausted(self) -> bool:
        return bool(self.exhaustion_reason())

    def exhaustion_reason(self) -> str | None:
        if self.iterations_used >= self.max_iterations:
            return "max_iterations"
        if self.tool_calls_used >= self.max_tool_calls:
            return "max_tool_calls"
        if self.mutations_used >= self.max_mutations:
            return "max_mutations"
        if self.playtests_used >= self.max_playtests:
            return "max_playtests"
        if self.runtime_seconds_used >= self.max_runtime_minutes * 60.0:
            return "max_runtime_minutes"
        return None

    def remaining_summary(self) -> dict[str, float | int]:
        return {
            "iterations": self.max_iterations - self.iterations_used,
            "tool_calls": self.max_tool_calls - self.tool_calls_used,
            "mutations": self.max_mutations - self.mutations_used,
            "playtests": self.max_playtests - self.playtests_used,
            "runtime_seconds": max(
                0.0, self.max_runtime_minutes * 60.0 - self.runtime_seconds_used
            ),
        }
