#!/usr/bin/env bash

set -Eeuo pipefail
cd "$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
cd ../runner-release

JSON=$(curl --silent "https://api.github.com/repos/actions/runner/releases/latest")

CURRENT_VER=$(echo "$JSON" | jq -r '.tag_name')
echo "Latest version: ${CURRENT_VER:1}"

if [[ -e ./bin/Runner.Listener ]]; then
	LOCAL_VER=$(./bin/Runner.Listener --version)
	echo "Installed version: $LOCAL_VER"
	if [[ "$LOCAL_VER" = "${CURRENT_VER:1}" ]]; then
		echo "update skip"
		exit 0
	fi
else
	echo "Installed version: never install"
fi

echo "New version released!"

URL=$(
	echo "$JSON" | jq -r '.assets[] | select(.name | contains("linux-x64") ) | .browser_download_url'
)

if [[ "${INVOCATION_ID:-}" ]]; then
	PARGS=(--verbose)
else
	PARGS=(--quiet --show-progress --progress=bar:force:noscroll)
fi

echo "Download file from $URL"
FILE="$CURRENT_VER.tar.gz"
if ! [[ -e "$FILE" ]]; then
	wget "${PARGS[@]}" -O "$FILE.downloading" --continue "$URL"
	mv "$FILE.downloading" "$FILE"
	echo "  download complete"
else
	echo "  already download"
fi

echo "Stop running server..."
systemctl stop github-actions@*.service || true

echo "Extract files..."
tar -xf "$FILE"

echo "Start all servers..."
systemctl start --all github-actions@*.service || true
