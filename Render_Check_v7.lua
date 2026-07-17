-- DaVinci Resolve Media Comparison Tool with GUI
-- Compare clips between OCN and TRANSCODES bins

local resolve = Resolve()
local projectManager = resolve:GetProjectManager()
local project = projectManager:GetCurrentProject()

-- Initialize UI Manager
local ui = app.UIManager
local disp = bmd.UIDispatcher(ui)

-- Global variables
local binNameOriginal = "OCN"
local binNameExported = "TRANSCODES"
local resultsText = ""
local configFilePath = os.getenv("HOME") .. "/.resolve_media_compare_config.txt"

-- Custom table merge function
function tableMerge(t1, t2)
    local result = {}
    for _, v in ipairs(t1) do
        table.insert(result, v)
    end
    for _, v in ipairs(t2) do
        table.insert(result, v)
    end
    return result
end

-- Function to find bin by name
function findBinByName(binName)
    local mediaPool = project:GetMediaPool()
    local rootFolder = mediaPool:GetRootFolder()
    local subFolders = rootFolder:GetSubFolders()

    for _, folder in ipairs(subFolders) do
        if folder:GetName() == binName then
            return folder
        end
    end
    return nil
end

-- Function to collect all media items in a bin
function collectMediaItems(bin)
    local items = {}
    local clips = bin:GetClips()

    for _, clip in ipairs(clips) do
        table.insert(items, clip)
    end

    local subFolders = bin:GetSubFolders()
    if subFolders then
        for _, subFolder in ipairs(subFolders) do
            local subItems = collectMediaItems(subFolder)
            items = tableMerge(items, subItems)
        end
    end

    return items
end

-- Function to get base filename without extension and _001 suffix
function getBaseName(filename)
    local baseName = filename:match("(.+)%.[^%.]+$") or filename
    baseName = baseName:gsub("_001$", "")
    return baseName
end

-- Function to parse timecode string to total frames
-- Expects format like "HH:MM:SS:FF" or "HH:MM:SS;FF" (drop frame)
function parseTimecodeToFrames(tcString, fps)
    if not tcString or tcString == "" then
        return nil
    end

    -- Default to 24 fps if not provided
    fps = fps or 24

    -- Handle both : and ; separators (drop frame uses ;)
    local h, m, s, f = tcString:match("(%d+)[:|;](%d+)[:|;](%d+)[:|;](%d+)")
    if not h then
        return nil
    end

    h, m, s, f = tonumber(h), tonumber(m), tonumber(s), tonumber(f)
    local totalFrames = (h * 3600 + m * 60 + s) * fps + f
    return totalFrames
end

-- Function to calculate timecode difference and return as formatted string
function getTimecodeDifference(tc1, tc2, fps)
    local frames1 = parseTimecodeToFrames(tc1, fps)
    local frames2 = parseTimecodeToFrames(tc2, fps)

    if not frames1 or not frames2 then
        return nil, nil
    end

    local diff = frames2 - frames1
    return diff, frames1, frames2
end

-- Function to extract clip number from a filename
-- Looks for common patterns like A001C003, B012C045, or trailing numbers
function extractClipNumber(filename)
    -- Try camera-roll pattern: letter(s) + roll digits + "C" + clip digits (e.g. A001C003)
    local clipNum = filename:match("[A-Z]%d+C(%d+)")
    if clipNum then
        return tonumber(clipNum)
    end

    -- Try trailing number pattern (e.g. MyClip_0042)
    clipNum = filename:match("_(%d+)$")
    if clipNum then
        return tonumber(clipNum)
    end

    -- Try any trailing digits
    clipNum = filename:match("(%d+)$")
    if clipNum then
        return tonumber(clipNum)
    end

    return nil
end

-- Parse a clip name into roll, clip number, digit count, and style.
-- style identifies the separator between roll and clip number so the
-- display string can be reconstructed later.
function parseRollAndClip(name)
    -- Pattern A: roll + "_C" + digits  (RED, Blackmagic, Canon, many cinema rigs).
    -- Lazy match anchors on the first "_C" so a trailing "C" in the suffix
    -- (e.g. "B012_C002_0415C9") cannot be mistaken for the clip "C".
    local roll, clipNum = name:match("^(.-)_C(%d+)")
    if roll and roll ~= "" and clipNum then
        return roll, tonumber(clipNum), #clipNum, "underscore_C"
    end

    -- Pattern B: letters + digits + "C" + digits, no underscore (ARRI, Sony Venice)
    roll, clipNum = name:match("^([A-Z]+%d+)C(%d+)")
    if roll and clipNum then
        return roll, tonumber(clipNum), #clipNum, "noUnderscoreC"
    end

    -- Pattern B2: letters + "_" + digits + "C" + digits (e.g. A_0005C003_...)
    roll, clipNum = name:match("^([A-Z]+_%d+)C(%d+)")
    if roll and clipNum then
        return roll, tonumber(clipNum), #clipNum, "underscoreDigitsC"
    end

    -- Pattern C: prefix + "_" + trailing digits (iPhone IMG_1234, generic)
    roll, clipNum = name:match("^(.-)_(%d+)$")
    if roll and roll ~= "" and clipNum then
        return roll, tonumber(clipNum), #clipNum, "trailing"
    end

    return nil
end

function styleSeparator(style)
    if style == "underscore_C" then return "_C" end
    if style == "noUnderscoreC" then return "C" end
    if style == "underscoreDigitsC" then return "C" end
    if style == "trailing" then return "_" end
    return ""
end

-- Detect gaps in clip numbering. Groups by roll, collapses timestamped roll
-- variants (e.g. "C005_04151714", "C005_04151748" -> "C005") when 2+ clips
-- share the stem, and reports clips whose naming no pattern recognized.
-- Returns: allGaps table, unparsedNames list.
function detectNumberingGaps(mediaItems)
    local parsed = {}
    local unparsed = {}

    for _, clip in ipairs(mediaItems) do
        local name = getBaseName(clip:GetName())
        local roll, num, digitCount, style = parseRollAndClip(name)
        if roll then
            table.insert(parsed, {
                roll = roll,
                num = num,
                digitCount = digitCount,
                style = style,
            })
        else
            table.insert(unparsed, name)
        end
    end

    -- Count clips sharing each potential stem (roll with trailing _digits stripped).
    local stemCounts = {}
    for _, p in ipairs(parsed) do
        -- Rolls like "A_0005" (underscoreDigitsC) end in _digits by design;
        -- collapsing them would merge distinct rolls, so skip them here.
        if p.style ~= "underscoreDigitsC" then
            local stem = p.roll:match("^(.-)_%d+$")
            if stem and stem ~= "" then
                stemCounts[stem] = (stemCounts[stem] or 0) + 1
            end
        end
    end

    -- Group clips. Collapse to stem only when 2+ clips share it.
    local groups = {}
    for _, p in ipairs(parsed) do
        local key = p.roll
        local collapsed = false
        local stem = nil
        if p.style ~= "underscoreDigitsC" then
            stem = p.roll:match("^(.-)_%d+$")
        end
        if stem and stem ~= "" and stemCounts[stem] and stemCounts[stem] >= 2 then
            key = stem
            collapsed = true
        end
        if not groups[key] then
            groups[key] = {
                numbers = {},
                digitCount = p.digitCount,
                style = p.style,
                collapsed = collapsed,
                roll = key,
            }
        end
        table.insert(groups[key].numbers, p.num)
        if p.digitCount > groups[key].digitCount then
            groups[key].digitCount = p.digitCount
        end
    end

    local allGaps = {}
    for _, data in pairs(groups) do
        local numbers = data.numbers
        if #numbers > 1 then
            table.sort(numbers)

            local minNum = numbers[1]
            local maxNum = numbers[#numbers]
            local numSet = {}
            for _, n in ipairs(numbers) do
                numSet[n] = true
            end

            local sep = styleSeparator(data.style)
            local displayPrefix
            if data.collapsed then
                displayPrefix = data.roll .. "_*" .. sep
            else
                displayPrefix = data.roll .. sep
            end

            local missing = {}
            for i = minNum, maxNum do
                if not numSet[i] then
                    local formatted = string.format("%0" .. data.digitCount .. "d", i)
                    table.insert(missing, displayPrefix .. formatted)
                end
            end

            if #missing > 0 then
                table.insert(allGaps, {
                    prefix = displayPrefix,
                    missing = missing,
                    rangeMin = minNum,
                    rangeMax = maxNum,
                    totalFound = #numbers,
                    collapsed = data.collapsed,
                })
            end
        end
    end

    return allGaps, unparsed
end

-- Function to browse for folder using AppleScript
function browseForFolder(title)
    local cmd = 'osascript -e \'set folderPath to choose folder with prompt "' .. title .. '"\' -e \'return POSIX path of folderPath\' 2>/dev/null'
    local handle = io.popen(cmd)
    if handle then
        local result = handle:read("*a")
        handle:close()
        -- Remove trailing newline and slash
        result = result:gsub("\n$", ""):gsub("/$", "")
        if result and result ~= "" then
            -- Force window to front after dialog closes
            os.execute('osascript -e \'tell application "DaVinci Resolve" to activate\' 2>/dev/null &')
            return result
        end
    end
    -- Force window to front even if cancelled
    os.execute('osascript -e \'tell application "DaVinci Resolve" to activate\' 2>/dev/null &')
    return nil
end

-- Function to browse for OCN folder
function browseOCNFolder()
    local selectedPath = browseForFolder("Select OCN Folder")
    if selectedPath then
        win:GetItems().OCNPathField.Text = selectedPath
        print("OCN path selected: " .. selectedPath)
    end
end

-- Function to browse for Transcodes folder
function browseTranscodesFolder()
    local selectedPath = browseForFolder("Select Transcodes Folder")
    if selectedPath then
        win:GetItems().TranscodesPathField.Text = selectedPath
        print("Transcodes path selected: " .. selectedPath)
    end
end

-- Function to save folder paths to config file
function savePaths()
    local ocnPath = win:GetItems().OCNPathField.Text
    local transcodesPath = win:GetItems().TranscodesPathField.Text

    local file = io.open(configFilePath, "w")
    if file then
        file:write(ocnPath .. "\n")
        file:write(transcodesPath .. "\n")
        file:close()

        local msg = win:GetItems().ResultsDisplay.PlainText
        msg = msg .. "\n✓ Folder paths saved!\n"
        win:GetItems().ResultsDisplay:SetText(msg)
        print("Paths saved to: " .. configFilePath)
    else
        local msg = win:GetItems().ResultsDisplay.PlainText
        msg = msg .. "\n✗ Failed to save paths\n"
        win:GetItems().ResultsDisplay:SetText(msg)
    end
end

-- Function to load folder paths from config file
function loadPaths()
    local file = io.open(configFilePath, "r")
    if file then
        local ocnPath = file:read("*line")
        local transcodesPath = file:read("*line")
        file:close()

        if ocnPath then
            win:GetItems().OCNPathField.Text = ocnPath
        end
        if transcodesPath then
            win:GetItems().TranscodesPathField.Text = transcodesPath
        end

        print("Paths loaded from: " .. configFilePath)
        return true
    end
    return false
end

-- Function to scan directory and get all media files
function scanDirectory(dirPath)
    local files = {}

    -- Use ls command to get files
    local handle = io.popen('find "' .. dirPath .. '" -type f \\( -iname "*.mov" -o -iname "*.mp4" -o -iname "*.mxf" -o -iname "*.r3d" -o -iname "*.braw" -o -iname "*.avi" -o -iname "*.mkv" -o -iname "*.dng" \\)')
    if handle then
        for file in handle:lines() do
            table.insert(files, file)
        end
        handle:close()
    end

    return files
end

-- Function to auto-import media files
function autoImport()
    if not project then
        win:GetItems().ResultsDisplay:SetText("ERROR: No project loaded.\n")
        return
    end

    local ocnPath = win:GetItems().OCNPathField.Text
    local transcodesPath = win:GetItems().TranscodesPathField.Text

    if ocnPath == "" or transcodesPath == "" then
        win:GetItems().ResultsDisplay:SetText("ERROR: Please enter folder paths and click 'Save Paths' first.\n")
        return
    end

    resultsText = "Starting auto-import...\n\n"
    win:GetItems().ResultsDisplay:SetText(resultsText)

    local mediaPool = project:GetMediaPool()

    -- Get or create bins
    local ocnBin = findBinByName(binNameOriginal)
    local transcodesBin = findBinByName(binNameExported)

    if not ocnBin then
        resultsText = resultsText .. "Creating OCN bin...\n"
        ocnBin = mediaPool:AddSubFolder(mediaPool:GetRootFolder(), binNameOriginal)
    end

    if not transcodesBin then
        resultsText = resultsText .. "Creating TRANSCODES bin...\n"
        transcodesBin = mediaPool:AddSubFolder(mediaPool:GetRootFolder(), binNameExported)
    end

    win:GetItems().ResultsDisplay:SetText(resultsText)

    -- Scan and import OCN files
    resultsText = resultsText .. "\nScanning OCN folder: " .. ocnPath .. "\n"
    win:GetItems().ResultsDisplay:SetText(resultsText)

    local ocnFiles = scanDirectory(ocnPath)
    resultsText = resultsText .. "Found " .. #ocnFiles .. " media files in OCN folder\n"

    if #ocnFiles > 0 then
        mediaPool:SetCurrentFolder(ocnBin)
        local imported = mediaPool:ImportMedia(ocnFiles)
        if imported then
            resultsText = resultsText .. "✓ Imported to OCN bin\n"
        else
            resultsText = resultsText .. "✗ Import to OCN bin failed (files may already exist)\n"
        end
    end

    win:GetItems().ResultsDisplay:SetText(resultsText)

    -- Scan and import TRANSCODES files
    resultsText = resultsText .. "\nScanning TRANSCODES folder: " .. transcodesPath .. "\n"
    win:GetItems().ResultsDisplay:SetText(resultsText)

    local transcodesFiles = scanDirectory(transcodesPath)
    resultsText = resultsText .. "Found " .. #transcodesFiles .. " media files in TRANSCODES folder\n"

    if #transcodesFiles > 0 then
        mediaPool:SetCurrentFolder(transcodesBin)
        local imported = mediaPool:ImportMedia(transcodesFiles)
        if imported then
            resultsText = resultsText .. "✓ Imported to TRANSCODES bin\n"
        else
            resultsText = resultsText .. "✗ Import to TRANSCODES bin failed (files may already exist)\n"
        end
    end

    resultsText = resultsText .. "\n=== AUTO-IMPORT COMPLETE ===\n"
    resultsText = resultsText .. "Total OCN files: " .. #ocnFiles .. "\n"
    resultsText = resultsText .. "Total TRANSCODES files: " .. #transcodesFiles .. "\n"

    win:GetItems().ResultsDisplay:SetText(resultsText)
end

-- Function to export log to file
function exportLog()
    -- Debug: Show that function is being called
    print("Export Log button clicked!")

    local currentResults = win:GetItems().ResultsDisplay.PlainText
    print("Current results length: " .. #currentResults)

    if currentResults == "" or currentResults == "Click 'Run Comparison' to start..." then
        local tempText = "No results to export. Run a comparison first.\n"
        win:GetItems().ResultsDisplay:SetText(tempText)
        print("No results to export")
        return
    end

    -- Get timestamp for filename
    local timestamp = os.date("%Y-%m-%d_%H-%M-%S")
    local projectName = "Unknown"

    if project then
        projectName = project:GetName() or "Unknown"
    end

    print("Project name: " .. projectName)

    -- Save to Desktop automatically
    local homeDir = os.getenv("HOME")
    print("Home dir: " .. (homeDir or "nil"))

    local desktopPath = homeDir .. "/Desktop/"
    local filename = "MediaComparison_" .. projectName .. "_" .. timestamp .. ".txt"
    local fullPath = desktopPath .. filename

    print("Attempting to write to: " .. fullPath)

    -- Write log file
    local file, err = io.open(fullPath, "w")
    if file then
        print("File opened successfully")
        -- Write header
        file:write("===========================================\n")
        file:write("DaVinci Resolve - Media Comparison Log\n")
        file:write("===========================================\n")
        file:write("Project: " .. projectName .. "\n")
        file:write("Date: " .. os.date("%Y-%m-%d %H:%M:%S") .. "\n")
        file:write("Original Bin: " .. win:GetItems().OriginalBinName:GetText() .. "\n")
        file:write("Exported Bin: " .. win:GetItems().ExportedBinName:GetText() .. "\n")
        file:write("===========================================\n\n")

        -- Write results
        file:write(currentResults)

        file:close()
        print("File written and closed successfully")

        local successMsg = currentResults .. "\n\n--- LOG EXPORTED ---\nSaved to: " .. fullPath .. "\n"
        win:GetItems().ResultsDisplay:SetText(successMsg)
    else
        print("ERROR opening file: " .. (err or "unknown error"))
        local errorMsg = currentResults .. "\n\nERROR: Could not write to file: " .. fullPath .. "\n"
        if err then
            errorMsg = errorMsg .. "Error: " .. err .. "\n"
        end
        win:GetItems().ResultsDisplay:SetText(errorMsg)
    end
end

-- Function to create bins
function createBins()
    resultsText = ""

    if not project then
        resultsText = "ERROR: No project loaded. Please load a project and try again.\n"
        win:GetItems().ResultsDisplay:SetText(resultsText)
        return
    end

    local mediaPool = project:GetMediaPool()
    local rootFolder = mediaPool:GetRootFolder()

    -- Get bin names from text fields
    local origBinName = win:GetItems().OriginalBinName:GetText()
    local exportBinName = win:GetItems().ExportedBinName:GetText()

    resultsText = "Creating bins...\n\n"

    -- Check if bins already exist
    local origBinExists = findBinByName(origBinName)
    local exportBinExists = findBinByName(exportBinName)

    -- Create Original Bin if it doesn't exist
    if origBinExists then
        resultsText = resultsText .. "✓ Bin '" .. origBinName .. "' already exists\n"
    else
        local newBin = mediaPool:AddSubFolder(rootFolder, origBinName)
        if newBin then
            resultsText = resultsText .. "✓ Created bin: '" .. origBinName .. "'\n"
        else
            resultsText = resultsText .. "✗ Failed to create bin: '" .. origBinName .. "'\n"
        end
    end

    -- Create Exported Bin if it doesn't exist
    if exportBinExists then
        resultsText = resultsText .. "✓ Bin '" .. exportBinName .. "' already exists\n"
    else
        local newBin = mediaPool:AddSubFolder(rootFolder, exportBinName)
        if newBin then
            resultsText = resultsText .. "✓ Created bin: '" .. exportBinName .. "'\n"
        else
            resultsText = resultsText .. "✗ Failed to create bin: '" .. exportBinName .. "'\n"
        end
    end

    resultsText = resultsText .. "\nBin creation complete!\n"
    win:GetItems().ResultsDisplay:SetText(resultsText)
end

-- Main comparison function
function runComparison()
    resultsText = ""

    if not project then
        resultsText = "ERROR: No project loaded. Please load a project and try again.\n"
        win:GetItems().ResultsDisplay:SetText(resultsText)
        return
    end

    local mediaPool = project:GetMediaPool()

    -- Update bin names from text fields
    binNameOriginal = win:GetItems().OriginalBinName:GetText()
    binNameExported = win:GetItems().ExportedBinName:GetText()

    resultsText = "Starting comparison...\n"
    resultsText = resultsText .. "Original Bin: " .. binNameOriginal .. "\n"
    resultsText = resultsText .. "Exported Bin: " .. binNameExported .. "\n\n"
    win:GetItems().ResultsDisplay:SetText(resultsText)

    -- Get the two bins
    local originalBin = findBinByName(binNameOriginal)
    local exportedBin = findBinByName(binNameExported)

    if not originalBin or not exportedBin then
        resultsText = resultsText .. "ERROR: One or both bins not found. Check bin names.\n"
        resultsText = resultsText .. "Looking for: '" .. binNameOriginal .. "' and '" .. binNameExported .. "'\n"
        win:GetItems().ResultsDisplay:SetText(resultsText)
        return
    end

    -- Collect media items from both bins
    local originalMedia = collectMediaItems(originalBin)
    local exportedMedia = collectMediaItems(exportedBin)

    resultsText = resultsText .. "Found " .. #originalMedia .. " clips in original bin\n"
    resultsText = resultsText .. "Found " .. #exportedMedia .. " clips in exported bin\n\n"
    win:GetItems().ResultsDisplay:SetText(resultsText)

    -- Create lookup table for exported clips
    local exportedLookup = {}
    for _, clip in ipairs(exportedMedia) do
        local baseName = getBaseName(clip:GetName())
        exportedLookup[baseName] = clip
    end

    -- Compare media items
    local matchCount = 0
    local missingInExport = {}
    local mismatches = {}
    local timecodeMismatches = {}

    -- Check if timecode matching is enabled
    local checkTimecode = win:GetItems().TimecodeMatchCheckbox.Checked

    for _, originalClip in ipairs(originalMedia) do
        local originalName = originalClip:GetName()
        local originalBaseName = getBaseName(originalName)
        local exportedClip = exportedLookup[originalBaseName]

        if not exportedClip then
            resultsText = resultsText .. "MISSING in TRANSCODES: " .. originalName .. "\n"
            table.insert(missingInExport, originalName)
        else
            -- Compare metadata
            local origDuration = originalClip:GetClipProperty("Duration")
            local exportDuration = exportedClip:GetClipProperty("Duration")
            local hasDurationMismatch = origDuration ~= exportDuration
            local hasTimecodeMismatch = false

            -- Check timecode if enabled
            local origStartTC = nil
            local exportStartTC = nil
            local tcDiff = nil

            if checkTimecode then
                origStartTC = originalClip:GetClipProperty("Start TC")
                exportStartTC = exportedClip:GetClipProperty("Start TC")

                -- Get FPS for accurate frame calculation
                local fpsValue = originalClip:GetClipProperty("FPS") or 24
                local fps
                if type(fpsValue) == "number" then
                    fps = fpsValue
                else
                    fps = tonumber(tostring(fpsValue):match("([%d%.]+)")) or 24
                end

                if origStartTC and exportStartTC and origStartTC ~= exportStartTC then
                    hasTimecodeMismatch = true
                    tcDiff = getTimecodeDifference(origStartTC, exportStartTC, fps)

                    local tcMismatch = {
                        original = originalName,
                        exported = exportedClip:GetName(),
                        origTC = origStartTC,
                        exportTC = exportStartTC,
                        frameDiff = tcDiff
                    }
                    table.insert(timecodeMismatches, tcMismatch)
                end
            end

            if hasDurationMismatch then
                local mismatch = {
                    original = originalName,
                    exported = exportedClip:GetName(),
                    issue = "Duration mismatch",
                    origValue = origDuration or "Unknown",
                    exportValue = exportDuration or "Unknown"
                }
                table.insert(mismatches, mismatch)
                resultsText = resultsText .. "DURATION MISMATCH:\n"
                resultsText = resultsText .. "  Original: " .. originalName .. " (" .. (origDuration or "Unknown") .. ")\n"
                resultsText = resultsText .. "  Exported: " .. exportedClip:GetName() .. " (" .. (exportDuration or "Unknown") .. ")\n"
            end

            if hasTimecodeMismatch then
                resultsText = resultsText .. "TIMECODE MISMATCH:\n"
                resultsText = resultsText .. "  Original: " .. originalName .. " (Start TC: " .. (origStartTC or "Unknown") .. ")\n"
                resultsText = resultsText .. "  Exported: " .. exportedClip:GetName() .. " (Start TC: " .. (exportStartTC or "Unknown") .. ")\n"
                if tcDiff then
                    local diffSign = tcDiff >= 0 and "+" or ""
                    resultsText = resultsText .. "  Difference: " .. diffSign .. tcDiff .. " frames\n"
                end
            end

            if not hasDurationMismatch and not hasTimecodeMismatch then
                matchCount = matchCount + 1
                resultsText = resultsText .. "✓ Match: " .. originalBaseName .. "\n"
            end
        end
        win:GetItems().ResultsDisplay:SetText(resultsText)
    end

    -- Check for extra files in export bin
    local extraInExport = {}
    for _, exportedClip in ipairs(exportedMedia) do
        local exportedName = exportedClip:GetName()
        local exportedBaseName = getBaseName(exportedName)

        local foundOriginal = false
        for _, originalClip in ipairs(originalMedia) do
            if getBaseName(originalClip:GetName()) == exportedBaseName then
                foundOriginal = true
                break
            end
        end

        if not foundOriginal then
            table.insert(extraInExport, exportedName)
            resultsText = resultsText .. "EXTRA in TRANSCODES (no original): " .. exportedName .. "\n"
        end
    end

    -- Gap detection in OCN numbering
    local checkGaps = win:GetItems().GapDetectionCheckbox.Checked
    local totalGapCount = 0

    if checkGaps then
        local gaps, unparsed = detectNumberingGaps(originalMedia)

        resultsText = resultsText .. "\n=== NUMBERING GAP DETECTION (OCN) ===\n"

        if #gaps > 0 then
            for _, gapGroup in ipairs(gaps) do
                local note = gapGroup.collapsed and ", timestamped" or ""
                resultsText = resultsText .. "\nPrefix: " .. gapGroup.prefix
                    .. " (found " .. gapGroup.totalFound .. " clips, range "
                    .. gapGroup.rangeMin .. "-" .. gapGroup.rangeMax .. note .. ")\n"
                resultsText = resultsText .. "Missing clip numbers:\n"
                for _, missing in ipairs(gapGroup.missing) do
                    resultsText = resultsText .. "  ⚠ " .. missing .. "\n"
                    totalGapCount = totalGapCount + 1
                end
            end
        else
            resultsText = resultsText .. "✓ No gaps detected in clip numbering\n"
        end

        if unparsed and #unparsed > 0 then
            resultsText = resultsText .. "\n⚠ " .. #unparsed
                .. " clip(s) skipped by gap detection (unrecognized naming):\n"
            local preview = {}
            for i = 1, math.min(5, #unparsed) do
                table.insert(preview, unparsed[i])
            end
            resultsText = resultsText .. "  " .. table.concat(preview, ", ")
            if #unparsed > 5 then
                resultsText = resultsText .. " (+" .. (#unparsed - 5) .. " more)"
            end
            resultsText = resultsText .. "\n"
        end

        win:GetItems().ResultsDisplay:SetText(resultsText)
    end

    -- Final summary
    resultsText = resultsText .. "\n=== VERIFICATION SUMMARY ===\n"
    resultsText = resultsText .. "Perfect matches: " .. matchCount .. "\n"
    resultsText = resultsText .. "Missing in TRANSCODES: " .. #missingInExport .. "\n"
    resultsText = resultsText .. "Extra in TRANSCODES: " .. #extraInExport .. "\n"
    resultsText = resultsText .. "Duration mismatches: " .. #mismatches .. "\n"
    if checkTimecode then
        resultsText = resultsText .. "Timecode mismatches: " .. #timecodeMismatches .. "\n"
    end
    if checkGaps then
        resultsText = resultsText .. "Numbering gaps in OCN: " .. totalGapCount .. "\n"
    end
    resultsText = resultsText .. "\n"

    if #missingInExport == 0 and #extraInExport == 0 and #mismatches == 0 and #timecodeMismatches == 0 and totalGapCount == 0 then
        resultsText = resultsText .. "SUCCESS: All " .. matchCount .. " clips verified successfully!\n"
    else
        resultsText = resultsText .. "ISSUES FOUND - Review the details above\n"
    end

    win:GetItems().ResultsDisplay:SetText(resultsText)
end

-- Create the GUI window
win = disp:AddWindow({
    ID = "CompareWindow",
    WindowTitle = "Media Comparison Tool",
    Geometry = {100, 100, 800, 600},

    ui:VGroup{
        ID = "root",
        Spacing = 5,

        -- Bin names section
        ui:HGroup{
            Weight = 0,
            Spacing = 10,
            ui:Label{Text = "Original Bin:", Weight = 0, MinimumSize = {80, 0}},
            ui:LineEdit{
                ID = "OriginalBinName",
                Text = "OCN",
                PlaceholderText = "Enter original bin name",
                ToolTip = "Name of the Media Pool bin containing your original camera negatives (source media).",
            },
            ui:Label{Text = "Exported Bin:", Weight = 0, MinimumSize = {85, 0}},
            ui:LineEdit{
                ID = "ExportedBinName",
                Text = "TRANSCODES",
                PlaceholderText = "Enter exported bin name",
                ToolTip = "Name of the Media Pool bin containing your rendered/transcoded deliverables.",
            },
        },

        -- Folder paths section
        ui:HGroup{
            Weight = 0,
            Spacing = 10,
            ui:Label{Text = "OCN Folder:", Weight = 0, MinimumSize = {80, 0}},
            ui:LineEdit{
                ID = "OCNPathField",
                Text = "",
                PlaceholderText = "/path/to/OCN/folder",
                ToolTip = "File system path to the folder containing your original camera negative files for auto-import.",
            },
            ui:Button{
                ID = "BrowseOCNButton",
                Text = "Browse...",
                MinimumSize = {80, 0},
                ToolTip = "Open a folder picker to select the OCN source folder.",
            },
        },

        ui:HGroup{
            Weight = 0,
            Spacing = 10,
            ui:Label{Text = "Transcodes Folder:", Weight = 0, MinimumSize = {80, 0}},
            ui:LineEdit{
                ID = "TranscodesPathField",
                Text = "",
                PlaceholderText = "/path/to/TRANSCODES/folder",
                ToolTip = "File system path to the folder containing your transcoded/rendered deliverable files for auto-import.",
            },
            ui:Button{
                ID = "BrowseTranscodesButton",
                Text = "Browse...",
                MinimumSize = {80, 0},
                ToolTip = "Open a folder picker to select the Transcodes deliverable folder.",
            },
        },

        -- Import buttons
        ui:HGroup{
            Weight = 0,
            Spacing = 10,
            ui:Button{
                ID = "SavePathsButton",
                Text = "Save Paths",
                ToolTip = "Save the OCN and Transcodes folder paths to a config file so they persist between sessions.",
            },
            ui:Button{
                ID = "AutoImportButton",
                Text = "Auto Import",
                ToolTip = "Scan the OCN and Transcodes folders for media files and import them into their respective bins automatically.",
            },
        },

        -- Comparison options
        ui:HGroup{
            Weight = 0,
            Spacing = 10,
            ui:CheckBox{
                ID = "TimecodeMatchCheckbox",
                Text = "Timecode Match",
                Checked = true,
                ToolTip = "Compare start timecodes between OCN and Transcodes clips. Flags any mismatches with frame-level difference.",
            },
            ui:CheckBox{
                ID = "GapDetectionCheckbox",
                Text = "Gap Detection",
                Checked = true,
                ToolTip = "Detect missing clip numbers in the OCN bin (e.g., A001C003 exists but A001C004 is missing). Useful for catching dropped or missing camera files.",
            },
        },

        -- Action buttons
        ui:HGroup{
            Weight = 0,
            Spacing = 10,
            ui:Button{
                ID = "CreateBinsButton",
                Text = "Create Bins",
                ToolTip = "Create the OCN and TRANSCODES bins in the Media Pool if they don't already exist.",
            },
            ui:Button{
                ID = "CompareButton",
                Text = "▶  Run Comparison",
                MinimumSize = {160, 32},
                ToolTip = "Compare all clips between the OCN and Transcodes bins. Checks for missing files, duration mismatches, timecode differences, and numbering gaps.",
                StyleSheet = [[
                    QPushButton {
                        background-color: #4CAF50;
                        color: white;
                        font-weight: bold;
                        font-size: 13px;
                        border: none;
                        border-radius: 4px;
                        padding: 4px 12px;
                    }
                    QPushButton:hover {
                        background-color: #45a049;
                    }
                    QPushButton:pressed {
                        background-color: #3d8b40;
                    }
                ]],
            },
            ui:Button{
                ID = "ExportLogButton",
                Text = "Export Log",
                ToolTip = "Save the current results to a timestamped text file on your Desktop for record-keeping.",
            },
            ui:Button{
                ID = "ClearButton",
                Text = "Clear Results",
                ToolTip = "Clear the results display below.",
            },
        },

        ui:TextEdit{
            ID = "ResultsDisplay",
            Text = "Click 'Run Comparison' to start...",
            ReadOnly = true,
            StyleSheet = [[
                font-family: monospace;
                background-color: #1e1e1e;
                color: #d4d4d4;
                padding: 8px;
            ]],
        },

        -- Close button
        ui:HGroup{
            Weight = 0,
            ui:HGap(0, 1),
            ui:Button{
                ID = "CloseButton",
                Text = "Close",
                ToolTip = "Close this window.",
            },
        },
    },
})

-- Get window items
itm = win:GetItems()

-- Button click handlers
function win.On.BrowseOCNButton.Clicked(ev)
    browseOCNFolder()
end

function win.On.BrowseTranscodesButton.Clicked(ev)
    browseTranscodesFolder()
end

function win.On.SavePathsButton.Clicked(ev)
    savePaths()
end

function win.On.AutoImportButton.Clicked(ev)
    autoImport()
end

function win.On.CreateBinsButton.Clicked(ev)
    createBins()
end

function win.On.CompareButton.Clicked(ev)
    runComparison()
end

function win.On.ExportLogButton.Clicked(ev)
    exportLog()
end

function win.On.ClearButton.Clicked(ev)
    itm.ResultsDisplay:SetText("")
end

function win.On.CloseButton.Clicked(ev)
    disp:ExitLoop()
end

-- Load saved paths on startup
loadPaths()

-- Show the window
win:Show()
disp:RunLoop()
win:Hide()
