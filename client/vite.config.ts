import { fileURLToPath, URL } from "node:url";

import { defineConfig } from "vite";
import vue from "@vitejs/plugin-vue";
import vueDevTools from "vite-plugin-vue-devtools";
import tailwindcss from "@tailwindcss/vite";

// https://vite.dev/config/
export default defineConfig({
  plugins: [vue(), vueDevTools(), tailwindcss()],
  resolve: {
    alias: {
      "@": fileURLToPath(new URL("./src", import.meta.url)),
    },
  },
  optimizeDeps: {
    exclude: [
      "@electric-sql/pglite",
      "@electric-sql/pglite/live",
      "@electric-sql/pglite-sync",
    ],
  },
  server: {
    proxy: {
      "/api": {
        target: "http://buckitup.xyz:4403",
        changeOrigin: true,
        rewrite: (path) => path.replace(/^\/api/, ""),
      },

      // To use with cloudflare worker
      // "/api": {
      //   target: "https://buckitup.ierehon1905.workers.dev",
      //   changeOrigin: true,
      // },

      // To use with local backend
      // "/api": {
      //   target: "",
      //   changeOrigin: true,
      //   rewrite: (path) => path.replace(/^\/api/, ""),
      // },
    },
  },
});
