"""Makes the backend's domain modules importable from these tests.

The autonomy rule belongs to the backend, so "can the simulator trip it?" has
to be answered by running the backend's real `FuelService` — a local copy of
the same arithmetic would drift the moment either side changed. That module
imports nothing outside the standard library, so this needs the path and none
of the backend's dependencies.
"""

import sys
from pathlib import Path

BACKEND_PATH = Path(__file__).resolve().parents[2] / "backend"

if BACKEND_PATH.is_dir() and str(BACKEND_PATH) not in sys.path:
    sys.path.insert(0, str(BACKEND_PATH))
