#!/usr/bin/env python3
"""
Robot Alshifa — Example Backend Controller
==========================================
This script demonstrates how to control the robot face tablet
from a Python backend over WebSocket and REST API.

Usage:
    python3 robot_controller.py

Requirements:
    pip install websockets aiohttp

The tablet must be running the Flutter app and connected to the same network.
"""

import asyncio
import json
import time
import websockets
import aiohttp
from dataclasses import dataclass
from typing import Optional


# ─── Configuration ────────────────────────────────────────────────────────────

TABLET_IP = "192.168.1.100"       # Change to your tablet's IP
WS_PORT   = 8081
REST_PORT = 8082
WS_URL    = f"ws://{TABLET_IP}:{WS_PORT}/robot"
REST_URL  = f"http://{TABLET_IP}:{REST_PORT}/api"


# ─── Robot Face Client ────────────────────────────────────────────────────────

class RobotFaceClient:
    """High-level Python SDK for controlling the robot face tablet."""

    def __init__(self, ws_url: str = WS_URL, rest_url: str = REST_URL):
        self.ws_url   = ws_url
        self.rest_url = rest_url
        self._ws      = None
        self._session = None
        self._cmd_id  = 0

    # ── Connection ──────────────────────────────────────────────────────────

    async def connect_ws(self):
        """Connect via WebSocket (real-time, recommended)."""
        self._ws = await websockets.connect(self.ws_url)
        print(f"[Robot] WebSocket connected to {self.ws_url}")

    async def connect_rest(self):
        """Open an HTTP session for REST API calls."""
        self._session = aiohttp.ClientSession()

    async def disconnect(self):
        if self._ws:
            await self._ws.close()
        if self._session:
            await self._session.close()

    # ── Low-level Command ───────────────────────────────────────────────────

    def _next_id(self) -> str:
        self._cmd_id += 1
        return str(self._cmd_id)

    async def send(self, command: dict):
        """Send a raw JSON command via WebSocket."""
        if self._ws is None:
            raise RuntimeError("WebSocket not connected. Call connect_ws() first.")
        command.setdefault("id", self._next_id())
        await self._ws.send(json.dumps(command))

    async def post(self, path: str, body: dict) -> dict:
        """Send a REST API POST request."""
        if self._session is None:
            raise RuntimeError("HTTP session not started. Call connect_rest() first.")
        async with self._session.post(
            f"{self.rest_url}{path}",
            json=body,
            headers={"Content-Type": "application/json"},
        ) as resp:
            return await resp.json()

    async def get(self, path: str) -> dict:
        if self._session is None:
            raise RuntimeError("HTTP session not started. Call connect_rest() first.")
        async with self._session.get(f"{self.rest_url}{path}") as resp:
            return await resp.json()

    # ── High-level API ──────────────────────────────────────────────────────

    async def neutral(self):
        await self.send({"type": "emotion", "emotion": "neutral"})

    async def happy(self, duration_ms: Optional[int] = None):
        cmd = {"type": "emotion", "emotion": "happy"}
        if duration_ms: cmd["duration"] = duration_ms
        await self.send(cmd)

    async def excited(self, duration_ms: Optional[int] = None):
        cmd = {"type": "emotion", "emotion": "excited"}
        if duration_ms: cmd["duration"] = duration_ms
        await self.send(cmd)

    async def sad(self, duration_ms: Optional[int] = None):
        cmd = {"type": "emotion", "emotion": "sad"}
        if duration_ms: cmd["duration"] = duration_ms
        await self.send(cmd)

    async def angry(self, duration_ms: Optional[int] = None):
        cmd = {"type": "emotion", "emotion": "angry"}
        if duration_ms: cmd["duration"] = duration_ms
        await self.send(cmd)

    async def confused(self, duration_ms: Optional[int] = None):
        cmd = {"type": "emotion", "emotion": "confused"}
        if duration_ms: cmd["duration"] = duration_ms
        await self.send(cmd)

    async def surprised(self, duration_ms: Optional[int] = None):
        cmd = {"type": "emotion", "emotion": "surprised"}
        if duration_ms: cmd["duration"] = duration_ms
        await self.send(cmd)

    async def sleepy(self, duration_ms: Optional[int] = None):
        cmd = {"type": "emotion", "emotion": "sleepy"}
        if duration_ms: cmd["duration"] = duration_ms
        await self.send(cmd)

    async def love(self, duration_ms: Optional[int] = None):
        cmd = {"type": "emotion", "emotion": "love"}
        if duration_ms: cmd["duration"] = duration_ms
        await self.send(cmd)

    async def thinking(self):
        await self.send({"type": "state", "state": "thinking"})

    async def talking(self):
        await self.send({"type": "state", "state": "talking"})

    async def listening(self):
        await self.send({"type": "state", "state": "listening"})

    async def sleep(self):
        await self.send({"type": "state", "state": "sleeping"})

    async def error(self):
        await self.send({"type": "emotion", "emotion": "error"})

    async def blink(self):
        await self.send({"type": "blink"})

    async def look_left(self):
        await self.send({"type": "look", "direction": "left"})

    async def look_right(self):
        await self.send({"type": "look", "direction": "right"})

    async def look_up(self):
        await self.send({"type": "look", "direction": "up"})

    async def look_down(self):
        await self.send({"type": "look", "direction": "down"})

    async def look_center(self):
        await self.send({"type": "look", "direction": "center"})

    async def speak(self, text: str):
        """Trigger talking animation while external TTS speaks."""
        await self.send({"type": "speech", "text": text})

    async def start_talking(self):
        await self.send({"type": "talk", "enabled": True})

    async def stop_talking(self):
        await self.send({"type": "talk", "enabled": False})

    async def reset(self):
        await self.send({"type": "reset"})

    # ── Status ──────────────────────────────────────────────────────────────

    async def get_status(self) -> dict:
        return await self.get("/robot/status")


# ─── Demo Sequence ────────────────────────────────────────────────────────────

async def demo():
    robot = RobotFaceClient()

    print("Connecting to robot face tablet...")
    await robot.connect_ws()

    print("\n=== Running Demo Sequence ===\n")

    # Greeting
    print("→ neutral")
    await robot.neutral()
    await asyncio.sleep(1.5)

    print("→ happy")
    await robot.happy()
    await asyncio.sleep(2.0)

    print("→ excited")
    await robot.excited()
    await asyncio.sleep(2.0)

    print("→ blink x3")
    for _ in range(3):
        await robot.blink()
        await asyncio.sleep(0.5)

    print("→ thinking")
    await robot.thinking()
    await asyncio.sleep(2.5)

    print("→ look left")
    await robot.look_left()
    await asyncio.sleep(1.0)

    print("→ look right")
    await robot.look_right()
    await asyncio.sleep(1.0)

    print("→ look center")
    await robot.look_center()
    await asyncio.sleep(0.5)

    print("→ speaking...")
    await robot.speak("Hello! I am your robot assistant. How can I help you today?")
    await asyncio.sleep(4.0)

    print("→ listening")
    await robot.listening()
    await asyncio.sleep(2.5)

    print("→ confused")
    await robot.confused()
    await asyncio.sleep(2.0)

    print("→ surprised")
    await robot.surprised()
    await asyncio.sleep(2.0)

    print("→ sad")
    await robot.sad()
    await asyncio.sleep(2.0)

    print("→ love")
    await robot.love()
    await asyncio.sleep(2.0)

    print("→ angry")
    await robot.angry(duration_ms=2000)
    await asyncio.sleep(2.5)

    print("→ sleepy")
    await robot.sleepy()
    await asyncio.sleep(2.0)

    print("→ sleep")
    await robot.sleep()
    await asyncio.sleep(2.0)

    print("→ wake → neutral")
    await robot.neutral()
    await asyncio.sleep(1.0)

    print("\n=== Demo Complete ===")
    await robot.disconnect()


# ─── Interactive Shell ────────────────────────────────────────────────────────

async def interactive_shell():
    robot = RobotFaceClient()

    print("Robot Alshifa Interactive Shell")
    print("================================")
    print(f"Connecting to {WS_URL}...")

    try:
        await robot.connect_ws()
        print("Connected! Type commands (e.g. happy, sad, blink, look left, quit)\n")
    except Exception as e:
        print(f"Failed to connect: {e}")
        print("Make sure the tablet is running the Flutter app and IP is correct.")
        return

    commands = {
        "neutral": robot.neutral,
        "happy": robot.happy,
        "excited": robot.excited,
        "sad": robot.sad,
        "angry": robot.angry,
        "confused": robot.confused,
        "surprised": robot.surprised,
        "sleepy": robot.sleepy,
        "love": robot.love,
        "thinking": robot.thinking,
        "talking": robot.talking,
        "listening": robot.listening,
        "sleep": robot.sleep,
        "error": robot.error,
        "blink": robot.blink,
        "look left": robot.look_left,
        "look right": robot.look_right,
        "look up": robot.look_up,
        "look down": robot.look_down,
        "look center": robot.look_center,
        "reset": robot.reset,
    }

    while True:
        try:
            cmd = input("robot> ").strip().lower()
            if cmd in ("quit", "exit", "q"):
                break
            elif cmd.startswith("speak "):
                text = cmd[6:]
                await robot.speak(text)
                print(f"Speaking: {text}")
            elif cmd in commands:
                await commands[cmd]()
                print(f"✓ {cmd}")
            elif cmd == "status":
                # Use REST for status
                await robot.connect_rest()
                status = await robot.get_status()
                print(f"Status: {json.dumps(status, indent=2)}")
            elif cmd == "demo":
                print("Running demo...")
                await demo_sequence(robot)
            elif cmd == "help":
                print("Available commands:")
                for k in sorted(commands.keys()):
                    print(f"  {k}")
                print("  speak <text>")
                print("  status")
                print("  demo")
                print("  quit")
            else:
                print(f"Unknown command: {cmd}. Type 'help' for list.")
        except KeyboardInterrupt:
            break
        except Exception as e:
            print(f"Error: {e}")

    await robot.disconnect()
    print("Disconnected.")


async def demo_sequence(robot: RobotFaceClient):
    emotions = ["happy", "excited", "sad", "confused", "surprised", "love", "thinking", "neutral"]
    for emotion in emotions:
        print(f"  → {emotion}")
        await robot.send({"type": "emotion", "emotion": emotion})
        await asyncio.sleep(1.5)


# ─── Entry Point ─────────────────────────────────────────────────────────────

if __name__ == "__main__":
    import sys

    if len(sys.argv) > 1 and sys.argv[1] == "demo":
        asyncio.run(demo())
    else:
        asyncio.run(interactive_shell())
