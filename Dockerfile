# syntax=docker/dockerfile:1

ARG BASE_IMAGE=homebridge/homebridge:2026-09-02

FROM node:24-bookworm-slim AS homebridge-build

WORKDIR /src/homebridge
COPY package.json package-lock.json ./
RUN npm ci --ignore-scripts --no-audit --no-fund
COPY . .
RUN mkdir -p /out && npm run build && npm pack --ignore-scripts --pack-destination /out

FROM node:24-bookworm-slim AS ui-build

ARG UI_REPO=https://github.com/lbenicio/homebridge-config-ui-x.git
ARG UI_REF=a7bdb764686f526bb85e17d84e44e692df5404ba

RUN apt-get update \
  && apt-get install --no-install-recommends -y ca-certificates git \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /src/homebridge-config-ui-x
RUN git clone --filter=blob:none "$UI_REPO" . \
  && git checkout --detach "$UI_REF"
RUN npm ci --no-audit --no-fund
RUN npm ci --prefix ui --no-audit --no-fund
RUN mkdir -p /out && npm run build && npm pack --ignore-scripts --pack-destination /out

FROM ${BASE_IMAGE}

COPY --from=homebridge-build /out/homebridge-2.4.0.tgz /opt/homebridge/vendor/homebridge.tgz
COPY --from=ui-build /out/homebridge-config-ui-x-5.29.0.tgz /opt/homebridge/vendor/homebridge-config-ui-x.tgz
COPY docker/start.sh /opt/homebridge/start.sh

RUN npm install --global --prefix /opt/homebridge --omit=dev --ignore-scripts \
  /opt/homebridge/vendor/homebridge-config-ui-x.tgz \
  && chmod 755 /opt/homebridge/start.sh
