#!/usr/bin/env bash
#
# download.bash — download a file from a URL and store it at a target location.

set -euo pipefail

download_file() {
  local url=$1
  local target=$2

  if [[ -z "${url}" || -z "${target}" ]]; then
    echo "Usage: $(basename "$0") <url> <target>" >&2
    return 1
  fi

  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "${url}" -o "${target}"
  elif command -v wget >/dev/null 2>&1; then
    wget -q -O "${target}" "${url}"
  else
    echo "Error: neither curl nor wget is available" >&2
    return 1
  fi
}

main() {
  download_file "$@"
}

main "$@"
