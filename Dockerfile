FROM node:lts-alpine3.21 AS build
WORKDIR /usr/src/app

RUN npm install -g https://preview_ao.arweave.net

COPY --chown=node:node . .
RUN npm install
