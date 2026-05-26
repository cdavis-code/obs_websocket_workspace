#!/bin/bash
set -e
cd "$(dirname "$0")/.."

echo "Installing Dart dependencies..."
dart pub get

echo "Compiling Dart to JavaScript..."
dart compile js -O4 -o build/dart/obs_mcp_server.js lib/obs_mcp_js.dart

echo "Copying to dist..."
mkdir -p dist
cp build/dart/obs_mcp_server.js dist/obs_mcp_server.runtime.js

# Also copy the .js.map file if it exists (for debugging)
if [ -f build/dart/obs_mcp_server.js.map ]; then
  cp build/dart/obs_mcp_server.js.map dist/obs_mcp_server.runtime.js.map
fi

# bin/obs-mcp-server.js is a hand-maintained Node.js wrapper that polyfills
# browser globals (self/window) before loading the dart2js runtime above.
# Do NOT overwrite it from build/dart/. Just keep it executable.
if [ -f bin/obs-mcp-server.js ]; then
  chmod +x bin/obs-mcp-server.js
else
  echo "WARNING: bin/obs-mcp-server.js is missing — the npm 'bin' entry will" \
       "fail. Restore it from the repository (it polyfills browser globals" \
       "before loading dist/obs_mcp_server.runtime.js)." >&2
fi

echo "Build complete!"
