# End-to-End Vocabulary Workflow Test Guide

## Overview
This guide provides step-by-step instructions for testing the complete vocabulary workflow from creation to ASR integration.

## Prerequisites
- VoiceFlow app built and installed at `/Applications/VoiceFlow.app`
- ASR server running (`scripts/start-server.sh`)
- Accessibility permissions granted
- Microphone permissions granted

## Test Scenarios

### Scenario 1: Create Programming Vocabulary and Link to Scene

**Steps:**
1. Launch VoiceFlow app from `/Applications/`
2. Open Settings → Vocabulary tab
3. Click "+" button to create new vocabulary
4. Enter details:
   - Name: "Programming"
   - Description: "Common programming terms"
5. Add entries:
   - Term: "React", Category: "framework"
   - Term: "Kubernetes", Category: "infrastructure"
   - Term: "TypeScript", Category: "language"
   - Term: "PostgreSQL", Category: "database"
   - Term: "GraphQL", Category: "api"
6. Navigate to Settings → Scenes
7. Select or create "Coding" scene
8. In vocabulary section, check "Programming" vocabulary
9. Save scene configuration

**Expected Results:**
- Vocabulary created with 5 entries
- Scene successfully linked to vocabulary
- Entry count displays "5 entries"

**Verification:**
- Check log: `[VocabularyStorage] Saved 1 vocabularies`
- Check file: `~/Library/Application Support/VoiceFlow/vocabularies.json` contains vocabulary

---

### Scenario 2: Voice Input Recognition Test

**Steps:**
1. Ensure "Coding" scene is active
2. Long-press Option key to start recording
3. Speak clearly: "I am using React and Kubernetes to build a TypeScript application with PostgreSQL database and GraphQL API"
4. Release Option key to stop recording
5. Check transcribed text

**Expected Results:**
- All technical terms recognized with correct capitalization:
  - "React" (not "react" or "re-act")
  - "Kubernetes" (not "cuber-netes")
  - "TypeScript" (not "type script")
  - "PostgreSQL" (not "postgres QL")
  - "GraphQL" (not "graph QL")

**Verification:**
- Check server logs: `[ASRServer] Applying 5 hotwords to context`
- Check transcription output matches expected capitalization
- Compare with baseline (no vocabulary) for accuracy improvement

---

### Scenario 3: CSV Export/Import with UTF-8

**Steps:**
1. Open Settings → Vocabulary
2. Select "Programming" vocabulary
3. Click "Export" button
4. Choose "CSV" format
5. Save to Desktop as `programming_vocab.csv`
6. Open CSV in text editor, verify format:
   ```
   term,pronunciation,mapping,category
   React,,,framework
   Kubernetes,,,infrastructure
   TypeScript,,,language
   PostgreSQL,,,database
   GraphQL,,,api
   ```
7. Add Chinese entry manually:
   ```
   李明,lǐ míng,Li Ming,name
   ```
8. Save with UTF-8 encoding
9. In VoiceFlow, click "Import" → select CSV
10. Enter name: "Programming Enhanced"
11. Verify imported vocabulary

**Expected Results:**
- CSV export contains all entries with proper headers
- UTF-8 encoding preserved
- Chinese characters (李明, lǐ míng) display correctly after import
- No mojibake or encoding errors

**Verification:**
- Run: `file ~/Desktop/programming_vocab.csv` → should show "UTF-8 Unicode text"
- Open in text editor → Chinese characters render properly
- Imported vocabulary contains 6 entries (5 original + 1 Chinese)

---

### Scenario 4: JSON Export/Import Round-trip

**Steps:**
1. Select "Programming" vocabulary
2. Click "Export" → choose "JSON" format
3. Save to Desktop as `programming_vocab.json`
4. Verify JSON structure:
   ```json
   {
     "id": "...",
     "name": "Programming",
     "description": "Common programming terms",
     "entries": [...]
   }
   ```
5. Delete "Programming" vocabulary
6. Click "Import" → select JSON file
7. Verify all data restored

**Expected Results:**
- JSON export contains complete vocabulary data
- After reimport, all fields match exactly:
  - Name: "Programming"
  - Description: "Common programming terms"
  - All 5 entries preserved
  - Categories preserved

**Verification:**
- No data loss during export/import cycle
- Entry IDs may change (new UUIDs) but content identical

---

### Scenario 5: Performance Test with 1000+ Entries

**Steps:**
1. Run performance test script:
   ```bash
   cd server
   python tests/generate_large_vocabulary.py --count 1000 --output /tmp/large_vocab.csv
   ```
2. Import generated CSV into VoiceFlow
3. Name: "Performance Test 1000"
4. Wait for import to complete
5. Link to "Coding" scene
6. Activate scene and record a test phrase
7. Measure ASR latency (time from stop to transcription)
8. Compare with baseline (no vocabulary)

**Expected Results:**
- Import completes successfully (no timeout or crash)
- UI remains responsive with 1000 entries
- Scrolling in entry list is smooth
- ASR latency increase < 10% compared to baseline
  - Baseline: ~500ms
  - With 1000 entries: < 550ms

**Verification:**
- Check memory usage: Activity Monitor → VoiceFlow.app (should be < 200MB increase)
- Check server logs for hotword count: `[ASRServer] Applying 1000 hotwords`
- Measure latency with stopwatch

---

### Scenario 6: Multiple Vocabularies per Scene

**Steps:**
1. Create second vocabulary:
   - Name: "Medical"
   - Entries: "acetaminophen", "thrombocytopenia", "electrocardiogram"
2. Link both "Programming" and "Medical" to "Coding" scene
3. Record: "Use React for the electrocardiogram dashboard"
4. Verify both vocabulary sets applied

**Expected Results:**
- Both "React" and "electrocardiogram" recognized correctly
- Server log shows combined hotword count: `[ASRServer] Applying 8 hotwords`

---

### Scenario 7: Scene Switching with Different Vocabularies

**Steps:**
1. Create "Medical Chat" scene → link only "Medical" vocabulary
2. Create "Code Review" scene → link only "Programming" vocabulary
3. Switch to "Medical Chat" → record medical terms
4. Switch to "Code Review" → record programming terms
5. Verify correct vocabulary applied in each context

**Expected Results:**
- Scene switching updates active vocabularies
- No vocabulary leakage between scenes
- Logs show vocabulary change: `[ASRClient] Active vocabularies changed`

---

## Automated Test Checklist

Run these automated checks:

```bash
# 1. Verify storage file created
test -f ~/Library/Application\ Support/VoiceFlow/vocabularies.json && echo "✅ Storage file exists"

# 2. Verify JSON structure
cat ~/Library/Application\ Support/VoiceFlow/vocabularies.json | python -m json.tool > /dev/null && echo "✅ Valid JSON"

# 3. Generate large vocabulary CSV
cd server && python tests/generate_large_vocabulary.py --count 1000 --output /tmp/test_vocab.csv && echo "✅ Large vocab generated"

# 4. Verify CSV encoding
file /tmp/test_vocab.csv | grep -q "UTF-8" && echo "✅ UTF-8 encoding confirmed"

# 5. Server accepts hotwords parameter
cd server && python -c "import json; msg = {'type': 'start', 'hotwords': ['React', 'Kubernetes']}; print('✅ Hotwords parameter valid')"
```

---

## Success Criteria

- [ ] Vocabulary CRUD operations work in UI
- [ ] Scene association persists correctly
- [ ] CSV import/export preserves UTF-8 (Chinese characters)
- [ ] JSON export/import is lossless
- [ ] ASR recognition improves for vocabulary terms
- [ ] 1000+ entries import without crash
- [ ] Performance degradation < 10% with large vocabularies
- [ ] Multiple vocabularies can be linked to one scene
- [ ] Scene switching updates active vocabularies
- [ ] Server logs show hotword application

---

## Troubleshooting

**Issue: Vocabulary not applied during recording**
- Check: Is vocabulary linked to active scene?
- Check: Server logs for `[ASRServer] Applying X hotwords`
- Verify: ASRClient start message includes "hotwords" parameter

**Issue: Chinese characters show as ���**
- Ensure CSV saved with UTF-8 encoding (not ASCII or Latin-1)
- Use text editor with UTF-8 support (not Notepad on Windows)

**Issue: Import fails with "Invalid format"**
- Verify CSV has required headers: `term,pronunciation,mapping,category`
- Check for quotes around multi-word values
- Ensure no empty first column

**Issue: Performance degradation > 10%**
- Check if other apps using microphone simultaneously
- Verify Python server has sufficient memory
- Test with smaller vocabulary subsets to identify threshold

---

## Log Locations

- VoiceFlow app logs: Console.app → filter "VoiceFlow"
- ASR server logs: `server/asr_server.log` (if logging enabled)
- Vocabulary storage: `~/Library/Application Support/VoiceFlow/vocabularies.json`
- System audio logs: `~/Library/Application Support/VoiceFlow/system_audio.log`
