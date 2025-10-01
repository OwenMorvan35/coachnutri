import base64
from pathlib import Path

DATA = base64.b64decode(
    "iVBORw0KGgoAAAANSUhEUgAAAA4AAAAOCAYAAAAfSC3RAAAAJ0lEQVR4nGMAAQAABQABDQottAAAAABJRU5ErkJggg=="
)
assets = Path("assets/images")
assets.mkdir(parents=True, exist_ok=True)
Path("assets/images/pattern_background.png").write_bytes(DATA)
