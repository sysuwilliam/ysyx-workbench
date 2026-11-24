#!/usr/bin/env bash
cd "$(dirname "$0")/.."

green=$'\033[1;32m'
cyan=$'\033[1;36m'
yellow=$'\033[1;33m'
reset=$'\033[0m'

./soc/obj_dir/VSimTop "$@" \
  > >(sed -u "s|^|${green}[out]${reset} |") \
  2> >(sed -u -e "s|^DBG|${yellow}DBG${reset}|" -e "s|^|${cyan}[sim]${reset} |" >&2)
