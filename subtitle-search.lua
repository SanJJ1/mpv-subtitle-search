-- Fuzzy search subtitles with fzf and jump to timestamp
-- Press / to activate

local utils = require("mp.utils")

math.randomseed(os.time())

-- Cache for parsed subtitles
local cache = {
    path = nil,
    entries = nil
}

-- State for active fzf session
local fzf_active = false
local sync_timer = nil

local function parse_time(time_str)
    local h, m, s, ms = time_str:match("(%d+):(%d+):(%d+)[.,](%d+)")
    if not h then
        m, s, ms = time_str:match("(%d+):(%d+)[.,](%d+)")
        h = 0
    end
    if not m then return nil end
    return tonumber(h) * 3600 + tonumber(m) * 60 + tonumber(s) + tonumber(ms) / 1000
end

local function format_time(seconds)
    local h = math.floor(seconds / 3600)
    local m = math.floor((seconds % 3600) / 60)
    local s = math.floor(seconds % 60)
    if h > 0 then
        return string.format("%d:%02d:%02d", h, m, s)
    else
        return string.format("%d:%02d", m, s)
    end
end

local function find_external_subtitle()
    local path = mp.get_property("path")
    if not path then return nil end

    local dir, filename = utils.split_path(path)
    local name = filename:match("(.+)%.[^.]+$") or filename

    local patterns = {
        name .. ".en.vtt",
        name .. ".en.srt",
        name .. ".vtt",
        name .. ".srt",
        name .. ".en-US.vtt",
        name .. ".en-US.srt",
    }

    for _, pattern in ipairs(patterns) do
        local sub_path = utils.join_path(dir, pattern)
        local f = io.open(sub_path, "r")
        if f then
            f:close()
            return sub_path
        end
    end
    return nil
end

local function extract_embedded_subtitle()
    local path = mp.get_property("path")
    if not path then return nil end

    local temp_dir = os.getenv("TEMP") or "C:\\Temp"
    local temp_vtt = temp_dir .. "\\mpv_embedded_subs_" .. os.time() .. ".vtt"

    -- Try to extract first subtitle track with ffmpeg
    local result = mp.command_native({
        name = "subprocess",
        args = {"ffmpeg", "-y", "-i", path, "-map", "0:s:0", "-f", "webvtt", temp_vtt},
        capture_stdout = true,
        capture_stderr = true,
    })

    if result.status == 0 then
        local f = io.open(temp_vtt, "r")
        if f then
            f:close()
            return temp_vtt, true  -- second return indicates temp file
        end
    end
    return nil
end

local function parse_vtt(filepath)
    local entries = {}
    local f = io.open(filepath, "r")
    if not f then return entries end

    local content = f:read("*all")
    f:close()

    local current_time = nil
    local current_text = {}

    for line in content:gmatch("[^\r\n]+") do
        local start_time = line:match("^(%d+:%d+:%d+[.,]%d+)%s*%-%-?>")
        if not start_time then
            start_time = line:match("^(%d+:%d+[.,]%d+)%s*%-%-?>")
        end

        if start_time then
            if current_time and #current_text > 0 then
                local text = table.concat(current_text, " "):gsub("<[^>]+>", ""):gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
                if #text > 0 then
                    table.insert(entries, {time = current_time, text = text})
                end
            end
            current_time = parse_time(start_time)
            current_text = {}
        elseif current_time and not line:match("^%d+$") and not line:match("^WEBVTT") and not line:match("^NOTE") and not line:match("^%s*$") then
            table.insert(current_text, line)
        end
    end

    if current_time and #current_text > 0 then
        local text = table.concat(current_text, " "):gsub("<[^>]+>", ""):gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
        if #text > 0 then
            table.insert(entries, {time = current_time, text = text})
        end
    end

    return entries
end

local function deduplicate_entries(entries)
    -- YouTube VTT has rolling subtitles where each line includes previous text
    -- Keep only entries where the text isn't a prefix of the next entry's text
    local result = {}
    for i, entry in ipairs(entries) do
        local dominated = false
        -- Check if this entry's text is a prefix of any nearby future entry
        for j = i + 1, math.min(i + 5, #entries) do
            local next_entry = entries[j]
            if next_entry.text:find(entry.text, 1, true) == 1 then
                dominated = true
                break
            end
        end
        if not dominated then
            table.insert(result, entry)
        end
    end
    return result
end

local function find_closest_index(entries, target_time)
    if not target_time or #entries == 0 then return 1 end
    local best = 1
    for i, entry in ipairs(entries) do
        if math.abs(entry.time - target_time) < math.abs(entries[best].time - target_time) then
            best = i
        end
        if entry.time > target_time then
            break
        end
    end
    return best
end

local function search_subtitles()
    if fzf_active then return end

    local current_path = mp.get_property("path")
    local entries

    -- Use cache if same video
    if cache.path == current_path and cache.entries then
        entries = cache.entries
    else
        -- Try external subtitle file first
        local sub_file = find_external_subtitle()
        local is_temp = false

        -- If no external file, try extracting embedded subtitles
        if not sub_file then
            mp.osd_message("Extracting embedded subtitles...", 1)
            sub_file, is_temp = extract_embedded_subtitle()
        end

        if not sub_file then
            mp.osd_message("No subtitles found", 2)
            return
        end

        entries = parse_vtt(sub_file)

        -- Clean up temp file if we extracted it
        if is_temp then
            os.remove(sub_file)
        end

        if #entries == 0 then
            mp.osd_message("No subtitles parsed", 2)
            return
        end

        -- Deduplicate rolling YouTube subtitles
        entries = deduplicate_entries(entries)

        -- Cache for this video
        cache.path = current_path
        cache.entries = entries
    end

    -- Get current playback position and find closest subtitle
    local current_pos = mp.get_property_number("time-pos") or 0
    local initial_index = find_closest_index(entries, current_pos)

    local temp_dir = os.getenv("TEMP") or "C:\\Temp"
    local timestamp = os.time()
    local subs_file = temp_dir .. "\\mpv_subs_" .. timestamp .. ".txt"
    local result_file = temp_dir .. "\\mpv_result_" .. timestamp .. ".txt"
    local batch_file = temp_dir .. "\\mpv_fzf_" .. timestamp .. ".bat"
    local done_file = temp_dir .. "\\mpv_done_" .. timestamp .. ".txt"
    local port = 20000 + math.random(0, 40000)

    -- Write subtitle entries
    local f = io.open(subs_file, "w")
    if not f then
        mp.osd_message("Failed to create temp file", 2)
        return
    end
    for _, entry in ipairs(entries) do
        f:write(string.format("%s\t%s\n", format_time(entry.time), entry.text))
    end
    f:close()

    -- Write batch file with --listen for live sync
    local bf = io.open(batch_file, "w")
    if not bf then
        mp.osd_message("Failed to create batch file", 2)
        return
    end
    bf:write('@echo off\n')
    bf:write('type "' .. subs_file .. '" | fzf --layout=reverse --prompt="Search: " --listen=localhost:' .. port .. ' --bind "load:pos(' .. initial_index .. ')" > "' .. result_file .. '" 2>nul\n')
    bf:write('echo done > "' .. done_file .. '"\n')
    bf:write('exit /b 0\n')
    bf:close()

    fzf_active = true

    -- Launch fzf asynchronously (start returns immediately)
    os.execute('start "" conhost cmd /c "' .. batch_file .. '"')

    -- Timer: sync cursor position and detect when fzf exits
    local last_idx = initial_index
    sync_timer = mp.add_periodic_timer(0.5, function()
        -- Check if fzf has exited
        local df = io.open(done_file, "r")
        if df then
            df:close()
            fzf_active = false
            sync_timer:kill()
            sync_timer = nil

            -- Read result
            local rf = io.open(result_file, "r")
            if rf then
                local line = rf:read("*line")
                rf:close()

                if line and #line > 0 then
                    local time_str = line:match("^([%d:]+)")
                    if time_str then
                        local parts = {}
                        for part in time_str:gmatch("%d+") do
                            table.insert(parts, tonumber(part))
                        end
                        local seconds = 0
                        if #parts == 3 then
                            seconds = parts[1] * 3600 + parts[2] * 60 + parts[3]
                        elseif #parts == 2 then
                            seconds = parts[1] * 60 + parts[2]
                        end
                        mp.set_property_number("time-pos", seconds)
                        mp.osd_message("Jumped to " .. time_str, 1)
                    end
                end
            end

            -- Cleanup
            os.remove(subs_file)
            os.remove(result_file)
            os.remove(batch_file)
            os.remove(done_file)
            return
        end

        -- Sync: update fzf cursor to follow playback (only if position changed)
        local pos = mp.get_property_number("time-pos")
        if pos then
            local idx = find_closest_index(entries, pos)
            if idx ~= last_idx then
                last_idx = idx
                mp.command_native_async({
                    name = "subprocess",
                    args = {"curl.exe", "-s", "--connect-timeout", "1", "-X", "POST", "http://localhost:" .. port, "-d", "pos(" .. idx .. ")"},
                    capture_stdout = true,
                    capture_stderr = true,
                }, function() end)
            end
        end
    end)
end

mp.add_key_binding("/", "subtitle-search", search_subtitles)
