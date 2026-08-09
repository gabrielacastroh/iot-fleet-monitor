"""Entry point: `python -m simulator [flags]` from inside this directory."""

import asyncio
import sys

from simulator.client import SimulatorError
from simulator.config import load_config
from simulator.fleet import run


def main() -> None:
    try:
        config = load_config()
    except ValueError as exc:
        print(f"Configuration error: {exc}", file=sys.stderr)
        raise SystemExit(2) from exc

    try:
        asyncio.run(run(config))
    except KeyboardInterrupt:
        print("\nStopped.")
    except SimulatorError as exc:
        print(f"Simulator error: {exc}", file=sys.stderr)
        raise SystemExit(1) from exc


if __name__ == "__main__":
    main()
