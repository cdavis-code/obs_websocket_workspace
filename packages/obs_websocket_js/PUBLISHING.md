# npm Publishing Setup for @unngh/obs-websocket

## What Was Done

### 1. GitHub Workflow Updated ✅
- **File**: `.github/workflows/dart.yml`
- **Changes**:
  - Added tag trigger: `obs_websocket_js-v*`
  - Added `publish-npm` job that runs on tag pushes
  - Configured to publish with `--access=public`
  - Uses `NPM_TOKEN` secret for authentication

### 2. Publish Script Created ✅
- **File**: `packages/obs_websocket_js/scripts/publish-npm.sh`
- **Purpose**: Automates version bumping, building, testing, and tagging
- **Usage**: `./scripts/publish-npm.sh [major|minor|patch|version]`

### 3. README Documentation Updated ✅
- **File**: `packages/obs_websocket_js/README.md`
- **Added**: Complete "Publishing to npm" section with:
  - Script usage examples
  - Manual publishing instructions
  - GitHub Action trigger details
  - Setup requirements

## Next Steps Required

### Set Up NPM_TOKEN Secret

1. Generate an npm access token:
   ```bash
   npm token create
   ```
   - Give it a name like "GitHub Actions - obs_websocket_js"
   - Set permissions to "Publish"

2. Add the token to GitHub:
   - Go to: https://github.com/cdavis-code/obs_websocket_workspace/settings/secrets/actions
   - Click "New repository secret"
   - Name: `NPM_TOKEN`
   - Value: Paste your npm token
   - Click "Add secret"

## How to Publish Future Versions

### Option 1: Using the Script (Recommended)

```bash
cd packages/obs_websocket_js

# For bug fixes
./scripts/publish-npm.sh patch

# For new features
./scripts/publish-npm.sh minor

# For breaking changes
./scripts/publish-npm.sh major

# Then push to trigger GitHub Action
git push origin main --tags
```

### Option 2: Manual Process

```bash
cd packages/obs_websocket_js

# 1. Update version in package.json
# 2. Build
npm run build

# 3. Test
npm test

# 4. Commit and tag
git add .
git commit -m "chore: release v5.8.0"
git tag -a obs_websocket_js-v5.8.0 -m "Release v5.8.0"

# 5. Push to trigger
git push origin main --tags
```

## Workflow Behavior

When you push a tag like `obs_websocket_js-v5.8.0`:

1. **Trigger**: GitHub Actions detects the tag
2. **Build Job**: 
   - Runs `obs_websocket_js` job (lint, build, test, typecheck)
3. **Publish Job** (only if build succeeds):
   - Checks out code
   - Sets up Dart and Node.js
   - Builds the package
   - Runs `npm publish --access=public`
   - Package appears on npm registry

## Verification

After publishing, verify:
- ✅ npm: https://www.npmjs.com/package/@unngh/obs-websocket
- ✅ GitHub Actions: https://github.com/cdavis-code/obs_websocket_workspace/actions
- ✅ Install test: `npm install @unngh/obs-websocket`

## Troubleshooting

### Workflow doesn't trigger
- Check tag format: must be `obs_websocket_js-vX.Y.Z`
- Verify workflow file is on the `main` branch

### Publish fails with authentication error
- Verify `NPM_TOKEN` secret is set in GitHub
- Check token hasn't expired
- Ensure token has publish permissions

### Publish fails with version already exists
- Bump the version number
- npm doesn't allow overwriting published versions
