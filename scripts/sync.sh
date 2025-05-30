#!/bin/bash

source /env.sh

login=$LFTP_USER
pass=$LFTP_PASSWORD
host=sftp://$LFTP_HOST
base_remote_dir=$LFTP_REMOTE_DIR
base_local_dir=/lftp-sync/synced
parallel=${LFTP_PARALLEL:-4}

set -e

sync_dir() {
  echo "Syncing $base_remote_dir --> $base_local_dir"
  mkdir -p $base_local_dir

  lftp  << EOF
  set sftp:auto-confirm yes
  set mirror:use-pget-n 4
  lftp -u $login,$pass $host
  mirror -c -P4 --no-perms --dereference --Remove-source-files --log=/var/log/lftp.log -vvv $base_remote_dir $base_local_dir
  quit
EOF
  echo "sync_dir() done"
}

mv_files() {
  pushd /lftp-sync/synced
  find . -type f | while read file; do
    target="/lftp-sync/import/$file"
    mkdir -p "$(dirname "$target")"
    mv -n -v "$file" "$target"
  done
  popd
}

if [ -e /config/lftp-sync.lock ]; then
  echo "Sync is running already."
  exit 1
else
  touch /config/lftp-sync.lock
  trap "rm -f /config/lftp-sync.lock" EXIT

  echo "Sync Starting: $(date)"
  sync_dir
  echo "Sync Done: $(date)"

  echo "Moving files starting: $(date)"
  mv_files
  echo "Moving files done: $(date)"

  rm -f /config/lftp-sync.lock
  exit 0
fi