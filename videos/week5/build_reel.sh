#!/usr/bin/env bash
set -euo pipefail

# Instagram Reel for Week 5 (信頼強化 — 内観・体験価値 × 大人デート)
# Output: 9:16, 1080x1920, 30fps, 24s (5 scenes + info card), H.264 + AAC
#
# Narrative: 空間(佇まい) → 横並びの席(USP) → 乾杯 → 食事中(滞在時間) → CTA(記念日)
# Message: 「横並びカウンターで、大人の記念日を」 — 失敗しない安心感

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
IMG_DIR="${REPO_DIR}/images/week5"
FONT="/usr/share/fonts/opentype/ipafont-mincho/ipam.ttf"
OUT="${SCRIPT_DIR}/zenen_week5_reel.mp4"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

W=1080
H=1920
FPS=30
DUR=3.6            # per scene
FADE=0.35          # in/out fade seconds

# Image sources from images/week5/
pick () { ls "${IMG_DIR}"/*"$1"*."$2" 2>/dev/null | head -1; }
IMG_ROOM="$(pick '(8)' JPG)"           # 内部 (8): カウンター全景・縦・装飾格子
IMG_COUNTER="$(pick '(10)' JPG)"       # 内部 (10): カウンター全景・縦・カーブ天井
IMG_TOAST="$(pick DSC00428 JPG)"       # 乾杯(後ろ姿カップル)
IMG_DINE="$(pick DSC00654 JPG)"        # 食事中(後ろ姿カップル・皿あり)
IMG_FINAL="$(pick DSC00446 JPG)"       # 乾杯(別角度・横並び鮮明)
for v in IMG_ROOM IMG_COUNTER IMG_TOAST IMG_DINE IMG_FINAL; do
  [ -f "${!v}" ] || { echo "Missing $v: ${!v}" >&2; exit 1; }
done

# BGM (first MP3 found in repo root)
BGM="$(ls "${REPO_DIR}"/*.mp3 2>/dev/null | head -1 || true)"
[ -n "${BGM}" ] && [ -f "${BGM}" ] && echo "BGM: ${BGM}" || echo "BGM: (none — silent)"

make_scene () {
  local idx="$1" img="$2" title="$3" sub="$4"
  local fade_out_start
  fade_out_start=$(awk -v d="$DUR" -v f="$FADE" 'BEGIN{printf "%.3f", d-f}')

  # Detect orientation. Landscape sources get blurred letterbox so
  # composition is preserved; portrait sources fill the canvas via crop.
  local iw ih pre wh
  wh=$(ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=p=0 "$img")
  iw=${wh%,*}; ih=${wh#*,}
  if [ "$iw" -gt "$ih" ]; then
    pre="
      [0:v]split=2[a][b];
      [a]scale=${W}:${H}:force_original_aspect_ratio=increase,crop=${W}:${H},
         gblur=sigma=40,eq=brightness=-0.2:saturation=0.85[bg0];
      [b]scale=${W}:-1[fg0];
      [bg0][fg0]overlay=(W-w)/2:(H-h)/2,setsar=1,
         eq=brightness=0.02:saturation=1.05[bg];
    "
  else
    pre="
      [0:v]scale=${W}:${H}:force_original_aspect_ratio=increase,
           crop=${W}:${H},setsar=1,eq=brightness=0.02:saturation=1.08[bg];
    "
  fi

  ffmpeg -hide_banner -loglevel error -y \
    -loop 1 -t "${DUR}" -i "${img}" \
    -filter_complex "
      ${pre}
      [bg]drawtext=fontfile=${FONT}:text='${title}':fontcolor=white:fontsize=76:
           x=(w-text_w)/2:y=h-460:
           borderw=5:bordercolor=black@0.9:
           shadowcolor=black@0.7:shadowx=3:shadowy=3:
           alpha='if(lt(t,${FADE}),t/${FADE},if(gt(t,${fade_out_start}),(${DUR}-t)/${FADE},1))'[t1];
      [t1]drawtext=fontfile=${FONT}:text='${sub}':fontcolor=0xE8C77B:fontsize=50:
           x=(w-text_w)/2:y=h-340:
           borderw=4:bordercolor=black@0.9:
           shadowcolor=black@0.7:shadowx=2:shadowy=2:
           alpha='if(lt(t,${FADE}+0.2),max(0,(t-${FADE})/${FADE}),if(gt(t,${fade_out_start}),(${DUR}-t)/${FADE},1))'[t2];
      [t2]drawtext=fontfile=${FONT}:text='西梅田 禅園':fontcolor=white@0.9:fontsize=34:
           x=(w-text_w)/2:y=80:
           borderw=3:bordercolor=black@0.85:
           shadowcolor=black@0.6:shadowx=2:shadowy=2[t3];
      [t3]fade=t=in:st=0:d=${FADE},fade=t=out:st=${fade_out_start}:d=${FADE}[v]
    " -map "[v]" \
    -r ${FPS} -c:v libx264 -pix_fmt yuv420p -preset medium -crf 20 \
    "${TMP}/s${idx}.mp4"
}

make_scene 1 "${IMG_ROOM}"    "おとなの、夜のはじまり。"       "灯りがひとつ、ふたつ。"
make_scene 2 "${IMG_COUNTER}" "肩を、並べる席。"               "1〜10名様、ゆとりの十席。"
make_scene 3 "${IMG_TOAST}"   "乾杯は、静かに。"               "ひと口めの、その瞬間に。"
make_scene 4 "${IMG_DINE}"    "季節と、ふたりのこと。"         "話題は、ゆっくりと。"
make_scene 5 "${IMG_FINAL}"   "記念日に、もうひと夜を。"       "その日の席を、プロフィールより。"

# Scene 6: store info card (solid dark, Mincho).
# Use textfile= to avoid colon/quote escaping issues in drawtext.
INFO_DUR=6.0
INFO_FADE_OUT=$(awk -v d="$INFO_DUR" 'BEGIN{printf "%.3f", d-0.5}')
mkdir -p "${TMP}/txt"
write_t () { printf '%s' "$2" > "${TMP}/txt/$1"; }
write_t title.txt      "西梅田 禅園"
write_t zip.txt        "〒530-0001"
write_t addr1.txt      "大阪市北区梅田 2-5-25"
write_t addr2.txt      "ハービスPLAZA B2F"
write_t tel.txt        "TEL  06-6457-1002"
write_t lunch.txt      "ランチ   11:00 - 14:45  L.O.14:00"
write_t dinner.txt     "ディナー 17:30 - 22:00  L.O.21:00"
write_t holiday.txt    "定休日　不定休"
write_t budget_lbl.txt "ご予算　ディナー"
write_t budget.txt     "通常 ¥9,000　／　宴会 ¥6,000 - ¥15,000"
write_t cta.txt        "その日の席を、プロフィールより。"

ffmpeg -hide_banner -loglevel error -y \
  -f lavfi -i "color=c=0x0a0a0a:s=${W}x${H}:r=${FPS}:d=${INFO_DUR}" \
  -vf "
    drawbox=x=(iw-560)/2:y=405:w=560:h=2:color=white@0.35:t=fill,
    drawbox=x=(iw-560)/2:y=780:w=560:h=2:color=white@0.35:t=fill,
    drawbox=x=(iw-560)/2:y=1030:w=560:h=2:color=white@0.35:t=fill,
    drawtext=fontfile=${FONT}:textfile=${TMP}/txt/title.txt:fontcolor=white:fontsize=92:x=(w-text_w)/2:y=270,
    drawtext=fontfile=${FONT}:textfile=${TMP}/txt/zip.txt:fontcolor=white@0.7:fontsize=30:x=(w-text_w)/2:y=455,
    drawtext=fontfile=${FONT}:textfile=${TMP}/txt/addr1.txt:fontcolor=white:fontsize=42:x=(w-text_w)/2:y=505,
    drawtext=fontfile=${FONT}:textfile=${TMP}/txt/addr2.txt:fontcolor=white:fontsize=42:x=(w-text_w)/2:y=565,
    drawtext=fontfile=${FONT}:textfile=${TMP}/txt/tel.txt:fontcolor=0xE8C77B:fontsize=54:x=(w-text_w)/2:y=670,
    drawtext=fontfile=${FONT}:textfile=${TMP}/txt/lunch.txt:fontcolor=white:fontsize=38:x=(w-text_w)/2:y=820,
    drawtext=fontfile=${FONT}:textfile=${TMP}/txt/dinner.txt:fontcolor=white:fontsize=38:x=(w-text_w)/2:y=880,
    drawtext=fontfile=${FONT}:textfile=${TMP}/txt/holiday.txt:fontcolor=white@0.85:fontsize=36:x=(w-text_w)/2:y=950,
    drawtext=fontfile=${FONT}:textfile=${TMP}/txt/budget_lbl.txt:fontcolor=white@0.7:fontsize=34:x=(w-text_w)/2:y=1075,
    drawtext=fontfile=${FONT}:textfile=${TMP}/txt/budget.txt:fontcolor=white:fontsize=38:x=(w-text_w)/2:y=1135,
    drawtext=fontfile=${FONT}:textfile=${TMP}/txt/cta.txt:fontcolor=0xE8C77B:fontsize=42:x=(w-text_w)/2:y=1700,
    fade=t=in:st=0:d=0.5,fade=t=out:st=${INFO_FADE_OUT}:d=0.5
  " \
  -r ${FPS} -c:v libx264 -pix_fmt yuv420p -preset medium -crf 20 \
  "${TMP}/s6.mp4"

# concat list (scenes 1-5 + info card)
: > "${TMP}/list.txt"
for i in 1 2 3 4 5 6; do echo "file '${TMP}/s${i}.mp4'" >> "${TMP}/list.txt"; done

# Total duration: 5 scenes × DUR + info card
TOTAL=$(awk -v d="$DUR" -v i="$INFO_DUR" 'BEGIN{printf "%.3f", d*5+i}')
FADE_OUT_START=$(awk -v t="$TOTAL" 'BEGIN{printf "%.3f", t-1.5}')

if [ -n "${BGM:-}" ] && [ -f "${BGM}" ]; then
  # Final: concat + BGM (trim, fade in/out, -6dB) + faststart
  ffmpeg -hide_banner -loglevel error -y \
    -f concat -safe 0 -i "${TMP}/list.txt" \
    -i "${BGM}" \
    -filter_complex "[1:a]atrim=0:${TOTAL},asetpts=PTS-STARTPTS,
                     volume=0.5,
                     afade=t=in:st=0:d=0.6,
                     afade=t=out:st=${FADE_OUT_START}:d=1.0[a]" \
    -map 0:v -map "[a]" \
    -t "${TOTAL}" \
    -c:v libx264 -pix_fmt yuv420p -preset medium -crf 20 \
    -c:a aac -b:a 160k -ar 44100 \
    -movflags +faststart \
    "${OUT}"
else
  ffmpeg -hide_banner -loglevel error -y \
    -f concat -safe 0 -i "${TMP}/list.txt" \
    -f lavfi -i "anullsrc=channel_layout=stereo:sample_rate=44100" \
    -shortest \
    -c:v libx264 -pix_fmt yuv420p -preset medium -crf 20 \
    -c:a aac -b:a 128k -ar 44100 \
    -movflags +faststart \
    "${OUT}"
fi

echo "Generated: ${OUT}"
ffprobe -v error -show_entries stream=codec_name,width,height,r_frame_rate,duration \
  -show_entries format=size,duration,bit_rate -of default=nw=1 "${OUT}"
