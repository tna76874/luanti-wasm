import { defineConfig } from 'vite'
import { resolve, basename } from 'path'
import fs from 'fs'
import path from 'path'

// UUID von Environment oder aus www-Verzeichnis auslesen
function getOrFindReleaseUUID() {
  if (process.env.RELEASE_UUID) {
    console.log(`✓ RELEASE_UUID from env: ${process.env.RELEASE_UUID}`)
    return process.env.RELEASE_UUID
  }

  // Fallback: Versuche UUID aus ../www/{UUID} zu finden
  const wwwParent = resolve(__dirname, '../www')
  if (fs.existsSync(wwwParent)) {
    const dirs = fs.readdirSync(wwwParent, { withFileTypes: true })
    for (const dir of dirs) {
      if (dir.isDirectory() && dir.name.match(/^[a-f0-9]{12}$/)) {
        console.log(`✓ RELEASE_UUID from ../www: ${dir.name}`)
        return dir.name
      }
    }
  }

  console.warn('⚠ RELEASE_UUID not found, using "dev"')
  return 'dev'
}

const RELEASE_UUID = getOrFindReleaseUUID()

export default defineConfig({
  root: resolve(__dirname, '../www'),

  build: {
    // Output direkt in custom_frontend/dist
    outDir: resolve(__dirname, 'dist'),
    emptyOutDir: true,
    minify: 'terser',

    rollupOptions: {
      input: resolve(__dirname, '../www/index.html'),
      output: {
        dir: resolve(__dirname, 'dist'),
        format: 'es',
      },
    },

    // Kopiere alles außer index.html 1:1
    copyPublicDir: false,
  },

  // Plugins für Static File Handling
  plugins: [
    {
      name: 'copy-static-files',
      generateBundle() {
        // Kopiere www/{UUID} und alles andere außer index.html
        const wwwDir = resolve(__dirname, '../www')
        const distDir = resolve(__dirname, 'dist')

        // Stelle sicher dass dist existiert
        if (!fs.existsSync(distDir)) {
          fs.mkdirSync(distDir, { recursive: true })
        }

        // Kopiere alle Verzeichnisse und Dateien außer index.html
        const copyRecursive = (src, dst) => {
          if (!fs.existsSync(dst)) {
            fs.mkdirSync(dst, { recursive: true })
          }

          const files = fs.readdirSync(src)
          for (const file of files) {
            if (file === 'index.html') {
              // Überspringe index.html - wird von Vite generiert
              continue
            }

            const srcPath = path.join(src, file)
            const dstPath = path.join(dst, file)
            const stat = fs.statSync(srcPath)

            if (stat.isDirectory()) {
              copyRecursive(srcPath, dstPath)
            } else {
              fs.copyFileSync(srcPath, dstPath)
            }
          }
        }

        console.log(`📋 Kopiere static files (außer index.html)...`)
        copyRecursive(wwwDir, distDir)
        console.log(`✓ Static files kopiert`)
      },
    },
  ],

  define: {
    __RELEASE_UUID__: JSON.stringify(RELEASE_UUID),
  },

  server: {
    port: 3000,
    open: true,
  },
})
