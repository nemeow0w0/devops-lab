FROM node:26-alpine

WORKDIR /app

COPY package*.json ./
RUN npm ci --omit=dev

COPY server.js ./

ENV NODE_ENV=production
ENV PORT=3355
EXPOSE 3355

USER node


CMD ["node", "server.js"]