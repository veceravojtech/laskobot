import { defineConfig } from 'tsup'

export default defineConfig({
  entry: [
    'src/index.ts',
    'src/index-http.ts',
    'src/index-multi.ts',
    'src/index-unified.ts',
    'src/daemon/websocket-daemon.ts'
  ],
  format: ['esm'],

  // Target platform
  platform: 'node',

  // Keep native modules and all node built-ins external
  external: [
    'sharp',
    'better-sqlite3',
    // Node.js built-in modules - must not be bundled for ESM
    'events',
    'stream',
    'util',
    'path',
    'fs',
    'crypto',
    'http',
    'https',
    'net',
    'tls',
    'zlib',
    'os',
    'process',
    'buffer',
    'child_process',
    'async_hooks',
    'url',
    'querystring',
    'assert',
    'dns',
    'readline',
    'string_decoder',
    'timers'
  ],

  // Generate sourcemaps for debugging
  sourcemap: false,

  // Clean dist before build
  clean: true,

  // Set shebang for executable files
  shims: true,

  // Minification (optional)
  minify: false,

  // Transpile target
  target: 'node20',

  // Post-build: set executable bit for entry points
  onSuccess: 'shx chmod +x dist/*.js dist/**/*.js'
})
