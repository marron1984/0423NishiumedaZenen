#!/usr/bin/env bash
set -euo pipefail

# Instagram Reel placeholder (9:16, 1080x1920, 30fps, ~18s)
# Week 4 theme: 意思決定 — 限定・希少性 × 職人技
# Replace solid-color scenes with real footage/stills when available.

FONT="/usr/share/fonts/opentype/ipafont-gothic/ipag.ttf"
OUT="$(dirname "$0")/zenen_week4_reel_sample.mp4"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

W=1080
H=1920
FPS=30
DUR=4.5

make_scene () {
  local idx="$1" bg="$2" title="$3" sub="$4"
  ffmpeg -hide_banner -loglevel error -y \
    -f lavfi -i "color=c=${bg}:s=${W}x${H}:r=${FPS}:d=${DUR}" \
    -vf "
      drawtext=fontfile=${FONT}:text='${title}':fontcolor=white:fontsize=88:
        x=(w-text_w)/2:y=(h/2)-120:
        alpha='if(lt(t,0.4),t/0.4,if(gt(t,${DUR}-0.4),(${DUR}-t)/0.4,1))',
      drawtext=fontfile=${FONT}:text='${sub}':fontcolor=0xd4b87a:fontsize=54:
        x=(w-text_w)/2:y=(h/2)+20:
        alpha='if(lt(t,0.8),max(0,(t-0.4)/0.4),if(gt(t,${DUR}-0.4),(${DUR}-t)/0.4,1))',
      drawtext=fontfile=${FONT}:text='西梅田 禅園':fontcolor=white:fontsize=36:
        x=(w-text_w)/2:y=h-140:alpha=0.7
    " \
    -c:v libx264 -pix_fmt yuv420p -preset medium -crf 20 \
    "${TMP}/s${idx}.mp4"
}

make_scene 1 "0x0a1929" "今月だけ、旬のピーク。" "春の食材が最も輝く、この瞬間に。"
make_scene 2 "0x1a1410" "職人が仕込む、一皿のために。" "この技術があるから、この味になる。"
make_scene 3 "0x2a0f0f" "一日限定のご用意。" "旬の希少食材を、確かな技で。"
make_scene 4 "0x0a1f15" "ご予約はプロフィールから。" "大阪・西梅田 ハービスPLAZA B2F"

# concat list
: > "${TMP}/list.txt"
for i in 1 2 3 4; do echo "file '${TMP}/s${i}.mp4'" >> "${TMP}/list.txt"; done

# concat + add silent AAC audio track (Instagram compatibility)
ffmpeg -hide_banner -loglevel error -y \
  -f concat -safe 0 -i "${TMP}/list.txt" \
  -f lavfi -i "anullsrc=channel_layout=stereo:sample_rate=44100" \
  -shortest \
  -c:v libx264 -pix_fmt yuv420p -preset medium -crf 20 \
  -c:a aac -b:a 128k -ar 44100 \
  -movflags +faststart \
  "${OUT}"

echo "Generated: ${OUT}"
ffprobe -v error -show_entries stream=codec_name,width,height,r_frame_rate,duration \
  -show_entries format=size,duration,bit_rate -of default=nw=1 "${OUT}"
