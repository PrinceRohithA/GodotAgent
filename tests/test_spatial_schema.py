"""Pure geometry fixtures for SpatialObject AABB / corners (no Godot required).

Mirrors the corner→AABB logic in smoke_project/addons/godot_mcp/spatial_observe.gd.
"""

from __future__ import annotations

import math
import unittest


def transform_point(cols: list[list[float]], p: tuple[float, float]) -> tuple[float, float]:
    """Apply Transform2D columns [[xx,xy],[yx,yy],[ox,oy]] to point."""
    x = cols[0][0] * p[0] + cols[1][0] * p[1] + cols[2][0]
    y = cols[0][1] * p[0] + cols[1][1] * p[1] + cols[2][1]
    return (x, y)


def aabb_from_points(points: list[tuple[float, float]]) -> dict[str, float]:
    xs = [p[0] for p in points]
    ys = [p[1] for p in points]
    min_x, max_x = min(xs), max(xs)
    min_y, max_y = min(ys), max(ys)
    return {
        "x": min_x,
        "y": min_y,
        "width": max_x - min_x,
        "height": max_y - min_y,
    }


def rect_corners(w: float, h: float, centered: bool = True) -> list[tuple[float, float]]:
    if centered:
        hx, hy = w / 2, h / 2
        return [(-hx, -hy), (hx, -hy), (hx, hy), (-hx, hy)]
    return [(0, 0), (w, 0), (w, h), (0, h)]


def xform_rotation_scale(
    rotation_rad: float, scale: tuple[float, float], origin: tuple[float, float] = (0, 0)
) -> list[list[float]]:
    c, s = math.cos(rotation_rad), math.sin(rotation_rad)
    sx, sy = scale
    return [[c * sx, s * sx], [-s * sy, c * sy], [origin[0], origin[1]]]


class SpatialSchemaGeometryTests(unittest.TestCase):
    def test_a_axis_aligned(self) -> None:
        corners = rect_corners(100, 20)
        xform = xform_rotation_scale(0, (1, 1))
        world = [transform_point(xform, p) for p in corners]
        aabb = aabb_from_points(world)
        self.assertAlmostEqual(aabb["width"], 100, places=3)
        self.assertAlmostEqual(aabb["height"], 20, places=3)

    def test_b_rotation_90(self) -> None:
        corners = rect_corners(100, 20)
        xform = xform_rotation_scale(math.pi / 2, (1, 1))
        world = [transform_point(xform, p) for p in corners]
        aabb = aabb_from_points(world)
        self.assertAlmostEqual(aabb["width"], 20, places=3)
        self.assertAlmostEqual(aabb["height"], 100, places=3)

    def test_c_rotation_45(self) -> None:
        corners = rect_corners(100, 20)
        xform = xform_rotation_scale(math.pi / 4, (1, 1))
        world = [transform_point(xform, p) for p in corners]
        aabb = aabb_from_points(world)
        expected = 100 * math.cos(math.pi / 4) + 20 * math.sin(math.pi / 4)
        self.assertAlmostEqual(aabb["width"], expected, places=2)
        self.assertAlmostEqual(aabb["height"], expected, places=2)

    def test_d_scale(self) -> None:
        corners = rect_corners(100, 20)
        xform = xform_rotation_scale(0, (2, 1))
        world = [transform_point(xform, p) for p in corners]
        aabb = aabb_from_points(world)
        self.assertAlmostEqual(aabb["width"], 200, places=3)
        self.assertAlmostEqual(aabb["height"], 20, places=3)

    def test_unsupported_geometry_flag(self) -> None:
        # Schema contract: unsupported → available false (fixture shape).
        geom = {"available": False, "reason": "unsupported_type"}
        self.assertFalse(geom["available"])
        self.assertEqual(geom["reason"], "unsupported_type")


if __name__ == "__main__":
    unittest.main()
