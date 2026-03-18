import type { OpenNextConfig } from '@opennextjs/cloudflare';

const config: OpenNextConfig = {
  default: {
    override: {
      wrapper: 'cloudflare-node',
      converter: 'edge',
      proxyExternalRequest: 'fetch',
      incrementalCache: 'dummy',
      tagCache: 'dummy',
      queue: 'dummy',
    },
  },
  edgeExternals: [
    'node:crypto',
    'node:async_hooks',
    'node:buffer',
    'node:stream',
    'node:util',
    'node:events',
    'node:path',
    'node:url',
    'node:fs',
    'node:http',
    'node:https',
    'node:net',
    'node:tls',
    'node:dns',
    'node:os',
    'node:zlib',
    'node:vm',
    'node:child_process',
    'node:string_decoder',
    'node:tty',
    'node:assert',
    'node:punycode',
    'node:timers',
    'node:worker_threads',
    'node:sqlite'
  ],
  middleware: {
    external: true,
    override: {
      wrapper: 'cloudflare-edge',
      converter: 'edge',
      proxyExternalRequest: 'fetch',
      incrementalCache: 'dummy',
      tagCache: 'dummy',
      queue: 'dummy',
    },
  },
  // 👇 👇 👇 必须加这个：直接控制 esbuild
  esbuild: {
    external: ['node:sqlite'],
  },
};

export default config;
