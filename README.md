# VidPro - Video Processing CLI

Unified command-line tool for all video processing tasks in the KPODCAST workflow.

## Why VidPro?

Before: scattered tools across multiple directories, inconsistent interfaces
After: one CLI for everything, intuitive commands, consistent output

## Quick Start

```bash
# Add to PATH (optional)
echo 'export PATH="$HOME/clawd-mura/projects/video-cli:$PATH"' >> ~/.zshrc
source ~/.zshrc

# Or use full path
~/clawd-mura/projects/video-cli/vidpro.sh help
```

## Common Workflows

### Create a Short (Full Pipeline)

```bash
# 1. Cut segment
vidpro cut episode.mp4 00:05:30 00:06:00 /tmp/segment.mp4

# 2. Clean SRT
vidpro clean-srt segment.srt segment_clean.srt

# 3. Burn subtitles
vidpro subs /tmp/segment.mp4 segment_clean.srt /tmp/segment_sub.mp4

# 4. Face crop to vertical
vidpro face-crop /tmp/segment_sub.mp4 short_final.mp4

# 5. Generate thumbnail
vidpro thumbnail episode.mp4 segment.srt "L2 R1" "ტექსტი 1" "ტექსტი 2" thumb.jpg
```

### Batch Processing

```bash
# Create timestamps file
cat > cuts.txt << 'EOF'
00:01:30,00:02:00,intro
00:05:45,00:06:15,funny_moment
00:12:00,00:12:30,conclusion
EOF

# Cut all segments
vidpro batch-cut episode.mp4 cuts.txt ./clips/

# Clean all SRT files
for srt in clips/*.srt; do
    vidpro clean-srt "$srt" "${srt%.srt}_clean.srt"
done
```

### Quick Tasks

```bash
# Get video info
vidpro info video.mp4

# Extract audio
vidpro extract-audio video.mp4 audio.mp3

# Resize video
vidpro resize video.mp4 1280 720 resized.mp4

# Concat videos
vidpro concat part1.mp4 part2.mp4 part3.mp4 full.mp4
```

## All Commands

| Command | What It Does | Speed |
|---------|--------------|-------|
| `cut` | Cut segment (stream copy) | Instant |
| `cut-precise` | Cut segment (re-encode) | Slow |
| `subs` | Burn subtitles (yellow Georgian) | Medium |
| `clean-srt` | Remove filler words | Instant |
| `face-crop` | Horizontal → vertical 9:16 | Medium |
| `thumbnail` | Generate YouTube thumbnail | 2-3 min |
| `batch-cut` | Cut multiple segments | Fast |
| `info` | Show video metadata | Instant |
| `concat` | Join videos | Fast |
| `resize` | Change dimensions | Medium |
| `extract-audio` | Extract audio as MP3 | Fast |

## When to Use What

### Cut vs Cut-Precise

- **Use `cut`** (stream copy): Fast, no quality loss, but not frame-perfect
- **Use `cut-precise`** (re-encode): Slow, frame-perfect timing

### Subtitles

Always clean SRT before burning:
```bash
vidpro clean-srt raw.srt clean.srt
vidpro subs video.mp4 clean.srt output.mp4
```

Georgian filler words removed: ააა, ამმ, მჰმ, მმ, მმმ, ეჰმ, ესე იგი

## Integration

### With YouTube Uploader

```bash
vidpro thumbnail ep.mp4 ep.srt "L2 R1" "text1" "text2" thumb.jpg

cd ~/clawd-mura/projects/yt-poster
python3 yt.py short video.mp4 \
  --title "Title #shorts" \
  --thumbnail ../video-cli/thumb.jpg
```

### With Mission Control

```bash
# Add task to Mission Control
curl -X POST http://localhost:3847/api/tasks \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Process episode 5",
    "description": "vidpro batch-cut episode5.mp4 timestamps.txt ./clips/",
    "priority": "high",
    "assignees": [1]
  }'
```

## Tips & Tricks

### Parallel Processing

```bash
# Process multiple videos in parallel (max 2 ffmpeg jobs recommended)
for video in *.mp4; do
    (vidpro cut "$video" 0 30 "clips/${video%.mp4}_clip.mp4") &
done
wait
```

### Dropbox Safety

Never write ffmpeg output directly to Dropbox (causes deadlocks):

```bash
# ❌ Wrong
vidpro cut video.mp4 0 30 ~/Dropbox/output.mp4

# ✅ Right
vidpro cut video.mp4 0 30 /tmp/output.mp4
cp /tmp/output.mp4 ~/Dropbox/output.mp4
```

### Timestamp Formats

VidPro accepts:
- Seconds: `90`
- HH:MM:SS: `00:01:30`
- Mixed: `vidpro cut video.mp4 90 00:02:00 out.mp4`

## File Structure

```
video-cli/
├── vidpro.sh           # Main CLI
├── README.md           # This file
└── examples/
    ├── cuts.txt        # Example timestamps file
    └── workflow.sh     # Full pipeline script
```

## Requirements

- ffmpeg (with libx264, libmp3lame)
- Python 3.8+ (for subtitle burning)
- moviepy, pysrt (pip3 install moviepy pysrt)

Optional:
- MediaPipe (for face crop)
- fal-client (for thumbnails)

## Troubleshooting

**"command not found: vidpro"**
```bash
# Use full path or add to PATH
~/clawd-mura/projects/video-cli/vidpro.sh help
```

**"Resource deadlock avoided" when writing to Dropbox**
- Always write to /tmp first, then cp to Dropbox

**Subtitles not rendering**
- Check font availability: `fc-list | grep -i arial`
- Install Arial Unicode MS if missing

**Batch cut not working**
- Check timestamps file format: `start,end,name` (CSV)
- Ensure no spaces around commas

## Performance

| Task | Time (for 1min video) |
|------|----------------------|
| Cut (stream copy) | <1s |
| Cut (re-encode) | ~40s |
| Subtitle burning | ~60s |
| Face crop | ~90s |
| Thumbnail generation | 2-3 min |

Mac Mini M2 Pro, 4K video

## Future Features

- [ ] GPU acceleration for encoding
- [ ] Auto scene detection for cuts
- [ ] Batch subtitle burning
- [ ] Quality presets (fast/balanced/high)
- [ ] Progress bars for long operations
- [ ] Web UI for non-technical users

---

Built by Jiji 🐕 for Irakli's video workflows.
