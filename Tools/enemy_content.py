#!/usr/bin/env python3
"""Audit enemy display-copy ownership or export the authored roster for marketing.

Usage: python3 Tools/enemy_content.py check
       python3 Tools/enemy_content.py export --output /absolute/path/roster.json
"""
import argparse
import json
import re
import sqlite3
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SEED = ROOT / "Db/DML/enemy_types.sql"


def authored_roster():
    with sqlite3.connect(":memory:") as connection:
        connection.row_factory = sqlite3.Row
        connection.executescript((ROOT / "Db/DDL/create_tables.sql").read_text())
        connection.executescript(SEED.read_text())
        return [dict(row) for row in connection.execute("SELECT * FROM enemy_type ORDER BY rowid")]


def check(rows):
    failures = []
    # Include untracked source files; exclude Git history and ignored build output.
    files = subprocess.check_output(
        ["git", "ls-files", "-z", "--cached", "--others", "--exclude-standard"], cwd=ROOT
    ).decode().split("\0")
    copy = [row[column] for row in rows for column in ("enemy_type_name", "enemy_type_description")]
    patterns = [(value, re.compile(r"(['\"])" + re.escape(value).replace("'", "(?:'|'')") + r"\1"))
                for value in copy]
    for relative in sorted(set(files)):
        path = ROOT / relative
        if path == SEED or not path.is_file():
            continue
        try:
            text = path.read_text()
        except UnicodeError:
            continue
        for value, pattern in patterns:
            for match in pattern.finditer(text):
                line = text.count("\n", 0, match.start()) + 1
                failures.append(f"{relative}:{line}: duplicate enemy display copy {value!r}")
        if path.suffix == ".sql" and re.search(r"enemy_type_name\s*=\s*'", text):
            failures.append(f"{relative}: wave/content references must use enemy_type_key or id")
    with sqlite3.connect(f"file:{ROOT / 'Db/in_defense_of_history.sqlite'}?mode=ro", uri=True) as db:
        db.row_factory = sqlite3.Row
        bundled = [dict(row) for row in db.execute("SELECT * FROM enemy_type ORDER BY rowid")]
    if rows != bundled:
        failures.append("Bundled enemy roster differs from its authored seed; rebuild Db/create_db.sh.")
    if failures:
        raise SystemExit("\n".join(failures))
    print(f"Verified {len(rows)} enemy types: one authored name and description each; no duplicate display literals; bundled data matches.")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=["check", "export"])
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    rows = authored_roster()
    if args.command == "check":
        check(rows)
    else:
        if args.output is None or not args.output.is_absolute():
            parser.error("export requires an absolute --output path")
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps(rows, ensure_ascii=False, indent=2) + "\n")
        print(f"Exported {len(rows)} authored enemy records to {args.output}")


if __name__ == "__main__":
    main()
