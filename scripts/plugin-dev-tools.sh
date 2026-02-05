#!/bin/bash
# VoiceFlow Plugin Development Toolkit
# Commands: validate, test, package, install
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
SCHEMA_PATH="$PROJECT_DIR/Plugins/manifest-schema.json"

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
print_usage() {
  echo "VoiceFlow Plugin Development Toolkit"
  echo ""
  echo "Usage: $0 <command> <plugin-path>"
  echo ""
  echo "Commands:"
  echo "  validate <path>  - Validate plugin manifest against schema"
  echo "  test <path>      - Run plugin tests"
  echo "  package <path>   - Package plugin for distribution"
  echo "  install <path>   - Install plugin to user directory"
  echo ""
  echo "Examples:"
  echo "  $0 validate Plugins/Examples/UppercasePlugin"
  echo "  $0 package Plugins/Examples/WebhookPlugin"
  echo "  $0 install Plugins/Examples/UppercasePlugin"
}

print_error() {
  echo -e "${RED}❌ Error:${NC} $1" >&2
}

print_success() {
  echo -e "${GREEN}✅${NC} $1"
}

print_info() {
  echo -e "${BLUE}ℹ${NC}  $1"
}

print_warning() {
  echo -e "${YELLOW}⚠️${NC}  $1"
}

# Validate command
cmd_validate() {
  local plugin_path="$1"

  if [ -z "$plugin_path" ]; then
    print_error "Plugin path is required"
    print_usage
    exit 1
  fi

  # Resolve to absolute path if relative
  if [[ "$plugin_path" != /* ]]; then
    plugin_path="$PROJECT_DIR/$plugin_path"
  fi

  if [ ! -d "$plugin_path" ]; then
    print_error "Plugin directory not found: $plugin_path"
    exit 1
  fi

  local manifest_path="$plugin_path/manifest.json"

  if [ ! -f "$manifest_path" ]; then
    print_error "manifest.json not found in $plugin_path"
    exit 1
  fi

  if [ ! -f "$SCHEMA_PATH" ]; then
    print_error "Schema file not found: $SCHEMA_PATH"
    exit 1
  fi

  print_info "Validating manifest: $manifest_path"
  print_info "Against schema: $SCHEMA_PATH"

  # Check if Python is available
  PYTHON_CMD=""
  for cmd in python3 python; do
    if command -v "$cmd" &>/dev/null; then
      PYTHON_CMD="$cmd"
      break
    fi
  done

  if [ -z "$PYTHON_CMD" ]; then
    print_error "Python not found. Install Python 3.x to validate manifests."
    exit 1
  fi

  # Try to validate using Python with jsonschema
  # First check if jsonschema is available
  if ! "$PYTHON_CMD" -c "import jsonschema" 2>/dev/null; then
    print_warning "jsonschema module not installed"
    print_info "Performing basic JSON syntax validation only..."

    # Basic JSON validation
    if "$PYTHON_CMD" -c "import json; json.load(open('$manifest_path'))" 2>/dev/null; then
      print_success "JSON syntax is valid"
      print_warning "Install jsonschema for full schema validation: pip install jsonschema"
      echo ""
      echo "Manifest validation passed (syntax only)"
      exit 0
    else
      print_error "Invalid JSON syntax in manifest"
      exit 1
    fi
  fi

  # Full schema validation
  validation_output=$("$PYTHON_CMD" -c "
import json
import sys
try:
    import jsonschema
    from jsonschema import validate, ValidationError

    # Load schema
    with open('$SCHEMA_PATH', 'r') as f:
        schema = json.load(f)

    # Load manifest
    with open('$manifest_path', 'r') as f:
        manifest = json.load(f)

    # Validate
    validate(instance=manifest, schema=schema)
    print('VALIDATION_SUCCESS')

except ValidationError as e:
    print(f'VALIDATION_ERROR: {e.message}', file=sys.stderr)
    if e.path:
        print(f'Field: {\".\".join(str(p) for p in e.path)}', file=sys.stderr)
    sys.exit(1)
except json.JSONDecodeError as e:
    print(f'JSON_ERROR: {e}', file=sys.stderr)
    sys.exit(1)
except Exception as e:
    print(f'ERROR: {e}', file=sys.stderr)
    sys.exit(1)
" 2>&1)

  validation_result=$?

  if [ $validation_result -eq 0 ]; then
    print_success "Manifest validation passed"

    # Show summary
    echo ""
    plugin_id=$("$PYTHON_CMD" -c "import json; print(json.load(open('$manifest_path'))['id'])")
    plugin_name=$("$PYTHON_CMD" -c "import json; print(json.load(open('$manifest_path'))['name'])")
    plugin_version=$("$PYTHON_CMD" -c "import json; print(json.load(open('$manifest_path'))['version'])")
    plugin_platform=$("$PYTHON_CMD" -c "import json; print(json.load(open('$manifest_path'))['platform'])")

    echo "Plugin Details:"
    echo "  ID: $plugin_id"
    echo "  Name: $plugin_name"
    echo "  Version: $plugin_version"
    echo "  Platform: $plugin_platform"
    echo ""
    echo "Manifest validation passed"
  else
    print_error "Manifest validation failed"
    echo "$validation_output"
    exit 1
  fi
}

# Test command
cmd_test() {
  local plugin_path="$1"

  if [ -z "$plugin_path" ]; then
    print_error "Plugin path is required"
    print_usage
    exit 1
  fi

  # Resolve to absolute path if relative
  if [[ "$plugin_path" != /* ]]; then
    plugin_path="$PROJECT_DIR/$plugin_path"
  fi

  if [ ! -d "$plugin_path" ]; then
    print_error "Plugin directory not found: $plugin_path"
    exit 1
  fi

  print_info "Looking for tests in: $plugin_path"

  # Check if Python is available
  PYTHON_CMD=""
  for cmd in python3 python; do
    if command -v "$cmd" &>/dev/null; then
      PYTHON_CMD="$cmd"
      break
    fi
  done

  if [ -z "$PYTHON_CMD" ]; then
    print_error "Python not found. Install Python 3.x to run tests."
    exit 1
  fi

  # Look for test files (test_*.py) or tests directory
  test_files=$(find "$plugin_path" -name "test_*.py" -o -name "*_test.py" 2>/dev/null)
  tests_dir="$plugin_path/tests"

  if [ -n "$test_files" ] || [ -d "$tests_dir" ]; then
    # Check if pytest is available
    if ! "$PYTHON_CMD" -m pytest --version &>/dev/null; then
      print_warning "pytest not installed"
      print_info "Attempting to run tests with unittest..."

      # Run with unittest
      if [ -n "$test_files" ]; then
        echo "$test_files" | while read -r test_file; do
          print_info "Running: $test_file"
          "$PYTHON_CMD" "$test_file"
        done
      fi

      if [ -d "$tests_dir" ]; then
        print_info "Running tests in: $tests_dir"
        "$PYTHON_CMD" -m unittest discover -s "$tests_dir" -p "test_*.py"
      fi
    else
      # Run with pytest
      print_info "Running tests with pytest..."
      if [ -d "$tests_dir" ]; then
        "$PYTHON_CMD" -m pytest "$tests_dir" -v
      else
        "$PYTHON_CMD" -m pytest "$plugin_path" -v
      fi
    fi

    print_success "Tests completed"
  else
    print_warning "No test files found in $plugin_path"
    print_info "Skipping tests (no test_*.py or tests/ directory found)"
    echo ""
    echo "Test command executed (no tests found)"
  fi
}

# Package command
cmd_package() {
  local plugin_path="$1"

  if [ -z "$plugin_path" ]; then
    print_error "Plugin path is required"
    print_usage
    exit 1
  fi

  # Resolve to absolute path if relative
  if [[ "$plugin_path" != /* ]]; then
    plugin_path="$PROJECT_DIR/$plugin_path"
  fi

  if [ ! -d "$plugin_path" ]; then
    print_error "Plugin directory not found: $plugin_path"
    exit 1
  fi

  local manifest_path="$plugin_path/manifest.json"

  if [ ! -f "$manifest_path" ]; then
    print_error "manifest.json not found in $plugin_path"
    exit 1
  fi

  # Check if Python is available
  PYTHON_CMD=""
  for cmd in python3 python; do
    if command -v "$cmd" &>/dev/null; then
      PYTHON_CMD="$cmd"
      break
    fi
  done

  if [ -z "$PYTHON_CMD" ]; then
    print_error "Python not found. Install Python 3.x to package plugins."
    exit 1
  fi

  # Extract plugin info from manifest
  plugin_id=$("$PYTHON_CMD" -c "import json; print(json.load(open('$manifest_path'))['id'])" 2>/dev/null)
  plugin_version=$("$PYTHON_CMD" -c "import json; print(json.load(open('$manifest_path'))['version'])" 2>/dev/null)

  if [ -z "$plugin_id" ]; then
    print_error "Could not read plugin ID from manifest"
    exit 1
  fi

  # Get plugin directory name
  local plugin_dir_name=$(basename "$plugin_path")
  local archive_name="${plugin_dir_name}.tar.gz"

  print_info "Packaging plugin: $plugin_id (v$plugin_version)"
  print_info "Creating archive: $archive_name"

  # Create tar.gz archive
  # Use -C to change to parent directory, then archive the plugin directory
  local parent_dir=$(dirname "$plugin_path")

  if tar -czf "$archive_name" -C "$parent_dir" "$plugin_dir_name" 2>&1; then
    print_success "Plugin packaged successfully"
    echo ""
    echo "Archive created: $archive_name"
    echo "Size: $(du -h "$archive_name" | cut -f1)"
  else
    print_error "Failed to create archive"
    exit 1
  fi
}

# Install command
cmd_install() {
  local plugin_path="$1"

  if [ -z "$plugin_path" ]; then
    print_error "Plugin path is required"
    print_usage
    exit 1
  fi

  # Resolve to absolute path if relative
  if [[ "$plugin_path" != /* ]]; then
    plugin_path="$PROJECT_DIR/$plugin_path"
  fi

  if [ ! -d "$plugin_path" ]; then
    print_error "Plugin directory not found: $plugin_path"
    exit 1
  fi

  local manifest_path="$plugin_path/manifest.json"

  if [ ! -f "$manifest_path" ]; then
    print_error "manifest.json not found in $plugin_path"
    exit 1
  fi

  # Check if Python is available
  PYTHON_CMD=""
  for cmd in python3 python; do
    if command -v "$cmd" &>/dev/null; then
      PYTHON_CMD="$cmd"
      break
    fi
  done

  if [ -z "$PYTHON_CMD" ]; then
    print_error "Python not found. Install Python 3.x to install plugins."
    exit 1
  fi

  # Extract plugin info from manifest
  plugin_id=$("$PYTHON_CMD" -c "import json; print(json.load(open('$manifest_path'))['id'])" 2>/dev/null)
  plugin_name=$("$PYTHON_CMD" -c "import json; print(json.load(open('$manifest_path'))['name'])" 2>/dev/null)
  plugin_version=$("$PYTHON_CMD" -c "import json; print(json.load(open('$manifest_path'))['version'])" 2>/dev/null)

  if [ -z "$plugin_id" ]; then
    print_error "Could not read plugin ID from manifest"
    exit 1
  fi

  # Get plugin directory name
  local plugin_dir_name=$(basename "$plugin_path")

  # Define user plugins directory
  local user_plugins_dir="$HOME/Library/Application Support/VoiceFlow/Plugins"
  local install_path="$user_plugins_dir/$plugin_dir_name"

  print_info "Installing plugin: $plugin_name (v$plugin_version)"
  print_info "Plugin ID: $plugin_id"
  print_info "Destination: $install_path"

  # Create user plugins directory if it doesn't exist
  if [ ! -d "$user_plugins_dir" ]; then
    print_info "Creating plugins directory: $user_plugins_dir"
    mkdir -p "$user_plugins_dir"
    if [ $? -ne 0 ]; then
      print_error "Failed to create plugins directory"
      exit 1
    fi
  fi

  # Check if plugin already exists
  if [ -d "$install_path" ]; then
    print_warning "Plugin already exists at destination"
    read -p "Overwrite existing plugin? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
      print_info "Installation cancelled"
      exit 0
    fi
    print_info "Removing existing plugin..."
    rm -rf "$install_path"
  fi

  # Copy plugin to user directory
  print_info "Copying plugin files..."
  cp -R "$plugin_path" "$install_path"

  if [ $? -eq 0 ]; then
    print_success "Plugin installed successfully"
    echo ""
    echo "Installation Details:"
    echo "  Plugin: $plugin_name"
    echo "  Version: $plugin_version"
    echo "  Location: $install_path"
    echo ""
    echo "The plugin will be available when VoiceFlow is restarted."
  else
    print_error "Failed to copy plugin files"
    exit 1
  fi
}

# Main command dispatcher
main() {
  if [ $# -lt 1 ]; then
    print_usage
    exit 1
  fi

  local command="$1"
  shift

  case "$command" in
    validate)
      cmd_validate "$@"
      ;;
    test)
      cmd_test "$@"
      ;;
    package)
      cmd_package "$@"
      ;;
    install)
      cmd_install "$@"
      ;;
    --help|-h|help)
      print_usage
      exit 0
      ;;
    *)
      print_error "Unknown command: $command"
      print_usage
      exit 1
      ;;
  esac
}

main "$@"
