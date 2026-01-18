#!/usr/bin/env python3
"""Bootstrap the test repository for integration tests.

Creates required directories and initializes trace file.
Cross-platform replacement for bootstrap-test-repo.sh.
"""

import sys
from pathlib import Path


def main() -> int:
    """Bootstrap the test repository."""
    # Get root directory (parent of scripts/)
    root_dir = Path(__file__).parent.parent.resolve()

    # Create reports directory
    reports_dir = root_dir / "reports"
    reports_dir.mkdir(parents=True, exist_ok=True)

    # Create empty trace file
    trace_file = reports_dir / "trace.jsonl"
    trace_file.write_text("")

    print("Bootstrap complete. Set CLAUDE_CLI_PATH and ANTHROPIC_API_KEY before running integration tests.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
