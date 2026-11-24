#!/usr/bin/env bash
# Checks a build with the work a video editor gives it: H.264 and AAC encoding, MP3 and PNG,
# probing, AV1 decoding, burned-in subtitles and drawn text.
#
#   ./smoke-test.sh <directory with ffmpeg and ffprobe>
set -euo pipefail

bin=$(cd "${1:?directory}" && pwd)
exe=""; case "$(uname -s)" in MINGW* | MSYS* | CYGWIN*) exe=.exe ;; esac
ffmpeg="$bin/ffmpeg$exe" ffprobe="$bin/ffprobe$exe"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
cd "$work"
run() { "$ffmpeg" -hide_banner -loglevel error -y "$@"; }

require() { # kind names...
  local kind=$1 list name; shift
  list=$("$ffmpeg" -hide_banner -"$kind")
  for name in "$@"; do
    grep -q " $name " <<<"$list" || { echo "Missing ${kind%s} $name" >&2; exit 1; }
  done
}
require encoders libx264 aac libmp3lame png pcm_s16le
require decoders libdav1d h264 hevc vp9 opus
require filters subtitles ass drawtext xfade loudnorm scale overlay

run -f lavfi -i testsrc2=size=640x360:rate=30 -f lavfi -i sine=frequency=440 -t 2 \
  -c:v libx264 -pix_fmt yuv420p -c:a aac -movflags +faststart clip.mp4
duration=$("$ffprobe" -v error -show_entries format=duration -of csv=p=0 clip.mp4)
awk -v d="$duration" 'BEGIN { exit !(d > 1.9 && d < 2.2) }' || { echo "Unexpected duration $duration" >&2; exit 1; }

run -i clip.mp4 -vn -c:a libmp3lame audio.mp3
run -i clip.mp4 -frames:v 1 still.png

# The fonts each platform has; libass finds them through fontconfig, CoreText or DirectWrite.
font=""
for candidate in /usr/share/fonts/truetype/dejavu/DejaVuSans.ttf /System/Library/Fonts/Supplemental/Arial.ttf \
  /c/Windows/Fonts/arial.ttf "C:/Windows/Fonts/arial.ttf" $(find /usr/share/fonts -name '*.ttf' 2>/dev/null | head -1); do
  [ -f "$candidate" ] && { font=$candidate; break; }
done
[ -n "$font" ] || { echo "No font found to test text" >&2; exit 1; }
cp "$font" font.ttf

printf '1\n00:00:00,000 --> 00:00:02,000\nSubtitles burn in ✓\n' > captions.srt
run -i clip.mp4 -vf "subtitles=captions.srt:fontsdir=." -c:v libx264 -c:a copy subtitled.mp4
run -i clip.mp4 -vf "drawtext=fontfile=font.ttf:text='Drawn text':fontsize=36:fontcolor=white:x=20:y=20" \
  -c:v libx264 -c:a copy text.mp4

run -f lavfi -i testsrc2=size=320x180:rate=24 -t 1 -c:v libx264 -pix_fmt yuv420p a.mp4
run -f lavfi -i color=c=blue:size=320x180:rate=24 -t 1 -c:v libx264 -pix_fmt yuv420p b.mp4
run -i a.mp4 -i b.mp4 -filter_complex "xfade=transition=fade:duration=0.5:offset=0.5" -c:v libx264 fade.mp4

"$ffmpeg" -hide_banner -version | sed -n 1p
echo "Smoke test passed"
