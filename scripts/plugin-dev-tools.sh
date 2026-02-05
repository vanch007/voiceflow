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

# Test command (placeholder)
cmd_test() {
  local plugin_path="$1"

  if [ -z "$plugin_path" ]; then
    print_error "Plugin path is required"
    print_usage
    exit 1
  fi

  print_warning "Test command not yet implemented"
  echo "This command will execute plugin tests in the future"
  exit 0
}

# Package command (placeholder)
cmd_package() {
  local plugin_path="$1"

  if [ -z "$plugin_path" ]; then
    print_error "Plugin path is required"
    print_usage
    exit 1
  fi

  print_warning "Package command not yet implemented"
  echo "This command will package plugins for distribution in the future"
  exit 0
}

# Install command (placeholder)
cmd_install() {
  local plugin_path="$1"

  if [ -z "$plugin_path" ]; then
    print_error "Plugin path is required"
    print_usage
    exit 1
  fi

  print_warning "Install command not yet implemented"
  echo "This command will install plugins to user directory in the future"
  exit 0
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
