import { mkdtemp, symlink, readFile, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { execFile } from 'node:child_process';
import { promisify } from 'node:util';
import { native } from './paths';

const exec = promisify(execFile);

// Execute the EXISTING content builder, unchanged, in a disposable Db directory.
// Symlinks reuse its SQL and script; the 13 GB working database is never opened,
// copied, overwritten, or stripped of simulator records by the web build.
export async function seedDatabase(source = join(native, 'Db')): Promise<Uint8Array> {
  const staging = await mkdtemp(join(tmpdir(), 'liberty-line-seed-'));
  try {
    for (const name of ['DDL', 'DML', 'create_db.sh']) await symlink(join(source, name), join(staging, name));
    await exec('/bin/sh', [join(staging, 'create_db.sh')]);
    return await readFile(join(staging, 'in_defense_of_history.sqlite'));
  } finally { await rm(staging, { recursive: true, force: true }); }
}
