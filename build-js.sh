#!/bin/bash
set -e

gleam build --target javascript

rm -rf dist
mkdir -p dist

npx esbuild build/dev/javascript/honk/honk.mjs \
  --bundle \
  --minify \
  --format=esm \
  --outfile=dist/honk.min.js

echo "Built to dist/honk.min.js"
