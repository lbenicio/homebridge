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

if [ ! -f "$HB_SERVICE_STORAGE_PATH/node_modules/homebridge/package.json" ]; then
  cd "$HB_SERVICE_STORAGE_PATH"
  echo "Re-installing homebridge..."
  npm --prefix "$HB_SERVICE_STORAGE_PATH" install --save homebridge@latest
fi

if [ -e "$HB_SERVICE_STORAGE_PATH/node_modules/homebridge-config-ui-x" ]; then
  rm -rf "$HB_SERVICE_STORAGE_PATH/node_modules/homebridge-config-ui-x"
fi

exec "$HB_SERVICE_NODE_EXEC_PATH" "$HB_SERVICE_EXEC_PATH" run -I -U "$HB_SERVICE_STORAGE_PATH" -P "$HB_SERVICE_STORAGE_PATH/node_modules" --strict-plugin-resolution "$@"
