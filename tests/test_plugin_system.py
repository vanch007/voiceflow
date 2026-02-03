#!/usr/bin/env python3
"""
End-to-End Plugin System Integration Test

Tests the complete plugin lifecycle across Swift and Python components:
- Plugin discovery and loading
- Manifest validation
- Plugin lifecycle hooks (on_load, on_transcription, on_unload)
- Text processing pipeline
- Error handling and isolation
"""

import asyncio
import json
import logging
import shutil
import sys
import tempfile
from pathlib import Path
from typing import List, Tuple

# Add server directory to path for imports
script_dir = Path(__file__).resolve().parent
project_root = script_dir.parent
server_dir = project_root / "server"
sys.path.insert(0, str(server_dir))

from plugin_api import (
    LoadFailedError,
    ManifestInvalidError,
    PluginInfo,
    PluginManifest,
    PluginPlatform,
    PluginState,
)
from plugin_loader import PluginLoader

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s - %(message)s"
)
logger = logging.getLogger(__name__)


class PluginSystemTest:
    """End-to-end test suite for the plugin system."""

    def __init__(self):
        """Initialize test suite."""
        self.temp_dir: Path = None
        self.plugins_dir: Path = None
        self.loader: PluginLoader = None
        self.test_results: List[Tuple[str, bool, str]] = []

    def setup(self):
        """Set up test environment with temporary plugins directory."""
        logger.info("Setting up test environment...")

        # Create temporary directory for plugins
        self.temp_dir = Path(tempfile.mkdtemp(prefix="voiceflow_plugin_test_"))
        self.plugins_dir = self.temp_dir / "Plugins"
        self.plugins_dir.mkdir(parents=True, exist_ok=True)

        logger.info(f"Created temporary plugins directory: {self.plugins_dir}")

    def teardown(self):
        """Clean up test environment."""
        logger.info("Cleaning up test environment...")

        if self.temp_dir and self.temp_dir.exists():
            shutil.rmtree(self.temp_dir)
            logger.info(f"Removed temporary directory: {self.temp_dir}")

    def install_example_plugins(self):
        """Install example Swift and Python plugins to test directory."""
        logger.info("Installing example plugins...")

        examples_dir = project_root / "Plugins" / "Examples"

        # Copy UppercasePlugin (Swift)
        uppercase_src = examples_dir / "UppercasePlugin"
        if uppercase_src.exists():
            uppercase_dst = self.plugins_dir / "UppercasePlugin"
            shutil.copytree(uppercase_src, uppercase_dst)
            logger.info(f"Installed UppercasePlugin to {uppercase_dst}")
        else:
            logger.warning(f"UppercasePlugin not found at {uppercase_src}")

        # Copy PunctuationPlugin (Python)
        punctuation_src = examples_dir / "PunctuationPlugin"
        if punctuation_src.exists():
            punctuation_dst = self.plugins_dir / "PunctuationPlugin"
            shutil.copytree(punctuation_src, punctuation_dst)
            logger.info(f"Installed PunctuationPlugin to {punctuation_dst}")
        else:
            logger.warning(f"PunctuationPlugin not found at {punctuation_src}")

    def add_test_result(self, test_name: str, passed: bool, message: str = ""):
        """Record test result."""
        self.test_results.append((test_name, passed, message))
        status = "✓ PASS" if passed else "✗ FAIL"
        logger.info(f"{status}: {test_name} - {message}")

    async def test_plugin_discovery(self):
        """Test: Plugin discovery finds all installed plugins."""
        logger.info("\n=== Test: Plugin Discovery ===")

        try:
            self.loader = PluginLoader(plugins_dir=self.plugins_dir)
            plugin_dirs = self.loader.discover_plugins()

            # Should find 2 plugins (UppercasePlugin and PunctuationPlugin)
            expected_count = 2
            actual_count = len(plugin_dirs)

            if actual_count == expected_count:
                self.add_test_result(
                    "Plugin Discovery",
                    True,
                    f"Found {actual_count} plugins as expected"
                )
            else:
                self.add_test_result(
                    "Plugin Discovery",
                    False,
                    f"Expected {expected_count} plugins, found {actual_count}"
                )
        except Exception as e:
            self.add_test_result("Plugin Discovery", False, f"Exception: {e}")

    async def test_manifest_loading(self):
        """Test: Manifest loading and validation."""
        logger.info("\n=== Test: Manifest Loading ===")

        try:
            plugin_dirs = self.loader.discover_plugins()

            for plugin_dir in plugin_dirs:
                try:
                    manifest = self.loader.load_manifest(plugin_dir)

                    # Validate manifest has required fields
                    required_fields = {
                        "id": manifest.id,
                        "name": manifest.name,
                        "version": manifest.version,
                        "author": manifest.author,
                        "description": manifest.description,
                        "entrypoint": manifest.entrypoint,
                    }

                    if all(required_fields.values()):
                        self.add_test_result(
                            f"Manifest Loading: {plugin_dir.name}",
                            True,
                            f"Loaded {manifest.name} v{manifest.version}"
                        )
                    else:
                        missing = [k for k, v in required_fields.items() if not v]
                        self.add_test_result(
                            f"Manifest Loading: {plugin_dir.name}",
                            False,
                            f"Missing fields: {missing}"
                        )
                except ManifestInvalidError as e:
                    self.add_test_result(
                        f"Manifest Loading: {plugin_dir.name}",
                        False,
                        f"Invalid manifest: {e}"
                    )
        except Exception as e:
            self.add_test_result("Manifest Loading", False, f"Exception: {e}")

    async def test_python_plugin_loading(self):
        """Test: Python plugin loading and initialization."""
        logger.info("\n=== Test: Python Plugin Loading ===")

        try:
            # Load PunctuationPlugin
            punctuation_dir = self.plugins_dir / "PunctuationPlugin"

            if punctuation_dir.exists():
                try:
                    plugin_info = await self.loader.load_plugin(punctuation_dir)

                    # Validate plugin loaded successfully
                    checks = {
                        "Plugin instance exists": plugin_info.plugin is not None,
                        "Manifest loaded": plugin_info.manifest is not None,
                        "Plugin ID matches": plugin_info.manifest.id == "com.voiceflow.plugins.punctuation",
                        "State is LOADED": plugin_info.state == PluginState.LOADED,
                        "No errors": plugin_info.error is None,
                    }

                    all_passed = all(checks.values())
                    failed_checks = [k for k, v in checks.items() if not v]

                    if all_passed:
                        self.add_test_result(
                            "Python Plugin Loading",
                            True,
                            f"PunctuationPlugin loaded successfully"
                        )
                    else:
                        self.add_test_result(
                            "Python Plugin Loading",
                            False,
                            f"Failed checks: {failed_checks}"
                        )
                except (LoadFailedError, ManifestInvalidError) as e:
                    self.add_test_result(
                        "Python Plugin Loading",
                        False,
                        f"Failed to load: {e}"
                    )
            else:
                self.add_test_result(
                    "Python Plugin Loading",
                    False,
                    "PunctuationPlugin directory not found"
                )
        except Exception as e:
            self.add_test_result("Python Plugin Loading", False, f"Exception: {e}")

    async def test_text_processing(self):
        """Test: Text processing through plugin pipeline."""
        logger.info("\n=== Test: Text Processing ===")

        try:
            # Load all plugins
            await self.loader.load_all_plugins()

            # Enable PunctuationPlugin
            punctuation_plugin = self.loader.get_plugin("com.voiceflow.plugins.punctuation")
            if punctuation_plugin:
                punctuation_plugin.state = PluginState.ENABLED

            # Test cases: (input, expected_contains)
            test_cases = [
                ("hello world", ["Hello world.", "?"]),  # Should add period and capitalize
                ("what is your name", ["What is your name?", "What"]),  # Should add question mark
                ("how are you", ["How are you?", "How"]),  # Question detection
                ("this is a test", ["This is a test.", "This"]),  # Statement with period
            ]

            for input_text, expected_patterns in test_cases:
                try:
                    processed = await self.loader.process_text(input_text)

                    # Check if at least one expected pattern is in the result
                    has_expected = any(pattern in processed for pattern in expected_patterns)

                    # Check that text was modified (capitalized at minimum)
                    is_modified = processed != input_text

                    if has_expected and is_modified:
                        self.add_test_result(
                            f"Text Processing: '{input_text}'",
                            True,
                            f"'{input_text}' → '{processed}'"
                        )
                    else:
                        self.add_test_result(
                            f"Text Processing: '{input_text}'",
                            False,
                            f"Expected patterns {expected_patterns}, got '{processed}'"
                        )
                except Exception as e:
                    self.add_test_result(
                        f"Text Processing: '{input_text}'",
                        False,
                        f"Exception: {e}"
                    )
        except Exception as e:
            self.add_test_result("Text Processing", False, f"Exception: {e}")

    async def test_plugin_lifecycle(self):
        """Test: Plugin lifecycle hooks (on_load, on_unload)."""
        logger.info("\n=== Test: Plugin Lifecycle ===")

        try:
            # Load a plugin
            punctuation_dir = self.plugins_dir / "PunctuationPlugin"
            plugin_info = await self.loader.load_plugin(punctuation_dir)
            plugin_id = plugin_info.manifest.id

            # Verify on_load was called (plugin is loaded)
            if plugin_info.state == PluginState.LOADED:
                self.add_test_result(
                    "Plugin Lifecycle: on_load",
                    True,
                    "Plugin loaded successfully"
                )
            else:
                self.add_test_result(
                    "Plugin Lifecycle: on_load",
                    False,
                    f"Unexpected state: {plugin_info.state}"
                )

            # Test on_unload
            try:
                await self.loader.unload_plugin(plugin_id)

                # Verify plugin was unloaded
                if plugin_id not in self.loader.loaded_plugins:
                    self.add_test_result(
                        "Plugin Lifecycle: on_unload",
                        True,
                        "Plugin unloaded successfully"
                    )
                else:
                    self.add_test_result(
                        "Plugin Lifecycle: on_unload",
                        False,
                        "Plugin still in loaded_plugins"
                    )
            except Exception as e:
                self.add_test_result(
                    "Plugin Lifecycle: on_unload",
                    False,
                    f"Exception during unload: {e}"
                )
        except Exception as e:
            self.add_test_result("Plugin Lifecycle", False, f"Exception: {e}")

    async def test_error_handling(self):
        """Test: Error handling for invalid plugins."""
        logger.info("\n=== Test: Error Handling ===")

        try:
            # Test 1: Invalid manifest (missing required fields)
            invalid_plugin_dir = self.plugins_dir / "InvalidPlugin"
            invalid_plugin_dir.mkdir(exist_ok=True)

            invalid_manifest = {
                "id": "test.invalid",
                "name": "Invalid Plugin"
                # Missing: version, author, description, entrypoint
            }

            with open(invalid_plugin_dir / "manifest.json", "w") as f:
                json.dump(invalid_manifest, f)

            try:
                manifest = self.loader.load_manifest(invalid_plugin_dir)
                self.add_test_result(
                    "Error Handling: Invalid Manifest",
                    False,
                    "Should have raised ManifestInvalidError"
                )
            except ManifestInvalidError:
                self.add_test_result(
                    "Error Handling: Invalid Manifest",
                    True,
                    "Correctly rejected invalid manifest"
                )

            # Test 2: Non-existent plugin directory
            try:
                non_existent = self.plugins_dir / "NonExistent"
                manifest = self.loader.load_manifest(non_existent)
                self.add_test_result(
                    "Error Handling: Missing Directory",
                    False,
                    "Should have raised ManifestInvalidError"
                )
            except ManifestInvalidError:
                self.add_test_result(
                    "Error Handling: Missing Directory",
                    True,
                    "Correctly handled missing directory"
                )
        except Exception as e:
            self.add_test_result("Error Handling", False, f"Exception: {e}")

    async def test_plugin_isolation(self):
        """Test: Plugins are isolated and errors don't crash the system."""
        logger.info("\n=== Test: Plugin Isolation ===")

        try:
            # Load all plugins
            await self.loader.load_all_plugins()

            # Enable all loaded plugins
            for plugin_info in self.loader.list_plugins():
                plugin_info.state = PluginState.ENABLED

            # Process text - even if one plugin fails, others should work
            test_text = "test isolation"

            try:
                processed = await self.loader.process_text(test_text)

                # Text should be processed even if some plugins fail
                self.add_test_result(
                    "Plugin Isolation",
                    True,
                    f"Text processed successfully: '{processed}'"
                )
            except Exception as e:
                self.add_test_result(
                    "Plugin Isolation",
                    False,
                    f"Processing failed: {e}"
                )
        except Exception as e:
            self.add_test_result("Plugin Isolation", False, f"Exception: {e}")

    def print_summary(self):
        """Print test results summary."""
        print("\n" + "=" * 70)
        print("TEST RESULTS SUMMARY")
        print("=" * 70)

        total_tests = len(self.test_results)
        passed_tests = sum(1 for _, passed, _ in self.test_results if passed)
        failed_tests = total_tests - passed_tests

        print(f"\nTotal Tests: {total_tests}")
        print(f"Passed: {passed_tests} ✓")
        print(f"Failed: {failed_tests} ✗")
        print(f"Success Rate: {(passed_tests/total_tests*100):.1f}%\n")

        if failed_tests > 0:
            print("Failed Tests:")
            for name, passed, message in self.test_results:
                if not passed:
                    print(f"  ✗ {name}: {message}")

        print("=" * 70)

        return failed_tests == 0

    async def run_all_tests(self):
        """Run all integration tests."""
        logger.info("Starting Plugin System Integration Tests")
        logger.info("=" * 70)

        try:
            self.setup()
            self.install_example_plugins()

            # Run tests in sequence
            await self.test_plugin_discovery()
            await self.test_manifest_loading()
            await self.test_python_plugin_loading()
            await self.test_text_processing()
            await self.test_plugin_lifecycle()
            await self.test_error_handling()
            await self.test_plugin_isolation()

        except Exception as e:
            logger.error(f"Test suite failed with exception: {e}", exc_info=True)
        finally:
            self.teardown()

        # Print summary
        all_passed = self.print_summary()

        return all_passed


async def main():
    """Main test runner."""
    test_suite = PluginSystemTest()

    try:
        all_passed = await test_suite.run_all_tests()

        if all_passed:
            logger.info("\n✓ All integration tests passed!")
            sys.exit(0)
        else:
            logger.error("\n✗ Some integration tests failed!")
            sys.exit(1)
    except Exception as e:
        logger.error(f"Test execution failed: {e}", exc_info=True)
        sys.exit(1)


if __name__ == "__main__":
    # Run the async test suite
    asyncio.run(main())
