/// <reference types="vitest/config" />
import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";
import { VitePWA } from "vite-plugin-pwa";

export default defineConfig({
  plugins: [
    react(),
    VitePWA({
      // prompt so instructors aren't mid-lesson when SW swaps (TT pattern)
      registerType: "prompt",
      includeAssets: ["icon.svg", "icon-192.png", "icon-512.png", "icon-192-maskable.png", "icon-512-maskable.png"],
      manifest: {
        name: "LicenseLogger for Schools",
        short_name: "LicenseLogger",
        description: "Driving school desk — board, plan, students, sign-offs.",
        theme_color: "#0F1B2D",
        background_color: "#F6F9FC",
        display: "standalone",
        start_url: "/",
        icons: [
          { src: "icon-192.png", sizes: "192x192", type: "image/png", purpose: "any" },
          { src: "icon-512.png", sizes: "512x512", type: "image/png", purpose: "any" },
          { src: "icon-192-maskable.png", sizes: "192x192", type: "image/png", purpose: "maskable" },
          { src: "icon-512-maskable.png", sizes: "512x512", type: "image/png", purpose: "maskable" },
          { src: "icon.svg", sizes: "any", type: "image/svg+xml", purpose: "any" },
        ],
      },
      workbox: {
        navigateFallbackDenylist: [/^\/auth/],
        runtimeCaching: [
          {
            urlPattern: ({ url }) =>
              url.hostname.endsWith("supabase.co") ||
              url.pathname.startsWith("/auth") ||
              url.pathname.includes("/rest/v1") ||
              url.pathname.includes("/functions/v1"),
            handler: "NetworkOnly",
          },
          {
            urlPattern: ({ request }) => request.destination === "image",
            handler: "StaleWhileRevalidate",
            options: { cacheName: "ll-images", expiration: { maxEntries: 64 } },
          },
        ],
      },
    }),
  ],
  test: {
    environment: "jsdom",
    globals: false,
    setupFiles: [],
    alias: {
      "virtual:pwa-register/react": "/src/test/stubs/pwa-register.ts",
    },
  },
  resolve: {
    alias: {
      // build still uses plugin virtual; tests override above
    },
  },
});
