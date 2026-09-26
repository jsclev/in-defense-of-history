import { defineConfig } from 'vite';
import { webConfig } from './tools/config';
export default defineConfig(({ mode }) => webConfig(mode === 'facebook' ? 'facebook' : 'website'));
