import type { CapacitorConfig } from "@capacitor/cli";

const serverUrl = process.env.CAPACITOR_SERVER_URL || "https://growthepie.com";
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
          "growthepie.com",
          "*.growthepie.com",
          "growthepie.xyz",
          "*.growthepie.xyz",
        ],
      }
    : undefined,
};

export default config;
