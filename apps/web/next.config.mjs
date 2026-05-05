/** @type {import('next').NextConfig} */

// A API pode rodar em outra origem (localhost:8000 em dev, api.flashmind.app em
// prod). Sem `connect-src` explícito no CSP, o `default-src 'self'` bloqueia
// todas as requisições XHR pra outros hosts — então precisamos permitir
// explicitamente cada origem de API.
const API_URL = process.env.NEXT_PUBLIC_API_URL ?? "http://localhost:8000/api/v1";
const apiOrigin = new URL(API_URL).origin;
const wsOrigin = apiOrigin.replace(/^http/, "ws");

const connectSrc = ["'self'", apiOrigin, wsOrigin]
  // Em dev o Next.js usa ws:// pro HMR; em prod o Vercel adiciona vitals.
  .concat(process.env.NODE_ENV === "development" ? ["ws:", "wss:"] : [])
  .join(" ");

const csp = [
  "default-src 'self'",
  `connect-src ${connectSrc}`,
  "script-src 'self' 'unsafe-inline' 'unsafe-eval'",
  "style-src 'self' 'unsafe-inline'",
  "img-src 'self' data: https: blob:",
  "font-src 'self' data:",
  "frame-ancestors 'none'",
  "base-uri 'self'",
].join("; ");

// Em dev, segurança restritiva mais atrapalha do que ajuda
// (devtools, hot reload, plugins, etc). Em prod aplicamos o CSP completo.
const isDev = process.env.NODE_ENV !== "production";

const securityHeaders = [
  { key: "X-Frame-Options", value: "DENY" },
  { key: "X-Content-Type-Options", value: "nosniff" },
  { key: "Referrer-Policy", value: "strict-origin-when-cross-origin" },
  ...(isDev
    ? []
    : [
        { key: "Strict-Transport-Security", value: "max-age=63072000; includeSubDomains" },
        { key: "Content-Security-Policy", value: csp },
      ]),
];

const nextConfig = {
  reactStrictMode: true,
  poweredByHeader: false,
  transpilePackages: ["react-markdown"],
  async headers() {
    return [
      // Segurança em todas as rotas
      {
        source: "/:path*",
        headers: securityHeaders,
      },
      // Assets do Next.js com hash no nome → imutáveis para sempre
      {
        source: "/_next/static/:path*",
        headers: [
          { key: "Cache-Control", value: "public, max-age=31536000, immutable" },
        ],
      },
      // Imagens e arquivos públicos → 1 dia de cache
      {
        source: "/:file(.*\\.(?:png|jpg|jpeg|gif|webp|svg|ico|woff2?|ttf|otf))",
        headers: [
          { key: "Cache-Control", value: "public, max-age=86400, stale-while-revalidate=3600" },
        ],
      },
      // Rotas de API Next.js (se houver) → sem cache
      {
        source: "/api/:path*",
        headers: [
          { key: "Cache-Control", value: "no-store" },
        ],
      },
    ];
  },
};

export default nextConfig;
