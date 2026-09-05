# Robot Alshifa — Flutter Robot Face Application

<div align="center">

```
  ┌─────────────────────────────────────┐
  │  ● ●                                │
  │  ───                                │
  └─────────────────────────────────────┘
      Robot Alshifa — Animated Face
```

**A production-quality Flutter application that turns an Android tablet into a robot's animated face.**

</div>

---

## Overview

Robot Alshifa is a real-time robot face engine built for Android tablets mounted inside small desktop robots. The tablet becomes the robot's expressive face — controlled remotely via USB serial, WebSocket, or REST API.

```
Backend (Python/ROS/Node) → USB or WiFi → Android Tablet → Robot Face
```

---


## Project Structure

```
robot_alshifa/
├── lib/
│   ├── main.dart                          # App entry, fullscreen setup
│   ├── core/
│   │   └── (constants, theme, utils)
│   ├── face/
│   │   ├── robot_face.dart                # Top-level face widget
│   │   ├── face_renderer.dart             # CustomPaint wrapper
│   │   ├── face_painter.dart              # Canvas drawing engine
│   │   └── emotion_controller.dart        # All animation logic
│   ├── robot/
│   │   ├── emotion.dart                   # Emotion enum + params
│   │   └── robot_controller.dart          # Central state manager
│   ├── communication/
│   │   ├── robot_transport.dart           # Abstract transport
│   │   ├── usb_transport.dart             # USB serial
│   │   ├── websocket_transport.dart       # WS client (tablet→server)
│   │   ├── websocket_server.dart          # WS server (server→tablet)
│   │   ├── rest_client.dart               # REST server + client
│   │   └── command_parser.dart            # JSON command dispatcher
│   └── settings/
│       └── device_config.dart             # Persistent config
├── android/
│   ├── app/
│   │   ├── src/main/AndroidManifest.xml   # Permissions, USB intent
│   │   ├── src/main/kotlin/.../MainActivity.kt
│   │   └── src/main/res/xml/usb_device_filter.xml
│   └── build.gradle
├── backend/
│   ├── robot_controller.py                # Python SDK + demo
│   └── ws_server.py                       # WebSocket test server
└── README.md
```

---



```bash
# Navigate to project
cd robot_alshifa

# Install dependencies
flutter pub get
```

### 3. Build & Deploy to Tablet

```bash
# Debug build (for development)
flutter run --release -d <device-id>

# Release APK
flutter build apk --release

# Install APK directly
adb install build/app/outputs/flutter-apk/app-release.apk
```

### 4. Find Device ID

```bash
flutter devices
```

---

## USB Communication Setup

### Hardware Requirements

The tablet connects to the robot's main computer via a USB serial adapter.

```
Robot Computer ─── USB Serial Cable ─── Android Tablet
(Linux/RaspberryPi)  (FTDI/CH340/CP2102)   (running Flutter app)
```

### Supported USB Adapters

| Chip | Vendor ID | Product ID |
|---|---|---|
| FTDI FT232 | 0x0403 | various |
| CP2102/CP2104 | 0x10C4 | 0xEA60 |
| CH340/CH341 | 0x1A86 | 0x7523 |
| Arduino Uno | 0x2341 | various |

### Adding Custom USB Device

Edit `android/app/src/main/res/xml/usb_device_filter.xml`:

```xml
<usb-device vendor-id="YOUR_VID" product-id="YOUR_PID" />
```

Convert hex to decimal: `0x10C4` = `4292`

### USB Protocol

Commands are newline-delimited JSON:

```
{"type":"emotion","emotion":"happy"}\n
{"type":"blink"}\n
{"type":"state","state":"talking"}\n
```

### Arduino/Python USB Sender Example

```python
import serial
import json

ser = serial.Serial('/dev/ttyUSB0', 115200, timeout=1)

def send_command(cmd: dict):
    ser.write((json.dumps(cmd) + '\n').encode())

send_command({"type": "emotion", "emotion": "happy"})
send_command({"type": "blink"})
send_command({"type": "state", "state": "talking"})
```

---

## WebSocket API

### Connection

```
ws://<tablet-ip>:8081/robot
```

The tablet runs a WebSocket **server** that the backend connects to.

> **Note:** In the current architecture, there are two modes:
> 1. **Tablet as server** (default): Backend connects to tablet
> 2. **Backend as server**: Tablet connects to backend (set WS URL in app)

### Example Commands

```json
// Set emotion
{ "type": "emotion", "emotion": "happy", "duration": 3000 }

// Set state
{ "type": "state", "state": "talking" }

// Trigger blink
{ "type": "blink" }

// Look direction
{ "type": "look", "direction": "left" }

// Speech (triggers talking animation)
{ "type": "speech", "text": "Hello, how are you?" }

// Talk control
{ "type": "talk", "enabled": true }

// Reset to neutral
{ "type": "reset" }
```

---

## REST API

The tablet runs a REST server on port `8082`.

### Endpoints

| Method | Path | Description |
|---|---|---|
| GET | `/api/robot/status` | Connection + state info |
| GET | `/api/robot/state` | Current emotion/state |
| POST | `/api/robot/emotion` | Set emotion |
| POST | `/api/robot/state` | Set state |
| POST | `/api/robot/speak` | Speech animation |
| POST | `/api/robot/eyes` | Eye action |
| POST | `/api/robot/mouth` | Mouth action |
| POST | `/api/robot/blink` | Trigger blink |
| POST | `/api/robot/look` | Look direction |
| POST | `/api/robot/reset` | Reset to neutral |

### Examples

```bash
# Get status
curl http://192.168.1.100:8082/api/robot/status

# Set happy emotion for 3 seconds
curl -X POST http://192.168.1.100:8082/api/robot/emotion \
  -H "Content-Type: application/json" \
  -d '{"emotion": "happy", "duration": 3000}'

# Start talking animation
curl -X POST http://192.168.1.100:8082/api/robot/state \
  -H "Content-Type: application/json" \
  -d '{"state": "talking"}'

# Blink
curl -X POST http://192.168.1.100:8082/api/robot/blink

# Look right
curl -X POST http://192.168.1.100:8082/api/robot/look \
  -H "Content-Type: application/json" \
  -d '{"direction": "right"}'

# Speak
curl -X POST http://192.168.1.100:8082/api/robot/speak \
  -H "Content-Type: application/json" \
  -d '{"text": "Hello, I am your robot assistant."}'
```

---

## Command Protocol Reference

### Command Types

| Type | Description | Required Fields |
|---|---|---|
| `emotion` | Set emotion | `emotion` |
| `state` | Set state | `state` |
| `blink` | Trigger blink | — |
| `look` | Eye direction | `direction` |
| `talk` | Talking on/off | `enabled` |
| `speech` | Speech text (auto-times talking) | `text` |
| `eyes` | Eye action | `action` |
| `mouth` | Mouth action | `shape` |
| `animation` | Named animation | `name` |
| `reset` | Reset to neutral | — |

### Supported Emotions

```
neutral  happy   excited  sad      angry
confused surprised sleepy  love    thinking
talking  listening  error  sleep
```

### Supported States

```
idle  talking  listening  thinking  sleeping  error
```

### Look Directions

```
left  right  up  down  center
```

### Full Command Schema

```json
{
  "id": "optional-unique-id",
  "type": "emotion",
  "emotion": "happy",
  "duration": 3000
}
```

---

## Python Backend SDK

### Installation

```bash
pip install websockets aiohttp
```

### Basic Usage

```python
import asyncio
from backend.robot_controller import RobotFaceClient

async def main():
    robot = RobotFaceClient(
        ws_url="ws://192.168.1.100:8081/robot",
        rest_url="http://192.168.1.100:8082/api"
    )
    
    await robot.connect_ws()
    
    # High-level API
    await robot.happy()
    await asyncio.sleep(2)
    
    await robot.thinking()
    await asyncio.sleep(2)
    
    await robot.speak("Hello, I am a robot!")
    await asyncio.sleep(3)
    
    await robot.neutral()
    await robot.disconnect()

asyncio.run(main())
```

### Run Interactive Shell

```bash
python3 backend/robot_controller.py
```

### Run Demo

```bash
python3 backend/robot_controller.py demo
```

### Run WebSocket Test Server

```bash
python3 backend/ws_server.py
```

---

## Kiosk Setup (Android)

### Enable Developer Options

1. Go to Settings → About tablet
2. Tap "Build number" 7 times
3. Enable Developer Options
4. Enable USB Debugging

### Auto-Launch on Boot

```bash
adb shell pm grant com.alshifa.robot_alshifa android.permission.RECEIVE_BOOT_COMPLETED
adb shell am start -n com.alshifa.robot_alshifa/.MainActivity
```

### Screen Pinning (Kiosk Lock)

In Developer Options, enable "Screen pinning", then:

```bash
adb shell am task lock $(adb shell am stack list | grep robot | awk '{print $2}')
```

### Disable Status Bar Interactions

```bash
adb shell settings put global policy_control immersive.full=*
```

### Prevent Sleep

```bash
adb shell svc power stayon true
```

---

## Developer Mode

Tap 7 times rapidly anywhere on the face to open the developer panel.

The panel shows:
- USB and WebSocket connection status
- Current emotion and state
- Buttons for all emotions
- Quick actions (blink, look directions, reset)
- Server URL info

---

## Performance Notes

- Animations run at 60 FPS via `Ticker` (not periodic rebuilds)
- `CustomPainter` with `shouldRepaint = true` for real-time canvas
- Idle animation uses a single `Ticker` for all motion
- No image assets — pure vector/canvas rendering
- Memory: ~60-80 MB typical usage
- CPU: <5% average on modern tablet hardware

---

## Building Release APK

```bash
# Generate signing key (first time only)
keytool -genkey -v -keystore robot_face.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias robot_face

# Create key.properties
echo "storePassword=YOUR_PASSWORD
keyPassword=YOUR_KEY_PASSWORD  
keyAlias=robot_face
storeFile=../robot_face.jks" > android/key.properties

# Build release APK
flutter build apk --release

# Output location:
# build/app/outputs/flutter-apk/app-release.apk
```

---

## Architecture

```
                ┌─────────────────────────────┐
                │        Backend System         │
                │  (Python / ROS / Node.js)    │
                └──────┬──────────┬────────────┘
                       │ USB      │ WebSocket/REST
                       ▼          ▼
                ┌─────────────────────────────┐
                │      Android Tablet          │
                │   ┌─────────────────────┐   │
                │   │  Flutter App         │   │
                │   │                     │   │
                │   │  UsbTransport       │   │
                │   │  WsTransport   ──►  │   │
                │   │  RestApiServer      │   │
                │   │        │            │   │
                │   │  CommandParser      │   │
                │   │        │            │   │
                │   │  RobotController    │   │
                │   │        │            │   │
                │   │  EmotionController  │   │
                │   │        │            │   │
                │   │  FacePainter (Canvas)│  │
                │   └─────────────────────┘   │
                └─────────────────────────────┘
```

---

## License

MIT License — Free to use for personal and commercial robot projects.

---

*Built with Flutter · Designed for physical robots · Open source*
