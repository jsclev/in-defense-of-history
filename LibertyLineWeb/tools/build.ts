import { build } from 'vite';
import { join } from 'node:path';
import { project } from './paths';
import { webConfig } from './config';
import { packageDirectory } from './archive';

const target = process.argv[2];
if (!target) throw new Error('Specify website or facebook');
await build({ ...webConfig(target), configFile: false });
const destination = join(project, 'releases', `${target}.zip`);
const size = await packageDirectory(join(project, 'dist', target), destination);
console.log(`Verified ${destination}: ${(size / 1024 / 1024).toFixed(1)} MiB`);
