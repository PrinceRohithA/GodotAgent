"""Abstract Godot tool interface and capability registry.

Agent Core depends only on these abstractions — never on a specific bridge.
"""

from tools.abstract import AbstractGodotTools
from tools.registry import CapabilityRegistry
from tools.schemas import ToolRisk, ToolResult, ToolStatus

__all__ = [
    "AbstractGodotTools",
    "CapabilityRegistry",
    "ToolRisk",
    "ToolResult",
    "ToolStatus",
]
