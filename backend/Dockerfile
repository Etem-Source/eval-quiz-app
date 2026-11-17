FROM node:20-alpine

ENV NODE_ENV=production
WORKDIR /app

COPY package*.json ./
RUN apk add --no-cache tini && npm install --omit=dev && npm cache clean --force

COPY --chown=node:node server.js ./

USER node
EXPOSE 3007

HEALTHCHECK --interval=30s --timeout=3s CMD wget -qO- http://localhost:3007/health || exit 1

ENTRYPOINT ["/sbin/tini", "--"]
CMD ["node", "server.js"]