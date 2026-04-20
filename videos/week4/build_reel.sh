#!/usr/bin/env bash
set -euo pipefail

# Instagram Reel for Week 4 (意思決定 — 限定・希少性 × 職人技)
# Output: 9:16, 1080x1920, 30fps, ~18s, H.264 + AAC, faststart
#
# Narrative: 夜桜(季節) → 仕込み(職人技) → 炭火(火入れ) → 焼き上がり(結果) → CTA
# Message: 「この技術があるから、この味・この価格になる」

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
FONT="/usr/share/fonts/opentype/ipafont-gothic/ipag.ttf"
OUT="${SCRIPT_DIR}/zenen_week4_reel.mp4"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

W=1080
H=1920
FPS=30
DUR=3.6            # per scene
FADE=0.35          # in/out fade seconds

# Image sources (glob by number to avoid Unicode NFD/NFC mismatches)
pick () { ls "${REPO_DIR}"/*"$1"*."$2" 2>/dev/null | head -1; }
IMG_SEASON="${REPO_DIR}/83010_0.jpg"
IMG_PREP="$(pick 0008 jpg)"
IMG_FIRE="$(pick 0124 JPG)"
IMG_DONE="$(pick 0142 JPG)"
IMG_CTA="$(pick 0139 JPG)"
for v in IMG_SEASON IMG_PREP IMG_FIRE IMG_DONE IMG_CTA; do
  [ -f "${!v}" ] || { echo "Missing $v: ${!v}" >&2; exit 1; }
done

make_scene () {
  local idx="$1" img="$2" title="$3" sub="$4"
  local fade_out_start
  fade_out_start=$(awk -v d="$DUR" -v f="$FADE" 'BEGIN{printf "%.3f", d-f}')

  ffmpeg -hide_banner -loglevel error -y \
    -loop 1 -t "${DUR}" -i "${img}" \
    -filter_complex "
      [0:v]scale=${W}:${H}:force_original_aspect_ratio=increase,
           crop=${W}:${H},
           setsar=1,
           eq=brightness=0.02:saturation=1.08[bg];
      [bg]drawbox=y=ih-620:w=iw:h=620:color=black@0.55:t=fill[dim];
      [dim]drawtext=fontfile=${FONT}:text='${title}':fontcolor=white:fontsize=76:
           x=(w-text_w)/2:y=h-460:
           borderw=2:bordercolor=black@0.5:
           alpha='if(lt(t,${FADE}),t/${FADE},if(gt(t,${fade_out_start}),(${DUR}-t)/${FADE},1))'[t1];
      [t1]drawtext=fontfile=${FONT}:text='${sub}':fontcolor=0xE8C77B:fontsize=50:
           x=(w-text_w)/2:y=h-340:
           borderw=1:bordercolor=black@0.5:
           alpha='if(lt(t,${FADE}+0.2),max(0,(t-${FADE})/${FADE}),if(gt(t,${fade_out_start}),(${DUR}-t)/${FADE},1))'[t2];
      [t2]drawtext=fontfile=${FONT}:text='西梅田 禅園':fontcolor=white@0.85:fontsize=34:
           x=(w-text_w)/2:y=80:
           borderw=1:bordercolor=black@0.4[t3];
      [t3]fade=t=in:st=0:d=${FADE},fade=t=out:st=${fade_out_start}:d=${FADE}[v]
    " -map "[v]" \
    -r ${FPS} -c:v libx264 -pix_fmt yuv420p -preset medium -crf 20 \
    "${TMP}/s${idx}.mp4"
}

make_scene 1 "${IMG_SEASON}" "今月だけの、旬の一瞬。" "春の大阪、この季節に味わう一皿。"
make_scene 2 "${IMG_PREP}"   "職人の手で、仕立てる。" "一切の妥協なく、素材と向き合う。"
make_scene 3 "${IMG_FIRE}"   "火入れを、見極める。" "炭の香り、温度、時間を読む。"
make_scene 4 "${IMG_DONE}"   "この技術が、この味に。" "だから、この価格になる。"
make_scene 5 "${IMG_CTA}"    "一日限定のご用意。" "ご予約はプロフィールから。"

# concat list
: > "${TMP}/list.txt"
for i in 1 2 3 4 5; do echo "file '${TMP}/s${i}.mp4'" >> "${TMP}/list.txt"; done

# Final: concat + silent AAC (IG compatibility) + faststart
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
