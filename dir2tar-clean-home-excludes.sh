#!/bin/bash

dir=${1:?directory name is required}
id=${2:?image id is required}
# dir=/home/user
# id=home-user

read -d '' excluded <<"EOF"
*~
~$*
~WRL*.tmp
./lost\+found
./.cache*
./_cache*
./.local/share/Trash
./.trash*
./_trash*
./.backup*
./backup*
./.яяbackup*
./яяbackup*
./.bak
./bak
./.thumbnails
./.config/gsmartcontrol
./.config/smplayer/file_settings
./.kde/share/apps/okular/docdata
./.local/share/meld
./.nv
./.dropbox*
./Dropbox
./.yandex
./.config/yandex-disk
./Yandex.Disk
./.config/syncthing
./Sync
./things*
./Videos/*
./Documents/*
./Downloads/*
./Pictures/*
./Music/*
./Public/*
./Templates/*
./Видео/*
./Документы/*
./Загрузки/*
./Изображения/*
./Картинки/*
./Музыка/*
./Общедоступные/*
./Шаблоны/*
./Личное
./личное
./Личная
./личная
./work
./distrib
./p
./d
./shared/*
./vms
./VirtualBox\ VMs
./nspawn*
./snap
./apps/archive
./apps/firefox
./apps/thunderbird
./.ssh*
./.recoll*
./.stardict
./.goldendict
./.icedove*
./.thunderbird*
./.mozilla*
./*.png
EOF

scriptdir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

echo "$excluded" | \
    "$scriptdir/dir2tar.sh" "$dir" "$id"
