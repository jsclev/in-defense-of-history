#!/usr/bin/env python3
"""Reject research recordings and oversized databases in device app bundles.

This is read-only validation. Database creation remains exclusively owned by
Db/create_db.sh; a failed check never deletes or rewrites the research database.
"""
import argparse
import hashlib
from pathlib import Path
import sqlite3
import tempfile


MAX_BYTES = 32 * 1024 * 1024
RECORDING_TABLES = (
    "level_run", "level_action", "simulator_run", "sweep_row",
    "money_study", "money_study_result",
)


def check_size(path):
    size = path.stat().st_size
    if not 0 < size <= MAX_BYTES:
        raise ValueError(f"{path}: {size:,} bytes; device database limit is {MAX_BYTES:,} bytes")
    return size


def check_content(connection):
    for table in RECORDING_TABLES:
        if connection.execute(f'SELECT EXISTS(SELECT 1 FROM "{table}" LIMIT 1)').fetchone()[0]:
            raise ValueError(f"{table}: saved run/study data must not ship in the device database")
    if connection.execute("PRAGMA quick_check").fetchall() != [("ok",)]:
        raise ValueError("device database failed SQLite quick_check")
    if connection.execute("PRAGMA foreign_key_check").fetchone() is not None:
        raise ValueError("device database contains broken foreign keys")


def check_database(path, expected_source=None):
    size = check_size(path)
    connection = sqlite3.connect(path.resolve().as_uri() + "?mode=ro", uri=True)
    try:
        check_content(connection)
    finally:
        connection.close()
    if expected_source is not None:
        check_size(expected_source)
        if hashlib.sha256(path.read_bytes()).digest() != hashlib.sha256(expected_source.read_bytes()).digest():
            raise ValueError("bundled device database differs from the validated authored database")
    print(f"Device database verified: {size:,} bytes, no saved runs or study results: {path}")


def self_test():
    # All database mutations stay in disposable in-memory fixtures.
    connection = sqlite3.connect(":memory:")
    try:
        for table in RECORDING_TABLES:
            connection.execute(f'CREATE TABLE "{table}" (id INTEGER PRIMARY KEY)')
        check_content(connection)
        for table in RECORDING_TABLES:
            connection.execute(f'INSERT INTO "{table}" VALUES (1)')
            try:
                check_content(connection)
            except ValueError as error:
                assert table in str(error)
            else:
                raise AssertionError(f"Saved data in {table} was accepted")
            connection.execute(f'DELETE FROM "{table}"')
        connection.execute('DROP TABLE level_run')
        try:
            check_content(connection)
        except sqlite3.OperationalError:
            pass
        else:
            raise AssertionError("Missing recording schema was accepted")
    finally:
        connection.close()
    with tempfile.TemporaryDirectory(prefix="td-device-db-size-") as directory:
        oversized = Path(directory) / "oversized"
        with oversized.open("wb") as stream:
            stream.truncate(MAX_BYTES + 1)
        try:
            check_size(oversized)
        except ValueError:
            pass
        else:
            raise AssertionError("Oversized file was accepted")
    print("Device database validation tests passed")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--database", type=Path)
    mode.add_argument("--self-test", action="store_true")
    parser.add_argument("--matches", type=Path)
    args = parser.parse_args()
    try:
        if args.self_test:
            self_test()
        else:
            check_database(args.database, args.matches)
    except (ValueError, OSError, sqlite3.Error) as error:
        parser.exit(1, f"error: {error}\nPreserve any required recordings, close database connections, and run Db/create_db.sh before a device build.\n")
