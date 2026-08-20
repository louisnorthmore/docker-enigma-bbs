#!/usr/bin/env bash
set -e

# ENiGMA 1/2 - container entrypoint.
# Seeds the art/mods/config volumes from /enigma-bbs-pre on first boot (empty
# otherwise-mounted PVCs), then runs the BBS.

PRE_POPULATED_VOLUMES=("config" "mods" "art")
BBS_ROOT_DIR=/enigma-bbs
BBS_STAGING_PATH=/enigma-bbs-pre
CONFIG_NAME=config.hjson

if [[ ! -f $BBS_ROOT_DIR/config/$CONFIG_NAME ]]; then
    for VOLUME in "${PRE_POPULATED_VOLUMES[@]}"
    do
        if [ -d "$BBS_ROOT_DIR/$VOLUME" ] && [ -z "$(ls -A "$BBS_ROOT_DIR/$VOLUME" 2>/dev/null)" ]; then
            cp -rp $BBS_STAGING_PATH/$VOLUME/* $BBS_ROOT_DIR/$VOLUME/
            echo "INFO: seeded $BBS_ROOT_DIR/$VOLUME from staging"
        else
            echo "WARN: skipped $BBS_ROOT_DIR/$VOLUME: volume not empty -> files may be needed"
        fi
    done
fi

if [[ ! -f $BBS_ROOT_DIR/config/$CONFIG_NAME ]]; then
  echo "ERROR: Missing configuration - ENiGMA 1/2 will not work"
  exit 1
fi

exec node main.js