#!/usr/bin/env python3
"""Allow three selected GA demonstrations; reject research data in device bundles.

This is read-only validation. Database creation remains exclusively owned by
Db/create_db.sh; a failed check never deletes or rewrites the research database.
"""
import argparse
import hashlib
from pathlib import Path
import sqlite3
import tempfile


MAX_BYTES = 128 * 1024 * 1024
MAX_DEMONSTRATIONS = 3
RESEARCH_TABLES = (
    "simulator_run", "sweep_row",
    "money_study", "money_study_result", "ga_study",
)


def check_size(path):
    size = path.stat().st_size
    if not 0 < size <= MAX_BYTES:
        raise ValueError(f"{path}: {size:,} bytes; device database limit is {MAX_BYTES:,} bytes")
    return size


def check_content(connection):
    for table in RESEARCH_TABLES:
        if connection.execute(f'SELECT EXISTS(SELECT 1 FROM "{table}" LIMIT 1)').fetchone()[0]:
            raise ValueError(f"{table}: saved run/study data must not ship in the device database")
    count = connection.execute("SELECT count(*) FROM level_run").fetchone()[0]
    linked = connection.execute("SELECT count(*) FROM genetic_solution_recording").fetchone()[0]
    if count != linked or count > MAX_DEMONSTRATIONS:
        raise ValueError("level_run: only up to three linked GA demonstrations may ship")
    invalid = connection.execute("""
        SELECT r.id FROM level_run r
        LEFT JOIN genetic_solution_recording p ON p.level_run_id=r.id
        LEFT JOIN ga_solution_details g ON g.run_id=p.run_id AND g.candidate_id=p.candidate_id AND g.panel=p.panel
        WHERE g.run_id IS NULL OR r.source<>'simulator' OR lower(r.level_id)<>lower(g.level_info_id)
           OR p.panel<>'validation' OR r.status NOT IN ('victory','defeat','timeout') OR r.status<>p.outcome
           OR NOT EXISTS (SELECT 1 FROM ga_panel f WHERE f.run_id=g.run_id AND f.candidate_id=g.candidate_id AND f.panel=g.panel
                          AND f.sample_count=f.expected_samples)
           OR NOT EXISTS (SELECT 1 FROM ga_evaluation e WHERE e.run_id=g.run_id AND e.candidate_id=g.candidate_id AND e.panel=g.panel AND e.seed=p.seed)
        LIMIT 1
        """).fetchone()
    if invalid:
        raise ValueError("level_run: demonstration must link to its complete validated solution and original seed")
    invalid = connection.execute("""
        SELECT r.id FROM level_run r LEFT JOIN level_action a ON a.run_id=r.id
        GROUP BY r.id HAVING count(a.sequence)<>r.last_sequence+1 OR min(a.sequence)<>0
            OR max(a.sequence)<>r.last_sequence OR max(a.tick)<>r.last_tick
        LIMIT 1
        """).fetchone()
    if invalid:
        raise ValueError("level_action: incomplete demonstration recording")
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
    print(f"Device database verified: {size:,} bytes, only linked GA demonstrations and no research results: {path}")


def self_test():
    # All database mutations stay in disposable in-memory fixtures.
    connection = sqlite3.connect(":memory:")
    try:
        for table in RESEARCH_TABLES:
            connection.execute(f'CREATE TABLE "{table}" (id INTEGER PRIMARY KEY)')
        connection.executescript('''
            CREATE TABLE genetic_solution(run_id TEXT, candidate_id INTEGER, panel TEXT, level_info_id TEXT,
                PRIMARY KEY(run_id,candidate_id,panel));
            CREATE VIEW ga_solution_details AS SELECT * FROM genetic_solution;
            CREATE TABLE ga_panel(run_id TEXT,candidate_id INTEGER,panel TEXT,expected_samples INTEGER,sample_count INTEGER);
            CREATE TABLE ga_evaluation(run_id TEXT,candidate_id INTEGER,panel TEXT,seed TEXT);
            CREATE TABLE level_run(id TEXT PRIMARY KEY, source TEXT, level_id TEXT, status TEXT, last_sequence INTEGER, last_tick INTEGER);
            CREATE TABLE level_action(run_id TEXT REFERENCES level_run(id),sequence INTEGER,tick INTEGER);
            CREATE TABLE genetic_solution_recording(run_id TEXT,candidate_id INTEGER,panel TEXT,level_run_id TEXT UNIQUE REFERENCES level_run(id),seed TEXT,outcome TEXT,
                FOREIGN KEY(run_id,candidate_id,panel) REFERENCES genetic_solution(run_id,candidate_id,panel));
        ''')
        check_content(connection)
        for table in RESEARCH_TABLES:
            connection.execute(f'INSERT INTO "{table}" VALUES (1)')
            try:
                check_content(connection)
            except ValueError as error:
                assert table in str(error)
            else:
                raise AssertionError(f"Saved data in {table} was accepted")
            connection.execute(f'DELETE FROM "{table}"')
        connection.executescript('''
            INSERT INTO genetic_solution VALUES('study',1,'validation','level');
            INSERT INTO ga_panel VALUES('study',1,'validation',1,1);
            INSERT INTO ga_evaluation VALUES('study',1,'validation','1776');
            INSERT INTO level_run VALUES('movie','simulator','LEVEL','victory',0,0);
            INSERT INTO level_action VALUES('movie',0,0);
            INSERT INTO genetic_solution_recording VALUES('study',1,'validation','movie','1776','victory');
        ''')
        check_content(connection)
        for mutation, repair in [
            ("UPDATE level_run SET source='player'", "UPDATE level_run SET source='simulator'"),
            ("UPDATE genetic_solution_recording SET seed='1'", "UPDATE genetic_solution_recording SET seed='1776'"),
            ("UPDATE level_run SET last_sequence=2", "UPDATE level_run SET last_sequence=0"),
            ("INSERT INTO level_run VALUES('unlinked','simulator','level','victory',0,0)", "DELETE FROM level_run WHERE id='unlinked'"),
        ]:
            connection.execute(mutation)
            try:
                check_content(connection)
            except ValueError:
                pass
            else:
                raise AssertionError(f"Invalid demonstration was accepted: {mutation}")
            connection.execute(repair)
        connection.executescript('DELETE FROM genetic_solution_recording; DELETE FROM level_action; DELETE FROM level_run;')
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
