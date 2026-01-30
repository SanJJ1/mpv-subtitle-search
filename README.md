# mpv-subtitle-search

Fuzzy search through video subtitles with [fzf](https://github.com/junegunn/fzf) and jump to any timestamp.

Press `/` to open a searchable list of all subtitle lines. Select one to jump directly to that point in the video.

> **Note**: Currently Windows-only. Linux/macOS support would require modifying the terminal spawning logic.

## Features

- **Fuzzy search** - Powered by fzf for fast, forgiving searches
- **External subtitles** - Automatically finds `.vtt` and `.srt` files alongside your video
- **Embedded subtitles** - Extracts subtitles from video containers using ffmpeg
- **YouTube support** - Deduplicates rolling subtitles from YouTube's auto-generated captions
- **Caching** - Subtitles are parsed once per video; subsequent searches are instant (resets when mpv closes)

## Requirements

- [mpv](https://mpv.io/)
- [fzf](https://github.com/junegunn/fzf) in your PATH
- [ffmpeg](https://ffmpeg.org/) in your PATH (required for embedded subtitles)
- Windows 10+ (uses `conhost` for terminal spawning)

## Installation

Copy `subtitle-search.lua` to your mpv scripts folder:

```
%APPDATA%\mpv\scripts\subtitle-search.lua
```

Or if using a portable mpv config:

```
<mpv-config-dir>\scripts\subtitle-search.lua
```

## Usage

1. Open a video in mpv
2. Press `/` to open the subtitle search
3. Type to fuzzy filter the list
4. Press Enter to jump to that timestamp
5. Press Esc to cancel

## Configuration

The default keybinding is `/`. To change it, add to your `input.conf`:

```
# Use Ctrl+f instead of /
Ctrl+f script-binding subtitle-search
```

## Supported Subtitle Formats

External subtitles are auto-detected if they match these naming patterns:
- `videoname.vtt` / `videoname.srt`
- `videoname.en.vtt` / `videoname.en.srt`
- `videoname.en-US.vtt` / `videoname.en-US.srt`

Other language codes or naming conventions require renaming the file.

## Limitations

- Windows-only (uses `conhost` for fzf)
- Only English subtitle patterns are auto-detected for external files
- For videos with multiple embedded subtitle tracks, only the first track is used
- The `/` key may conflict with other mpv scripts

## Troubleshooting

**"No subtitles found" message**
- Ensure subtitle files match the video filename (see Supported Subtitle Formats above)
- For embedded subtitles, ensure ffmpeg is installed and in your PATH

**fzf window doesn't appear**
- Verify fzf is installed: `fzf --version`
- Ensure fzf is in your system PATH

## How it works

1. Looks for external subtitle files next to the video
2. If none found, extracts embedded subtitles using ffmpeg
3. Parses the subtitle file and deduplicates YouTube-style rolling captions
4. Opens fzf in a conhost window with all subtitle lines
5. On selection, seeks mpv to that timestamp

## License

MIT
