# mpv-subtitle-search

Fuzzy search through video subtitles with [fzf](https://github.com/junegunn/fzf) and jump to any timestamp.

Press `/` to open a searchable list of all subtitle lines. Select one to jump directly to that point in the video.

## Features

- **Fuzzy search** - Powered by fzf for fast, forgiving searches
- **External subtitles** - Automatically finds `.vtt` and `.srt` files alongside your video
- **Embedded subtitles** - Extracts subtitles from video containers using ffmpeg
- **YouTube support** - Deduplicates rolling subtitles from YouTube's auto-generated captions
- **Caching** - Subtitles are parsed once per video; subsequent searches are instant

## Requirements

- [mpv](https://mpv.io/)
- [fzf](https://github.com/junegunn/fzf)
- [ffmpeg](https://ffmpeg.org/) (optional, for embedded subtitle extraction)

## Installation

### Windows

Copy `subtitle-search.lua` to your mpv scripts folder:

```
%APPDATA%\mpv\scripts\subtitle-search.lua
```

Or if using a portable mpv config:

```
<mpv-config-dir>\scripts\subtitle-search.lua
```

### Linux/macOS

```bash
cp subtitle-search.lua ~/.config/mpv/scripts/
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

## How it works

1. Looks for external subtitle files (`.en.vtt`, `.srt`, etc.) next to the video
2. If none found, extracts embedded subtitles using ffmpeg
3. Parses the subtitle file and deduplicates YouTube-style rolling captions
4. Opens fzf in a terminal window with all subtitle lines
5. On selection, seeks mpv to that timestamp

## License

MIT
