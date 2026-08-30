#!/usr/bin/env python3
"""
Robot Alshifa — WebSocket Command Server
=========================================
A simple test server that you can use to push commands to the
tablet over WebSocket. The tablet connects TO this server as a client.

This is an alternative mode where the backend hosts the WebSocket server
and the tablet connects to it (vs the tablet hosting the server).

Usage:
    python3 ws_server.py

Then in the Flutter app, set the WS URL to:
    ws://<this-machine-ip>:8081/robot
"""

import asyncio
import json
import websockets
from websockets.server import serve


CLIENTS = set()


async def handler(websocket):
    """Handle a tablet client connection."""
    CLIENTS.add(websocket)
    client_addr = websocket.remote_address
    print(f"[+] Tablet connected from {client_addr} ({len(CLIENTS)} clients)")

    try:
        async for message in websocket:
            try:
                data = json.loads(message)
                print(f"[Tablet→Server] {json.dumps(data)}")

                # Handle pings
                if data.get("type") == "ping":
                    await websocket.send(json.dumps({"type": "pong"}))

            except json.JSONDecodeError:
                print(f"[!] Invalid JSON from tablet: {message}")

    except websockets.exceptions.ConnectionClosed:
        pass
    finally:
        CLIENTS.remove(websocket)
        print(f"[-] Tablet disconnected ({len(CLIENTS)} clients)")


async def broadcast(command: dict):
    """Send a command to all connected tablet clients."""
    if not CLIENTS:
        return
    msg = json.dumps(command)
    await asyncio.gather(*[c.send(msg) for c in CLIENTS], return_exceptions=True)


async def command_input():
    """Read commands from stdin and broadcast to tablets."""
    print("\nServer ready. Type commands to send to all connected tablets.")
    print("Examples: happy, sad, talking, blink, look left, speak Hello robot\n")

    emotion_list = [
        "neutral", "happy", "excited", "sad", "angry",
        "confused", "surprised", "sleepy", "love",
        "thinking", "talking", "listening", "error", "sleep"
    ]

    loop = asyncio.get_event_loop()

    while True:
        try:
            line = await loop.run_in_executor(None, input, "server> ")
            line = line.strip().lower()

            if line in ("quit", "exit"):
                break
            elif line in emotion_list:
                await broadcast({"type": "emotion", "emotion": line})
                print(f"→ emotion: {line}")
            elif line == "blink":
                await broadcast({"type": "blink"})
            elif line.startswith("look "):
                direction = line[5:].strip()
                await broadcast({"type": "look", "direction": direction})
            elif line.startswith("speak "):
                text = line[6:]
                await broadcast({"type": "speech", "text": text})
            elif line in ("talking on", "talk on"):
                await broadcast({"type": "talk", "enabled": True})
            elif line in ("talking off", "talk off"):
                await broadcast({"type": "talk", "enabled": False})
            elif line == "reset":
                await broadcast({"type": "reset"})
            elif line == "status":
                print(f"Connected clients: {len(CLIENTS)}")
            elif line == "demo":
                await run_demo()
            else:
                print("Unknown command. Emotions, blink, look <dir>, speak <text>, demo, status, quit")

        except (EOFError, KeyboardInterrupt):
            break


async def run_demo():
    """Run an automatic demo sequence."""
    sequence = [
        ("emotion", {"emotion": "happy"}, 2.0),
        ("emotion", {"emotion": "excited"}, 2.0),
        ("look",    {"direction": "left"},  1.0),
        ("look",    {"direction": "right"}, 1.0),
        ("look",    {"direction": "center"}, 0.5),
        ("blink",   {},                     0.5),
        ("emotion", {"emotion": "thinking"}, 2.0),
        ("emotion", {"emotion": "confused"}, 1.5),
        ("emotion", {"emotion": "surprised"}, 1.5),
        ("emotion", {"emotion": "sad"},     1.5),
        ("emotion", {"emotion": "love"},    2.0),
        ("speech",  {"text": "Hello world!"}, 3.0),
        ("emotion", {"emotion": "neutral"}, 1.0),
    ]

    print("Running demo...")
    for cmd_type, extra, delay in sequence:
        cmd = {"type": cmd_type, **extra}
        await broadcast(cmd)
        print(f"  → {json.dumps(cmd)}")
        await asyncio.sleep(delay)
    print("Demo complete.")


async def main():
    host = "0.0.0.0"
    port = 8081

    print(f"Robot Alshifa WebSocket Server")
    print(f"================================")
    print(f"Listening on ws://{host}:{port}/robot")
    print(f"Configure the Flutter app to connect to:")
    print(f"  ws://<THIS-MACHINE-IP>:{port}/robot\n")

    async with serve(handler, host, port, subprotocols=[]):
        await command_input()


if __name__ == "__main__":
    asyncio.run(main())
