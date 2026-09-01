import path from "node:path";
import { fileURLToPath } from "node:url";
import { defineConfig } from "vite";

const root = path.dirname(fileURLToPath(import.meta.url));

export default defineConfig({
  root: ".",
  resolve: {
    alias: {
      "@shared": path.resolve(root, "../_shared"),
    },
  },
  server: {
    port: 5173,
    strictPort: true,
    fs: {
      allow: [root, path.resolve(root, "../_shared")],
    },
  },
});
