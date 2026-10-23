#!/usr/bin/env bash
# DIY Prepper Disk v3: Raspberry Pi OS 64-bit + IIAB + offline educational library
# Original inspiration: https://www.prepperdisk.com/pages/diy-prepper-disk-adv
# NOT affiliated with Prepper Disk. Never distributes proprietary books/media.
# See help: bash install-diy-prepperdisk-tui.sh help
# No disk is formatted/erased; no inbound Internet port forwarding is configured.
set -Eeuo pipefail
IFS=$'\n\t'
umask 022

IIAB_INSTALL_URL='https://iiab.io/install.txt'
KIWIX_BASE='https://download.kiwix.org/zim'
STATE='/var/lib/prepperdisk'
WEB='/library/www/html/prepperdisk'
ZIMS='/library/zims/content'
MANUALS="$WEB/manuals"
VIDEOS="$WEB/videos"
OPT='/opt/prepperdisk'
LOG="$STATE/operations.log"

say(){ printf '\n\033[1;34m== %s\033[0m\n' "$*"; }
warn(){ printf 'WARNING: %s\n' "$*" >&2; }
err(){ printf 'ERROR: %s\n' "$*" >&2; exit 1; }
root(){ (( EUID == 0 )) || err 'Please run this command with sudo.'; }
has(){ command -v "$1" >/dev/null 2>&1; }
confirm(){ local a; [[ -t 0 ]] || err 'Confirmation requires an interactive terminal.'; read -r -p "$1 [y/N] " a; [[ "$a" =~ ^([yY]|[yY][eE][sS])$ ]]; }
log(){ install -d "$STATE"; printf '%s | %s\n' "$(date -Is)" "$*" >> "$LOG"; }

help(){ cat <<'EOF'
DIY PREPPER DISK v3 — TUI + COMMAND-LINE INSTALLER, RASPBERRY PI OS LITE 64-BIT

INTERACTIVE TERMINAL MENU (recommended):
  bash install-diy-prepperdisk-tui.sh
  bash install-diy-prepperdisk-tui.sh menu
    Launches a whiptail/dialog menu; falls back to a numbered Bash menu.
    For the enhanced interface, install whiptail if absent:
      sudo apt-get install -y whiptail
    Run as your normal Pi user, with sudo available for admin tasks.

FIRST RUN (Pi on Ethernet + internet, login with your normal Pi account):
  bash install-diy-prepperdisk-tui.sh install
    Runs the official, interactive Internet-in-a-Box installer.
    IIAB may reboot and require repeating `sudo iiab` until completed.

THEN RUN AFTER IIAB IS FULLY INSTALLED:
  sudo bash install-diy-prepperdisk-tui.sh all starter
  sudo bash install-diy-prepperdisk-tui.sh all balanced
  sudo bash install-diy-prepperdisk-tui.sh all full
    Configures IIAB Maps, Kolibri, USB library, Kiwix archives, public PDFs,
    creates the offline portal / Morse tool / phrasebook, attempts Argos
    Translate (English <-> Spanish), and indexes local content.
    Select carefully: full can consume HUNDREDS of gigabytes.

INDIVIDUAL RE-RUNNABLE OPERATIONS:
  sudo bash install-diy-prepperdisk-tui.sh services starter|balanced|full
  sudo bash install-diy-prepperdisk-tui.sh content starter|balanced|full
  sudo bash install-diy-prepperdisk-tui.sh manuals
  sudo bash install-diy-prepperdisk-tui.sh portal
  sudo bash install-diy-prepperdisk-tui.sh translator [en es]
  sudo bash install-diy-prepperdisk-tui.sh add-zim https://.../file.zim
  sudo bash install-diy-prepperdisk-tui.sh add-pdfs /path/to/folder
  sudo bash install-diy-prepperdisk-tui.sh add-videos /path/to/folder
  sudo bash install-diy-prepperdisk-tui.sh hotspot
  bash install-diy-prepperdisk-tui.sh status

NOTES:
- Kolibri *software* is installed by `services` but course imports are chosen
  separately at http://box.lan/admin > Install Content > Kolibri.
- IIAB global offline maps install with `services`. Download high-res map
  rectangles inside http://box.lan/maps/ while still connected to internet.
- IIAB USB library mounts depend on storage/filesystem and may need setup.
- RepeaterBook's proprietary data is NOT scraped/redistributed. Use official app.
- Offline translator installs a browser interface on port 8765 IF its dependencies
  and translation models install successfully. CPU/RAM use is substantial.
- Offline Morse tool decodes TYPED dots/dashes (not live radio audio).
- No YouTube/TED videos are downloaded unless available as a legal Kiwix ZIM.
- Downloads resume where the publisher supports byte-range requests.
- Publicly available != public domain; honor each source's license/terms.
- An IIAB profile may already install some of the services; script is re-runnable.
- Back up /etc/iiab/local_vars.yml before changes. No disk wiping.
EOF
}

check_pi(){
  [[ -e /proc/device-tree/model || -e /etc/rpi-issue ]] || err 'Run on a Raspberry Pi running Raspberry Pi OS.'
  [[ "$(uname -m)" == aarch64 ]] || err 'Raspberry Pi OS 64-bit (aarch64) is required.'
  has apt-get || err 'apt-get missing.'
}
base_deps(){
  root; check_pi
  if ! has curl || ! has python3 || ! has file; then
    apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y curl ca-certificates python3 file
  fi
}
iiab_ready(){ [[ -d /etc/iiab && -d /opt/iiab/iiab && -d /library ]]; }
require_iiab(){ iiab_ready || err 'IIAB not present: first run install and finish its reboots/continuation.'; }
need_indexer(){ [[ -x /usr/bin/iiab-make-kiwix-lib ]] || warn 'iiab-make-kiwix-lib not installed; finish IIAB setup or enable Kiwix in Admin Console.'; }
profile_ok(){ case "$1" in starter|balanced|full) ;; *) err 'Profile: starter, balanced, or full';; esac; }

install_iiab(){
  check_pi; has curl || { echo 'Install curl first: sudo apt-get install curl'; exit 1; }
  [[ -t 0 ]] || err 'The official installer is interactive.'
  say 'Official Internet-in-a-Box installer (may reboot)'
  echo 'Use Ethernet. Run this on a fresh Raspberry Pi OS Lite 64-bit install.'
  confirm 'Fetch and execute the official IIAB installer?' || return 0
  local tmp
  tmp=$(mktemp /tmp/iiab-official.XXXXXXXX)
  trap 'rm -f -- "$tmp"' RETURN
  curl -fL --retry 4 --connect-timeout 20 --output "$tmp" "$IIAB_INSTALL_URL"
  [[ -s "$tmp" ]] || err 'Installer download empty.'
  chmod 755 "$tmp"
  echo "IIAB installer SHA256: $(sha256sum "$tmp" | cut -d' ' -f1)"
  echo 'Published installation guidance: https://github.com/iiab/iiab/wiki/IIAB-Installation'
  # IIAB's official one-liner runs under a regular user; avoid launching it as
  # root just because the wrapper was started with sudo.
  if (( EUID == 0 )); then
    [[ -n "${SUDO_USER:-}" && "${SUDO_USER}" != root ]] || err 'Run install as your normal Pi user (without sudo).'
    runuser -u "$SUDO_USER" -- bash "$tmp"
  else
    bash "$tmp"
  fi
  echo 'If IIAB requests reboot, complete installation with: sudo iiab'
  echo 'Then run: sudo bash install-diy-prepperdisk-tui.sh all balanced'
}

# Update only known keys in the IIAB local configuration and preserve other lines.
# Does not execute or evaluate YAML.
set_iiab_keys(){
  local profile="$1" vars='/etc/iiab/local_vars.yml' zoom sat
  profile_ok "$profile"
  case "$profile" in
    starter) zoom='nat-z8'; sat='7' ;;
    balanced) zoom='11'; sat='9' ;;
    full) zoom='11'; sat='9' ;; # Don't silently fetch ~160 GB basemaps.
  esac
  install -d -m 0755 /etc/iiab
  [[ -f "$vars" ]] && cp -a -- "$vars" "$vars.prepperdisk.$(date +%Y%m%d-%H%M%S).bak"
  python3 - "$vars" "$zoom" "$sat" <<'PY'
import pathlib,re,sys
path=pathlib.Path(sys.argv[1]); zoom,sat=sys.argv[2:]
values={
 'osm_vector_maps_install':'False', 'osm_vector_maps_enabled':'False',
 'maps_install':'True','maps_enabled':'True',
 'maps_vector_zoom':zoom,'maps_satellite_zoom':sat,
 'maps_region_downloader':'True',
 'maps_search_engine':'static','maps_search_static_db':'pop-1k-cities',
 'kolibri_install':'True','kolibri_enabled':'True',
 'usb_lib_install':'True','usb_lib_enabled':'True',
 'kiwix_install':'True','kiwix_enabled':'True',
}
lines=path.read_text().splitlines() if path.exists() else []
# In-place update active lines; preserve comments and unrelated config.
for key,value in values.items():
    pat=re.compile(r'^\s*'+re.escape(key)+r'\s*:')
    locations=[i for i,line in enumerate(lines) if pat.match(line)]
    if locations:
        lines[locations[-1]]=f'{key}: {value}'
    else:
        lines.append(f'{key}: {value}')
path.write_text('\n'.join(lines).rstrip()+'\n')
PY
  echo "Applied Kolibri/Kiwix/new IIAB Maps settings in $vars (backup created if file existed)."
}
services(){
  root; base_deps; require_iiab
  local profile="${1:-starter}"
  profile_ok "$profile"
  say "Configuring IIAB built-in maps and Kolibri: $profile"
  set_iiab_keys "$profile"
  local runrole='/opt/iiab/iiab/runrole' failures=0
  [[ -x "$runrole" ]] || err 'IIAB runrole not installed; complete IIAB software installation first.'
  # IIAB's supported syntax per roles/maps/README.md is runrole maps --reinstall.
  ( cd /opt/iiab/iiab && ./runrole kiwix --reinstall ) || { warn 'Kiwix role failed; check the IIAB installation logs.'; ((failures+=1)); }
  ( cd /opt/iiab/iiab && ./runrole maps --reinstall ) || { warn 'Maps installation failed; inspect IIAB role logs and retry services.'; ((failures+=1)); }
  ( cd /opt/iiab/iiab && ./runrole kolibri --reinstall ) || { warn 'Kolibri installation failed; inspect IIAB role logs and retry services.'; ((failures+=1)); }
  ( cd /opt/iiab/iiab && ./runrole usb_lib --reinstall ) || { warn 'USB library role failed; USB file access may need Admin Console configuration.'; ((failures+=1)); }
  log "services $profile"
  echo 'For high-res regional maps: http://box.lan/maps/ (choose rectangle online).'
  echo 'For Kolibri learning channels: http://box.lan/admin > Install Content.'
  (( failures == 0 ))
}

# Discover exact filenames from the publisher's current HTTPS directory listing.
latest_zim(){
  local folder="$1" prefix="$2" page
  [[ "$folder" =~ ^[a-z_]+$ && "$prefix" =~ ^[a-zA-Z0-9_.-]+$ ]] || return 1
  page=$(curl -fsSL --retry 2 --connect-timeout 20 --max-time 120 "$KIWIX_BASE/$folder/") || return 1
  printf '%s' "$page" | python3 -c '
import sys,html,re
body=html.unescape(sys.stdin.read())
prefix=sys.argv[1]
# Exact archive prefix, followed only by YYYY-MM (optional letter), then .zim.
pattern=r"(?:href=[\"\x27])?("+re.escape(prefix)+r"_\d{4}-\d{2}[a-z]?\.zim)"
found=set(re.findall(pattern,body))
print(sorted(found,reverse=True)[0] if found else "")
' "$prefix" | while IFS= read -r name; do
    [[ -n "$name" ]] || exit 1
    printf '%s/%s/%s\n' "$KIWIX_BASE" "$folder" "$name"
  done
}

download(){
  local url="$1" dest="$2" kind="$3" tmp avail_kb remote_bytes partial_bytes required_kb got
  [[ "$url" == https://* ]] || { warn "Refusing non-HTTPS URL: $url"; return 1; }
  [[ "$dest" == /library/* ]] || { warn 'Download destination must be under /library.'; return 1; }
  install -d -m 0755 "$(dirname "$dest")" "$STATE"
  [[ -s "$dest" ]] && { echo "Exists: $dest"; return 0; }
  tmp="$dest.part"
  remote_bytes=$(curl -sSIL --retry 2 --connect-timeout 12 --max-time 30 "$url" 2>/dev/null | tr -d '\r' | awk 'tolower($1)=="content-length:" && $2~/^[0-9]+$/ {n=$2} END {print n+0}') || remote_bytes=0
  partial_bytes=0; [[ -f "$tmp" ]] && partial_bytes=$(stat -c %s "$tmp")
  avail_kb=$(df -Pk "$(dirname "$dest")" | awk 'END{print $4}')
  if (( remote_bytes > 0 )); then
    required_kb=$(( (remote_bytes-partial_bytes+1023)/1024+1024*1024 ))
    (( required_kb < 1024*1024 )) && required_kb=$((1024*1024))
    if (( avail_kb < required_kb )); then warn "Insufficient free space for $dest (keep 1 GiB free)"; return 1; fi
  else
    warn "Remote size not provided for $(basename "$dest"); check free space."
  fi
  say "Downloading $(basename "$dest")"
  # Resume only if server supports it. -C - will fail cleanly if server does not.
  if ! curl -fL --retry 5 --retry-delay 3 --connect-timeout 30 -C - -o "$tmp" "$url"; then
    warn "Download incomplete; resumable part kept: $tmp"; return 1
  fi
  [[ -s "$tmp" ]] || { warn "Empty download: $tmp"; return 1; }
  got=$(stat -c %s "$tmp")
  if (( remote_bytes > 0 && got != remote_bytes )); then warn "Size mismatch: $dest ($got vs $remote_bytes)"; return 1; fi
  if [[ "$kind" == pdf ]]; then
    [[ "$(head -c 5 "$tmp")" == '%PDF-' ]] || { warn "Not a PDF: $url"; rm -f "$tmp"; return 1; }
  fi
  mv -f -- "$tmp" "$dest"
  log "download $dest $url"
}

archive(){
  local label="$1" folder="$2" url='' candidate; shift 2
  say "Archive: $label"
  for candidate in "$@"; do
    if url=$(latest_zim "$folder" "$candidate") && [[ -n "$url" ]]; then
      if download "$url" "$ZIMS/${url##*/}" zim; then return 0; else return 1; fi
    fi
  done
  warn "No matching Kiwix archive found for: $label; try IIAB Admin > Install Content."
  return 1
}
reindex(){
  if [[ -x /usr/bin/iiab-make-kiwix-lib ]]; then
    /usr/bin/iiab-make-kiwix-lib || warn 'Unable to regenerate IIAB Kiwix index.'
    systemctl try-restart kiwix-serve.service >/dev/null 2>&1 || true
  else warn 'IIAB Kiwix indexer not installed; archive files saved but not indexed yet.'; fi
}
content(){
  root; require_iiab; has curl && has python3 || err 'Install curl and python3 first.'
  local p="${1:-starter}" failed=0
  profile_ok "$p"
  install -d "$ZIMS" "$STATE"
  say "Kiwix content profile $p — check storage first"
  df -h "$ZIMS"
  case "$p" in
    starter) archive 'Wikipedia English top articles' wikipedia wikipedia_en_top_maxi wikipedia_en_top_nopic || ((failed+=1)) ;;
    balanced) archive 'Wikipedia English complete no images' wikipedia wikipedia_en_all_nopic || ((failed+=1)) ;;
    full) archive 'Wikipedia English complete with images' wikipedia wikipedia_en_all_maxi || ((failed+=1)) ;;
  esac
  archive 'Medical Wikipedia' wikipedia wikipedia_en_medicine_maxi wikipedia_en_medicine_nopic || ((failed+=1))
  archive 'iFixit repair guides' ifixit ifixit_en_all || ((failed+=1))
  archive 'Appropedia sustainability guides' other appropedia_en_all_maxi || ((failed+=1))
  if [[ "$p" != starter ]]; then
    archive 'wikiHow English' wikihow wikihow_en_maxi wikihow_en_all_maxi || ((failed+=1))
    archive 'Project Gutenberg books' gutenberg gutenberg_en_all gutenberg_en_all_maxi || ((failed+=1))
    archive 'Wikibooks' wikibooks wikibooks_en_all_maxi || ((failed+=1))
    archive 'TED agriculture videos' ted ted_mul_agriculture || ((failed+=1))
    archive 'TED natural disasters videos' ted ted_mul_natural-disasters ted_mul_disaster || ((failed+=1))
  fi
  if [[ "$p" == full ]]; then
    archive 'Wikisource' wikisource wikisource_en_all_maxi || ((failed+=1))
    archive 'Outdoors questions' stack_exchange outdoors_stackexchange_com_en_all || ((failed+=1))
    archive 'Woodworking questions' stack_exchange woodworking_stackexchange_com_en_all || ((failed+=1))
    archive 'Sustainable living questions' stack_exchange sustainableliving_stackexchange_com_en_all || ((failed+=1))
    archive 'TED science videos' ted ted_mul_science || ((failed+=1))
  fi
  reindex
  log "content $p failures=$failed"
  echo "Download profile finished; $failed archive categories missing/failed. Re-run anytime."
  (( failed == 0 ))
}

# Small, published official reference documents; DO NOT crawl websites indiscriminately.
manuals(){
  root; require_iiab; install -d "$MANUALS"
  local n=0
  download 'https://www.ready.gov/sites/default/files/2021-02/ready_checklist.pdf' "$MANUALS/ready-emergency-kit-checklist.pdf" pdf || ((n+=1))
  download 'https://www.usfa.fema.gov/downloads/pdf/publications/escape_grid.pdf' "$MANUALS/usfa-home-fire-escape-plan.pdf" pdf || ((n+=1))
  download 'https://www.ready.gov/sites/default/files/2020-03/ready_family-communications-plan_kids.pdf' "$MANUALS/ready-family-communications-plan.pdf" pdf || ((n+=1))
  download 'https://stacks.cdc.gov/view/cdc/80620/cdc_80620_DS1.pdf' "$MANUALS/cdc-wildfire-smoke-guide.pdf" pdf || ((n+=1))
  index_files "$MANUALS" 'Public emergency manuals' pdf
  log "manuals failures=$n"
  echo 'Publisher catalogs for additional free manuals: ready.gov/publications and armypubs.army.mil'
  echo 'Nuclear War Survival Skills authorized download: https://oism.org/nwss/'
  echo 'Get your preferred version from the author site, then use add-pdfs.'
  (( n == 0 ))
}

index_files(){
  local folder="$1" title="$2" ext="$3"
  python3 - "$folder" "$title" "$ext" <<'PY'
import pathlib,sys,html,urllib.parse
path=pathlib.Path(sys.argv[1]); title=sys.argv[2]; exts=sys.argv[3].split(',')
files=sorted((p for p in path.iterdir() if p.is_file() and p.suffix.lower().lstrip('.') in exts),key=lambda p:p.name.lower())
s=['<!doctype html><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">',
   '<title>'+html.escape(title)+'</title><style>body{font:18px system-ui;max-width:800px;margin:40px auto;padding:12px;background:#101827;color:#fff}a{color:#7ed3fc}li{margin:.7em}</style>',
   '<p><a href="/prepperdisk/">← Offline library home</a></p><h1>'+html.escape(title)+'</h1><ul>']
for f in files: s.append(f'<li><a href="{urllib.parse.quote(f.name)}">{html.escape(f.name)}</a></li>')
s.append('</ul><p>Files stored locally on this device.</p>')
(path/'index.html').write_text('\n'.join(s))
PY
}
import_files(){
  root; require_iiab
  local mode="$1" src="$2" target name count=0
  [[ -d "$src" ]] || err "Source directory does not exist: $src"
  case "$mode" in
    pdfs) target="$MANUALS";;
    videos) target="$VIDEOS";;
    *) err 'Unknown file mode';;
  esac
  [[ "$(realpath "$src")" != "$(realpath -m "$target")" ]] || err 'Source and destination are the same directory.'
  install -d "$target"
  while IFS= read -r -d '' name; do
    cp -n -- "$name" "$target/$(basename "$name")" || warn "Could not copy $name"
    ((count+=1))
  done < <(if [[ "$mode" == pdfs ]]; then find "$src" -maxdepth 1 -type f -iname '*.pdf' -print0; else find "$src" -maxdepth 1 -type f \( -iname '*.mp4' -o -iname '*.webm' -o -iname '*.ogv' \) -print0; fi)
  if [[ "$mode" == pdfs ]]; then index_files "$target" 'Offline PDF manuals' pdf
  else index_files "$target" 'Offline videos' mp4,webm,ogv; fi
  echo "Imported $count local files from $src"
}

portal(){
  root; require_iiab
  install -d "$WEB/morse" "$WEB/phrases" "$MANUALS" "$VIDEOS"
  index_files "$MANUALS" 'Offline PDF manuals' pdf
  index_files "$VIDEOS" 'Offline videos' mp4,webm,ogv
  cat > "$WEB/index.html" <<'HTML'
<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>DIY Offline Survival Library</title>
<style>body{background:#0b1320;color:#eaf2fa;font:17px system-ui,sans-serif;max-width:1000px;margin:auto;padding:24px}a{color:#94d8ff}h1{font-size:2.1rem}p{line-height:1.5}.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(230px,1fr));gap:15px}.item{border:1px solid #445465;background:#182538;padding:20px;border-radius:14px}.item a{font-size:1.13rem;font-weight:700}.muted{color:#bed0df}footer{margin-top:35px}</style>
<h1>🧭 Offline Survival Library</h1><p>Served entirely from this Raspberry Pi. Internet is not required once content is downloaded and tested.</p>
<div class="grid">
<div class="item"><a href="/kiwix/">📚 Kiwix knowledge library</a><p>Wikipedia, medicine, repairs, sustainable living, books and TED video archives (if downloaded).</p></div>
<div class="item"><a href="/maps/">🗺️ Offline maps</a><p>World maps, satellite photos, terrain and high-quality downloaded regions.</p></div>
<div class="item"><a href="/kolibri/">🎓 Offline classroom</a><p>Courses work offline once channels have been imported in Kolibri.</p></div>
<div class="item"><a href="manuals/">🚨 Emergency PDF manuals</a><p>Official FEMA and fire safety publications, plus your imported files.</p></div>
<div class="item"><a href="videos/">🎬 Offline videos</a><p>Local MP4, WebM and Ogg videos you have permission to store.</p></div>
<div class="item"><a href="morse/">📻 Morse encoder & typed decoder</a><p>Convert text to signals, send audible tone, decode entered dots and dashes.</p></div>
<div class="item"><a href="phrases/">🌍 Emergency phrases</a><p>Static printable English / Spanish phrases for basic communication.</p></div>
<div class="item"><a href="http://box.lan:8765/">🗣️ Offline translation (optional)</a><p>Separate locally running Argos Translate service. Only works if successfully installed.</p></div>
<div class="item"><a href="/admin/">⚙️ IIAB admin console</a><p>Choose map areas, import Kolibri courses, manage additional ZIM content.</p></div>
</div>
<footer><p class="muted">Emergency information may be outdated; this library is a reference, not a substitute for trained medical help. RepeaterBook: use its official offline mobile app (not bundled).</p></footer></html>
HTML
  cat > "$WEB/morse/index.html" <<'HTML'
<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Morse tool</title>
<style>body{font:18px system-ui;max-width:780px;margin:24px auto;padding:12px;background:#121a27;color:#fff}textarea{width:95%;height:95px;padding:12px;font:19px monospace;background:#fff;color:#111}a{color:#75d0ff}button{padding:10px 17px;margin:7px 0}pre{white-space:pre-wrap;word-break:break-word;background:#243149;padding:15px}</style>
<p><a href="/prepperdisk/">← Library</a></p><h1>📻 Offline Morse code</h1><p>Encodes text; decodes <strong>manually entered</strong> signals. It does NOT detect radio audio automatically.</p>
<label>Plain text<textarea id="plain" placeholder="SOS need help"></textarea></label><p><button id="encode">Encode & play</button></p>
<label>Morse (space between letters, / between words)<textarea id="code" placeholder="... --- ..."></textarea></label><p><button id="decode">Decode to text</button> <button id="beep">Play Morse audio</button></p>
<p id="message" aria-live="polite"></p><script>
const alphabet={A:'.-',B:'-...',C:'-.-.',D:'-..',E:'.',F:'..-.',G:'--.',H:'....',I:'..',J:'.---',K:'-.-',L:'.-..',M:'--',N:'-.',O:'---',P:'.--.',Q:'--.-',R:'.-.',S:'...',T:'-',U:'..-',V:'...-',W:'.--',X:'-..-',Y:'-.--',Z:'--..',0:'-----',1:'.----',2:'..---',3:'...--',4:'....-',5:'.....',6:'-....',7:'--...',8:'---..',9:'----.', '.':'.-.-.-',',':'--..--','?':'..--..','/':'-..-.','=':'-...-'};
const inv=Object.fromEntries(Object.entries(alphabet).map(([x,y])=>[y,x]));
const plain=document.querySelector('#plain'),code=document.querySelector('#code'),status=document.querySelector('#message');
function encode(){code.value=plain.value.toUpperCase().trim().split(/\s+/).map(w=>[...w].map(c=>alphabet[c]||'').filter(Boolean).join(' ')).join(' / ');}
document.querySelector('#encode').onclick=()=>{encode();play();};
document.querySelector('#decode').onclick=()=>{plain.value=code.value.trim().split(/\s*\/\s*/).map(w=>w.trim().split(/\s+/).map(s=>inv[s]||'?').join('')).join(' ');};
async function play(){try{const AudioContext=window.AudioContext||window.webkitAudioContext;const ctx=new AudioContext();await ctx.resume();let t=ctx.currentTime+.1;for(const c of code.value.slice(0,900)){if(c==='.'||c==='-'){let d=(c==='.'?.085:.255),o=ctx.createOscillator(),gain=ctx.createGain();o.frequency.value=600;gain.gain.value=.08;o.connect(gain);gain.connect(ctx.destination);o.start(t);o.stop(t+d);t+=d+.085;}else if(c===' ')t+=.17;else if(c==='/')t+=.35;}status.textContent='Playing encoded Morse';setTimeout(()=>ctx.close(),Math.max(500,(t-ctx.currentTime+1)*1000));}catch(e){status.textContent='Audio playback unavailable in this browser.';}}
document.querySelector('#beep').onclick=()=>play();
</script></html>
HTML
  cat > "$WEB/phrases/index.html" <<'HTML'
<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Offline emergency phrases</title>
<style>body{font:18px system-ui;max-width:800px;margin:25px auto;padding:15px;background:#0c1623;color:#fff}a{color:#9cf}table{border-collapse:collapse;width:100%}td,th{border:1px solid #567;padding:10px;text-align:left}tr:nth-child(even){background:#25334a}</style>
<p><a href="/prepperdisk/">← Library</a></p><h1>Emergency phrases: English ↔ Español</h1><p>Simple offline reference (not machine translation). Show the screen or print it.</p>
<table><tr><th>English</th><th>Español</th></tr><tr><td>I need help.</td><td>Necesito ayuda.</td></tr>
<tr><td>Call an ambulance.</td><td>Llame a una ambulancia.</td></tr><tr><td>Where is the hospital?</td><td>¿Dónde está el hospital?</td></tr>
<tr><td>I need water.</td><td>Necesito agua.</td></tr><tr><td>I am lost.</td><td>Estoy perdido/a.</td></tr>
<tr><td>Is it safe here?</td><td>¿Es seguro aquí?</td></tr><tr><td>There is a fire.</td><td>Hay un incendio.</td></tr>
<tr><td>Where is the exit?</td><td>¿Dónde está la salida?</td></tr><tr><td>I do not understand.</td><td>No entiendo.</td></tr>
<tr><td>Do you speak English?</td><td>¿Habla inglés?</td></tr><tr><td>Help! Emergency!</td><td>¡Ayuda! ¡Emergencia!</td></tr>
</table><p>For broader sentence translation, install the optional Argos Translate service (http://box.lan:8765/).</p></html>
HTML
  log portal
  say 'Local landing page: http://box.lan/prepperdisk/'
}

# Web interface is served separately (same-origin POST; no cross-origin APIs).
# Small request size + no external calls; bind to LAN via :8765. Do not port-forward it.
translator(){
  root; require_iiab; check_pi
  local src="${1:-en}" dst="${2:-es}"
  [[ "$src" =~ ^[a-z]{2,3}$ && "$dst" =~ ^[a-z]{2,3}$ ]] || err 'Language codes must be ISO language identifiers.'
  has runuser || err 'runuser required.'
  say "Installing optional offline Argos Translate: $src ⇄ $dst"
  DEBIAN_FRONTEND=noninteractive apt-get update
  DEBIAN_FRONTEND=noninteractive apt-get install -y python3-venv python3-pip build-essential
  if ! id -u prepperdisk >/dev/null 2>&1; then
    useradd --system --home-dir "$STATE" --shell /usr/sbin/nologin prepperdisk
  fi
  install -d -m 0755 "$OPT" "$STATE"
  chown -R prepperdisk:prepperdisk "$STATE"
  [[ -x "$OPT/venv/bin/python" ]] || python3 -m venv "$OPT/venv"
  "$OPT/venv/bin/pip" install --disable-pip-version-check argostranslate || { warn 'Argos install failed (may lack ARM wheels or RAM); translator not enabled.'; return 1; }
  cat > "$OPT/import_models.py" <<'PY'
import sys
import argostranslate.package as ap
src,dst=sys.argv[1:3]
ap.update_package_index()
packages=ap.get_available_packages()
for a,b in [(src,dst),(dst,src)]:
    pkg=next((p for p in packages if p.from_code==a and p.to_code==b),None)
    if not pkg:
        raise RuntimeError(f'No official Argos model for {a}->{b}')
    print('Installing',a,'->',b,flush=True)
    ap.install_from_path(pkg.download())
PY
  if ! runuser -u prepperdisk -- env HOME="$STATE" "$OPT/venv/bin/python" "$OPT/import_models.py" "$src" "$dst"; then
    warn 'Argos model download failed. Service not activated. Re-run translator later.'; return 1
  fi
  cat > "$OPT/server.py" <<'PY'
from http.server import BaseHTTPRequestHandler,ThreadingHTTPServer
import json,html,os
import argostranslate.translate as at
INDEX='''<!doctype html><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Offline translator</title>
<style>body{font:18px system-ui;max-width:750px;margin:30px auto;padding:16px;background:#142035;color:#fff}textarea{width:96%;min-height:140px;padding:8px}button{padding:12px}a{color:#9cf}pre{white-space:pre-wrap;background:#253851;padding:13px}</style>
<p><a href="http://box.lan/prepperdisk/">← Library</a></p><h1>Offline Argos translator</h1><p>Runs on this Pi. Translation is not reliable for life-critical medical or safety instructions.</p>
<label>From <select id="src"><option value="en">English</option><option value="es">Spanish</option></select></label>
<label>To <select id="dst"><option value="es">Spanish</option><option value="en">English</option></select></label>
<p><textarea id="message" placeholder="Type text to translate"></textarea></p><button id="go">Translate</button><pre id="result"></pre>
<script>document.querySelector('#go').onclick=async()=>{const out=document.querySelector('#result');out.textContent='Translating…';try{const r=await fetch('/translate',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({text:document.querySelector('#message').value,src:document.querySelector('#src').value,dst:document.querySelector('#dst').value})});const j=await r.json();out.textContent=r.ok?j.translation:(j.error||'Failed');}catch(e){out.textContent='Service not available.'}};</script>'''
class Handler(BaseHTTPRequestHandler):
    def respond(self,status,body,ct='application/json'):
        self.send_response(status);self.send_header('Content-Type',ct+'; charset=utf-8');self.send_header('Cache-Control','no-store');self.send_header('X-Content-Type-Options','nosniff');self.send_header('Content-Security-Policy',"default-src 'self' 'unsafe-inline'");self.end_headers();self.wfile.write(body.encode())
    def do_GET(self):
        if self.path=='/':self.respond(200,INDEX,'text/html')
        else:self.respond(404,json.dumps({'error':'not found'}))
    def do_POST(self):
        if self.path!='/translate':return self.respond(404,json.dumps({'error':'not found'}))
        try:
            n=int(self.headers.get('Content-Length','0'))
            if n<1 or n>8192:return self.respond(413,json.dumps({'error':'Max 8KB'}))
            data=json.loads(self.rfile.read(n)); text=data.get('text','');src=data.get('src','');dst=data.get('dst','')
            if not isinstance(text,str) or len(text)>4000 or not all(isinstance(x,str) and x.isalpha() and len(x)<9 for x in [src,dst]):raise ValueError('Invalid input')
            result=at.translate(text,src,dst)
            self.respond(200,json.dumps({'translation':result},ensure_ascii=False))
        except Exception as e:self.respond(400,json.dumps({'error':str(e)}))
ThreadingHTTPServer(('0.0.0.0',8765),Handler).serve_forever()
PY
  cat > /etc/systemd/system/prepperdisk-translate.service <<EOF
[Unit]
Description=PrepperDisk local offline translator
After=network.target
[Service]
Type=simple
User=prepperdisk
Group=prepperdisk
WorkingDirectory=$OPT
Environment=HOME=$STATE
ExecStart=$OPT/venv/bin/python $OPT/server.py
Restart=on-failure
RestartSec=5
NoNewPrivileges=true
ProtectSystem=full
PrivateTmp=true
[Install]
WantedBy=multi-user.target
EOF
  systemctl daemon-reload
  systemctl enable --now prepperdisk-translate.service
  systemctl is-active --quiet prepperdisk-translate.service || { warn 'Translator service could not start. Check journalctl -u prepperdisk-translate'; return 1; }
  log 'translator'
  echo 'Translator: http://box.lan:8765/ (LAN only; do not expose to internet).'
}

hotspot(){
  root; require_iiab
  has iiab-hotspot-on || err 'IIAB hotspot helper not installed; configure from IIAB Admin > Networking.'
  warn 'Wi-Fi changes may drop your SSH connection. Use Ethernet.'
  confirm 'Enable IIAB hotspot now?' || return 0
  iiab-hotspot-on
}

status(){
  echo '=== DIY PrepperDisk status ==='
  uname -a
  echo
  if [[ -d /library ]]; then df -h /library; else echo 'No /library mount'; fi
  echo
  for f in "$WEB/index.html" "$WEB/morse/index.html" "$WEB/phrases/index.html"; do
    [[ -f "$f" ]] && echo "Present: $f" || echo "Missing: $f"
  done
  if [[ -d "$ZIMS" ]]; then echo "ZIM count: $(find "$ZIMS" -maxdepth 1 -name '*.zim' -type f | wc -l)"; du -sh "$ZIMS"; fi
  for svc in kiwix-serve kolibri prepperdisk-translate nginx; do
    printf '%s: ' "$svc"; systemctl is-active "$svc" 2>/dev/null || true
  done
  echo 'Landing page: http://box.lan/prepperdisk/'
  echo 'Logs: /var/lib/prepperdisk/operations.log'
}

all(){
  root; require_iiab
  local p="${1:-starter}" failures=0
  profile_ok "$p"
  if [[ "$p" == full ]]; then
    warn 'FULL can download hundreds of gigabytes. Ensure you have >=512 GB usable storage.'
    confirm 'Download the FULL content profile?' || return 0
  fi
  services "$p" || ((failures+=1))
  portal || ((failures+=1))
  manuals || ((failures+=1))
  content "$p" || ((failures+=1))
  # Model downloads can be large and Argos often fails on older Pi memory; make
  # it opt-in on starter but automatic attempt for balanced/full.
  if [[ "$p" != starter ]]; then translator en es || ((failures+=1)); fi
  echo "All steps attempted. $failures step(s) reported an error or missing archive."
  echo 'Visit: http://box.lan/prepperdisk/'
  echo 'Remaining manual choices: Kolibri channels; detailed map regions; licensed videos; RepeaterBook official app.'
  (( failures == 0 ))
}

# ----------------------------------------
# v3 interactive text user interface (TUI)
# ----------------------------------------
# Uses whiptail/dialog if available; a numbered Bash menu is the fallback.
# The TUI calls the same subcommands used by automation so it cannot silently
# execute a different installation path.
TUI_PROFILE='balanced'
TUI_BACKEND=''
TUI_CONFIG="${HOME:-/tmp}/.config/prepperdisk/profile"
TUI_SCRIPT="$(realpath -- "${BASH_SOURCE[0]}")"

ui_init(){
  if has whiptail && [[ -t 0 && -t 1 && "${TERM:-dumb}" != dumb ]]; then
    TUI_BACKEND='whiptail'
  elif has dialog && [[ -t 0 && -t 1 && "${TERM:-dumb}" != dumb ]]; then
    TUI_BACKEND='dialog'
  fi
  if [[ -f "$TUI_CONFIG" ]]; then
    local saved=''
    IFS= read -r saved < "$TUI_CONFIG" || true
    case "$saved" in starter|balanced|full) TUI_PROFILE="$saved";; esac
  fi
}
ui_save_profile(){
  if mkdir -p -- "$(dirname "$TUI_CONFIG")" 2>/dev/null; then
    printf '%s\n' "$TUI_PROFILE" > "$TUI_CONFIG" 2>/dev/null || true
  fi
}
ui_call(){
  "$TUI_BACKEND" --backtitle 'DIY Prepper Disk — Raspberry Pi Offline Library' "$@"
}
ui_pause(){
  local answer=''
  printf '\nPress Enter to return to the menu...' >&2
  IFS= read -r answer || true
}
ui_message(){
  local title="$1" message="$2"
  if [[ -n "$TUI_BACKEND" ]]; then
    ui_call --title "$title" --msgbox "$message" 16 75
  else
    printf '\n=== %s ===\n%s\n' "$title" "$message" >&2
    ui_pause
  fi
}
ui_yesno(){
  local title="$1" message="$2" answer=''
  if [[ -n "$TUI_BACKEND" ]]; then
    ui_call --title "$title" --yesno "$message" 17 76
  else
    printf '\n=== %s ===\n%s\n' "$title" "$message" >&2
    printf 'Continue? [y/N] ' >&2
    IFS= read -r answer || return 1
    [[ "$answer" =~ ^([yY]|[yY][eE][sS])$ ]]
  fi
}
ui_select(){
  local title="$1" message="$2" count=0 item answer=''
  shift 2
  if [[ -n "$TUI_BACKEND" ]]; then
    ui_call --title "$title" --menu "$message" 22 78 12 "$@" 3>&1 1>&2 2>&3
  else
    printf '\n=== %s ===\n%s\n' "$title" "$message" >&2
    while (( $# > 0 )); do
      printf '  %-12s %s\n' "$1" "$2" >&2
      shift 2
    done
    printf 'Choice (blank to go back): ' >&2
    IFS= read -r answer || return 1
    [[ -n "$answer" ]] || return 1
    printf '%s\n' "$answer"
  fi
}
ui_input(){
  local title="$1" message="$2" value="${3:-}"
  if [[ -n "$TUI_BACKEND" ]]; then
    ui_call --title "$title" --inputbox "$message" 17 78 "$value" 3>&1 1>&2 2>&3
  else
    printf '\n=== %s ===\n%s\n' "$title" "$message" >&2
    printf 'Enter value (blank to cancel): ' >&2
    IFS= read -r value || return 1
    [[ -n "$value" ]] || return 1
    printf '%s\n' "$value"
  fi
}
ui_profile_pick(){
  local choice=''
  if [[ -n "$TUI_BACKEND" ]]; then
    choice=$(ui_call --title 'Choose content profile' --radiolist \
      'Starter is smallest. Balanced and Full download much more data. Maps/course regions are chosen separately in IIAB.' \
      18 78 5 \
      starter 'Smaller introductory Kiwix collection' "$([[ "$TUI_PROFILE" == starter ]] && echo ON || echo OFF)" \
      balanced 'Wikipedia no images, reference and learning archives' "$([[ "$TUI_PROFILE" == balanced ]] && echo ON || echo OFF)" \
      full 'Large Wikipedia with images and extra archives; 512GB+ recommended' "$([[ "$TUI_PROFILE" == full ]] && echo ON || echo OFF)" \
      3>&1 1>&2 2>&3) || return 0
  else
    choice=$(ui_select 'Content profile' "Current: $TUI_PROFILE" \
      starter 'Smallest, faster downloads' balanced 'More comprehensive' full 'Very large downloads') || return 0
  fi
  case "$choice" in
    starter|balanced|full) TUI_PROFILE="$choice"; ui_save_profile;;
    *) ui_message 'Invalid profile' 'Choose starter, balanced or full.';;
  esac
}
ui_selected_tasks(){
  local result='' key description default response selected=''
  if [[ -n "$TUI_BACKEND" ]]; then
    ui_call --title 'Choose components to install' --separate-output --checklist \
      "Select tasks to run. Profile: $TUI_PROFILE. Space toggles choices; Enter begins." \
      20 78 9 \
      services 'IIAB Maps, Kolibri, USB library, Kiwix services' ON \
      portal 'Offline start page, Morse and phrasebook' ON \
      manuals 'Public emergency PDF downloads' ON \
      content 'Kiwix archives for the selected profile' ON \
      translator 'Argos offline English-Spanish translation (large/optional)' OFF \
      3>&1 1>&2 2>&3
  else
    printf '\nChoose components. Press Enter to keep each default.\n' >&2
    for key in services portal manuals content translator; do
      case "$key" in translator) default=N;; *) default=Y;; esac
      printf '  %-12s Install? [Y/n] (translator [y/N]): ' "$key" >&2
      IFS= read -r response || return 1
      if [[ "$key" == translator ]]; then
        [[ "$response" =~ ^([yY]|[yY][eE][sS])$ ]] && selected+="${key}"$'\n'
      else
        [[ -z "$response" || "$response" =~ ^([yY]|[yY][eE][sS])$ ]] && selected+="${key}"$'\n'
      fi
    done
    [[ -n "$selected" ]] || return 1
    printf '%s' "$selected"
  fi
}
ui_fs_info(){
  if [[ -d /library ]]; then
    df -h /library 2>/dev/null | tail -n 1
  else
    df -h / 2>/dev/null | tail -n 1
  fi
}
ui_require_iiab(){
  if ! iiab_ready; then
    ui_message 'IIAB not installed' \
      'Install Internet-in-a-Box (menu option 1) first and finish its reboots. Then return to the selected operation.'
    return 1
  fi
}
ui_command(){
  local result=0 cmd="$1"; shift || true
  printf '\n============================================================\n' >&2
  printf 'RUNNING: %s %s\n' "$cmd" "$*" >&2
  printf '============================================================\n' >&2
  # IIAB bootstrap is intended to start as the original, non-root Pi user.
  # Every other mutating command needs root; status is read-only.
  if [[ "$cmd" == install || "$cmd" == status ]]; then
    bash "$TUI_SCRIPT" "$cmd" "$@" || result=$?
  elif (( EUID == 0 )); then
    bash "$TUI_SCRIPT" "$cmd" "$@" || result=$?
  elif has sudo; then
    sudo bash "$TUI_SCRIPT" "$cmd" "$@" || result=$?
  else
    warn 'sudo is not installed. Run TUI with sudo for configuration tasks.'
    result=1
  fi
  if (( result == 0 )); then
    printf '\nSUCCESS: %s\n' "$cmd" >&2
  else
    printf '\nFAILED: %s (exit %d). Check messages above.\n' "$cmd" "$result" >&2
  fi
  ui_pause
  return "$result"
}
ui_preflight(){
  local tasks="$1" size status
  size=$(ui_fs_info)
  if iiab_ready; then status='Installed / ready'; else status='Not installed / incomplete'; fi
  ui_yesno 'Confirm selected downloads and changes' \
    "IIAB: $status
Content profile: $TUI_PROFILE
Storage: $size

Tasks:
$tasks

No storage devices will be formatted. Kiwix archives, maps and translation packages can use substantial disk space and internet bandwidth. Changes to IIAB settings will be backed up. Continue?"
}
ui_run_tasks(){
  local selected='' task failures=0 count=0 report=''
  selected=$(ui_selected_tasks) || return 0
  [[ -n "$selected" ]] || { ui_message 'No tasks selected' 'Nothing was selected.'; return 0; }
  ui_require_iiab || return 0
  if [[ "$TUI_PROFILE" == full ]]; then
    ui_yesno 'Large download warning' \
      'The Full profile can consume hundreds of gigabytes and take a long time. A 512GB or larger drive is recommended. Proceed with Full?' || return 0
  fi
  ui_preflight "$selected" || return 0
  while IFS= read -r task; do
    [[ -n "$task" ]] || continue
    case "$task" in services|portal|manuals|content|translator) ;; *) warn "Skipping unknown task: $task"; continue;; esac
    ((count+=1))
    case "$task" in
      services|content) ui_command "$task" "$TUI_PROFILE" || { ((failures+=1)); report+="$task: failed"$'\n'; };;
      translator) ui_command translator en es || { ((failures+=1)); report+='translator: failed'$'\n'; };;
      *) ui_command "$task" || { ((failures+=1)); report+="$task: failed"$'\n'; };;
    esac
  done <<< "$selected"
  ui_message 'Selected tasks complete' \
    "Attempted: $count
Reported failures: $failures
${report:-No tasks reported an error.}
Some IIAB courses and detailed map regions still require manual selection."
}
ui_quick_install(){
  ui_require_iiab || return 0
  if [[ "$TUI_PROFILE" == full ]]; then
    ui_yesno 'Full profile: disk warning' \
      'The Full content profile can be several hundred GB. Ensure sufficient free space and stable power.' || return 0
  fi
  ui_preflight "services, portal, manuals, content, and (except starter) translator" || return 0
  ui_command all "$TUI_PROFILE" || true
}
ui_import_menu(){
  local mode='' folder=''
  ui_require_iiab || return 0
  mode=$(ui_select 'Import files' 'Copy from a directory already attached/mounted to the Pi.' \
    pdfs 'Import .pdf files into manuals' videos 'Import .mp4/.webm/.ogv into videos') || return 0
  case "$mode" in pdfs|videos) ;; *) return 0;; esac
  folder=$(ui_input 'Source folder' 'Absolute path to existing folder, e.g. /media/pi/USB/Manuals' '') || return 0
  [[ -d "$folder" ]] || { ui_message 'Folder not found' "Missing directory: $folder"; return 0; }
  ui_yesno 'Confirm file import' "Copy $mode from:\n$folder\n\nFiles with the same name will not be overwritten." || return 0
  ui_command "add-$mode" "$folder" || true
}
ui_add_zim(){
  local address=''
  ui_require_iiab || return 0
  address=$(ui_input 'Add Kiwix archive' 'Paste a direct HTTPS URL to a .zim file (not a page showing ZIM links).' '') || return 0
  ui_yesno 'Download ZIM archive' "Download and index the following archive?\n\n$address" || return 0
  ui_command add-zim "$address" || true
}
ui_install_first(){
  if iiab_ready; then
    ui_yesno 'IIAB already found' 'IIAB files appear to be installed. Rerun its official bootstrap installer anyway?' || return 0
  fi
  ui_yesno 'Install Internet-in-a-Box' \
    'This starts the official interactive IIAB installer from iiab.io. Use Ethernet and a fresh Raspberry Pi OS Lite 64-bit install. IIAB may reboot and require finishing with sudo iiab. Continue?' || return 0
  ui_command install || true
}
ui_show_log(){
  if [[ ! -s "$LOG" ]]; then
    ui_message 'Operations log' 'No operations log yet. It is created as installation tasks run.'
    return 0
  fi
  if [[ -n "$TUI_BACKEND" ]]; then
    ui_call --title 'Prepper Disk operations log' --scrolltext --textbox "$LOG" 22 78 || true
  else
    tail -n 80 "$LOG" || true
    ui_pause
  fi
}
ui_help_screen(){
  ui_message 'Help and offline setup notes' \
    'Recommended sequence:
1. Install IIAB, complete reboots and run sudo iiab if requested.
2. Select Starter/Balanced/Full content profile.
3. Run guided setup or choose components.
4. Choose specific Kolibri courses in IIAB Admin.
5. Choose high-resolution offline map regions in IIAB Maps while online.
6. Test your library disconnected from the internet.

The hotspot can disconnect SSH on Wi-Fi: configure over Ethernet.

Licensed books and proprietary Prepper Disk content are not included.
You can still use CLI subcommands; run the script with help.'
}
tui(){
  [[ -t 0 && -t 1 ]] || err 'TUI requires an interactive terminal (SSH -t works). Use help for automation.'
  ui_init
  local choice=''
  while :; do
    choice=$(ui_select "DIY PREPPER DISK | Profile: $TUI_PROFILE" \
      "IIAB: $(iiab_ready && echo present || echo not-installed) | Storage: $(ui_fs_info)" \
      1 'Install initial Internet-in-a-Box' \
      2 'Choose content profile (Starter / Balanced / Full)' \
      3 'Guided complete setup for selected profile' \
      4 'Choose individual components (checkboxes)' \
      5 'Import your PDFs or video files' \
      6 'Add one Kiwix ZIM archive by URL' \
      7 'Enable Wi-Fi hotspot (Ethernet recommended)' \
      8 'Check installed services and storage' \
      9 'View installation log' \
      10 'Help / remaining manual tasks' \
      Q 'Quit') || break
    case "$choice" in
      1) ui_install_first;;
      2) ui_profile_pick;;
      3) ui_quick_install;;
      4) ui_run_tasks;;
      5) ui_import_menu;;
      6) ui_add_zim;;
      7) if ui_require_iiab && ui_yesno 'Hotspot safety warning' \
           'Enabling the hotspot can disconnect an SSH session using Wi-Fi. Run from an Ethernet connection or physical Pi console. Continue?'; then
           ui_command hotspot || true
         fi;;
      8) ui_command status || true;;
      9) ui_show_log;;
      10) ui_help_screen;;
      q|Q|quit|exit) break;;
      *) ui_message 'Unknown selection' "Please select one of the displayed options (received: $choice).";;
    esac
  done
  printf '\nGoodbye. Run %s to open the menu again.\n' "bash $(basename "$TUI_SCRIPT")" >&2
}


main(){
  local cmd="${1:-}"
  if [[ -z "$cmd" ]]; then
    if [[ -t 0 && -t 1 ]]; then cmd='menu'; else cmd='help'; fi
  else
    shift
  fi
  case "$cmd" in
    menu|tui) tui;;
    help|-h|--help) help;;
    install) install_iiab;;
    all) all "${1:-starter}";;
    services) services "${1:-starter}";;
    content) content "${1:-starter}";;
    manuals) manuals;;
    portal) portal;;
    translator) translator "${1:-en}" "${2:-es}";;
    add-zim) root; require_iiab; [[ -n "${1:-}" && "$1" =~ ^https://[A-Za-z0-9._/-]+\.zim$ ]] || err 'Supply a direct HTTPS .zim URL'; download "$1" "$ZIMS/${1##*/}" zim && reindex;;
    add-pdfs) [[ -n "${1:-}" ]] || err 'Provide directory'; import_files pdfs "$1";;
    add-videos) [[ -n "${1:-}" ]] || err 'Provide directory'; import_files videos "$1";;
    hotspot) hotspot;;
    status) status;;
    *) help; err "Unknown command: $cmd";;
  esac
}
main "$@"
