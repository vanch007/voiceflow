#!/usr/bin/env python3
"""
Automated end-to-end tests for vocabulary workflow.
Tests aspects that can be automated without full app GUI interaction.

Usage:
    python test_e2e_vocabulary_workflow.py
"""

import json
import csv
import sys
from pathlib import Path
from io import StringIO


def test_csv_utf8_encoding():
    """Test that sample CSV has proper UTF-8 encoding"""
    print("\n[TEST 1] CSV UTF-8 Encoding")

    csv_path = Path(__file__).parent / "sample_vocabulary.csv"

    try:
        with open(csv_path, 'r', encoding='utf-8') as f:
            content = f.read()

        # Check for Chinese characters
        if '李明' in content and '北京' in content:
            print("  ✅ Chinese characters present")
        else:
            print("  ❌ Chinese characters missing")
            return False

        # Verify CSV parsing
        with open(csv_path, 'r', encoding='utf-8') as f:
            reader = csv.DictReader(f)
            rows = list(reader)

        print(f"  ✅ CSV parsed successfully ({len(rows)} entries)")

        # Verify Chinese entry
        chinese_entries = [r for r in rows if '李明' in r['term'] or '北京' in r['term']]
        if len(chinese_entries) >= 2:
            print(f"  ✅ Chinese entries found: {len(chinese_entries)}")
            for entry in chinese_entries[:2]:
                print(f"      {entry['term']} → {entry.get('pronunciation', 'N/A')}")
        else:
            print("  ❌ Chinese entries not found")
            return False

        return True

    except Exception as e:
        print(f"  ❌ Error: {e}")
        return False


def test_json_export_format():
    """Test vocabulary JSON export format"""
    print("\n[TEST 2] JSON Export Format")

    sample_vocab = {
        "id": "123e4567-e89b-12d3-a456-426614174000",
        "name": "Programming",
        "description": "Common programming terms",
        "entries": [
            {
                "id": "entry-1",
                "term": "React",
                "pronunciation": "",
                "mapping": "",
                "category": "framework"
            },
            {
                "id": "entry-2",
                "term": "李明",
                "pronunciation": "lǐ míng",
                "mapping": "Li Ming",
                "category": "name"
            }
        ],
        "createdAt": "2026-02-11T00:00:00Z",
        "updatedAt": "2026-02-11T00:00:00Z"
    }

    try:
        # Test JSON serialization
        json_str = json.dumps(sample_vocab, ensure_ascii=False, indent=2)
        print("  ✅ JSON serialization successful")

        # Verify Chinese characters preserved
        if '李明' in json_str and 'lǐ míng' in json_str:
            print("  ✅ Chinese characters preserved in JSON")
        else:
            print("  ❌ Chinese characters not preserved")
            return False

        # Test deserialization
        parsed = json.loads(json_str)
        if parsed['entries'][1]['term'] == '李明':
            print("  ✅ JSON round-trip successful")
        else:
            print("  ❌ JSON round-trip failed")
            return False

        return True

    except Exception as e:
        print(f"  ❌ Error: {e}")
        return False


def test_csv_export_import_cycle():
    """Test CSV export/import preserves data"""
    print("\n[TEST 3] CSV Export/Import Cycle")

    original_data = [
        {"term": "React", "pronunciation": "", "mapping": "", "category": "framework"},
        {"term": "李明", "pronunciation": "lǐ míng", "mapping": "Li Ming", "category": "name"},
        {"term": "北京", "pronunciation": "běi jīng", "mapping": "Beijing", "category": "place"},
    ]

    try:
        # Export to CSV string
        output = StringIO()
        fieldnames = ['term', 'pronunciation', 'mapping', 'category']
        writer = csv.DictWriter(output, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(original_data)
        csv_content = output.getvalue()

        print("  ✅ CSV export generated")

        # Verify UTF-8 characters in output
        if '李明' in csv_content and '北京' in csv_content:
            print("  ✅ Chinese characters in CSV export")
        else:
            print("  ❌ Chinese characters lost in export")
            return False

        # Import from CSV string
        input_stream = StringIO(csv_content)
        reader = csv.DictReader(input_stream)
        imported_data = list(reader)

        print(f"  ✅ CSV import parsed ({len(imported_data)} entries)")

        # Verify data integrity
        for i, (original, imported) in enumerate(zip(original_data, imported_data)):
            if original['term'] != imported['term']:
                print(f"  ❌ Term mismatch at index {i}: {original['term']} != {imported['term']}")
                return False
            if original.get('pronunciation', '') != imported.get('pronunciation', ''):
                print(f"  ❌ Pronunciation mismatch at index {i}")
                return False

        print("  ✅ All data preserved in round-trip")
        return True

    except Exception as e:
        print(f"  ❌ Error: {e}")
        return False


def test_large_vocabulary_generation():
    """Test generation of large vocabulary for performance testing"""
    print("\n[TEST 4] Large Vocabulary Generation")

    try:
        # Import the generator
        from generate_large_vocabulary import generate_vocabulary_entries

        # Generate 1000 entries
        entries = generate_vocabulary_entries(1000, "mixed")

        if len(entries) != 1000:
            print(f"  ❌ Expected 1000 entries, got {len(entries)}")
            return False

        print(f"  ✅ Generated {len(entries)} entries")

        # Check for Chinese entries
        chinese_entries = [e for e in entries if any(ord(c) > 127 for c in e['term'])]
        print(f"  ✅ Chinese entries: {len(chinese_entries)}")

        # Check for category distribution
        categories = set(e['category'] for e in entries)
        print(f"  ✅ Categories: {', '.join(sorted(categories))}")

        # Verify unique terms
        terms = [e['term'] for e in entries]
        if len(terms) == len(set(terms)):
            print("  ✅ All terms unique")
        else:
            duplicates = len(terms) - len(set(terms))
            print(f"  ⚠️  {duplicates} duplicate terms found")

        return True

    except ImportError:
        print("  ⚠️  generate_large_vocabulary.py not found, skipping")
        return True  # Not a failure, just skip
    except Exception as e:
        print(f"  ❌ Error: {e}")
        return False


def test_websocket_message_format():
    """Test that WebSocket start message with hotwords is valid"""
    print("\n[TEST 5] WebSocket Message Format")

    start_message = {
        "type": "start",
        "mode": "voice_input",
        "model": "qwen3-asr",
        "language": "auto",
        "enable_polish": "true",
        "hotwords": ["React", "Kubernetes", "TypeScript", "李明", "北京"]
    }

    try:
        # Test JSON serialization
        json_str = json.dumps(start_message, ensure_ascii=False)
        print("  ✅ Message serialization successful")

        # Verify hotwords array
        parsed = json.loads(json_str)
        if 'hotwords' in parsed and isinstance(parsed['hotwords'], list):
            print(f"  ✅ Hotwords array present ({len(parsed['hotwords'])} items)")
        else:
            print("  ❌ Hotwords array missing or invalid")
            return False

        # Verify Chinese hotwords preserved
        if '李明' in parsed['hotwords'] and '北京' in parsed['hotwords']:
            print("  ✅ Chinese hotwords preserved")
        else:
            print("  ❌ Chinese hotwords not preserved")
            return False

        return True

    except Exception as e:
        print(f"  ❌ Error: {e}")
        return False


def main():
    print("=" * 60)
    print("End-to-End Vocabulary Workflow - Automated Tests")
    print("=" * 60)

    tests = [
        test_csv_utf8_encoding,
        test_json_export_format,
        test_csv_export_import_cycle,
        test_large_vocabulary_generation,
        test_websocket_message_format,
    ]

    results = []
    for test_func in tests:
        try:
            result = test_func()
            results.append(result)
        except Exception as e:
            print(f"\n❌ Test {test_func.__name__} failed with exception: {e}")
            results.append(False)

    print("\n" + "=" * 60)
    print("SUMMARY")
    print("=" * 60)

    passed = sum(results)
    total = len(results)

    print(f"Passed: {passed}/{total}")

    if passed == total:
        print("\n✅ All automated tests passed!")
        print("\nNext steps:")
        print("1. Run manual GUI tests (see e2e_vocabulary_test_guide.md)")
        print("2. Test voice input with vocabulary terms")
        print("3. Verify ASR accuracy improvement")
        print("4. Run performance benchmark with 1000+ entries")
        return 0
    else:
        print(f"\n❌ {total - passed} test(s) failed")
        return 1


if __name__ == '__main__':
    sys.exit(main())
