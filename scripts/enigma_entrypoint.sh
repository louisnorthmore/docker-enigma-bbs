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
    #  Seed the config volume: config.hjson + generated menus must exist for the
    #  BBS to boot. Other volumes (mods/art) are copied only when empty.
    if [ -f "$BBS_STAGING_PATH/config/$CONFIG_NAME" ]; then
        cp -p $BBS_STAGING_PATH/config/$CONFIG_NAME $BBS_ROOT_DIR/config/
    fi
    if [ -d "$BBS_STAGING_PATH/config/menus" ]; then
        mkdir -p $BBS_ROOT_DIR/config/menus
        cp -rp $BBS_STAGING_PATH/config/menus/* $BBS_ROOT_DIR/config/menus/
    fi
    #  achievements.hjson ships in the staging config (the config PVC masks the
    #  image copy); seed it too so the achievements module works.
    cp -p $BBS_STAGING_PATH/config/achievements.hjson $BBS_ROOT_DIR/config/ 2>/dev/null || true
    for VOLUME in mods art
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

#  Ensure staged achievements.hjson is in the live config (idempotent for
#  already-seeded PVCs whose image copy is masked by the mount).
cp -p $BBS_STAGING_PATH/config/achievements.hjson $BBS_ROOT_DIR/config/achievements.hjson 2>/dev/null || true

#  CONNECT splash art is referenced by the generated login menus but ships in
#  no upstream theme; seed it into the live theme dir idempotently for PVCs
#  that were populated before this file existed.
if [ -f "$BBS_STAGING_PATH/art/themes/luciano_blocktronics/CONNECT.ANS" ]; then
    mkdir -p $BBS_ROOT_DIR/art/themes/luciano_blocktronics
    cp -p $BBS_STAGING_PATH/art/themes/luciano_blocktronics/CONNECT.ANS \
          $BBS_ROOT_DIR/art/themes/luciano_blocktronics/CONNECT.ANS \
        2>/dev/null || true
fi

#  Ensure the ftn_bso spool structure exists so the import watch/dirs work from
#  the first boot (BBS creates inbound dirs lazily, but the @watch: poller
#  throws ENOENT if the watched dir is absent at startup).
mkdir -p $BBS_ROOT_DIR/mail/ftn_in \
         $BBS_ROOT_DIR/mail/ftn_secin \
         $BBS_ROOT_DIR/mail/ftn_out \
         $BBS_ROOT_DIR/mail/reject

exec node main.js