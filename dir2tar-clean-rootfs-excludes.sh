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
./var/www/*
./root/c11n
./root/yar-data
./home-in-root
./home_in_root
./home/*/.cache*
./home/*/_cache*
./home/*/.local/share/Trash
./home/*/.trash*
./home/*/_trash*
./home/*/.backup*
./home/*/backup*
./home/*/.яяbackup*
./home/*/яяbackup*
./home/*/.bak
./home/*/bak
./home/*/.thumbnails
./home/*/.config/gsmartcontrol
./home/*/.config/smplayer/file_settings
./home/*/.kde/share/apps/okular/docdata
./home/*/.local/share/meld
./home/*/.nv
./home/*/.dropbox*
./home/*/Dropbox
./home/*/.yandex
./home/*/.config/yandex-disk
./home/*/Yandex.Disk
./home/*/.config/syncthing
./home/*/Sync
./home/*/things*
./home/*/Videos/*
./home/*/Documents/*
./home/*/Downloads/*
./home/*/Pictures/*
./home/*/Music/*
./home/*/Public/*
./home/*/Templates/*
./home/*/Видео/*
./home/*/Документы/*
./home/*/Загрузки/*
./home/*/Изображения/*
./home/*/Картинки/*
./home/*/Музыка/*
./home/*/Общедоступные/*
./home/*/Шаблоны/*
./home/*/Личное
./home/*/личное
./home/*/Личная
./home/*/личная
./home/*/work
./home/*/distrib
./home/*/p
./home/*/d
./home/*/vms
./home/*/VirtualBox\ VMs
./home/*/nspawn*
./home/*/snap
./home/*/apps/archive
./home/*/.ssh*
./home/*/.recoll*
./home/*/.stardict
./home/*/.goldendict
./home/*/.icedove*
./home/*/.thunderbird*
./home/*/.mozilla*
EOF

scriptdir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

echo "$excluded" | \
    "$scriptdir/dir2tar.sh" "$dir" "$id"
