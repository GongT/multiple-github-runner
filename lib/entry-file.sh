#!/usr/bin/env bash

set -Eeuo pipefail

die() {
	echo "$*" >&2
	exit 1
}

mkdir -p "$RUNTIME_DIRECTORY/upper"
mkdir -p "$RUNTIME_DIRECTORY/work"

TMP_WD=/tmp/wd
mkdir -p "$TMP_WD"

MOUNT_ARGS=(
	-o
	"lowerdir=$SRC_ROOT/runner-release:$CONFIGURATION_DIRECTORY,upperdir=$RUNTIME_DIRECTORY/upper,workdir=$RUNTIME_DIRECTORY/work"
	"$TMP_WD"
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

cd "$TMP_WD"
mkdir -p "./_diag"
mount --bind "$LOGS_DIRECTORY" "./_diag"

sed -i 's#"workFolder": "[^"]*"#"workFolder": "__WORK_PATH__"#g' .runner
sed -i "s#__WORK_PATH__#$STATE_DIRECTORY#g" .runner

if [[ -e .env ]]; then
	{
		echo "[ENV] ============="
		cat .env
		echo "[ENV] ============="
	} >&2
fi

export HOME="$STATE_DIRECTORY/_home"
mkdir -p "$HOME"

exec ./bin/runsvc.sh
