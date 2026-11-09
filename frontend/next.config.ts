import type { NextConfig } from "next";

const config: NextConfig = {
  reactStrictMode: true,
  poweredByHeader: false,
  devIndicators: false,
  serverExternalPackages: ["undici"],
  // Los datos estáticos pesan: nunca deben empaquetarse en el trazado del servidor.
  outputFileTracingExcludes: { "*": ["public/cesium/**", ".data-cache/**", ".tile-cache/**"] },
  async headers() {
    return [
      {
        source: "/cesium/:path*",
        headers: [{ key: "Cache-Control", value: "public, max-age=604800, immutable" }],
      },
      {
        source: "/data/:path*",
        headers: [{ key: "Cache-Control", value: "public, max-age=3600, stale-while-revalidate=86400" }],
      },
    ];
  },
};

export default config;
