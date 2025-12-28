#!/bin/bash

dir=${1:?directory name is required}
id=${2:?image id is required}
# dir=/srv/nspawn/debian-9
# id=nspawn-debian-9

read -d '' excluded <<"EOF"
*~
~$*
~WRL*.tmp
./lost\+found
./swapfile
./media/*
./var/cache/apt/archives/*
./var/lib/snapd/cache/*
./var/log/journal/*
./boot/images/*
./srv/backups/*
./srv/nspawn/*
./srv/chroot/*
./srv/dc/*
./var/lib/docker/*
./root/yar-data
./home-in-root
./home_in_root
./home/*/.cache*
./home/*/var/*
EOF

scriptdir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

echo "$excluded" | \
    "$scriptdir/dir2tar.sh" "$dir" "$id"
