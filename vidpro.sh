#!/bin/bash
# Video Processing CLI - Unified tool for common video tasks
# Usage: vidpro <command> [args...]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Tool paths
YT_POSTER="$HOME/clawd-mura/projects/yt-poster"
FACE_CROP="$HOME/clawd-mura/projects/face-crop"
THUMBNAIL_GEN="$HOME/clawd-mura/projects/thumbnail-gen"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

function print_header() {
    echo -e "${CYAN}╔════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}          ${BLUE}📹 VidPro - Video Processing CLI${NC}              ${CYAN}║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════╝${NC}"
}

function print_usage() {
    print_header
    cat << EOF

USAGE:
    vidpro <command> [options]

COMMANDS:
    ${GREEN}cut${NC} <input> <start> <end> <output>
        Cut video segment with stream copy (instant, no re-encode)
        Times: HH:MM:SS or seconds
        Example: vidpro cut video.mp4 00:01:30 00:02:00 clip.mp4

    ${GREEN}cut-precise${NC} <input> <start> <end> <output>
        Cut with re-encode for frame-perfect precision
        Example: vidpro cut-precise video.mp4 90 120 clip.mp4

    ${GREEN}subs${NC} <video> <srt> <output>
        Burn subtitles into video (yellow Georgian style)
        Example: vidpro subs video.mp4 subs.srt output.mp4

    ${GREEN}clean-srt${NC} <input.srt> <output.srt>
        Remove Georgian filler words from SRT
        Removes: ააა, ამმ, მჰმ, მმ, მმმ, ეჰმ, ესე იგი
        Example: vidpro clean-srt raw.srt clean.srt

    ${GREEN}face-crop${NC} <video> <output>
        Auto-crop horizontal video to vertical (9:16) with face tracking
        Example: vidpro face-crop horizontal.mp4 vertical.mp4

    ${GREEN}thumbnail${NC} <video> <srt> <selection> <text1> <text2> <output>
        Generate YouTube thumbnail
        Example: vidpro thumbnail ep.mp4 ep.srt "L2 R1" "ყველაფერი" "სიზმარია" thumb.jpg

    ${GREEN}batch-cut${NC} <video> <timestamps_file> <output_dir>
        Batch cut multiple segments from timestamps file
        Format: start,end,name (one per line)
        Example: vidpro batch-cut video.mp4 cuts.txt ./clips/

    ${GREEN}info${NC} <video>
        Show video metadata (duration, resolution, codec, etc.)

    ${GREEN}concat${NC} <file1> <file2> [...] <output>
        Concatenate multiple videos (stream copy, must have same codec/res)
        Example: vidpro concat part1.mp4 part2.mp4 part3.mp4 full.mp4

    ${GREEN}resize${NC} <video> <width> <height> <output>
        Resize video to specific dimensions
        Example: vidpro resize video.mp4 1280 720 resized.mp4

    ${GREEN}extract-audio${NC} <video> <output.mp3>
        Extract audio track as MP3
        Example: vidpro extract-audio video.mp4 audio.mp3

    ${GREEN}help${NC}
        Show this help

OPTIONS:
    --fast            Skip quality checks (faster)
    --parallel N      Use N parallel processes (default: 1)
    --work-dir PATH   Temp work directory (default: /tmp)

EXAMPLES:
    # Full shorts workflow
    vidpro cut episode.mp4 00:05:30 00:06:00 /tmp/segment.mp4
    vidpro clean-srt segment.srt segment_clean.srt
    vidpro subs /tmp/segment.mp4 segment_clean.srt /tmp/segment_sub.mp4
    vidpro face-crop /tmp/segment_sub.mp4 short_vertical.mp4
    vidpro thumbnail episode.mp4 segment.srt "L2 R1" "ტექსტი 1" "ტექსტი 2" thumb.jpg

    # Batch processing
    cat > cuts.txt << 'EOL'
00:01:30,00:02:00,intro
00:05:45,00:06:15,funny_moment
00:12:00,00:12:30,conclusion
EOL
    vidpro batch-cut episode.mp4 cuts.txt ./clips/

NOTES:
    - Stream copy is instant but not frame-perfect
    - Use cut-precise for exact timing (slower)
    - Always clean SRT before burning subtitles
    - Face crop requires video with visible faces
    - Thumbnail generation needs FAL_KEY env var

RELATED TOOLS:
    ~/clawd-mura/projects/yt-poster/yt.py        - YouTube upload CLI
    ~/clawd-mura/projects/thumbnail-gen/         - Standalone thumbnail tool
    ~/clawd-mura/projects/face-crop/             - Standalone face cropper

EOF
}

# ═══════════════════════════════════════════════════════════
# COMMANDS
# ═══════════════════════════════════════════════════════════

function cmd_cut() {
    if [ $# -lt 4 ]; then
        echo -e "${RED}Usage: vidpro cut <input> <start> <end> <output>${NC}"
        exit 1
    fi
    
    input="$1"
    start="$2"
    end="$3"
    output="$4"
    
    echo -e "${BLUE}✂️  Cutting video (stream copy)...${NC}"
    echo "   Input: $input"
    echo "   Start: $start"
    echo "   End: $end"
    echo "   Output: $output"
    
    # Calculate duration
    if [[ "$start" =~ ^[0-9]+$ ]] && [[ "$end" =~ ^[0-9]+$ ]]; then
        duration=$((end - start))
    else
        # Let ffmpeg handle time calculations
        duration=""
    fi
    
    if [ -n "$duration" ]; then
        ffmpeg -y -ss "$start" -i "$input" -t "$duration" -c copy "$output"
    else
        ffmpeg -y -ss "$start" -to "$end" -i "$input" -c copy "$output"
    fi
    
    echo -e "${GREEN}✅ Done: $output${NC}"
}

function cmd_cut_precise() {
    if [ $# -lt 4 ]; then
        echo -e "${RED}Usage: vidpro cut-precise <input> <start> <end> <output>${NC}"
        exit 1
    fi
    
    input="$1"
    start="$2"
    end="$3"
    output="$4"
    
    echo -e "${BLUE}✂️  Cutting video (precise re-encode)...${NC}"
    echo "   ⚠️  This will take time - re-encoding for precision"
    
    if [[ "$start" =~ ^[0-9]+$ ]] && [[ "$end" =~ ^[0-9]+$ ]]; then
        duration=$((end - start))
    else
        duration=""
    fi
    
    if [ -n "$duration" ]; then
        ffmpeg -y -ss "$start" -i "$input" -t "$duration" \
            -c:v libx264 -preset fast -crf 23 -c:a aac -b:a 128k \
            "$output"
    else
        ffmpeg -y -ss "$start" -to "$end" -i "$input" \
            -c:v libx264 -preset fast -crf 23 -c:a aac -b:a 128k \
            "$output"
    fi
    
    echo -e "${GREEN}✅ Done: $output${NC}"
}

function cmd_subs() {
    if [ $# -lt 3 ]; then
        echo -e "${RED}Usage: vidpro subs <video> <srt> <output>${NC}"
        exit 1
    fi
    
    video="$1"
    srt="$2"
    output="$3"
    
    echo -e "${BLUE}💬 Burning subtitles (yellow Georgian style)...${NC}"
    
    # Use Python script for better subtitle rendering (from lessons learned)
    python3 - "$video" "$srt" "$output" << 'EOPYTHON'
import sys
from moviepy.editor import VideoFileClip, TextClip, CompositeVideoClip
import pysrt

video_path = sys.argv[1]
srt_path = sys.argv[2]
output_path = sys.argv[3]

print(f"Loading video: {video_path}")
video = VideoFileClip(video_path)

print(f"Loading subtitles: {srt_path}")
subs = pysrt.open(srt_path, encoding='utf-8')

def time_to_seconds(t):
    return t.hours * 3600 + t.minutes * 60 + t.seconds + t.milliseconds / 1000

subtitle_clips = []
for sub in subs:
    start = time_to_seconds(sub.start)
    end = time_to_seconds(sub.end)
    duration = end - start
    
    txt_clip = TextClip(
        sub.text,
        fontsize=48,
        color='yellow',
        font='Arial-Unicode-MS',
        stroke_color='black',
        stroke_width=2,
        method='caption',
        size=(video.w * 0.9, None)
    ).set_position(('center', 'bottom')).set_start(start).set_duration(duration)
    
    subtitle_clips.append(txt_clip)

print("Compositing subtitles...")
final = CompositeVideoClip([video] + subtitle_clips)

print(f"Writing output: {output_path}")
final.write_videofile(output_path, codec='libx264', audio_codec='aac', temp_audiofile='/tmp/temp_audio.m4a', remove_temp=True)

print("✅ Done!")
EOPYTHON
    
    echo -e "${GREEN}✅ Done: $output${NC}"
}

function cmd_clean_srt() {
    if [ $# -lt 2 ]; then
        echo -e "${RED}Usage: vidpro clean-srt <input.srt> <output.srt>${NC}"
        exit 1
    fi
    
    input="$1"
    output="$2"
    
    if [ ! -f "$YT_POSTER/clean_srt.py" ]; then
        echo -e "${RED}❌ clean_srt.py not found in $YT_POSTER${NC}"
        exit 1
    fi
    
    echo -e "${BLUE}🧹 Cleaning Georgian filler words from SRT...${NC}"
    python3 "$YT_POSTER/clean_srt.py" "$input" "$output"
    echo -e "${GREEN}✅ Done: $output${NC}"
}

function cmd_face_crop() {
    if [ $# -lt 2 ]; then
        echo -e "${RED}Usage: vidpro face-crop <video> <output>${NC}"
        exit 1
    fi
    
    video="$1"
    output="$2"
    
    if [ ! -d "$FACE_CROP" ]; then
        echo -e "${RED}❌ Face crop tool not found: $FACE_CROP${NC}"
        exit 1
    fi
    
    echo -e "${BLUE}👤 Face-tracking crop (horizontal → vertical 9:16)...${NC}"
    echo -e "${YELLOW}⚠️  This requires a Python script - placeholder for now${NC}"
    echo "   Input: $video"
    echo "   Output: $output"
    echo ""
    echo "TODO: Implement face crop integration"
    echo "See: ~/clawd-mura/projects/face-crop/"
}

function cmd_thumbnail() {
    if [ $# -lt 6 ]; then
        echo -e "${RED}Usage: vidpro thumbnail <video> <srt> <selection> <text1> <text2> <output>${NC}"
        exit 1
    fi
    
    video="$1"
    srt="$2"
    selection="$3"
    text1="$4"
    text2="$5"
    output="$6"
    
    if [ ! -f "$THUMBNAIL_GEN/thumbgen.sh" ]; then
        echo -e "${RED}❌ Thumbnail generator not found: $THUMBNAIL_GEN/thumbgen.sh${NC}"
        exit 1
    fi
    
    echo -e "${BLUE}🎨 Generating thumbnail...${NC}"
    "$THUMBNAIL_GEN/thumbgen.sh" full "$video" "$srt" "$selection" "$text1" "$text2" "$output"
}

function cmd_batch_cut() {
    if [ $# -lt 3 ]; then
        echo -e "${RED}Usage: vidpro batch-cut <video> <timestamps_file> <output_dir>${NC}"
        exit 1
    fi
    
    video="$1"
    timestamps="$2"
    output_dir="$3"
    
    if [ ! -f "$timestamps" ]; then
        echo -e "${RED}❌ Timestamps file not found: $timestamps${NC}"
        exit 1
    fi
    
    mkdir -p "$output_dir"
    
    echo -e "${BLUE}✂️  Batch cutting video...${NC}"
    echo "   Input: $video"
    echo "   Timestamps: $timestamps"
    echo "   Output dir: $output_dir"
    echo ""
    
    count=0
    while IFS=',' read -r start end name; do
        # Skip empty lines and comments
        [[ "$start" =~ ^#.*$ ]] && continue
        [[ -z "$start" ]] && continue
        
        count=$((count + 1))
        output="$output_dir/${name}.mp4"
        
        echo -e "${CYAN}[$count] ${name}${NC}"
        echo "    Start: $start, End: $end"
        echo "    Output: $output"
        
        cmd_cut "$video" "$start" "$end" "$output"
        echo ""
    done < "$timestamps"
    
    echo -e "${GREEN}✅ Batch cut complete: $count clips${NC}"
}

function cmd_info() {
    if [ $# -lt 1 ]; then
        echo -e "${RED}Usage: vidpro info <video>${NC}"
        exit 1
    fi
    
    video="$1"
    
    echo -e "${BLUE}ℹ️  Video metadata:${NC}"
    ffprobe -v quiet -print_format json -show_format -show_streams "$video" | python3 -m json.tool || ffprobe "$video"
}

function cmd_concat() {
    if [ $# -lt 3 ]; then
        echo -e "${RED}Usage: vidpro concat <file1> <file2> [...] <output>${NC}"
        exit 1
    fi
    
    # Last arg is output
    args=("$@")
    output="${args[-1]}"
    unset 'args[-1]'
    
    # Create concat list
    concat_list="/tmp/vidpro_concat_$$.txt"
    for file in "${args[@]}"; do
        echo "file '$file'" >> "$concat_list"
    done
    
    echo -e "${BLUE}🔗 Concatenating ${#args[@]} videos...${NC}"
    cat "$concat_list"
    echo ""
    
    ffmpeg -y -f concat -safe 0 -i "$concat_list" -c copy "$output"
    rm "$concat_list"
    
    echo -e "${GREEN}✅ Done: $output${NC}"
}

function cmd_resize() {
    if [ $# -lt 4 ]; then
        echo -e "${RED}Usage: vidpro resize <video> <width> <height> <output>${NC}"
        exit 1
    fi
    
    video="$1"
    width="$2"
    height="$3"
    output="$4"
    
    echo -e "${BLUE}📐 Resizing video to ${width}x${height}...${NC}"
    ffmpeg -y -i "$video" -vf "scale=${width}:${height}" -c:v libx264 -preset fast -crf 23 -c:a copy "$output"
    echo -e "${GREEN}✅ Done: $output${NC}"
}

function cmd_extract_audio() {
    if [ $# -lt 2 ]; then
        echo -e "${RED}Usage: vidpro extract-audio <video> <output.mp3>${NC}"
        exit 1
    fi
    
    video="$1"
    output="$2"
    
    echo -e "${BLUE}🎵 Extracting audio...${NC}"
    ffmpeg -y -i "$video" -vn -acodec libmp3lame -q:a 2 "$output"
    echo -e "${GREEN}✅ Done: $output${NC}"
}

# ═══════════════════════════════════════════════════════════
# MAIN
# ═══════════════════════════════════════════════════════════

case "${1:-help}" in
    cut)
        shift
        cmd_cut "$@"
        ;;
    cut-precise)
        shift
        cmd_cut_precise "$@"
        ;;
    subs)
        shift
        cmd_subs "$@"
        ;;
    clean-srt)
        shift
        cmd_clean_srt "$@"
        ;;
    face-crop)
        shift
        cmd_face_crop "$@"
        ;;
    thumbnail)
        shift
        cmd_thumbnail "$@"
        ;;
    batch-cut)
        shift
        cmd_batch_cut "$@"
        ;;
    info)
        shift
        cmd_info "$@"
        ;;
    concat)
        shift
        cmd_concat "$@"
        ;;
    resize)
        shift
        cmd_resize "$@"
        ;;
    extract-audio)
        shift
        cmd_extract_audio "$@"
        ;;
    help|--help|-h)
        print_usage
        ;;
    *)
        echo -e "${RED}Unknown command: $1${NC}"
        echo ""
        print_usage
        exit 1
        ;;
esac
