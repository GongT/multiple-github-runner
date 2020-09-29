#!/usr/bin/env bash

set -Eeuo pipefail

source "$(dirname "$(realpath "${BASH_SOURCE[0]}")")/lib/functions.sh"

SVC_FILE="/usr/lib/systemd/system/github-actions@.service"
SVC_FILE2="/usr/lib/systemd/system/github-actions-runner-updater.service"
SVC_FILE3="/usr/lib/systemd/system/github-actions-runner-updater.timer"
ENTRY_FILE="/usr/libexec/github-actions-entry.sh"
ENV_FILE="$CONFIG_ROOT/service.txt"

ARGS=()

COLLECTED_SERVICES=()
function collect() {
	local NAME=$1
	COLLECTED_SERVICES+=("github-actions@$NAME.service")
}

function install() {
	if [[ -e "$ENV_FILE" ]]; then
		sed -i "/^SRC_ROOT=/d" "$ENV_FILE"
		sed -i "/^$/d" "$ENV_FILE"
		if [[ "$(tail -1 "$CONFIG_ROOT/service.txt" | wc -l)" -eq 0 ]]; then
			echo >> "$ENV_FILE"
		fi
	fi
	echo "SRC_ROOT=$SRC_ROOT" >> "$ENV_FILE"

	echo "Create file: $SVC_FILE"
	cp "$SRC_ROOT/lib/github-actions@.service" "$SVC_FILE"

	echo "Create file: $SVC_FILE2"
	cp "$SRC_ROOT/lib/github-actions-runner-updater.service" "$SVC_FILE2"

	echo "Create file: $SVC_FILE3"
	cp "$SRC_ROOT/lib/github-actions-runner-updater.timer" "$SVC_FILE3"

	systemctl enable --now "$(basename "$SVC_FILE3")"
	systemctl daemon-reload
}

function uninstall() {
	echo "Delete file: $SVC_FILE"
	rm -f "$SVC_FILE"
	echo "Delete file: $SVC_FILE2"
	rm -f "$SVC_FILE2"
	echo "Delete file: $SVC_FILE3"
	rm -f "$SVC_FILE3"
	systemctl disable --now "$(basename "$SVC_FILE3")"
}

function rm_service() {
	local NAME=$1
	if systemctl is-enabled "github-actions@$NAME.service" &> /dev/null; then
		echo "Disable $NAME..."
		systemctl -q disable --now "github-actions@$NAME.service"
	else
		echo "$NAME: Already Disabled"
	fi
}
function en_service() {
	local NAME=$1
	if ! systemctl is-enabled "github-actions@$NAME.service" &> /dev/null; then
		echo "Enable $NAME..."
		systemctl -q enable "github-actions@$NAME.service"
	else
		echo "$NAME: Already enabled"
	fi
}

function should_not_empty() {
	if [[ $# -eq 0 ]]; then
		echo -e "\e[2mno service.\e[0m"
		exit 0
	fi
}

function usage() {
	echo "Usage: $0 <action>"
	echo "    install: install systemd service, enable all services."
	echo "    uninstall: remove systemd service, disable and stop all services."
	echo "    status: show status of each services."
	echo "    start: start all services."
	echo "    stop: stop all services."
	echo "    restart: restart all services."
	echo "    list: list all services."
	echo "    logs: display realtime log of all services."
}

if [[ "$#" -gt 0 ]]; then
	ACTION="$1"
	shift
else
	usage
	exit 0
fi

case "$ACTION" in
install)
	install
	foreach_project en_service
	;;
install-if-not)
	if ! [[ -e "$SVC_FILE" ]]; then
		install
	fi
	;;
uninstall)
	foreach_project rm_service
	uninstall
	;;
list)
	export SYSTEMD_COLORS=true
	ACTION='list-units'
	ARGS+=(--all --no-pager)
	;&
start | stop | status | restart)
	foreach_project collect
	should_not_empty "${ARGS[@]}"
	systemctl $ACTION "${ARGS[@]}" --no-pager "${COLLECTED_SERVICES[@]}"
	;;
logs)
	foreach_project collect
	for I in "${COLLECTED_SERVICES[@]}"; do
		ARGS+=(-u "$I")
	done
	journalctl -f "${ARGS[@]}"
	;;
*)
	echo "invalid action: $ACTION" >&2
	usage >&2
	exit 1
	;;
esac
