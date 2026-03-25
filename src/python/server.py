"""
server.py — Phase 1
Python WebSocket server. Receives Spoke metadata from Max via the n4m bridge.
Logs each registration. Sends an acknowledgment back to Max.

Phase 1 only handles metadata. Spectral data, masking logic, and AI
classification are added in later phases as additional message types.
"""

import asyncio
import json
import websockets

HOST = "localhost"
PORT = 8765

# In-memory registry — grows in Phase 2 to hold the full RegistryEntry shape
registry: dict[str, dict] = {}


async def handler(websocket):
    client = websocket.remote_address
    print(f"[server] spoke connected from {client}")

    try:
        async for raw in websocket:
            try:
                msg = json.loads(raw)
            except json.JSONDecodeError:
                print(f"[server] bad JSON from {client}: {raw[:80]}")
                continue

            msg_type = msg.get("type")

            if msg_type == "meta":
                meta = msg.get("payload", {})
                spoke_id = meta.get("name", "unknown")
                registry[spoke_id] = meta

                print(
                    f"[spoke] {meta.get('name', '?'):<20} "
                    f"category={meta.get('category', '?'):<10} "
                    f"color={meta.get('color', '?')}"
                )

                await websocket.send(json.dumps({
                    "type": "ack",
                    "spoke": spoke_id,
                    "registered": len(registry)
                }))

            else:
                print(f"[server] unknown message type: {msg_type}")

    except websockets.exceptions.ConnectionClosedOK:
        pass
    except websockets.exceptions.ConnectionClosedError as e:
        print(f"[server] connection error from {client}: {e}")
    finally:
        print(f"[server] spoke disconnected from {client}")


async def main():
    print(f"[server] listening on ws://{HOST}:{PORT}")
    async with websockets.serve(handler, HOST, PORT):
        await asyncio.Future()  # run forever


if __name__ == "__main__":
    asyncio.run(main())
