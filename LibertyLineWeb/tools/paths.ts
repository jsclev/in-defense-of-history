import { fileURLToPath } from 'node:url';
import { dirname, resolve } from 'node:path';

export const project = resolve(dirname(fileURLToPath(import.meta.url)), '..');
export const native = resolve(project, '..');
export const art = resolve(native, '../in-defense-of-history-data');
export const generated = resolve(project, 'generated');
