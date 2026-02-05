# VoiceFlow Plugin Packaging & Distribution Guide

## ⚠️ Distribution Security Notice

**CRITICAL: When distributing plugins, you are responsible for user safety.** Recipients will be installing your code with full system access. Before distributing:

- **Review all dependencies** for known vulnerabilities
- **Pin dependency versions** to avoid supply chain attacks
- **Sign your releases** (when tooling becomes available)
- **Provide source code** alongside binaries for transparency
- **Document security implications** of any network access or file system usage

**Never distribute plugins containing:**
- Hardcoded credentials or API keys
- Obfuscated code without clear explanation
- Unvetted third-party dependencies
- Backdoors or telemetry without explicit user consent

---

## Table of Contents

1. [Overview](#overview)
2. [Directory Structure Requirements](#directory-structure-requirements)
3. [Dependency Management](#dependency-management)
4. [Versioning Best Practices](#versioning-best-practices)
5. [Distribution Formats](#distribution-formats)
6. [Packaging Workflow](#packaging-workflow)
7. [Installation Instructions](#installation-instructions)
8. [Changelog & Release Notes](#changelog--release-notes)
9. [Distribution Checklist](#distribution-checklist)
10. [Troubleshooting](#troubleshooting)

---

## Overview

Plugin packaging prepares your VoiceFlow plugin for distribution to other users. A well-packaged plugin includes all necessary files, clear documentation, and properly managed dependencies.

### What Gets Packaged?

- **Required:**
  - `manifest.json` - Plugin metadata and configuration
  - Entry point file (`plugin.swift` or `plugin.py`)
  - `README.md` - Installation and usage instructions

- **Optional but Recommended:**
  - `LICENSE` - Software license (MIT, Apache 2.0, etc.)
  - `CHANGELOG.md` - Version history
  - `requirements.txt` (Python) - Python dependencies
  - `Package.swift` (Swift) - Swift package dependencies
  - Additional source files (helpers, utilities)
  - `tests/` - Unit tests for verification

### Distribution Goals

1. **Self-contained** - All dependencies bundled or documented
2. **Reproducible** - Users get identical behavior across installations
3. **Transparent** - Source code and dependencies are reviewable
4. **Documented** - Clear installation and usage instructions
5. **Versioned** - Proper semantic versioning for updates

---

## Directory Structure Requirements

### Minimal Plugin Structure

```
MyPlugin/
├── manifest.json          # Required: Plugin metadata
├── plugin.swift           # Required: Entry point (Swift)
└── README.md              # Recommended: Documentation
```

### Recommended Plugin Structure

```
MyPlugin/
├── manifest.json          # Plugin metadata
├── plugin.swift           # Entry point (Swift example)
├── README.md              # Installation & usage guide
├── LICENSE                # Software license
├── CHANGELOG.md           # Version history
├── Package.swift          # Swift dependencies (if any)
├── Sources/               # Additional Swift modules (optional)
│   ├── Helpers/
│   │   └── TextUtils.swift
│   └── Models/
│       └── Config.swift
└── tests/                 # Unit tests (optional)
    └── MyPluginTests.swift
```

### Python Plugin Structure

```
MyPythonPlugin/
├── manifest.json          # Plugin metadata
├── plugin.py              # Entry point
├── README.md              # Documentation
├── LICENSE                # Software license
├── CHANGELOG.md           # Version history
├── requirements.txt       # Python dependencies
├── src/                   # Additional modules (optional)
│   ├── __init__.py
│   ├── helpers.py
│   └── config.py
└── tests/                 # Unit tests (optional)
    ├── __init__.py
    └── test_plugin.py
```

### Complex Plugin with Resources

```
AdvancedPlugin/
├── manifest.json
├── plugin.swift
├── README.md
├── LICENSE
├── CHANGELOG.md
├── Package.swift
├── Sources/
│   └── AdvancedPlugin/
│       ├── Plugin.swift
│       ├── NetworkClient.swift
│       └── DataProcessor.swift
├── Resources/             # Configuration files
│   ├── config.json
│   ├── models/
│   │   └── language_model.dat
│   └── dictionaries/
│       └── custom_words.txt
├── tests/
│   └── AdvancedPluginTests.swift
└── docs/                  # Additional documentation
    ├── ARCHITECTURE.md
    └── API.md
```

### Critical Rules

1. **Root directory name** must match plugin name (no spaces, use hyphens)
2. **manifest.json** must be in the root directory
3. **Entry point file** path must match `entrypoint` field in manifest
4. **No absolute paths** - all resource references must be relative
5. **Case sensitivity** - macOS filesystem is case-insensitive but preserve case for cross-platform compatibility

---

## Dependency Management

### Swift Dependencies

VoiceFlow plugins can use Swift Package Manager (SPM) dependencies, but they must be **statically linked** or **bundled**.

#### Declaring Swift Dependencies

Create `Package.swift` in your plugin root:

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MyPlugin",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "MyPlugin", targets: ["MyPlugin"])
    ],
    dependencies: [
        // Declare dependencies here
        .package(url: "https://github.com/Alamofire/Alamofire.git", from: "5.8.0"),
        .package(url: "https://github.com/SwiftyJSON/SwiftyJSON.git", from: "5.0.0")
    ],
    targets: [
        .target(
            name: "MyPlugin",
            dependencies: ["Alamofire", "SwiftyJSON"]
        )
    ]
)
```

#### Bundling Swift Dependencies

**Option 1: Static Linking (Recommended)**

Build your plugin as a static library with dependencies embedded:

```bash
swift build -c release --static-swift-stdlib
```

**Option 2: Document Dependencies**

In `manifest.json`:

```json
{
  "dependencies": {
    "swift": [
      {
        "name": "Alamofire",
        "version": "5.8.0",
        "url": "https://github.com/Alamofire/Alamofire.git"
      }
    ]
  }
}
```

And in your `README.md`, instruct users to install dependencies.

#### ⚠️ Swift Dependency Warnings

- **Version conflicts**: Multiple plugins may require different versions of the same package
- **No current isolation**: VoiceFlow loads all plugins in the same process - dependency conflicts will cause crashes
- **Mitigation**: Pin exact versions and test with common plugins before distribution

### Python Dependencies

Python plugins use `pip` for dependency management.

#### Declaring Python Dependencies

Create `requirements.txt`:

```txt
# Core dependencies with pinned versions
requests==2.31.0
nltk==3.8.1
numpy==1.24.3

# Optional dependencies
# pandas==2.0.3

# Development dependencies (not needed for distribution)
# pytest==7.4.0
# black==23.7.0
```

#### Bundling Python Dependencies

**Option 1: Vendoring (Recommended for Simple Plugins)**

Bundle dependencies directly in your plugin:

```bash
# Create vendor directory
mkdir -p MyPlugin/vendor

# Install dependencies to vendor directory
pip install -r requirements.txt --target MyPlugin/vendor

# Update plugin code to use vendored dependencies
```

In `plugin.py`:

```python
import sys
import os

# Add vendor directory to path
vendor_dir = os.path.join(os.path.dirname(__file__), 'vendor')
if vendor_dir not in sys.path:
    sys.path.insert(0, vendor_dir)

# Now import dependencies
import requests
import nltk
```

**Option 2: Virtual Environment (Advanced)**

Document in README:

```markdown
## Installation

1. Create virtual environment:
   ```bash
   cd ~/Library/Application\ Support/VoiceFlow/Plugins/MyPlugin
   python3 -m venv .venv
   source .venv/bin/activate
   ```

2. Install dependencies:
   ```bash
   pip install -r requirements.txt
   ```

3. Configure VoiceFlow to use this virtual environment (if supported)
```

**Option 3: System-Wide Installation**

In `README.md`:

```markdown
## Prerequisites

Install required Python packages:

```bash
pip3 install -r requirements.txt
```

**Note:** This installs packages globally and may conflict with other applications.
```

#### Python Dependency Manifest

In `manifest.json`:

```json
{
  "dependencies": {
    "python": [
      {
        "name": "requests",
        "version": "2.31.0",
        "purpose": "HTTP client for webhook integration"
      },
      {
        "name": "nltk",
        "version": "3.8.1",
        "purpose": "Natural language processing"
      }
    ]
  }
}
```

#### ⚠️ Python Dependency Warnings

- **Global namespace pollution**: System-wide pip installs affect all Python applications
- **Version conflicts**: Different plugins may require incompatible versions
- **Binary dependencies**: Packages with C extensions (numpy, scipy) may fail on different macOS versions
- **Mitigation**: Use vendoring for simple dependencies, document exact Python version requirements

### Dependency Conflict Resolution

#### Detection

Before distributing, test with common plugins:

```bash
# Install your plugin alongside popular plugins
cd ~/Library/Application\ Support/VoiceFlow/Plugins/

# Test loading
# Check Console.app for dependency errors
```

#### Prevention Strategies

1. **Minimize dependencies** - Only include what's absolutely necessary
2. **Pin exact versions** - Use `==` not `>=` in requirements.txt
3. **Namespace vendored code** - Rename vendored packages to avoid collisions
4. **Document conflicts** - Maintain a compatibility matrix in README

Example compatibility matrix:

```markdown
## Known Compatibility Issues

| Plugin | Version | Conflict | Solution |
|--------|---------|----------|----------|
| ChinesePunctuationPlugin | 1.x | nltk version mismatch | Use vendored NLTK |
| WebhookPlugin | 2.x | requests 3.x incompatible | Stay on requests 2.x |
```

---

## Versioning Best Practices

### Semantic Versioning

VoiceFlow plugins **must** use [Semantic Versioning 2.0.0](https://semver.org/):

```
MAJOR.MINOR.PATCH
```

- **MAJOR**: Incompatible API changes (breaking changes)
- **MINOR**: New functionality (backward-compatible)
- **PATCH**: Bug fixes (backward-compatible)

### Version Examples

```json
// Initial release
{"version": "1.0.0"}

// Bug fix (text processing edge case)
{"version": "1.0.1"}

// New feature (add configuration option)
{"version": "1.1.0"}

// Breaking change (rename plugin ID, change API)
{"version": "2.0.0"}
```

### Version Manifest Requirements

In `manifest.json`:

```json
{
  "version": "1.2.3",
  "minVoiceFlowVersion": "1.0.0",
  "changelog": "https://github.com/yourname/yourplugin/blob/main/CHANGELOG.md"
}
```

### Pre-release Versions

For beta testing:

```json
{"version": "1.2.0-beta.1"}
{"version": "1.2.0-rc.2"}
{"version": "2.0.0-alpha.3"}
```

### Version Bumping Checklist

Before incrementing version:

- [ ] **PATCH**: Bug fixes only, no new features
  - Update `version` in `manifest.json`
  - Add entry to `CHANGELOG.md`
  - Tag git commit: `git tag v1.0.1`

- [ ] **MINOR**: New features, backward-compatible
  - Update `version` in `manifest.json`
  - Update `README.md` with new feature docs
  - Add entry to `CHANGELOG.md`
  - Tag git commit: `git tag v1.1.0`

- [ ] **MAJOR**: Breaking changes
  - Update `version` in `manifest.json`
  - Create migration guide in `MIGRATION.md`
  - Update all documentation
  - Add prominent changelog entry
  - Tag git commit: `git tag v2.0.0`

---

## Distribution Formats

### Format Comparison

| Format | Use Case | Pros | Cons |
|--------|----------|------|------|
| **ZIP** | Simple distribution | Universal compatibility | No permissions preserved |
| **TAR.GZ** | Unix/macOS native | Preserves permissions, smaller | Windows compatibility issues |
| **Git Repository** | Open source | Version history, easy updates | Requires git knowledge |
| **DMG** | macOS installer | Professional appearance | Overkill for plugins |

### Recommended: TAR.GZ for Distribution

#### Creating a Release Archive

```bash
#!/bin/bash
# package.sh - Create distributable plugin archive

PLUGIN_NAME="MyPlugin"
VERSION="1.0.0"
ARCHIVE_NAME="${PLUGIN_NAME}-${VERSION}.tar.gz"

# Navigate to plugin directory
cd ~/MyPluginDevelopment/${PLUGIN_NAME}

# Create archive excluding dev files
tar -czf "../${ARCHIVE_NAME}" \
  --exclude=".git" \
  --exclude=".DS_Store" \
  --exclude="*.swp" \
  --exclude="__pycache__" \
  --exclude=".pytest_cache" \
  --exclude="vendor" \
  --exclude=".venv" \
  .

echo "✅ Created ${ARCHIVE_NAME}"
echo "📦 Size: $(du -h ../${ARCHIVE_NAME} | cut -f1)"

# Verify archive contents
echo "📋 Contents:"
tar -tzf "../${ARCHIVE_NAME}" | head -20
```

#### Archive Contents Verification

```bash
# Extract to temporary directory and verify
mkdir -p /tmp/verify
tar -xzf MyPlugin-1.0.0.tar.gz -C /tmp/verify

# Check required files
test -f /tmp/verify/manifest.json && echo "✅ manifest.json"
test -f /tmp/verify/plugin.swift && echo "✅ plugin.swift"
test -f /tmp/verify/README.md && echo "✅ README.md"

# Validate manifest
python3 -c "
import json, jsonschema
schema = json.load(open('manifest-schema.json'))
manifest = json.load(open('/tmp/verify/manifest.json'))
jsonschema.validate(manifest, schema)
print('✅ manifest.json is valid')
"
```

### ZIP Alternative (Cross-Platform)

```bash
# Create ZIP archive
zip -r MyPlugin-1.0.0.zip . \
  -x "*.git*" \
  -x "*__pycache__*" \
  -x "*.DS_Store" \
  -x "*.venv*"

# Verify
unzip -l MyPlugin-1.0.0.zip
```

### Git Repository Distribution

For open-source plugins:

```bash
# Tag release
git tag -a v1.0.0 -m "Release version 1.0.0"
git push origin v1.0.0

# Create GitHub release with tarball
gh release create v1.0.0 \
  --title "MyPlugin v1.0.0" \
  --notes "See CHANGELOG.md for details" \
  MyPlugin-1.0.0.tar.gz
```

### Checksum Generation

Always provide checksums for verification:

```bash
# Generate SHA-256 checksum
shasum -a 256 MyPlugin-1.0.0.tar.gz > MyPlugin-1.0.0.tar.gz.sha256

# Verify later
shasum -a 256 -c MyPlugin-1.0.0.tar.gz.sha256
```

---

## Packaging Workflow

### Step-by-Step Packaging Process

#### 1. Pre-Packaging Cleanup

```bash
#!/bin/bash
# clean.sh - Prepare for packaging

# Remove build artifacts
rm -rf .build/
rm -rf build/
rm -rf dist/

# Remove Python cache
find . -type d -name "__pycache__" -exec rm -rf {} +
find . -type f -name "*.pyc" -delete

# Remove editor files
find . -type f -name ".DS_Store" -delete
find . -type f -name "*.swp" -delete
find . -type f -name "*~" -delete

# Remove development configs
rm -rf .venv/
rm -f .env
rm -f .env.local

echo "✅ Cleanup complete"
```

#### 2. Version Update

```bash
#!/bin/bash
# bump-version.sh - Update version across files

OLD_VERSION="1.0.0"
NEW_VERSION="1.1.0"

# Update manifest.json
sed -i '' "s/\"version\": \"$OLD_VERSION\"/\"version\": \"$NEW_VERSION\"/" manifest.json

# Update README.md (if version mentioned)
sed -i '' "s/version $OLD_VERSION/version $NEW_VERSION/g" README.md

echo "✅ Version bumped to $NEW_VERSION"
```

#### 3. Dependency Bundling

```bash
# For Python plugins with vendoring
pip install -r requirements.txt --target vendor/ --upgrade

# For Swift plugins (if bundling)
swift build -c release
```

#### 4. Testing

```bash
# Run plugin tests
./scripts/test.sh

# Validate manifest
python3 -c "
import json, jsonschema
schema = json.load(open('manifest-schema.json'))
manifest = json.load(open('manifest.json'))
jsonschema.validate(manifest, schema)
print('✅ Valid manifest')
"

# Test installation
cp -r . ~/Library/Application\ Support/VoiceFlow/Plugins/TestInstall/
# Launch VoiceFlow and verify plugin loads
```

#### 5. Create Archive

```bash
# Package with timestamp
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
PLUGIN_NAME=$(jq -r '.name' manifest.json | tr ' ' '-')
VERSION=$(jq -r '.version' manifest.json)

tar -czf "${PLUGIN_NAME}-${VERSION}.tar.gz" \
  --exclude=".git" \
  --exclude="__pycache__" \
  --exclude=".DS_Store" \
  .

# Generate checksum
shasum -a 256 "${PLUGIN_NAME}-${VERSION}.tar.gz" > "${PLUGIN_NAME}-${VERSION}.tar.gz.sha256"
```

#### 6. Distribution

```bash
# Upload to GitHub releases
gh release create "v${VERSION}" \
  --title "${PLUGIN_NAME} v${VERSION}" \
  --notes-file CHANGELOG.md \
  "${PLUGIN_NAME}-${VERSION}.tar.gz" \
  "${PLUGIN_NAME}-${VERSION}.tar.gz.sha256"

# Or upload to custom server
scp "${PLUGIN_NAME}-${VERSION}.tar.gz" user@example.com:/var/www/plugins/
```

### Automated Packaging Script

Complete `package.sh` script:

```bash
#!/bin/bash
set -e

# Configuration
PLUGIN_DIR="."
MANIFEST="manifest.json"

# Extract metadata
PLUGIN_NAME=$(jq -r '.name' "$MANIFEST" | tr ' ' '-')
VERSION=$(jq -r '.version' "$MANIFEST")
ARCHIVE_NAME="${PLUGIN_NAME}-${VERSION}.tar.gz"

echo "📦 Packaging ${PLUGIN_NAME} v${VERSION}"

# Step 1: Cleanup
echo "🧹 Cleaning..."
find . -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
find . -type f -name "*.pyc" -delete 2>/dev/null || true
find . -type f -name ".DS_Store" -delete 2>/dev/null || true

# Step 2: Validate manifest
echo "✅ Validating manifest..."
python3 -c "
import json, jsonschema
schema = json.load(open('../../manifest-schema.json'))
manifest = json.load(open('$MANIFEST'))
jsonschema.validate(manifest, schema)
print('  ✓ Manifest is valid')
" || { echo "❌ Manifest validation failed"; exit 1; }

# Step 3: Run tests (if test command exists)
if [ -f "run_tests.sh" ]; then
  echo "🧪 Running tests..."
  ./run_tests.sh || { echo "❌ Tests failed"; exit 1; }
fi

# Step 4: Create archive
echo "📦 Creating archive..."
tar -czf "../${ARCHIVE_NAME}" \
  --exclude=".git" \
  --exclude=".gitignore" \
  --exclude="__pycache__" \
  --exclude=".DS_Store" \
  --exclude="*.swp" \
  --exclude=".pytest_cache" \
  --exclude=".venv" \
  --exclude="venv" \
  --exclude="run_tests.sh" \
  --exclude="package.sh" \
  .

# Step 5: Generate checksum
echo "🔐 Generating checksum..."
cd ..
shasum -a 256 "${ARCHIVE_NAME}" > "${ARCHIVE_NAME}.sha256"

# Step 6: Report
echo ""
echo "✅ Packaging complete!"
echo "📦 Archive: ${ARCHIVE_NAME}"
echo "📊 Size: $(du -h ${ARCHIVE_NAME} | cut -f1)"
echo "🔐 SHA-256: $(cat ${ARCHIVE_NAME}.sha256)"
echo ""
echo "Next steps:"
echo "1. Test installation: tar -xzf ${ARCHIVE_NAME}"
echo "2. Create git tag: git tag v${VERSION}"
echo "3. Push tag: git push origin v${VERSION}"
echo "4. Create GitHub release and upload ${ARCHIVE_NAME}"
```

---

## Installation Instructions

### For Users: Installing a Plugin

Provide these instructions in your `README.md`:

#### Method 1: Manual Installation (Recommended)

```markdown
## Installation

1. **Download the latest release:**
   - Download `MyPlugin-1.0.0.tar.gz` from [Releases](https://github.com/yourname/myplugin/releases)
   - Verify checksum (optional but recommended):
     ```bash
     shasum -a 256 -c MyPlugin-1.0.0.tar.gz.sha256
     ```

2. **Extract the archive:**
   ```bash
   mkdir -p ~/Library/Application\ Support/VoiceFlow/Plugins/
   cd ~/Library/Application\ Support/VoiceFlow/Plugins/
   tar -xzf ~/Downloads/MyPlugin-1.0.0.tar.gz
   ```

3. **Install dependencies (Python plugins only):**
   ```bash
   cd MyPlugin
   pip3 install -r requirements.txt
   ```

4. **Restart VoiceFlow:**
   - Quit VoiceFlow completely
   - Relaunch VoiceFlow
   - Go to Preferences → Plugins
   - Enable "MyPlugin"

5. **Verify installation:**
   - Speak into VoiceFlow
   - Check that your plugin processes the text as expected
   - Check Console.app for any error messages
```

#### Method 2: Git Clone (For Developers)

```markdown
## Development Installation

For developers who want to contribute or modify the plugin:

```bash
cd ~/Library/Application\ Support/VoiceFlow/Plugins/
git clone https://github.com/yourname/myplugin.git MyPlugin
cd MyPlugin
pip3 install -r requirements.txt  # Python only
```

Now you can edit the plugin code directly and restart VoiceFlow to test changes.
```

#### Method 3: CLI Toolkit (If Available)

```markdown
## Installation via VoiceFlow CLI

If you have the VoiceFlow plugin development tools installed:

```bash
# Install from archive
voiceflow-plugin install MyPlugin-1.0.0.tar.gz

# Or install from GitHub
voiceflow-plugin install --github yourname/myplugin

# Or install from local directory
voiceflow-plugin install /path/to/MyPlugin
```
```

### Uninstallation Instructions

```markdown
## Uninstallation

1. **Disable the plugin:**
   - Open VoiceFlow Preferences → Plugins
   - Uncheck "MyPlugin"
   - Restart VoiceFlow

2. **Remove plugin files:**
   ```bash
   rm -rf ~/Library/Application\ Support/VoiceFlow/Plugins/MyPlugin
   ```

3. **Remove dependencies (Python plugins):**
   ```bash
   pip3 uninstall -r requirements.txt
   ```

   **Note:** Only run this if no other plugins use these dependencies.
```

### Upgrade Instructions

```markdown
## Upgrading

To upgrade from an older version:

1. **Backup your configuration (if applicable):**
   ```bash
   cp ~/Library/Application\ Support/VoiceFlow/Plugins/MyPlugin/config.json ~/config-backup.json
   ```

2. **Remove old version:**
   ```bash
   rm -rf ~/Library/Application\ Support/VoiceFlow/Plugins/MyPlugin
   ```

3. **Install new version:**
   Follow the installation instructions above

4. **Restore configuration:**
   ```bash
   cp ~/config-backup.json ~/Library/Application\ Support/VoiceFlow/Plugins/MyPlugin/config.json
   ```

5. **Check for breaking changes:**
   Review [CHANGELOG.md](CHANGELOG.md) for migration notes
```

---

## Changelog & Release Notes

### CHANGELOG.md Format

Follow [Keep a Changelog](https://keepachangelog.com/) format:

```markdown
# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Feature X is being developed

## [1.1.0] - 2024-03-15

### Added
- New configuration option for custom punctuation marks
- Support for emoji insertion
- Debug logging mode

### Changed
- Improved text processing performance by 50%
- Updated NLTK dependency to 3.8.1

### Fixed
- Fixed crash when processing empty strings
- Corrected Unicode handling for Chinese characters

### Deprecated
- `oldConfigFormat` will be removed in v2.0.0 - use `newConfigFormat` instead

## [1.0.1] - 2024-02-20

### Fixed
- Fixed memory leak in text processing loop
- Corrected manifest.json version field

## [1.0.0] - 2024-02-01

### Added
- Initial release
- Basic text transformation
- Manifest-based configuration
- Swift and Python implementations

[Unreleased]: https://github.com/yourname/myplugin/compare/v1.1.0...HEAD
[1.1.0]: https://github.com/yourname/myplugin/compare/v1.0.1...v1.1.0
[1.0.1]: https://github.com/yourname/myplugin/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/yourname/myplugin/releases/tag/v1.0.0
```

### Release Notes Template

For GitHub releases:

```markdown
## MyPlugin v1.1.0 - "Emoji Support" Release

### 🎉 What's New

- **Emoji Insertion**: Automatically add contextual emojis to your transcriptions
- **Custom Punctuation**: Configure your own punctuation preferences
- **Debug Mode**: Enable verbose logging for troubleshooting

### 🔧 Improvements

- 50% faster text processing through optimized algorithms
- Better Unicode handling for international characters
- Updated dependencies for improved security

### 🐛 Bug Fixes

- Fixed crash when processing empty strings (#42)
- Resolved memory leak in long-running sessions (#38)
- Corrected Chinese character encoding issues (#35)

### ⚠️ Breaking Changes

None - this is a backward-compatible release.

### 📦 Installation

Download `MyPlugin-1.1.0.tar.gz` and follow the [installation guide](README.md#installation).

**Checksum (SHA-256):**
```
a1b2c3d4e5f6... MyPlugin-1.1.0.tar.gz
```

### 🙏 Contributors

Thanks to @contributor1, @contributor2 for their contributions!

### 📚 Documentation

- [Full Changelog](CHANGELOG.md)
- [Migration Guide](MIGRATION.md) (if upgrading from v1.0.x)
- [API Documentation](docs/API.md)
```

### Version History Best Practices

1. **Keep changelog updated** - Add entries as you develop, not just at release time
2. **Group changes by type** - Added, Changed, Deprecated, Removed, Fixed, Security
3. **Write for users** - Explain impact, not implementation details
4. **Link to issues** - Reference GitHub issues/PRs for context
5. **Date all releases** - Use ISO 8601 format (YYYY-MM-DD)
6. **Mark breaking changes** - Use ⚠️ emoji and clear warnings

---

## Distribution Checklist

Before releasing a plugin version, verify:

### Pre-Release Checklist

- [ ] **Version updated** in `manifest.json`
- [ ] **CHANGELOG.md updated** with all changes
- [ ] **README.md accurate** (installation, configuration, usage)
- [ ] **LICENSE file present** and correct
- [ ] **Dependencies documented** in `requirements.txt` or `Package.swift`
- [ ] **Dependency versions pinned** (exact versions, not ranges)
- [ ] **Tests passing** (run full test suite)
- [ ] **Manifest validates** against schema
- [ ] **Code reviewed** for security issues
- [ ] **No hardcoded secrets** (API keys, passwords, tokens)
- [ ] **No debug code** (print statements, test data)
- [ ] **Documentation complete** (all features documented)

### Security Review Checklist

- [ ] **Dependencies scanned** for known vulnerabilities
- [ ] **Network requests documented** (what, when, why)
- [ ] **File system access documented**
- [ ] **No obfuscated code** (all code readable and reviewable)
- [ ] **Privacy policy** if collecting any data
- [ ] **Source code available** for transparency

### Packaging Checklist

- [ ] **Clean build** (removed all build artifacts)
- [ ] **Archive created** (tar.gz or zip)
- [ ] **Checksum generated** (SHA-256)
- [ ] **Archive tested** (extract and verify contents)
- [ ] **Installation tested** (clean install on fresh system)
- [ ] **Upgrade tested** (if upgrading from previous version)

### Distribution Checklist

- [ ] **Git tag created** (`git tag vX.Y.Z`)
- [ ] **Git tag pushed** (`git push origin vX.Y.Z`)
- [ ] **GitHub release created** with release notes
- [ ] **Archive uploaded** to release
- [ ] **Checksum included** in release description
- [ ] **Installation instructions** clear and tested
- [ ] **Social media announcement** (if applicable)
- [ ] **Documentation site updated** (if applicable)

---

## Troubleshooting

### Common Packaging Issues

#### Issue: Archive Too Large

**Problem:** Archive exceeds reasonable size (>50MB for simple plugins)

**Solutions:**
```bash
# Identify large files
tar -tzf MyPlugin.tar.gz | xargs -I {} sh -c 'echo $(tar -xzOf MyPlugin.tar.gz {} | wc -c) {}' | sort -rn | head -20

# Exclude large development files
tar -czf MyPlugin.tar.gz . \
  --exclude="*.mp4" \
  --exclude="*.mov" \
  --exclude="large_dataset.csv" \
  --exclude="venv"
```

#### Issue: Dependency Version Conflicts

**Problem:** Plugin dependencies conflict with system or other plugins

**Solutions:**
1. Use vendoring (bundle dependencies)
2. Pin exact versions
3. Document known conflicts in README
4. Provide conflict resolution guide

#### Issue: Manifest Validation Fails

**Problem:** Manifest doesn't validate against schema

**Solutions:**
```bash
# Detailed validation with error messages
python3 << 'EOF'
import json
import jsonschema

schema = json.load(open('manifest-schema.json'))
manifest = json.load(open('manifest.json'))

try:
    jsonschema.validate(manifest, schema)
    print("✅ Valid manifest")
except jsonschema.exceptions.ValidationError as e:
    print("❌ Validation error:")
    print(f"  Path: {' → '.join(str(p) for p in e.path)}")
    print(f"  Error: {e.message}")
    print(f"  Schema: {e.schema}")
EOF
```

#### Issue: Installation Path Errors

**Problem:** Plugin installed to wrong location

**Solution:**
```bash
# Verify correct installation path
PLUGIN_DIR="$HOME/Library/Application Support/VoiceFlow/Plugins"
echo "Plugins should be installed to: $PLUGIN_DIR"

# Create directory if missing
mkdir -p "$PLUGIN_DIR"

# Verify VoiceFlow can read the directory
ls -la "$PLUGIN_DIR"
```

#### Issue: Permission Denied Errors

**Problem:** Files have incorrect permissions after extraction

**Solution:**
```bash
# Fix permissions after extraction
chmod -R u+rw MyPlugin/
chmod u+x MyPlugin/*.sh  # If you have scripts

# When packaging, preserve permissions
tar -czpf MyPlugin.tar.gz .  # Note the 'p' flag
```

#### Issue: Missing Dependencies on User System

**Problem:** Users report missing Python/Swift dependencies

**Solutions:**

1. **Python**: Vendor dependencies or provide clear install script
   ```bash
   # install-deps.sh
   #!/bin/bash
   pip3 install -r requirements.txt --user
   ```

2. **Swift**: Bundle dependencies statically or document SPM setup
   ```markdown
   ## Build from Source

   ```bash
   swift build -c release
   cp .build/release/MyPlugin.dylib .
   ```
   ```

### Testing Your Distribution

#### Complete Distribution Test

```bash
#!/bin/bash
# test-distribution.sh - Verify packaged plugin works

set -e

ARCHIVE="MyPlugin-1.0.0.tar.gz"
TEST_DIR="/tmp/plugin-test-$$"

echo "🧪 Testing plugin distribution..."

# 1. Create clean test environment
mkdir -p "$TEST_DIR"
cd "$TEST_DIR"

# 2. Extract archive
echo "📦 Extracting archive..."
tar -xzf "$OLDPWD/$ARCHIVE"

# 3. Verify required files
echo "✅ Verifying files..."
test -f manifest.json || { echo "❌ Missing manifest.json"; exit 1; }
test -f README.md || { echo "❌ Missing README.md"; exit 1; }

# 4. Validate manifest
echo "✅ Validating manifest..."
python3 -c "
import json, jsonschema
schema = json.load(open('../../manifest-schema.json'))
manifest = json.load(open('manifest.json'))
jsonschema.validate(manifest, schema)
print('  ✓ Manifest is valid')
"

# 5. Check for common issues
echo "✅ Checking for issues..."
find . -name "*.pyc" && echo "⚠️  Warning: Contains .pyc files"
find . -name ".DS_Store" && echo "⚠️  Warning: Contains .DS_Store files"
find . -name "__pycache__" && echo "⚠️  Warning: Contains __pycache__"

# 6. Test installation
echo "✅ Testing installation..."
PLUGIN_DIR="$HOME/Library/Application Support/VoiceFlow/Plugins/MyPlugin-Test"
mkdir -p "$PLUGIN_DIR"
cp -r . "$PLUGIN_DIR/"

echo ""
echo "✅ Distribution test complete!"
echo "📍 Test installation location: $PLUGIN_DIR"
echo ""
echo "Next steps:"
echo "1. Launch VoiceFlow"
echo "2. Enable MyPlugin-Test in preferences"
echo "3. Test plugin functionality"
echo "4. Remove test installation:"
echo "   rm -rf '$PLUGIN_DIR'"
echo "   rm -rf '$TEST_DIR'"
```

---

## Advanced Topics

### Code Signing (Future)

While VoiceFlow doesn't currently verify code signatures, prepare for future support:

```bash
# Sign your plugin (macOS)
codesign --sign "Developer ID Application: Your Name" --timestamp MyPlugin.dylib

# Verify signature
codesign --verify --verbose MyPlugin.dylib
```

### Automated Releases with CI/CD

Example GitHub Actions workflow:

```yaml
# .github/workflows/release.yml
name: Release Plugin

on:
  push:
    tags:
      - 'v*'

jobs:
  release:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v3

      - name: Extract version
        id: version
        run: echo "VERSION=${GITHUB_REF#refs/tags/v}" >> $GITHUB_OUTPUT

      - name: Package plugin
        run: ./package.sh

      - name: Create release
        uses: softprops/action-gh-release@v1
        with:
          files: |
            MyPlugin-${{ steps.version.outputs.VERSION }}.tar.gz
            MyPlugin-${{ steps.version.outputs.VERSION }}.tar.gz.sha256
          body_path: CHANGELOG.md
```

### Plugin Metrics & Telemetry

If including usage metrics:

```markdown
## Privacy & Telemetry

This plugin collects the following anonymous usage data:

- Feature usage counts (which features are used)
- Error frequency (crashes and exceptions)
- Performance metrics (processing time)

**Data is:**
- Anonymous (no personally identifiable information)
- Encrypted in transit
- Used only for improving plugin quality

**Data is NOT:**
- Sold to third parties
- Used for advertising
- Linked to your identity

To disable telemetry, set `"telemetry": false` in config.json.
```

---

## Summary

Key takeaways for plugin packaging:

1. **Directory structure** - Keep it clean and organized
2. **Dependencies** - Bundle or document clearly, pin versions
3. **Versioning** - Use semantic versioning consistently
4. **Distribution** - TAR.GZ with checksums
5. **Documentation** - Clear installation and upgrade instructions
6. **Changelog** - Maintain detailed version history
7. **Testing** - Verify packaging and installation before release
8. **Security** - Review code, scan dependencies, provide transparency

---

## Next Steps

- **Learn testing**: Read [PLUGIN_TESTING.md](PLUGIN_TESTING.md)
- **Explore examples**: Check `Plugins/Examples/` for real-world packaging
- **Use the toolkit**: Try `scripts/plugin-dev-tools.sh package`
- **Join community**: Share your plugin and get feedback

---

**Questions?** Check the [Plugin Development Guide](PLUGIN_DEVELOPMENT.md) or [API Reference](PLUGIN_API_REFERENCE.md).
