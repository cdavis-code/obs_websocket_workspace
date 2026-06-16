#!/bin/bash

# Script to publish a new version of @unngh/obs-websocket to npm
# Usage: ./scripts/publish-npm.sh [major|minor|patch|version]

set -e

PACKAGE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PACKAGE_DIR"

# Get current version
CURRENT_VERSION=$(node -p "require('./package.json').version")
echo "Current version: $CURRENT_VERSION"

# Determine new version
if [ -z "$1" ]; then
  echo "Usage: $0 [major|minor|patch|<version>]"
  echo "  major  - Bump major version (1.0.0 -> 2.0.0)"
  echo "  minor  - Bump minor version (1.0.0 -> 1.1.0)"
  echo "  patch  - Bump patch version (1.0.0 -> 1.0.1)"
  echo "  <version> - Set specific version (e.g., 5.8.0)"
  exit 1
fi

if [[ "$1" == "major" || "$1" == "minor" || "$1" == "patch" ]]; then
  NEW_VERSION=$(npm version --no-git-tag-version $1)
else
  NEW_VERSION=$(npm version --no-git-tag-version "$1")
fi

NEW_VERSION=${NEW_VERSION#v}
echo "New version: $NEW_VERSION"

# Build the package
echo ""
echo "🔨 Building package..."
npm run build

# Run tests
echo ""
echo "🧪 Running tests..."
npm test

# Create git tag
echo ""
echo "📝 Creating git tag..."
git add package.json
git commit -m "chore(obs_websocket_js): release v$NEW_VERSION"
git tag -a "obs_websocket_js-v$NEW_VERSION" -m "Release obs_websocket_js v$NEW_VERSION"

echo ""
echo "✅ Version $NEW_VERSION ready!"
echo ""
echo "To publish:"
echo "  1. Push to GitHub: git push origin main --tags"
echo "  2. GitHub Actions will automatically publish to npm"
echo ""
echo "Or publish manually:"
echo "  npm publish --access=public"
