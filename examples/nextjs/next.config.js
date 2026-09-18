/** @type {import('next').NextConfig} */
const nextConfig = {
  // Standalone output copies only the needed files into .next/standalone,
  // which is what the production stage of the Dockerfile ships.
  output: "standalone",
};

module.exports = nextConfig;
