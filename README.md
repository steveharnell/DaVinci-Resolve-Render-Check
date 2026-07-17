# DaVinci Resolve Render Check


<img width="709" height="323" alt="Screenshot 2026-06-17 at 8 17 05 PM" src="https://github.com/user-attachments/assets/c49bccff-ebc2-4607-847f-37773137275d" />


A GUI-based Lua script for DaVinci Resolve that automates the import, organization, and verification of exported/transcoded footage against original camera files — now with roll-aware numbering-gap detection across a wide range of digital cinema and mobile camera formats.

## Script Included

### **Render_Check_v7.lua** — Media Comparison Tool with GUI, Timecode Verification, and Gap Detection
A comprehensive tool with a graphical interface for comparing clips between OCN (Original Camera Negative) and TRANSCODES bins to verify all exports match their camera originals, including timecode synchronization and missing-clip detection.

## What's New in v7

- 🎬 **Underscore-roll naming support** — gap detection now recognizes clips named `A_0005C003_260716_121755_…` (camera letter + `_` + roll digits + `C` + clip number), as produced by the ARRI Alexa 35. This convention was previously reported as "unrecognized naming" and skipped.
- 🛡️ **Roll-collapse safeguard** — rolls in the new style (e.g. `A_0005`) are excluded from timestamp stem collapsing, so `A_0005` and `A_0006` are analyzed as separate rolls instead of being merged into a single `A` group, which could mask real gaps.

## What's New in v6

- 🎯 **Accurate gap detection** — fixed a false-positive bug where clips with a trailing `C` in their suffix (e.g. `B012_C002_0415C9`) were incorrectly flagged as missing.
- 🎥 **Roll-based grouping** — clips are now grouped by *roll ID* instead of raw prefix, so rolls with timestamped names (Canon XF-AVC, Blackmagic BRAW, iPhone BM Camera) are analyzed as a single series.
- 🧩 **Timestamp roll collapse** — automatically collapses variants like `C005_04151714`, `C005_04151748`, `C005_04151712` into a single `C005` roll for gap analysis when 2+ clips share the stem.
- ⚠️ **Unrecognized-naming report** — gap detection now surfaces clips whose naming couldn't be parsed (GoPro `GX010001`, Sony XDCAM `C0001`, Panasonic P2, etc.) so you know what was skipped.
- 📋 **Broader camera support** — pattern set audited against ARRI, RED, Sony Venice/FX, Blackmagic, Canon, iPhone native, and iPhone Blackmagic Camera naming conventions.

## What It Does

**GUI Features:**
- 🖥️ **Intuitive interface** with folder browser and real-time results display
- 📁 **Auto-import** — Automatically imports media from specified folders
- 💾 **Persistent settings** — Remembers folder paths between sessions
- 🔨 **Automatic bin creation** — Creates OCN and TRANSCODES bins as needed
- 📊 **Export logs** — Saves detailed comparison reports to Desktop
- 🎯 **Clear results display** — Real-time feedback with monospace console

**Verification Capabilities:**
- 🔍 **Matches clips by filename** (ignoring file extensions and `_001` suffixes)
- 📊 **Handles different formats** — `.mov`, `.mp4`, `.mxf`, `.r3d`, `.braw`, `.avi`, `.mkv`, `.dng`
- ⏱️ **Verifies duration matching** to ensure complete exports
- 🕐 **Timecode verification** — Compares start timecodes to detect sync issues (optional)
- 🧮 **Numbering gap detection** — Flags missing clip numbers within each roll (optional)
- 📋 **Detailed reporting** of matches, missing files, duration mismatches, timecode mismatches, and numbering gaps
- 🔀 **Order independent** — clips don't need to be sorted the same way
- 🗂️ **Recursive folder scanning** — Finds media in nested subdirectories

## Installation

1. **Download the script** (`Render_Check_v7.lua`)

2. **Copy to DaVinci Resolve scripts folder**:
   - **macOS**: `/Users/[USERNAME]/Library/Application Support/Blackmagic Design/DaVinci Resolve/Fusion/Scripts/Utility`
   - **Windows**: `%APPDATA%\Blackmagic Design\DaVinci Resolve\Support\Fusion\Scripts\Utility`
   - **Linux**: `~/.local/share/DaVinciResolve/Fusion/Scripts/Utility`

   *(Replace `[USERNAME]` with your actual username on macOS)*

3. **Restart DaVinci Resolve** (if already running)

## How to Access

Once installed, launch the script via:

**Workspace → Scripts → Utility → Render_Check_v7**

## Complete Workflow

### First-Time Setup:
1. **Launch the script** from the Workspace menu
2. Click **"Browse..."** next to OCN Folder and select your original media folder
3. Click **"Browse..."** next to Transcodes Folder and select your transcoded media folder
4. Click **"Save Paths"** to remember these locations

### Regular Workflow:

#### Step 1: Auto Import Media
1. Click **"Auto Import"** to automatically import all supported media files from both folders
2. Script creates OCN and TRANSCODES bins if they don't exist
3. Files are organized into their respective bins

#### Step 2: Run Comparison
1. **Enable/disable "Timecode Match"** checkbox (enabled by default) to verify start timecodes
2. **Enable/disable "Gap Detection"** checkbox (enabled by default) to flag missing clip numbers within each roll
3. Click **"Run Comparison"** to verify exports against originals
4. Review results in the display window
5. Check for:
   - ✅ **Perfect matches** — Files with matching durations and timecodes
   - ❌ **Missing in TRANSCODES** — Originals without exports
   - ⚠️ **Extra in TRANSCODES** — Exports without matching originals
   - ⚠️ **Duration mismatches** — Files with different lengths
   - ⚠️ **Timecode mismatches** — Files with different start timecodes (when enabled)
   - ⚠️ **Numbering gaps** — Missing clip numbers within a roll (when enabled)
   - ⚠️ **Skipped clips** — Filenames gap detection couldn't parse

#### Step 3: Export Results (Optional)
1. Click **"Export Log"** to save a timestamped report to your Desktop
2. Log file includes all verification details for archival

## GUI Overview

**Interface Components:**
- **Bin Name Fields** — Customize bin names (default: "OCN" and "TRANSCODES")
- **Folder Path Fields** — Specify source folders for auto-import
- **Browse Buttons** — macOS folder picker dialogs
- **Save Paths** — Persist folder locations between sessions
- **Auto Import** — Scan and import media from specified folders
- **Timecode Match Checkbox** — Enable/disable timecode verification (default: enabled)
- **Gap Detection Checkbox** — Enable/disable numbering-gap detection (default: enabled)
- **Create Bins** — Manually create OCN and TRANSCODES bins
- **Run Comparison** — Execute verification analysis
- **Export Log** — Save results to text file
- **Clear Results** — Reset the display window
- **Results Display** — Real-time feedback with monospace formatting

## Example Output

**Auto Import:**
```
Starting auto-import...

Creating OCN bin...
Creating TRANSCODES bin...

Scanning OCN folder: /Volumes/Media/Originals
Found 113 media files in OCN folder
✓ Imported to OCN bin

Scanning TRANSCODES folder: /Volumes/Media/Transcodes
Found 113 media files in TRANSCODES folder
✓ Imported to TRANSCODES bin

=== AUTO-IMPORT COMPLETE ===
Total OCN files: 113
Total TRANSCODES files: 113
```

**Verification Results:**
```
Found 113 clips in original bin
Found 113 clips in exported bin

✓ Match: A015_C001_0415ID
✓ Match: A015_C002_0415BA
✓ Match: B012_C001_0415V0
✓ Match: B012_C002_0415C9
...

=== NUMBERING GAP DETECTION (OCN) ===

Prefix: A017_C (found 5 clips, range 1-6)
Missing clip numbers:
  ⚠ A017_C004

Prefix: C005_*_C (found 14 clips, range 1-15, timestamped)
Missing clip numbers:
  ⚠ C005_*_C008

⚠ 2 clip(s) skipped by gap detection (unrecognized naming):
  GX010001, C0001

=== VERIFICATION SUMMARY ===
Perfect matches: 113
Missing in TRANSCODES: 0
Extra in TRANSCODES: 0
Duration mismatches: 0
Timecode mismatches: 0
Numbering gaps in OCN: 2

ISSUES FOUND - Review the details above
```

## File Matching Examples

The verification script intelligently matches files by base name (ignoring extensions and `_001` suffixes):
- `A001C006_250613_RNQZ.mxf` ↔ `A001C006_250613_RNQZ.mov` ✅
- `B012_C002_0415C9.mxf` ↔ `B012_C002_0415C9.mov` ✅
- `CLIP001.R3D` ↔ `CLIP001.mov` ✅
- `Interview_Take1_001.mov` ↔ `Interview_Take1.mp4` ✅
- `Scene_05.braw` ↔ `Scene_05.mp4` ✅

## Supported File Formats

The script automatically detects and imports these media formats:
- `.mov` — QuickTime
- `.mp4` — MPEG-4
- `.mxf` — Material Exchange Format
- `.r3d` — RED Digital Cinema
- `.braw` — Blackmagic RAW
- `.avi` — Audio Video Interleave
- `.mkv` — Matroska Video
- `.dng` — Digital Negative (image sequences)

## Camera Naming Conventions Supported by Gap Detection

Gap detection recognizes clip numbers from the following naming schemes:

| Camera / Source | Example | Grouping |
|---|---|---|
| **RED** (R3D) | `A001_C001_0415V0` | `A001_C###` |
| **ARRI Alexa** (Mini / LF / 35 / 65) | `A001C001_230415_R1AB` | `A001C###` |
| **Sony Venice / FX9 / FX6 / FX3** | `A001C001_230415AB` | `A001C###` |
| **Blackmagic URSA / Pocket** (BRAW, reel mode) | `A001_C001_2024…` | `A001_C###` |
| **Blackmagic URSA / Pocket** (BRAW, timestamped) | `A001_08071234_C001` | `A001_*_C###` (collapsed) |
| **Canon C200 / C300 / C500** (XF-AVC) | `AA_0001_240415_C001` | `AA_0001_*_C###` (collapsed) |
| **iPhone native Camera** | `IMG_1234` | `IMG_####` |
| **iPhone Blackmagic Camera** (reel mode) | `A001_C0001_…` | `A001_C####` |
| **iPhone Blackmagic Camera** (timestamped) | `A001_20230515_C0001` | `A001_*_C####` (collapsed) |
| **ARRI Alexa 35** (underscore-roll style) | `A_0005C003_260716_121755_h1DOR` | `A_0005C###` |

**Formats not currently auto-grouped** (reported under "skipped by gap detection"):
- Sony XDCAM bare `C0001.MXF`
- GoPro `GX010001.MP4` / `GH010001.MP4`
- Panasonic P2 `0001AB.MXF`
- DJI flat-numbered clips

These clips still participate fully in filename/duration/timecode matching — only the roll-based gap analysis skips them.

## Use Cases

- **DIT Workflows**: Verify all camera originals were properly transcoded on set
- **Post-production QC**: Confirm all media survived the transcode process
- **Delivery verification**: Ensure exported files match source footage exactly
- **Archive management**: Check backup transcodes are complete before drive returns
- **Batch processing validation**: Confirm no clips were missed during automated workflows
- **Multi-camera projects**: Verify all camera angles were transcoded
- **Timecode synchronization**: Detect timecode drift or offset issues in transcoded files
- **Camera-card completeness**: Catch dropped or missing clips on ingest before returning drives

## Timecode Verification

The **Timecode Match** feature compares the start timecode between original and transcoded clips to detect synchronization issues.

**Why Timecode Verification Matters:**
- **Maintains sync** — Ensures transcoded files maintain the same timecode as camera originals
- **Detects offset issues** — Identifies clips with timecode drift or incorrect starting points
- **Critical for multi-cam** — Verifies all camera angles remain synchronized after transcoding
- **Frame-accurate reporting** — Shows exact frame differences when mismatches occur

**How It Works:**
1. Reads the "Start TC" metadata property from both original and transcoded clips
2. Parses timecode format (HH:MM:SS:FF or HH:MM:SS;FF for drop frame)
3. Calculates frame-accurate differences based on clip frame rate
4. Reports mismatches with positive (+) or negative (-) frame offsets

**When to Enable:**
- ✅ **Multi-camera shoots** — Essential for maintaining sync between cameras
- ✅ **Live event recordings** — Verifies timecode from synchronized camera systems
- ✅ **Jam-synced productions** — Confirms timecode maintained through transcode process
- ⚠️ **Archive transcodes** — May not be necessary if timecode isn't critical to workflow

**When to Disable:**
- Projects where timecode isn't relevant (wedding videos, vlogs, social content)
- Clips without embedded timecode metadata
- When transcode intentionally resets timecode (e.g., starting all clips at 01:00:00:00)

**Supported Timecode Formats:**
- Non-drop frame: `01:00:00:00` (colon separators)
- Drop frame: `01:00:00;00` (semicolon before frames)
- Automatically detects clip frame rate (23.976, 24, 25, 29.97, 30, etc.)

## Numbering Gap Detection

The **Gap Detection** feature analyzes OCN clip names for missing numbers within each roll, catching dropped or missing camera files that the filename/duration comparison wouldn't surface.

**How It Works:**
1. Parses each clip name into a *roll* and *clip number* using four ordered patterns covering the major cinema and mobile camera conventions
2. Counts how many clips share each potential *stem* (roll with a trailing `_digits` segment stripped) and collapses timestamped roll variants to their stem when 2+ clips agree
3. For each group with 2 or more clips, finds gaps between the minimum and maximum clip number and reports them
4. Lists any clips whose naming couldn't be parsed so you can verify nothing was silently skipped

**Output Notes:**
- **Non-collapsed groups** display as e.g. `B012_C (found 17 clips, range 1-17)` — prefix matches the actual filename structure
- **Collapsed groups** display as e.g. `C005_*_C (found 15 clips, range 1-15, timestamped)` — the `*` indicates a variable middle segment in the actual filenames
- **Skipped clips** appear in a separate `⚠ N clip(s) skipped by gap detection` block with up to 5 sample names

**When to Enable:**
- ✅ **Ingest verification** — Confirm all camera-card clips were copied before returning the card
- ✅ **Multi-reel shoots** — Catch missing clips within each roll before transcoding
- ✅ **Long-form productions** — Verify numbering continuity across many rolls

**When to Disable:**
- Projects using non-numeric clip names (e.g. scene/take based naming)
- Mixed-source edits where numbering is expected to be non-contiguous
- When intentional skipped numbers exist (deleted bad takes, rejected clips)

## Configuration File

The script creates a configuration file to remember your folder paths:
- **Location**: `~/.resolve_media_compare_config.txt`
- **Contents**: OCN folder path and Transcodes folder path
- **Auto-loads** on script launch for convenience

## Troubleshooting

**"ERROR: No project loaded"**
- Open a DaVinci Resolve project before running the script

**"ERROR: Please enter folder paths and click 'Save Paths' first"**
- Use the Browse buttons to select your folders
- Click Save Paths before running Auto Import

**"✗ Import to OCN bin failed (files may already exist)"**
- Files are already in the media pool
- This is normal if running import multiple times on the same media

**No clips appear in bins after import**
- Check that the folder paths are correct
- Verify the folders contain supported media formats
- Try manually importing one file to test media pool access

**Duration mismatches reported**
- Verify your transcode settings match source frame rates
- Check for clips that were trimmed during export
- Some formats report duration differently (frames vs. timecode)

**Timecode mismatches reported**
- Check if your transcode preset is set to "Preserve source timecode"
- Some export formats may reset timecode to 00:00:00:00 or 01:00:00:00
- Verify source clips have embedded timecode metadata
- Multi-camera shoots may have intentional timecode offsets (e.g., B-camera offset by +1 hour)
- Disable "Timecode Match" checkbox if timecode verification isn't needed for your workflow

**Unexpected numbering gap reported**
- Check that audio companion files (e.g. `_A01`, `_A02`) aren't being imported into the OCN bin — they can inflate clip counts but won't cause false gaps on their own
- Verify the reported missing clip number isn't an intentional skip (deleted take, rejected clip)
- For cameras that embed a timestamp between roll and clip (Canon, BRAW, iPhone BM), confirm the timestamped variants actually share a stem (e.g. all clips start with the same `C005_`)

**"⚠ N clip(s) skipped by gap detection"**
- These clips have naming that no pattern recognized (typical for GoPro, Sony XDCAM bare `C####`, Panasonic P2, DJI)
- They're still fully verified by filename, duration, and timecode comparison
- If you expect gap analysis on these clips, rename them to a recognized convention during ingest

## Requirements

- **DaVinci Resolve** (Studio or Free) with Lua scripting support
- **macOS** (uses AppleScript for folder browser dialogs; Windows/Linux support possible with modifications)
- **Consistent filename conventions** between originals and exports
- **Project open** in DaVinci Resolve before running script

## Tips for Best Results

1. **Organize before import** — Keep OCN and transcode files in separate folders
2. **Consistent naming** — Use the same base filenames for originals and exports
3. **Export logs regularly** — Save verification reports for your records
4. **Check duration mismatches** — These often indicate incomplete transcodes
5. **Review missing files** — May indicate failed exports or incorrect folder selection
6. **Enable timecode matching for multi-cam** — Critical for maintaining sync across camera angles
7. **Enable gap detection on ingest** — Catches missing clips before you return the camera card
8. **Verify timecode in transcode settings** — Ensure your export preset preserves source timecode
9. **Keep audio companions out of the OCN bin** — Import only the primary video clips to keep counts accurate

## Keyboard Shortcut Setup

You can assign a keyboard shortcut to launch Render Check directly from DaVinci Resolve without navigating the Workspace menu.

### Assign Ctrl+R in DaVinci Resolve

1. Open **DaVinci Resolve** with a project loaded
2. Go to **DaVinci Resolve → Keyboard Customization** (macOS) or **File → Keyboard Customization** (Windows/Linux)
3. In the search field, type **`Render_Check`** (or the exact script name as it appears under Workspace → Scripts)
4. Locate the script entry under the **Scripts** category
5. Click in the **Key** column next to the script name
6. Press **Ctrl+R** (or **⌘R** on macOS if preferred) to assign it
7. Click **Save** to confirm — if prompted about a conflict, choose **Reassign**

> **Note:** On macOS, **⌘R** is reserved by Resolve for Render Queue. **Ctrl+R** (the Control key, not Command) is the recommended shortcut to avoid conflicts.

### Verify the Shortcut

- Press **Ctrl+R** from any page in DaVinci Resolve
- The Render Check GUI should launch immediately
- If nothing happens, confirm the script is in the correct `Utility` scripts folder and that Resolve has been restarted since installation

> **Tip:** DaVinci Resolve's keyboard customization UI may only surface scripts that have been accessed at least once via the Workspace menu. If the script doesn't appear in the shortcut list, run it manually once first via **Workspace → Scripts → Utility → Render_Check_v7**, then return to Keyboard Customization.

## Version History

- **v7** — Added gap-detection support for underscore-roll naming (`A_0005C003_…`), excluded these rolls from timestamp stem collapsing to prevent distinct rolls from being merged
- **v6** — Roll-based gap grouping, timestamp stem collapse, unrecognized-naming report, broader camera convention coverage, fixed false-positive gap bug for clips with trailing `C` in suffix
- **v4** — GUI with folder browser, auto-import, timecode verification, gap detection (prefix-based), export logs, persistent settings

## Contributing

Submit issues or pull requests to improve functionality or add new verification features.

## License

This script is provided as-is for educational and production use. Modify as needed for your workflow.

---

**Created for DITs and post-production professionals who need reliable verification of transcoded media.**

<img width="769" height="381" alt="DaVinci_Resolve_Render_Check_Screenshot" src="https://github.com/user-attachments/assets/0bedad92-0e15-4a40-adce-9d1d367f2cd5" />

