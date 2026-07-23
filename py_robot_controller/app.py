"""Pygame implementation of the Robot Controller application.

Run this module directly, enter the robot's UDP endpoint, and press Enter to
connect. Press Escape at any time to open the connection panel.
"""

from __future__ import annotations

import json
import math
import socket
import struct
import time
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable

import pygame


WINDOW_SIZE = (800, 600)
PIXELS_PER_METER = 160.0
GRID_SPACING = 0.5
ROBOT_WIDTH = 0.18
ROBOT_LENGTH = 0.30
ROBOT_COLOR = pygame.Color("lawngreen")
CONFIG_PATH = Path(__file__).with_name("robot_connection.json")


def clamp(value: float, minimum: float, maximum: float) -> float:
    return max(minimum, min(value, maximum))


@dataclass(frozen=True)
class Vec2:
    x: float = 0.0
    y: float = 0.0

    def __add__(self, other: "Vec2") -> "Vec2":
        return Vec2(self.x + other.x, self.y + other.y)

    def __sub__(self, other: "Vec2") -> "Vec2":
        return Vec2(self.x - other.x, self.y - other.y)

    def __mul__(self, scalar: float) -> "Vec2":
        return Vec2(self.x * scalar, self.y * scalar)

    def distance_to(self, other: "Vec2") -> float:
        return math.hypot(self.x - other.x, self.y - other.y)

    def rotated(self, angle: float) -> "Vec2":
        cosine, sine = math.cos(angle), math.sin(angle)
        return Vec2(self.x * cosine - self.y * sine, self.x * sine + self.y * cosine)


class OccupancyMap:
    """A log-odds occupancy grid updated from a narrow sonar fan."""

    CELL_SIZE = 0.05
    WIDTH = 480
    HEIGHT = 480
    SONAR_MAX_RANGE = 4.0
    SONAR_HALF_FOV = math.radians(3.0)
    OCCUPIED_HALF_FOV = math.radians(3.0)
    OCCUPIED_BAND = 0.08
    OCCUPIED_UPDATE = 2.0
    FREE_UPDATE = -0.8
    MIN_LOG_ODDS = -5.0
    MAX_LOG_ODDS = 5.0

    def __init__(self) -> None:
        self.origin = Vec2(-self.WIDTH * self.CELL_SIZE * 0.5, -self.HEIGHT * self.CELL_SIZE * 0.5)
        self._values = [0.0] * (self.WIDTH * self.HEIGHT)

    def integrate(self, distance: float, robot_position: Vec2, heading: float) -> set[tuple[int, int]]:
        if distance <= 0.0:
            return set()
        has_obstacle = distance <= self.SONAR_MAX_RANGE
        scan_range = distance if has_obstacle else self.SONAR_MAX_RANGE
        changed: set[tuple[int, int]] = set()
        ray_count = max(1, math.ceil(scan_range * self.SONAR_HALF_FOV * 2.0 / self.CELL_SIZE))
        start = self.world_to_cell(robot_position)
        forward = Vec2(math.sin(heading), -math.cos(heading))
        for ray in range(ray_count + 1):
            angle = self._lerp(-self.SONAR_HALF_FOV, self.SONAR_HALF_FOV, ray / ray_count)
            end = self.world_to_cell(robot_position + forward.rotated(angle) * scan_range)
            self._stamp_ray(start, end, scan_range, has_obstacle, abs(angle) <= self.OCCUPIED_HALF_FOV, robot_position, changed)
        return changed

    def shade_at(self, cell: tuple[int, int]) -> int:
        value = self._values[cell[1] * self.WIDTH + cell[0]]
        probability = 1.0 / (1.0 + math.exp(-value))
        return round((1.0 - probability) * 255.0)

    def world_to_cell(self, point: Vec2) -> tuple[int, int]:
        return (
            math.floor((point.x - self.origin.x) / self.CELL_SIZE),
            math.floor((point.y - self.origin.y) / self.CELL_SIZE),
        )

    def cell_to_world(self, cell: tuple[int, int]) -> Vec2:
        return self.origin + Vec2(cell[0] + 0.5, cell[1] + 0.5) * self.CELL_SIZE

    def _stamp_ray(self, start: tuple[int, int], end: tuple[int, int], distance: float, has_obstacle: bool, central: bool, robot_position: Vec2, changed: set[tuple[int, int]]) -> None:
        for cell in self._line_cells(start, end):
            is_end_band = robot_position.distance_to(self.cell_to_world(cell)) >= distance - self.OCCUPIED_BAND
            if has_obstacle and is_end_band:
                if central:
                    self._update_cell(cell, self.OCCUPIED_UPDATE, changed)
            else:
                self._update_cell(cell, self.FREE_UPDATE, changed)

    def _update_cell(self, cell: tuple[int, int], update: float, changed: set[tuple[int, int]]) -> None:
        x, y = cell
        if not (0 <= x < self.WIDTH and 0 <= y < self.HEIGHT):
            return
        index = y * self.WIDTH + x
        self._values[index] = clamp(self._values[index] + update, self.MIN_LOG_ODDS, self.MAX_LOG_ODDS)
        changed.add(cell)

    @staticmethod
    def _line_cells(start: tuple[int, int], end: tuple[int, int]) -> Iterable[tuple[int, int]]:
        x, y = start
        end_x, end_y = end
        delta_x, delta_y = abs(end_x - x), -abs(end_y - y)
        step_x = 1 if x < end_x else -1
        step_y = 1 if y < end_y else -1
        error = delta_x + delta_y
        while True:
            yield x, y
            if (x, y) == (end_x, end_y):
                return
            doubled_error = 2 * error
            if doubled_error >= delta_y:
                error += delta_y
                x += step_x
            if doubled_error <= delta_x:
                error += delta_x
                y += step_y

    @staticmethod
    def _lerp(start: float, end: float, weight: float) -> float:
        return start + (end - start) * weight


class PoseEstimator:
    MAX_SPEED = 6.0 / 21.23
    MAX_TURN_RATE = 20.0 * math.pi / 31.85

    def __init__(self) -> None:
        self.robot_position = Vec2()
        self.heading = 0.0

    def update(self, direction: Vec2, delta: float) -> None:
        self.heading = (self.heading + direction.x * self.MAX_TURN_RATE * delta + math.pi) % (2 * math.pi) - math.pi
        self.robot_position = self.robot_position + self.forward_direction() * (-direction.y * self.MAX_SPEED * delta)

    def forward_direction(self) -> Vec2:
        return Vec2(math.sin(self.heading), -math.cos(self.heading))


class UdpRobot:
    # Keep the robot watchdog fed while limiting UDP traffic to 6 Hz.
    CONTROL_PERIOD = 1.0 / 6.0
    MOTOR_LIMIT = 255

    def __init__(self, address: str, port: int) -> None:
        self.socket = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        self.socket.setblocking(False)
        self.address = (address, port)
        self.elapsed = self.CONTROL_PERIOD
        self.previous_direction = Vec2()

    def update(self, direction: Vec2, delta: float) -> float | None:
        self.elapsed += delta
        if direction != self.previous_direction or self.elapsed >= self.CONTROL_PERIOD:
            forward, turn = -direction.y, direction.x
            left = round(clamp(forward + turn, -1.0, 1.0) * self.MOTOR_LIMIT)
            right = round(clamp(forward - turn, -1.0, 1.0) * self.MOTOR_LIMIT)
            self.socket.sendto(struct.pack("<ii", left, right), self.address)
            self.previous_direction, self.elapsed = direction, 0.0
        latest = None
        while True:
            try:
                packet, _ = self.socket.recvfrom(1024)
            except BlockingIOError:
                return latest
            if len(packet) >= 4:
                latest = struct.unpack_from("<f", packet)[0]

    def close(self) -> None:
        self.socket.sendto(struct.pack("<ii", 0, 0), self.address)
        self.socket.close()


class RobotSession:
    def __init__(self, backend: UdpRobot) -> None:
        self.backend = backend
        self.pose = PoseEstimator()
        self.map = OccupancyMap()
        self.last_distance = -1.0

    def process(self, direction: Vec2, delta: float) -> set[tuple[int, int]]:
        self.pose.update(direction, delta)
        distance = self.backend.update(direction, delta)
        if distance is None:
            return set()
        self.last_distance = distance
        return self.map.integrate(distance, self.pose.robot_position, self.pose.heading)

    def close(self) -> None:
        self.backend.close()


class App:
    def __init__(self) -> None:
        pygame.init()
        pygame.display.set_caption("Robot Controller (Python)")
        self.screen = pygame.display.set_mode(WINDOW_SIZE)
        self.clock = pygame.time.Clock()
        self.font = pygame.font.Font(None, 20)
        self.small_font = pygame.font.Font(None, 17)
        self.running = True
        self.show_panel = True
        self.address, self.port = self._load_connection()
        self.focused_field = 0
        self.message = "Enter the UDP robot address and port."
        self.map = OccupancyMap()
        self.session: RobotSession | None = None
        self.map_surface = pygame.Surface((OccupancyMap.WIDTH, OccupancyMap.HEIGHT))
        self.map_surface.fill((128, 128, 128))

    def run(self) -> None:
        while self.running:
            delta = min(self.clock.tick(60) / 1000.0, 0.1)
            self._handle_events()
            if not self.show_panel and self.session is not None:
                changed = self.session.process(self._direction(), delta)
                self._update_map_surface(changed)
            self._draw()
        if self.session is not None:
            self.session.close()
        pygame.quit()

    def _handle_events(self) -> None:
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                self.running = False
            elif event.type == pygame.KEYDOWN:
                if event.key == pygame.K_ESCAPE:
                    self.show_panel = not self.show_panel
                elif self.show_panel:
                    self._handle_panel_key(event)

    def _handle_panel_key(self, event: pygame.event.Event) -> None:
        if event.key == pygame.K_TAB:
            self.focused_field = (self.focused_field + 1) % 2
        elif event.key == pygame.K_RETURN:
            self._connect()
        elif event.key == pygame.K_BACKSPACE:
            if self.focused_field == 0:
                self.address = self.address[:-1]
            elif self.focused_field == 1:
                self.port = self.port[:-1]
        elif event.unicode:
            if self.focused_field == 0 and event.unicode.isprintable():
                self.address += event.unicode
            elif self.focused_field == 1 and event.unicode.isdigit():
                self.port += event.unicode

    def _connect(self) -> None:
        try:
            port = int(self.port)
            if not (self.address and 1 <= port <= 65535):
                raise ValueError
            if self.session is not None:
                self.session.close()
            self.session = RobotSession(UdpRobot(self.address, port))
            self.map = self.session.map
            self.map_surface.fill((128, 128, 128))
            self._save_connection()
            self.message = f"UDP target: {self.address}:{port}"
            self.show_panel = False
        except (ValueError, OSError) as error:
            self.message = f"Could not connect: {error}"

    def _direction(self) -> Vec2:
        keys = pygame.key.get_pressed()
        return Vec2(float(keys[pygame.K_RIGHT] or keys[pygame.K_d]) - float(keys[pygame.K_LEFT] or keys[pygame.K_a]), float(keys[pygame.K_DOWN] or keys[pygame.K_s]) - float(keys[pygame.K_UP] or keys[pygame.K_w]))

    def _update_map_surface(self, changed: Iterable[tuple[int, int]]) -> None:
        if self.session is None:
            return
        for cell in changed:
            shade = self.session.map.shade_at(cell)
            self.map_surface.set_at(cell, (shade, shade, shade))

    def _world_to_screen(self, point: Vec2) -> tuple[float, float]:
        position = self.session.pose.robot_position if self.session is not None else Vec2()
        return WINDOW_SIZE[0] * 0.5 + (point.x - position.x) * PIXELS_PER_METER, WINDOW_SIZE[1] * 0.5 + (point.y - position.y) * PIXELS_PER_METER

    def _draw(self) -> None:
        self.screen.fill((20, 20, 20))
        self._draw_map()
        self._draw_grid()
        self._draw_robot()
        self._draw_hud()
        if self.show_panel:
            self._draw_panel()
        pygame.display.flip()

    def _draw_map(self) -> None:
        map_origin = self._world_to_screen(self.map.origin)
        size = round(OccupancyMap.WIDTH * OccupancyMap.CELL_SIZE * PIXELS_PER_METER)
        self.screen.blit(pygame.transform.scale(self.map_surface, (size, size)), map_origin)

    def _draw_grid(self) -> None:
        position = self.session.pose.robot_position if self.session is not None else Vec2()
        top_left = Vec2(position.x - WINDOW_SIZE[0] * 0.5 / PIXELS_PER_METER, position.y - WINDOW_SIZE[1] * 0.5 / PIXELS_PER_METER)
        first_x = math.floor(top_left.x / GRID_SPACING) * GRID_SPACING
        first_y = math.floor(top_left.y / GRID_SPACING) * GRID_SPACING
        color = (60, 60, 60)
        x = first_x
        while self._world_to_screen(Vec2(x, 0))[0] <= WINDOW_SIZE[0]:
            screen_x = round(self._world_to_screen(Vec2(x, 0))[0])
            pygame.draw.line(self.screen, color, (screen_x, 0), (screen_x, WINDOW_SIZE[1]))
            x += GRID_SPACING
        y = first_y
        while self._world_to_screen(Vec2(0, y))[1] <= WINDOW_SIZE[1]:
            screen_y = round(self._world_to_screen(Vec2(0, y))[1])
            pygame.draw.line(self.screen, color, (0, screen_y), (WINDOW_SIZE[0], screen_y))
            y += GRID_SPACING

    def _draw_robot(self) -> None:
        center = Vec2(WINDOW_SIZE[0] * 0.5, WINDOW_SIZE[1] * 0.5)
        heading = self.session.pose.heading if self.session is not None else 0.0
        forward = Vec2(math.sin(heading), -math.cos(heading))
        side = Vec2(-forward.y, forward.x)
        half_length, half_width = ROBOT_LENGTH * PIXELS_PER_METER * 0.5, ROBOT_WIDTH * PIXELS_PER_METER * 0.5
        corners = [center + forward * half_length + side * half_width, center + forward * half_length - side * half_width, center - forward * half_length - side * half_width, center - forward * half_length + side * half_width]
        points = [(point.x, point.y) for point in corners]
        pygame.draw.lines(self.screen, ROBOT_COLOR, True, points, 2)
        nose = center + forward * (half_length + half_width * 0.6)
        pygame.draw.lines(self.screen, ROBOT_COLOR, False, [points[0], (nose.x, nose.y), points[1]], 2)

    def _draw_hud(self) -> None:
        distance = "Dist: --" if self.session is None or self.session.last_distance < 0.0 else f"Dist: {self.session.last_distance:.2f}m"
        pose = self.session.pose if self.session is not None else PoseEstimator()
        angle = math.degrees(pose.heading)
        self.screen.blit(self.font.render(distance, True, (220, 220, 220)), (8, WINDOW_SIZE[1] - 42))
        self.screen.blit(self.small_font.render(f"x={pose.robot_position.x:.2f} y={pose.robot_position.y:.2f} {angle:.0f}°", True, (160, 160, 160)), (8, WINDOW_SIZE[1] - 22))
        self.screen.blit(self.small_font.render("WASD / arrows: drive    Esc: connection", True, (200, 200, 200)), (8, 8))

    def _draw_panel(self) -> None:
        overlay = pygame.Surface(WINDOW_SIZE, pygame.SRCALPHA)
        overlay.fill((0, 0, 0, 100))
        self.screen.blit(overlay, (0, 0))
        panel = pygame.Rect(190, 190, 420, 220)
        pygame.draw.rect(self.screen, (35, 35, 40), panel, border_radius=8)
        pygame.draw.rect(self.screen, (130, 130, 140), panel, 1, border_radius=8)
        self._draw_field("IP address", self.address, 0, 225)
        self._draw_field("UDP port", self.port, 1, 275)
        self.screen.blit(self.font.render("Enter: connect     Tab: select     Esc: close", True, (190, 190, 190)), (225, 335))
        self.screen.blit(self.small_font.render(self.message, True, (150, 220, 150) if not self.message.startswith("Could not") else (255, 150, 150)), (225, 365))

    def _draw_field(self, label: str, value: str, index: int, top: int) -> None:
        self.screen.blit(self.font.render(label, True, (210, 210, 210)), (225, top))
        rect = pygame.Rect(330, top - 5, 240, 30)
        pygame.draw.rect(self.screen, (20, 20, 24), rect)
        pygame.draw.rect(self.screen, (110, 190, 255) if self.focused_field == index else (100, 100, 110), rect, 2 if self.focused_field == index else 1)
        suffix = "|" if self.focused_field == index and int(time.monotonic() * 2) % 2 == 0 else ""
        self.screen.blit(self.font.render(value + suffix, True, (240, 240, 240)), (337, top + 1))

    @staticmethod
    def _load_connection() -> tuple[str, str]:
        try:
            settings = json.loads(CONFIG_PATH.read_text(encoding="utf-8"))
            return str(settings.get("address", "10.119.23.109")), str(settings.get("port", 1240))
        except (OSError, json.JSONDecodeError):
            return "10.119.23.109", "1240"

    def _save_connection(self) -> None:
        CONFIG_PATH.write_text(json.dumps({"address": self.address, "port": int(self.port)}, indent=2), encoding="utf-8")


if __name__ == "__main__":
    App().run()
