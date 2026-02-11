import type { CapacitorConfig } from "@capacitor/cli";

// Keep simulator/dev deterministic by defaulting to localhost.
// Use CAPACITOR_SERVER_URL to point to hosted environments when needed.
const serverUrl = process.env.CAPACITOR_SERVER_URL || "http://localhost:3000";
const useHostedServer = /^https?:\/\//.test(serverUrl);

const config: CapacitorConfig = {
  appId: "com.growthepie.mobile",
  appName: "growthepie",
  webDir: "capacitor-web",
  bundledWebRuntime: false,
  server: useHostedServer
    ? {
        url: serverUrl,
        cleartext: serverUrl.startsWith("http://"),
        allowNavigation: [
          "localhost",
          "127.0.0.1",
          "growthepie.com",
          "*.growthepie.com",
          "growthepie.xyz",
          "*.growthepie.xyz",
        ],
      }
    : undefined,
};

export default config;
