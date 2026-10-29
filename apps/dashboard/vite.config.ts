/// <reference types="vitest/config" />
import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";
import { VitePWA } from "vite-plugin-pwa";

export default defineConfig({
  plugins: [
    react(),
    VitePWA({
      registerType: "autoUpdate",
      includeAssets: ["icon.svg"],
      manifest: {
        name: "LicenseLogger for Schools",
        short_name: "LicenseLogger",
        theme_color: "#0F1B2D",
        background_color: "#F6F9FC",
        display: "standalone",
        icons: [{ src: "icon.svg", sizes: "any", type: "image/svg+xml", purpose: "any maskable" }],
      },
      workbox: {
        // Never cache API/auth calls: data must always be fresh and per-user.
        navigateFallbackDenylist: [/^\/auth/],
        runtimeCaching: [],
      },
    }),
  ],
  test: {
    environment: "jsdom",
    globals: false,
    setupFiles: [],
  },
});
