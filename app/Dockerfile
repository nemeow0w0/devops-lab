FROM node:26-alpine3.24


WORKDIR /app

COPY package*.json ./
RUN npm ci --omit=dev && rm -rf /usr/local/lib/node_modules/npm /usr/local/bin/npm /usr/local/bin/npx


COPY server.js ./

ENV NODE_ENV=production
ENV PORT=3355
EXPOSE 3355


HEALTHCHECK --interval=10s CMD wget -qO- http://localhost:3355/health || exit 1

USER node


CMD ["node", "server.js"]
