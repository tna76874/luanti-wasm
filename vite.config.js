import { defineConfig } from 'vite';
import { viteStaticCopy } from 'vite-plugin-static-copy';

export default defineConfig({
  base: './',
  
  plugins: [
    viteStaticCopy({
      targets: [
        {
          // Spiegelt den kompletten www-Inhalt in die Root des Dev-Servers / Builds
          src: 'www/*',
          dest: '.'
        }
      ]
    })
  ],

  server: {
    port: 3000,
    host: true, // Wichtig für Docker
    headers: {
      'Cross-Origin-Opener-Policy': 'same-origin',
      'Cross-Origin-Embedder-Policy': 'require-corp',
    },
  },

  assetsInclude: ['**/*.pack', '**/*.wasm'],

  build: {
    outDir: 'dist',
    rollupOptions: {
      external: ['**/wasm/launcher.js'] 
    }
  },
  plugins: [
    viteStaticCopy({
      targets: [
        {
          src: 'www/wasm/*',
          dest: 'wasm'
        }
      ]
    })
  ]
});