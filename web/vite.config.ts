import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";
import path from "path";

export default defineConfig({
  plugins: [react()],
  base: "./",
  server: {
    host: "0.0.0.0",
    port: 5173,
    https: {
      key: path.resolve(__dirname, "certs/key.pem"),
      cert: path.resolve(__dirname, "certs/cert.pem")
    }
  },
  preview: {
    host: "0.0.0.0",
    port: 4173
  }
});
