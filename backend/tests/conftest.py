import sys
from pathlib import Path

# Ensure tests can import the backend package when run from repository root.
ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))
