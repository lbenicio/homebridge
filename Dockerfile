# syntax=docker/dockerfile:1

ARG BASE_IMAGE=homebridge/homebridge:2026-09-02@sha256:77c685a40911b3b95448f3550be0c8b94cd7b4e66daecc1cc39a8285be75b245

FROM node:24-bookworm-slim@sha256:0e0ff40c39bc087845bfb27465a0df4ea419520094bc35842ff83dd8cbe6f9b6 AS homebridge-build

WORKDIR /src/homebridge
COPY package.json package-lock.json ./
RUN npm ci --ignore-scripts --no-audit --no-fund
COPY . .
RUN mkdir -p /out && npm run build && npm pack --ignore-scripts --pack-destination /out

FROM node:24-bookworm-slim@sha256:0e0ff40c39bc087845bfb27465a0df4ea419520094bc35842ff83dd8cbe6f9b6 AS ui-build

ARG UI_REPO=https://github.com/lbenicio/homebridge-config-ui-x.git
ARG UI_REF=590fd6e1423d7778693c82b5a4a87f30d6812900

RUN apt-get update \
  && apt-get install --no-install-recommends -y ca-certificates git \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /src/homebridge-config-ui-x
RUN git clone --filter=blob:none "$UI_REPO" . \
  && git checkout --detach "$UI_REF"
RUN npm ci --no-audit --no-fund
RUN npm ci --prefix ui --no-audit --no-fund
RUN mkdir -p /out && npm run build && npm pack --ignore-scripts --pack-destination /out

FROM node:24-bookworm-slim@sha256:0e0ff40c39bc087845bfb27465a0df4ea419520094bc35842ff83dd8cbe6f9b6 AS tuya-local-build

WORKDIR /src/homebridge-tuya-local-platform
COPY homebridge-tuya-local-platform/package.json homebridge-tuya-local-platform/package-lock.json ./
RUN npm ci --ignore-scripts --no-audit --no-fund
COPY homebridge-tuya-local-platform/ .
RUN npm run build
RUN mkdir -p /out && npm pack --ignore-scripts --pack-destination /out \
  && mv /out/*.tgz /out/tuya-local.tgz

FROM ${BASE_IMAGE}

COPY --from=homebridge-build /out/homebridge-2.4.0.tgz /opt/homebridge/vendor/homebridge.tgz
COPY --from=ui-build /out/homebridge-config-ui-x-5.29.0.tgz /opt/homebridge/vendor/homebridge-config-ui-x.tgz
COPY --from=tuya-local-build /out/tuya-local.tgz /opt/homebridge/vendor/tuya-local.tgz
COPY docker/start.sh /opt/homebridge/start.sh

RUN npm install --global --prefix /opt/homebridge --omit=dev --ignore-scripts \
  /opt/homebridge/vendor/homebridge-config-ui-x.tgz \
  && chmod 755 /opt/homebridge/start.sh
