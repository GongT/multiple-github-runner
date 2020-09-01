#!/usr/bin/env bash

set -Eeuo pipefail

source "$(dirname "$(realpath "${BASH_SOURCE[0]}")")/lib/functions.sh"
MY_ARGS=("$@")

if ! [[ -f "runner-release/config.sh" ]]; then
	die "You must unzip runner release to 'runner-release' folder"
fi
if [[ -f "runner-release/.credentials" ]]; then
	die "You must have CLEAN runner program files 'runner-release' folder, but it already configured."
fi

mkdir -p "$CONFIG_ROOT"
declare -xr TEMP_TEMP=$(mktemp --directory)
MOUNTS=()

function _handle_exit() {
	set +Ee
	# set +x
	cd /
	for I in "${MOUNTS[@]}"; do
		if mountpoint "$I" &> /dev/null; then
			echo "cleanup: umount $I"
			umount "$I"
		fi
		echo "cleanup: remove directory $I"
		rm -rf "$I"
	done
}
trap "_handle_exit" EXIT

function do_mount() {
	local CONFIG_CONTENTS_ROOT="$1"

	mkdir -p "$CONFIG_CONTENTS_ROOT.workdir"
	MOUNTS+=("$CONFIG_CONTENTS_ROOT.workdir")

	local MOUNT_ARGS=(
		-o
		"lowerdir=$SRC_ROOT/runner-release,upperdir=$CONFIG_CONTENTS_ROOT,workdir=$CONFIG_CONTENTS_ROOT.workdir"
		"$TEMP_TEMP"
	)

	if grep -q overlayfs /proc/filesystems; then
		echo "mount overlayfs..."
		mount -t overlayfs overlayfs "${MOUNT_ARGS[@]}"
	elif grep -q overlay /proc/filesystems; then
		echo "mount overlay..."
		mount -t overlay overlay "${MOUNT_ARGS[@]}"
	elif command -v fuse-overlayfs &> /dev/null; then
		echo "mount fuse-overlayfs..."
		fuse-overlayfs "${MOUNT_ARGS[@]}"
	else
		die "can not mount overlay filesystem, please install some support package."
	fi
	MOUNTS+=("$TEMP_TEMP")
}
function exec_configsh() {
	unshare --user "--wd=$TEMP_TEMP" "$TEMP_TEMP/config.sh" "${@}"
}

function setup() {
	local -r IS_REMOVE=
	declare -xr TEMP_CONFIG=$(mktemp --directory)

	do_mount "$TEMP_CONFIG"

	exec_configsh "$@" --work "$(mktemp -u)" --replace

	NAME=$(cat "$TEMP_CONFIG/.runner" | grep gitHubUrl | grep -oE 'github.com/[^"]*' | sed 's#github\.com/##g' | sed 's#/#@#g')
	if [[ ! "$NAME" ]]; then
		die "Something went wrong. gitHubUrl should exists, but not found."
	fi

	CFG_DIR="$CONFIG_ROOT/$NAME"
	if [[ -e "$CFG_DIR" ]]; then
		echo -e "\e[38;5;9mWARN: config file will be overwrite: $CFG_DIR\e[0m"
	fi

	cp -r -T "$TEMP_CONFIG" "$CFG_DIR"
	chown -R root:root "$CFG_DIR"

	bash "$SRC_ROOT/service.sh" install-if-not

	systemctl --quiet enable "github-actions@$NAME.service"
	echo -e "\e[38;5;10mSystem service install and enabled: github-actions@$NAME.service\e[0m (but you need start it this time)"
}
function cleanup() {
	declare -r IS_REMOVE=yes
	MY_ARGS=(remove)

	do_mount "$CONFIG_ROOT/$NAME"

	exec_configsh remove
}

if [[ "${1+found}" = found ]] && [[ "$1" = remove ]]; then
	shift
	if [[ "${1+found}" = found ]]; then
		NAME=$1
	else
		echo "Select which to remove:"
		select_config
	fi
	cleanup "$NAME"
else
	setup "$@"
fi
