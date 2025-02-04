#!/usr/bin/env bash

if ! HASH="$(sha1sum tests/Dockerfile | cut -d ' ' -f 1)"; then
	echo "ERROR: could not create sha1sum for tests/Dockerfile" >&2
	exit 1
fi

BATS_IMAGE=bats:proxy-startup-tests-"$HASH"

if ! docker image inspect "${BATS_IMAGE}" >/dev/null 2>/dev/null; then
	if ! docker build -t "${BATS_IMAGE}" tests; then
		echo "ERROR: could not build docker image" >&2
		exit 1
	fi
fi

docker run --interactive --tty --rm \
	--mount "type=bind,source=$PWD,target=/code,readonly" \
	"${BATS_IMAGE}" tests
