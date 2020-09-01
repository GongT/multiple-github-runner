#!/usr/bin/env bash

set -Eeuo pipefail

cd "$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
cd ..

declare -xr SRC_ROOT=$(pwd)
declare -xr CONFIG_ROOT="/etc/github-runners"

function die() {
	echo "$*" >&2
	exit 1
}

function foreach_project() {
	local CB=$1 i

	pushd "$CONFIG_ROOT" &> /dev/null || return 0
	for i in */.runner; do
		local NAME=$(basename "$(dirname "$i")")
		"$CB" "$NAME"
	done
	popd &> /dev/null
}

function select_config() {
	local -A SELECTIONS=()
	local -i INDEX=1

	_prep() {
		SELECTIONS[$INDEX]=$NAME
		echo -e "  \e[38;5;14m$INDEX\e[0m: $NAME" >&2
		INDEX="$INDEX + 1"
	}

	foreach_project _prep

	local SELECTION=-1
	while true; do
		read -e -r -p "select by index> " SELECTION
		if [[ "${SELECTIONS[$SELECTION]+found}" = found ]]; then
			break
		else
			echo "invalid selection." >&2
		fi
	done
	NAME="${SELECTIONS[$SELECTION]}"
}
