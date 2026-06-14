import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  // Allow the dev server's /_next/* resources to be fetched
  allowedDevOrigins: ["localhost", "127.0.0.1", "192.168.55.116"],
};

export default nextConfig;
