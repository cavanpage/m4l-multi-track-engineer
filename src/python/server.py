"""
server.py — Phase 1
Python OSC/UDP server. Receives Spoke metadata from Max via udpsend (OSC format).
Sends acknowledgments back to Max via udpreceive on a separate port.

Max's native udpsend object sends OSC-formatted packets — python-osc handles parsing.
No WebSocket or npm required.

Message types handled here grow with each phase:
  /spoke/meta  — Phase 1: track name, color, category
  /spoke/rms   — Phase 2: RMS level per spoke
  /spoke/fft   — Phase 3: 128-bin spectral array
"""

import json
from pythonosc import dispatcher, osc_server, udp_client

HOST          = "localhost"
RECEIVE_PORT  = 8765   # Max udpsend target
SEND_PORT     = 8766   # Max udpreceive listens here

# In-memory registry — shape grows in Phase 2 to match full RegistryEntry
registry: dict[str, dict] = {}

# Client for sending acks back to Max
osc_client = udp_client.SimpleUDPClient(HOST, SEND_PORT)


def handle_meta(address: str, json_str: str) -> None:
    try:
        meta = json.loads(json_str)
    except json.JSONDecodeError:
        print(f"[server] bad JSON on {address}: {json_str[:80]}")
        return

    spoke_id = meta.get("name", "unknown")
    registry[spoke_id] = meta

    print(
        f"[spoke]  {meta.get('name', '?'):<20} "
        f"category={meta.get('category', '?'):<10} "
        f"color={meta.get('color', '?')}"
    )

    osc_client.send_message("/ack", json.dumps({
        "spoke": spoke_id,
        "registered": len(registry)
    }))


if __name__ == "__main__":
    disp = dispatcher.Dispatcher()
    disp.map("/spoke/meta", handle_meta)

    # Default handler — logs unknown OSC addresses instead of silently dropping
    disp.set_default_handler(
        lambda address, *args: print(f"[server] unhandled OSC: {address} {args}")
    )

    server = osc_server.ThreadingOSCUDPServer((HOST, RECEIVE_PORT), disp)
    print(f"[server] listening on {HOST}:{RECEIVE_PORT}  (acks → {HOST}:{SEND_PORT})")

    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\n[server] stopped")
