"""Print the archive download URL of one artifact from the Actions API.

Reads the JSON listing on stdin, writes the URL (or an empty line) to stdout.
Kept in its own file so the workflow never has to nest shell quotes inside a
YAML block scalar.

    curl -sSL -H "Authorization: Bearer $TOKEN" "$api" \
        | python3 ci/list_artifacts.py harbor-oracle-trial-exam003
"""

import json
import sys


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: list_artifacts.py <artifact-name>", file=sys.stderr)
        return 2
    wanted = sys.argv[1]
    try:
        data = json.load(sys.stdin)
    except json.JSONDecodeError as exc:
        print(f"could not parse Actions API response: {exc}", file=sys.stderr)
        return 1

    for artifact in data.get("artifacts", []):
        if artifact.get("name") == wanted and not artifact.get("expired"):
            print(artifact["archive_download_url"])
            return 0

    # Matching expired artifacts is better than printing nothing: the caller
    # reports a precise failure either way.
    for artifact in data.get("artifacts", []):
        if artifact.get("name") == wanted:
            print(artifact["archive_download_url"])
            return 0

    print("", end="")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
