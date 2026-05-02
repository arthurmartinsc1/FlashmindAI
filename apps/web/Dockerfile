# syntax=docker/dockerfile:1.7
# Imagem de DESENVOLVIMENTO do front Next.js. O docker-compose monta o código
# como volume e sobe `npm run dev` (hot reload). Para produção, refaria-se em
# multi-stage com `output: standalone` — fora de escopo deste projeto.
FROM node:20-alpine

ENV NEXT_TELEMETRY_DISABLED=1

WORKDIR /app

# libc6-compat: necessário para alguns binários nativos (lightningcss, esbuild)
RUN apk add --no-cache libc6-compat

# Instala dependências primeiro (camada cacheada enquanto package.json não mudar)
COPY package.json package-lock.json* ./
RUN npm install --no-audit --no-fund

COPY . .

EXPOSE 3000

# O compose sobrescreve CMD em dev (`npm run dev`).
CMD ["npm", "run", "dev"]
