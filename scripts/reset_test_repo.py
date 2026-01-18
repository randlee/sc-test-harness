#!/usr/bin/env python3
"""Reset the test repository to a clean state.

Performs git reset/clean and reinitializes trace file.
Cross-platform replacement for reset-test-repo.sh.
"""

import subprocess
import sys
from pathlib import Path


def run_git_command(args: list[str], cwd: Path) -> bool:
    """Run a git command and return success status."""
    try:
        result = subprocess.run(
            ["git"] + args,
            cwd=cwd,
            check=True,
            capture_output=True,
            text=True,
        )
        return True
    except subprocess.CalledProcessError as e:
        print(f"Git command failed: git {' '.join(args)}", file=sys.stderr)
        print(f"stderr: {e.stderr}", file=sys.stderr)
        return False
    except FileNotFoundError:
        print("Error: git not found in PATH", file=sys.stderr)
        return False


def main() -> int:
    """Reset the test repository."""
    print("Resetting test repo...")

    # Get root directory (parent of scripts/)
    root_dir = Path(__file__).parent.parent.resolve()

    # Git reset --hard
    if not run_git_command(["reset", "--hard"], root_dir):
        return 1

    # Git clean -fdx
    if not run_git_command(["clean", "-fdx"], root_dir):
        return 1

    # Create reports directory
    reports_dir = root_dir / "reports"
    reports_dir.mkdir(parents=True, exist_ok=True)

    # Create empty trace file
    trace_file = reports_dir / "trace.jsonl"
    trace_file.write_text("")

    print("Reset complete.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
