#!/usr/bin/env python3
"""Discover YouTube hostnames that are missing from lists/youtube.txt.

Source: certificate transparency logs via crt.sh. Every hostname that gets a
public TLS certificate is logged, so new YouTube names show up there soon
after they go live.

Limits (see README/CONTEXT): wildcard certificates (e.g. *.googlevideo.com)
hide per-session shard hosts such as r3---sn-xxxx.googlevideo.com. Those are
handled by suffix blocking in the build output, not by this script.

Usage:
  python3 tools/discover.py                 # print candidates
  python3 tools/discover.py --write         # append candidates to the list
  python3 tools/discover.py --offline F     # read one crt.sh JSON file (testing)
  python3 tools/discover.py --list PATH     # use another list file (testing)

Stdlib only. Exit status: 0 if at least one source answered, 2 otherwise.
"""

import argparse
import datetime as dt
import json
import re
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
DEFAULT_LIST = REPO / "lists" / "youtube.txt"

# Roots searched on crt.sh. Subdomains of these are candidates.
ROOTS = [
    "youtube.com",
    "googlevideo.com",
    "ytimg.com",
    "ggpht.com",
    "youtu.be",
    "youtube-nocookie.com",
    "withyoutube.com",
]

# youtube.<tld> and youtube.<cc>.<tld> regional variants.
REGIONAL_RE = re.compile(r"^youtube\.[a-z]{2,}(\.[a-z]{2,})?$")

# Plain hostname check (LDH labels, at least one dot, alphabetic TLD).
HOST_RE = re.compile(r"^(?=.{1,253}$)([a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z]{2,}$")

USER_AGENT = "social-media-domains-reference-list-discover/1.0"
RETRIES = 4


def fetch_crtsh(root):
    """Return the parsed crt.sh JSON for %.root, or None if it kept failing."""
    query = urllib.parse.urlencode({"q": "%." + root, "output": "json"})
    request = urllib.request.Request(
        "https://crt.sh/?" + query, headers={"User-Agent": USER_AGENT}
    )
    for attempt in range(RETRIES):
        try:
            with urllib.request.urlopen(request, timeout=120) as response:
                return json.load(response)
        except (urllib.error.URLError, json.JSONDecodeError, TimeoutError, OSError) as exc:
            print(f"crt.sh {root}: attempt {attempt + 1} failed: {exc}", file=sys.stderr)
            if attempt < RETRIES - 1:
                time.sleep(15 * 2**attempt)
    return None


def hostnames_from_crtsh(records):
    """Pull valid hostnames out of crt.sh records (wildcards reduced to the base)."""
    names = set()
    for record in records:
        for raw in record.get("name_value", "").split("\n"):
            name = raw.strip().lower()
            if name.startswith("*."):
                name = name[2:]
            if HOST_RE.match(name):
                names.add(name)
    return names


def is_youtube(name):
    if any(name == root or name.endswith("." + root) for root in ROOTS):
        return True
    return bool(REGIONAL_RE.match(name))


def existing_hosts(text):
    """Hostnames already present, whether stored bare or as '0.0.0.0 host'."""
    hosts = set()
    for line in text.splitlines():
        stripped = line.strip()
        if not stripped or stripped.startswith("#"):
            continue
        hosts.add(stripped.split()[-1].lower())
    return hosts


def count_entries(text):
    return sum(
        1
        for line in text.splitlines()
        if line.strip() and not line.strip().startswith("#")
    )


def write_candidates(list_path, text, candidates):
    today = dt.date.today().isoformat()
    block = [f"", f"# Discovered via crt.sh on {today}"]
    block += [f"0.0.0.0 {name}" for name in candidates]
    updated = text.rstrip("\n") + "\n" + "\n".join(block) + "\n"
    total = count_entries(updated)
    updated = re.sub(r"^# Entries: \d+$", f"# Entries: {total}", updated, count=1, flags=re.M)
    list_path.write_text(updated, encoding="utf-8")


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--write", action="store_true", help="append candidates to the list file")
    parser.add_argument("--offline", metavar="FILE", help="read crt.sh JSON from FILE instead of the network")
    parser.add_argument("--list", metavar="PATH", default=str(DEFAULT_LIST), help="list file to compare against")
    args = parser.parse_args()

    list_path = Path(args.list)
    text = list_path.read_text(encoding="utf-8")
    known = existing_hosts(text)

    seen = set()
    if args.offline:
        records = json.loads(Path(args.offline).read_text(encoding="utf-8"))
        seen |= hostnames_from_crtsh(records)
        answered = 1
    else:
        answered = 0
        for root in ROOTS:
            records = fetch_crtsh(root)
            if records is None:
                print(f"warning: no answer for {root}", file=sys.stderr)
                continue
            answered += 1
            seen |= hostnames_from_crtsh(records)

    candidates = sorted(n for n in seen if is_youtube(n) and n not in known)

    if candidates:
        print(f"{len(candidates)} candidate(s) not in {list_path.name}:")
        for name in candidates:
            print(f"  {name}")
    else:
        print(f"No new candidates for {list_path.name}.")

    if args.write and candidates:
        write_candidates(list_path, text, candidates)
        print(f"Appended {len(candidates)} entries to {list_path}")

    if answered == 0:
        print("error: no source answered", file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
