import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  logging: {
    // Invention labels and content must not enter development action traces.
    serverFunctions: false,
  },
};

export default nextConfig;
