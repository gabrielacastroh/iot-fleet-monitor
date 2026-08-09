import { fileURLToPath, URL } from "node:url";
import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";
import tailwindcss from "@tailwindcss/vite";

// https://vite.dev/config/
export default defineConfig({
  plugins: [react(), tailwindcss()],
  resolve: {
    alias: {
      "@": fileURLToPath(new URL("./src", import.meta.url)),
    },
  },
  // maplibre-gl loads its own worker as a separate module at runtime; Vite's
  // esbuild pre-bundler doesn't follow that reference, so the worker chunk
  // 404s in dev and the map never initializes (blank canvas, no error).
  // Excluding it from optimizeDeps leaves the package's own build untouched.
  optimizeDeps: {
    exclude: ["maplibre-gl"],
  },
});
