#!/bin/sh

HB_SERVICE_STORAGE_PATH="/var/lib/homebridge"
HB_SERVICE_NODE_EXEC_PATH="/opt/homebridge/bin/node"
HB_SERVICE_EXEC_PATH="/opt/homebridge/lib/node_modules/homebridge-config-ui-x/dist/bin/hb-service.js"

. "/opt/homebridge/source.sh"

cd "$HB_SERVICE_STORAGE_PATH"

if [ -e "$HB_SERVICE_STORAGE_PATH/package.json" ]; then
  jq empty "$HB_SERVICE_STORAGE_PATH/package.json" 2>/dev/null
  if [ "$?" != 0 ]; then
    echo "ERROR: $HB_SERVICE_STORAGE_PATH/package.json is not a valid JSON file; deleting..."
    rm -rf "$HB_SERVICE_STORAGE_PATH/package.json"
    rm -rf "$HB_SERVICE_STORAGE_PATH/package-lock.json"
    rm -rf "$HB_SERVICE_STORAGE_PATH/pnpm-lock.yaml"
    rm -rf "$HB_SERVICE_STORAGE_PATH/node_modules"
  fi
fi

if [ -e "$HB_SERVICE_STORAGE_PATH/package-lock.json" ]; then
  rm -rf "$HB_SERVICE_STORAGE_PATH/package-lock.json"
fi

if [ -e "$HB_SERVICE_STORAGE_PATH/package.json" ]; then
  CLEAN_PACKAGE_JSON="$HB_SERVICE_STORAGE_PATH/package.json.cleaned"
  if ! jq 'del(
    .dependencies["@nubisco/homebridge-tuya-local-platform"],
    .dependencies["@lbenicio/homebridge-tuya"],
    .dependencies["homebridge-tuya"],
    .dependencies["homebridge-tuya-platform"],
    .devDependencies["@nubisco/homebridge-tuya-local-platform"],
    .devDependencies["@lbenicio/homebridge-tuya"],
    .devDependencies["homebridge-tuya"],
    .devDependencies["homebridge-tuya-platform"]
  )' "$HB_SERVICE_STORAGE_PATH/package.json" > "$CLEAN_PACKAGE_JSON"; then
    echo "ERROR: failed to clean stale Tuya dependencies."
    exit 1
  fi
  mv "$CLEAN_PACKAGE_JSON" "$HB_SERVICE_STORAGE_PATH/package.json"
fi

npm --prefix "$HB_SERVICE_STORAGE_PATH" uninstall --save --ignore-scripts \
  @nubisco/homebridge-tuya-local-platform @lbenicio/homebridge-tuya homebridge-tuya homebridge-tuya-platform >/dev/null 2>&1 || true

rm -rf "$HB_SERVICE_STORAGE_PATH/node_modules/@homebridge-plugins"/.homebridge-tuya-*

CUSTOM_HOMEBRIDGE_VERSION="$(sha256sum /opt/homebridge/vendor/homebridge.tgz | cut -d ' ' -f 1)"
if [ "$(cat "$HB_SERVICE_STORAGE_PATH/.custom-homebridge-version" 2>/dev/null)" != "$CUSTOM_HOMEBRIDGE_VERSION" ]; then
  echo "Installing the Homebridge fork into the persistent plugin path..."
  if ! npm --prefix "$HB_SERVICE_STORAGE_PATH" install --no-save --omit=dev --ignore-scripts \
    /opt/homebridge/vendor/homebridge.tgz; then
    echo "ERROR: failed to install the bundled Homebridge fork."
    exit 1
  fi
  printf '%s' "$CUSTOM_HOMEBRIDGE_VERSION" > "$HB_SERVICE_STORAGE_PATH/.custom-homebridge-version"
fi

CUSTOM_TUYA_LOCAL_VERSION="$(sha256sum /opt/homebridge/vendor/tuya-local.tgz | cut -d ' ' -f 1)"
if [ "$(cat "$HB_SERVICE_STORAGE_PATH/.custom-tuya-local-version" 2>/dev/null)" != "$CUSTOM_TUYA_LOCAL_VERSION" ]; then
  echo "Installing the bundled Tuya local platform plugin..."
  if ! npm --prefix "$HB_SERVICE_STORAGE_PATH" install --save --omit=dev --ignore-scripts \
    /opt/homebridge/vendor/tuya-local.tgz; then
    echo "ERROR: failed to install the bundled Tuya local platform plugin."
    exit 1
  fi
  printf '%s' "$CUSTOM_TUYA_LOCAL_VERSION" > "$HB_SERVICE_STORAGE_PATH/.custom-tuya-local-version"
fi

if [ ! -f "$HB_SERVICE_STORAGE_PATH/node_modules/homebridge/package.json" ]; then
  cd "$HB_SERVICE_STORAGE_PATH"
  echo "Installing the bundled Homebridge fork..."
  if ! npm --prefix "$HB_SERVICE_STORAGE_PATH" install --save --omit=dev --ignore-scripts \
    /opt/homebridge/vendor/homebridge.tgz; then
    echo "ERROR: failed to install the bundled Homebridge fork."
    exit 1
  fi
fi

if [ -e "$HB_SERVICE_STORAGE_PATH/node_modules/homebridge-config-ui-x" ]; then
  rm -rf "$HB_SERVICE_STORAGE_PATH/node_modules/homebridge-config-ui-x"
fi

exec "$HB_SERVICE_NODE_EXEC_PATH" "$HB_SERVICE_EXEC_PATH" run -I -U "$HB_SERVICE_STORAGE_PATH" -P "$HB_SERVICE_STORAGE_PATH/node_modules" --strict-plugin-resolution "$@"
