#!/bin/bash

dir=${1:?directory name is required}
id=${2:?image id is required}
# dir=/home/user
# id=home-user

read -d '' excluded <<"EOF"
./lost\+found
./.cache
./.trash*
./_trash*
./.thumbnails
./.config/smplayer/file_settings
./.kde/share/apps/okular/docdata
./.local/share/meld
./.nv
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
./work
./distrib
./p
./d
./vms
./nspawn*
./apps/archive/
./.stardict
./.goldendict
./.icedove
./.thunderbird
./.mozilla
EOF

scriptdir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

echo "$excluded" | \
    "$scriptdir/dir2tar.sh" "$dir" "$id"
