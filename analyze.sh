#!/bin/bash
set -euo pipefail
CMD="$1"; MSI="$2"
mkdir -p results extracted binaries

case "$CMD" in

info)
  echo "=== File info ==="
  ls -l "$MSI"
  file "$MSI"
  echo
  echo "=== Hashes ==="
  sha256sum "$MSI"
  sha1sum "$MSI"
  md5sum "$MSI"
  echo
  echo "=== MSI summary (msiinfo suminfo) ==="
  msiinfo suminfo "$MSI" 2>&1 || true
  echo
  echo "=== MSI tables list ==="
  msiinfo tables "$MSI" 2>&1 || true
  ;;

tables)
  echo "=== Dumping all MSI tables ==="
  for tbl in $(msiinfo tables "$MSI" 2>/dev/null); do
    echo
    echo "--- TABLE: $tbl ---"
    msiinfo export "$MSI" "$tbl" 2>/dev/null | head -200 || true
  done
  ;;

extract)
  echo "=== Extracting MSI with msiextract ==="
  cd extracted
  msiextract "../$MSI" 2>&1 || true
  cd ..
  echo
  echo "=== Extracted file tree ==="
  find extracted -type f | sort
  echo
  echo "=== File details ==="
  find extracted -type f -exec sh -c '
    for f; do
      printf "%-70s %8d  %s  %s\n" "$f" "$(stat -c%s "$f")" "$(sha256sum "$f" | cut -c1-16)" "$(file -b "$f" | head -c80)"
    done
  ' _ {} +
  echo
  echo "=== Also extracting with 7z ==="
  mkdir -p extracted-7z
  7z x -oextracted-7z "$MSI" -y 2>&1 | tail -20 || true
  echo
  echo "=== 7z file tree ==="
  find extracted-7z -type f | sort
  echo
  echo "=== 7z file details ==="
  find extracted-7z -type f -exec sh -c '
    for f; do
      printf "%-70s %8d  %s  %s\n" "$f" "$(stat -c%s "$f")" "$(sha256sum "$f" | cut -c1-16)" "$(file -b "$f" | head -c80)"
    done
  ' _ {} +
  ;;

actions)
  echo "=== CustomAction table ==="
  msiinfo export "$MSI" CustomAction 2>/dev/null || echo "(no CustomAction table)"
  echo
  echo "=== InstallExecuteSequence ==="
  msiinfo export "$MSI" InstallExecuteSequence 2>/dev/null || echo "(no InstallExecuteSequence)"
  echo
  echo "=== InstallUISequence ==="
  msiinfo export "$MSI" InstallUISequence 2>/dev/null || echo "(no InstallUISequence)"
  echo
  echo "=== Binary table (names only) ==="
  msiinfo export "$MSI" Binary 2>/dev/null | cut -f1 || echo "(no Binary table)"
  echo
  echo "=== Property table ==="
  msiinfo export "$MSI" Property 2>/dev/null || echo "(no Property table)"
  echo
  echo "=== LaunchCondition ==="
  msiinfo export "$MSI" LaunchCondition 2>/dev/null || echo "(no LaunchCondition)"
  echo
  echo "=== ServiceInstall ==="
  msiinfo export "$MSI" ServiceInstall 2>/dev/null || echo "(no ServiceInstall)"
  echo
  echo "=== ServiceControl ==="
  msiinfo export "$MSI" ServiceControl 2>/dev/null || echo "(no ServiceControl)"
  ;;

registry)
  echo "=== Registry table ==="
  msiinfo export "$MSI" Registry 2>/dev/null || echo "(no Registry table)"
  echo
  echo "=== RemoveRegistry ==="
  msiinfo export "$MSI" RemoveRegistry 2>/dev/null || echo "(no RemoveRegistry)"
  echo
  echo "=== Environment ==="
  msiinfo export "$MSI" Environment 2>/dev/null || echo "(no Environment)"
  ;;

strings)
  echo "=== Interesting strings from MSI ==="
  strings -n 8 "$MSI" | grep -iE '(http|https|ftp|powershell|cmd\.exe|curl|wget|invoke|download|screenconnect|connectwise|prxy|relay|agent|register|token|password|encode|base64|bypass|hidden|noprofile|exec|iex|msiexec|script|wscript|cscript)' | sort -u | head -500
  echo
  echo "=== URLs ==="
  strings "$MSI" | grep -oE 'https?://[^ "><]+' | sort -u | head -100
  echo
  echo "=== All PE files in extracted ==="
  find extracted extracted-7z -type f 2>/dev/null | while read f; do
    head -c2 "$f" 2>/dev/null | grep -qP 'MZ' && echo "PE: $f" || true
  done
  echo
  echo "=== Interesting strings from extracted PEs ==="
  find extracted extracted-7z -type f 2>/dev/null | while read f; do
    head -c2 "$f" 2>/dev/null | grep -qP 'MZ' || continue
    hits=$(strings -n 8 "$f" | grep -ciE '(screenconnect|connectwise|prxy|relay|agent|register|curl|powershell|base64|invoke|download)' || true)
    if [ "$hits" -gt 0 ]; then
      echo
      echo "--- $f ($hits hits) ---"
      strings -n 8 "$f" | grep -iE '(screenconnect|connectwise|prxy|relay|agent|register|curl|powershell|base64|invoke|download)' | sort -u | head -50
    fi
  done
  echo
  echo "=== PowerShell / script content ==="
  find extracted extracted-7z -type f \( -name '*.ps1' -o -name '*.bat' -o -name '*.cmd' -o -name '*.vbs' -o -name '*.js' \) 2>/dev/null | while read f; do
    echo "--- $f ---"
    cat "$f" | head -200
    echo
  done
  ;;

signature)
  echo "=== MSI digital signature ==="
  osslsigncode verify -in "$MSI" 2>&1 || true
  echo
  echo "=== Signature extraction ==="
  osslsigncode extract-signature -in "$MSI" -out results/msi-sig.pem 2>&1 || true
  if [ -f results/msi-sig.pem ]; then
    echo
    echo "=== Certificate details ==="
    openssl pkcs7 -in results/msi-sig.pem -inform DER -print_certs -text 2>/dev/null | head -100 || true
  fi
  echo
  echo "=== Extracted PE signatures ==="
  find extracted extracted-7z -type f 2>/dev/null | while read f; do
    head -c2 "$f" 2>/dev/null | grep -qP 'MZ' || continue
    sig=$(osslsigncode verify -in "$f" 2>&1 || true)
    if echo "$sig" | grep -q 'Signature verification'; then
      echo
      echo "--- $f ---"
      echo "$sig" | grep -E '(Subject:|Signature verification|Signing time)' | head -5
    fi
  done
  ;;

binaries)
  echo "=== Extracting Binary table streams ==="
  msiinfo export "$MSI" Binary 2>/dev/null | tail -n+4 | while IFS=$'\t' read -r name rest; do
    [ -z "$name" ] && continue
    echo "Binary: $name"
    # msiextract puts Binary streams in a specific way, try msidump approach
  done
  echo
  echo "=== Using 7z to find CAB streams ==="
  find extracted-7z -type f -name '*.cab' 2>/dev/null | while read cab; do
    echo "--- CAB: $cab ---"
    cabextract -l "$cab" 2>&1 | head -30 || true
    mkdir -p "binaries/$(basename "$cab" .cab)"
    cabextract -d "binaries/$(basename "$cab" .cab)" "$cab" 2>&1 || true
  done
  echo
  echo "=== Binary streams from 7z extraction ==="
  find extracted-7z binaries -type f 2>/dev/null | while read f; do
    sz=$(stat -c%s "$f" 2>/dev/null || echo 0)
    tp=$(file -b "$f" 2>/dev/null | head -c80)
    printf "%-70s %8d  %s\n" "$f" "$sz" "$tp"
  done
  echo
  echo "=== Decoded PowerShell from CustomAction (if base64) ==="
  msiinfo export "$MSI" CustomAction 2>/dev/null | grep -i 'encodedcommand\|base64\|powershell' | while read -r line; do
    echo "Raw: $line"
    b64=$(echo "$line" | grep -oP '(?<=-EncodedCommand\s)[A-Za-z0-9+/=]+' || true)
    if [ -n "$b64" ]; then
      echo "Decoded:"
      echo "$b64" | base64 -d 2>/dev/null | iconv -f utf-16le -t utf-8 2>/dev/null || echo "(decode failed)"
    fi
    echo
  done
  echo
  echo "=== Looking for embedded scripts in Binary table blobs ==="
  find extracted-7z -type f 2>/dev/null | while read f; do
    tp=$(file -b "$f" 2>/dev/null)
    case "$tp" in
      *ASCII*|*UTF*|*script*|*text*)
        echo "--- TEXT: $f ---"
        head -100 "$f"
        echo
        ;;
      *CAB*|*cabinet*)
        echo "--- NESTED CAB: $f ---"
        cabextract -l "$f" 2>&1 | head -20 || true
        ;;
    esac
  done
  ;;

*)
  echo "Usage: $0 {info|tables|extract|actions|registry|strings|signature|binaries} <msi-file>"
  exit 1
  ;;
esac
