#!/bin/bash
#
#  tar2os - installing preconfigured linux instance from tar image
#
#  Copyright (C) 2014, 2015, 2016, 2017, 2021, 2022, 2023, 2024
#  Alexander Yermolenko <yaa.mbox@gmail.com>
#
#  This file is part of OSTAROS, a set of tools for creating images of
#  existing GNU/Linux installations and making new installations from
#  them.
#
#  OSTAROS is free software: you can redistribute it and/or modify it
#  under the terms of the GNU General Public License as published by
#  the Free Software Foundation, either version 3 of the License, or
#  (at your option) any later version.
#
#  OSTAROS is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with OSTAROS.  If not, see <http://www.gnu.org/licenses/>.
#

die()
{
    msg=${1:-"Unknown Error"}
    whiptail --title "Error" --msgbox "ERROR: $msg" 25 80
    echo "ERROR: $msg" 1>&2
    exit 1
}

goodbye()
{
    msg=${1:-"Cancelled by user"}
    whiptail --title "Goodbye!" --msgbox "$msg" 25 80
    echo "INFO: $msg" 1>&2
    exit 1
}

modal_info()
{
    local msg=${1:-"Info message"}
    whiptail \
        --title "Info" \
        --msgbox \
        "$msg" \
        25 80
}

modal_warning()
{
    local msg=${1:-"Warning message"}
    whiptail \
        --title "WARNING!" \
        --msgbox \
        "$msg" \
        25 80
}

require()
{
    local cmd=${1:?"Command name is required"}
    shift
    hash "$cmd" >/dev/null 2>&1 || die "$cmd not found! $@"
}

whiptail --version || die "whiptail not found"
parted --version || die "parted not found"
pv --version || die "pv not found"

declare -a menu

build_menu()
{
    menu=()
    for item in "$@"; do
        menu+=("$item" " ")
    done
}

build_devmenu()
{
    menu=()
    for item in "$@"; do
        details=$( get_dev_info $item )
        menu+=("$item" "$details")
    done
}

build_partmenu()
{
    menu=()
    for item in "$@"; do
        details=$( get_part_info $item )
        menu+=("$item" "$details")
    done
}

get_dev_info()
{
    DEVICE_BY_ID=$( get_devbyid_symlink $1 )
    DEVICE_ID_FULL=${DEVICE_BY_ID#/dev/disk/by-id/}
    DEVICE_ID=${DEVICE_ID_FULL:0:40}
    [ ! -z "$DEVICE_ID" -a "$DEVICE_ID" != " " ] || die "Can't get disk id"
    DEVICE_SIZE=$( parted -m -s -a optimal $1 print | grep "^$1" | awk -F':' '{print $2 }' )
    [ ! -z "$DEVICE_SIZE" -a "$DEVICE_SIZE" != " " ] || die "Can't get disk size"
    echo "$DEVICE_SIZE $DEVICE_ID"
}

get_part_info()
{
    parted -m -s -a optimal $1 print | grep "^$1" | awk -F':' '{print $2 }'
}

get_devbyid_symlink()
{
    find -L /dev/disk/by-id -samefile "$1" -print -quit
}

get_ram_size()
{
    MEM_SIZE=$(( $( awk '/MemTotal/{print $2}' /proc/meminfo ) / 1024 ))
    echo "$MEM_SIZE"
}

shopt -s nullglob

INSTALL_TAG=ubu

SEPARATE_HOME=1
BTRFS=0

EXTRA_MKFS_EXT4_OPTIONS=()
# EXTRA_MKFS_EXT4_OPTIONS+=( -O ^metadata_csum )

ENABLE_PROXY=0
PROXY_STRING="http://user:password@10.0.2.1:8080/"
PROXY_STRING="http://10.0.2.1:8080/"

system_proxy_setup()
{
    MNT_FSROOT="$1"

    [ ! -z "$MNT_FSROOT" -a "$MNT_FSROOT" != " " ] || die "Incorrect argument"
    [ ! -z "$PROXY_STRING" -a "$PROXY_STRING" != " " ] || die "Incorrect proxy settings"

    echo "Configuring system in $MNT_FSROOT for proxy usage"

    [ -e "$MNT_FSROOT/etc/profile.d/proxy.sh" ] && die "Previous proxy configuration detected (/etc/profile.d/proxy.sh)"
    [ -e "$MNT_FSROOT/etc/sudoers.d/proxy" ] && die "Previous proxy configuration detected (/etc/sudoers.d/proxy)"
    cat "$MNT_FSROOT/etc/environment" | grep -q "_proxy" && die "Previous proxy configuration detected (/etc/environment)"
    cat "$MNT_FSROOT/etc/rc.local" | grep -q "_proxy" && die "Previous proxy configuration detected (/etc/rc.local)"


    read -d '' proxy4profile <<EOF
export http_proxy="$PROXY_STRING"
export HTTP_PROXY="$PROXY_STRING"
export ftp_proxy="$PROXY_STRING"
export FTP_PROXY="$PROXY_STRING"
export https_proxy="$PROXY_STRING"
export HTTPS_PROXY="$PROXY_STRING"
export no_proxy="localhost,127.0.0.1"
export NO_PROXY="localhost,127.0.0.1"
EOF

    echo "$proxy4profile" > "$MNT_FSROOT/etc/profile.d/proxy.sh"


    read -d '' proxy4sudoers <<EOF
Defaults env_keep += "http_proxy https_proxy ftp_proxy no_proxy"
EOF

    echo "$proxy4sudoers" > "$MNT_FSROOT/etc/sudoers.d/proxy"

    chmod 0440 "$MNT_FSROOT/etc/sudoers.d/proxy"

    read -d '' proxy4environment <<EOF
http_proxy="$PROXY_STRING"
HTTP_PROXY="$PROXY_STRING"
ftp_proxy="$PROXY_STRING"
FTP_PROXY="$PROXY_STRING"
https_proxy="$PROXY_STRING"
HTTPS_PROXY="$PROXY_STRING"
no_proxy="localhost,127.0.0.1"
NO_PROXY="localhost,127.0.0.1"
EOF

    c=$( tail -c 1 "$MNT_FSROOT/etc/environment" )
    [ "$c" != "" ] && echo "" >> "$MNT_FSROOT/etc/environment"
    echo "$proxy4environment" >> "$MNT_FSROOT/etc/environment"


    read -d '' proxy4rclocal <<EOF
http_proxy="$PROXY_STRING" \\
ftp_proxy="$PROXY_STRING" \\
https_proxy="$PROXY_STRING" \\
no_proxy="localhost,127.0.0.1" \\
/usr/sbin/aptd -t >/dev/null 2>&1 &
EOF

    while read line
    do
        echo "$line" | grep -q "^exit 0"
        [ $? -eq 0 ] && echo "$proxy4rclocal" && echo ""
        echo "$line"
    done < "$MNT_FSROOT/etc/rc.local" > "$MNT_FSROOT/etc/rc.local-with-proxy"

    chmod a+x "$MNT_FSROOT/etc/rc.local-with-proxy"

    mv "$MNT_FSROOT/etc/rc.local" "$MNT_FSROOT/etc/rc.local.bak"
    mv "$MNT_FSROOT/etc/rc.local-with-proxy" "$MNT_FSROOT/etc/rc.local"


    read -d '' proxy4aptconfd <<EOF
Acquire::http::Proxy "$PROXY_STRING";
Acquire::ftp::Proxy "$PROXY_STRING";
Acquire::https::Proxy "$PROXY_STRING";
EOF

    echo "$proxy4aptconfd" > "$MNT_FSROOT/etc/apt/apt.conf.d/99proxy"
}

firefox_proxy_setup()
{
    MNT_FSHOME="$1"

    [ ! -z "$MNT_FSHOME" -a "$MNT_FSHOME" != " " ] || die "Incorrect argument"
    [ ! -z "$PROXY_STRING" -a "$PROXY_STRING" != " " ] || die "Incorrect proxy settings"

    echo "Configuring Firefox in $MNT_FSHOME for proxy usage"

    bs=$( date +%s )
    [ -e "$MNT_FSHOME/.mozilla-clean-with-proxy" ] || return 0
    [ -e "$MNT_FSHOME/.mozilla" ] && \
        mv "$MNT_FSHOME/.mozilla" "$MNT_FSHOME/.mozilla-backup-$bs" || die "Cannot backup Firefox profile"
    mv "$MNT_FSHOME/.mozilla-clean-with-proxy" "$MNT_FSHOME/.mozilla" || die "Cannot setup proxy in Firefox"
}

restore_file_capabilities()
{
    local getcap_output=${1:?"getcap output filename is required"}
    local fs_prefix=${2:?"fs prefix is required"}

    [ -f "$getcap_output" ] || die "Cannot find file capabilities info: $getcap_output"
    [ -d "$fs_prefix" ] || die "Target directory does not exist: $fs_prefix"

    echo "Restoring file capabilities from $getcap_output inside $fs_prefix"

    local files=()
    local cap_sets=()
    while IFS= read -r line || [[ -n "$line" ]]; do
        local file="${line%%[[:blank:]]*}"
        local cap_set="${line#*[[:blank:]]}"
        [[ -z "${cap_set// }" ]] && die "Capabilities info for file \"$file\" is empty"
        files+=("${file}")
        cap_sets+=("${cap_set}")
    done < "$getcap_output"

    for index in "${!files[@]}"; do
        local file="${files[$index]}"
        local cap_set="${cap_sets[$index]}"
        echo "Setting '$cap_set' on '$fs_prefix/$file'"
        setcap "$cap_set" "$fs_prefix/$file" || die "Cannot set capabilities on $fs_prefix/$file"
    done
}

# Force running in tty in case of autorun on SystemRescueCD
if [ "$0" = "/var/autorun/tmp/autorun" -a "$( hostname )" = "sysresccd" ]
then
    cp "$0" "/root/.sysresccd-autorun"
    echo "bash /root/.sysresccd-autorun" > "/root/.zlogin"
    # disable waiting for keypress
    touch "/etc/ar_nowait"
    exit 0
fi

echo "Welcome!"
whiptail \
    --title "Welcome to OSTAROS GNU/Linux installer!" \
    --msgbox \
    "Press OK (Enter) to start installation.\n\nНажмите ОК (Enter) для начала установки." \
    25 80

INSTALL_TAG=$( whiptail \
                   --title "Installation tag selection" \
                   --inputbox "Provide a short installation \"label\" for the system\n\nЗадайте короткую \"метку\" для системы\n\n[a-z0-9]*\n\nExample: ubu2204" \
                   25 80 \
                   "$INSTALL_TAG" \
                   3>&1 1>&2 2>&3 )

echo "INSTALL_TAG: $INSTALL_TAG"

whiptail \
    --title "Proxy setup" \
    --yesno \
    "Configure this PC to use proxy server (10.0.2.1:8080)?\n\nНастроить этот ПК для использования прокси-сервера (10.0.2.1:8080)?" \
    25 80
if [ $? -eq 0 ]
then
    ENABLE_PROXY=1
fi

# Select image

echo "Found images:"
images=({/livemnt/boot/,/run/archiso/bootmnt/,/mnt/flash/,/mnt/,/mnt/r/mnt/flash/}{tarred/,.clones/tarred/}*)
echo "${images[@]}"

while true
do
    if [ ! ${#images[@]} -eq 1 ]
    then
        build_menu "${images[@]}"
        [ ! ${#menu[@]} -eq 0 ] || die "No appropriate image found."
        IMGDIR=$( whiptail \
                      --title "Image selection" \
                      --menu "Select an image to install" \
                      25 80 15 \
                      "${menu[@]}" \
                      3>&1 1>&2 2>&3 )
        [ ! $? -eq 0 ] && goodbye
    else
        IMGDIR=${images[0]}
    fi
    [ ! -z "$IMGDIR" -a "$IMGDIR" != " " ] || die "Wrong image"
    echo "Selected image: $IMGDIR"

    MEM_SIZE=$( get_ram_size )

    if [ $MEM_SIZE -gt 400 -a -z "${IMGDIR##*12.04*}" ]
    then
        whiptail \
            --title "Are you sure?" \
            --yesno \
            "This PC has a lot of RAM ($MEM_SIZE MB).\nBut you have selected old distribution (12.04).\nDo you really want to install this old operating system version?\n\nНа компьютере достаточно много оперативной памяти ($MEM_SIZE MB).\nОднако, Вы выбрали старую версию дистрибутива (12.04).\nВы уверены, что хотите установить эту старую версию операционной системы?" \
            25 80
        [ ! $? -eq 0 ] && continue
    fi

    break
done

partprobe

# Select device

echo "Found devices:"
devices=(/dev/sd[a-z])
echo "${devices[@]}"

if [ ${#devices[@]} -eq 0 ]
then
    devices+=( $( whiptail \
                      --title "Device selection" \
                      --inputbox "Provide a device to install the system to\n\nВыберите диск, на который будет производиться установка" \
                      25 80 \
                      "/dev/sdX" \
                      3>&1 1>&2 2>&3 ) )
fi

if [ ! ${#devices[@]} -eq 1 ]
then
    build_devmenu "${devices[@]}"
    [ ! ${#menu[@]} -eq 0 ] || die "No appropriate device found."
    DEVICE=$( whiptail \
        --title "Device selection" \
        --menu "Select a device to install the system to\n\nВыберите жёсткий диск, на который будет производиться установка" \
        25 80 15 \
        "${menu[@]}" \
        3>&1 1>&2 2>&3 )
    [ ! $? -eq 0 ] && goodbye
else
    DEVICE=${devices[0]}
fi
[ ! -z "$DEVICE" -a "$DEVICE" != " " ] || die "Wrong device"
echo "Selected device: $DEVICE"

# Partitioning

whiptail \
    --title "Partitioning method" \
    --yesno \
    --defaultno \
    "Do you want to do manual partitioning?\n\nХотите провести разметку диска самостоятельно?" \
    25 80
if [ $? -eq 0 ]
then
    echo "Performing manual partitioning."

    whiptail \
        --title "Separate home partition" \
        --yesno \
        "Place /home on a separate partition?" \
        25 80
    [ ! $? -eq 0 ] && SEPARATE_HOME=0

    build_menu "cfdisk" "fdisk" "parted"
    tool=$( whiptail \
        --title "Partitioning tool selection" \
        --menu "Select a tool to do manual partitioning\n\nВыберите утилиту для разметки диска" \
        25 80 15 "${menu[@]}" \
        3>&1 1>&2 2>&3 )
    [ ! $? -eq 0 ] && goodbye
    [ ! -z "$tool" -a "$tool" != " " ] || die "Wrong tool"
    echo "Selected tool: $tool"

    $tool $DEVICE || die "manual partitioning failed"

    partprobe

    # TODO: List non-windows partitions only
    echo "Available partitions on $DEVICE:"
    parts=($DEVICE[1-9])
    echo "${parts[@]}"

    build_partmenu "${parts[@]}"
    [ ! ${#menu[@]} -eq 0 ] || die "No appropriate partition found."
    PARTROOT=$( whiptail \
        --title "Root partition selection" \
        --menu "Select a / (ROOT) partition\n\nВыберите раздел для / (ROOT)" \
        25 80 15 \
        "${menu[@]}" \
        3>&1 1>&2 2>&3 )
    [ ! $? -eq 0 ] && goodbye
    [ ! -z "$PARTROOT" -a "$PARTROOT" != " " ] || die "Wrong partition"
    echo "Selected / partition: $PARTROOT"
    parts=( $( for item in ${parts[@]}; do [ "$item" != "$PARTROOT" ] && echo $item; done ) )

    if [ $SEPARATE_HOME -eq 1 ]
    then
        build_partmenu "${parts[@]}"
        [ ! ${#menu[@]} -eq 0 ] || die "No appropriate partitions found."
        PARTHOME=$( whiptail \
            --title "Home partition selection" \
            --menu "Select a /home partition\n\nВыберите раздел для /home" \
            25 80 15 \
            "${menu[@]}" \
            3>&1 1>&2 2>&3 )
        [ ! $? -eq 0 ] && goodbye
        [ ! -z "$PARTHOME" -a "$PARTHOME" != " " ] || die "Wrong partition"
        echo "Selected /home partition: $PARTHOME"
        parts=( $( for item in ${parts[@]}; do [ "$item" != "$PARTHOME" ] && echo $item; done ) )
    else
        PARTHOME=none
    fi

    build_partmenu "${parts[@]}"
    [ ! ${#menu[@]} -eq 0 ] || die "No appropriate partitions found."
    PARTSWAP=$( whiptail \
        --title "Swap partition selection" \
        --menu "Select a swap partition\n\nВыберите swap-раздел" \
        25 80 15 \
        "${menu[@]}" \
        3>&1 1>&2 2>&3 )
    [ ! $? -eq 0 ] && goodbye
    [ ! -z "$PARTSWAP" -a "$PARTSWAP" != " " ] || die "Wrong partition"
    echo "Selected swap partition: $PARTSWAP"
    parts=( $( for item in ${parts[@]}; do [ "$item" != "$PARTSWAP" ] && echo $item; done ) )

else
    echo "Perfroming automatic partitioning."

    MEM_SIZE=$( get_ram_size )

    DISK_SIZE_WITH_SUFFIX=$( parted -s -m $DEVICE unit MB print free | grep "^$DEVICE" | tail -n 1 | awk -F':' '{print $2 }' )

    DISK_SIZE=${DISK_SIZE_WITH_SUFFIX:0:-2}


    SWAP_SIZE=$(( $MEM_SIZE * 2 ))
    [ $SWAP_SIZE -lt 512 ] && SWAP_SIZE=512
    SWAP_PERCENT=$(( $SWAP_SIZE * 100 / $DISK_SIZE ))

    [ $SWAP_PERCENT -lt 1 ] && SWAP_PERCENT=1
    SWAP_SIZE=$(( $DISK_SIZE * $SWAP_PERCENT / 100 ))

    [ $SWAP_SIZE -lt $(( $MEM_SIZE * 2 )) ] && SWAP_PERCENT=$(( $SWAP_PERCENT + 1 ))
    SWAP_SIZE=$(( $DISK_SIZE * $SWAP_PERCENT / 100 ))

    [ $SWAP_SIZE -lt $(( $MEM_SIZE * 2 )) ] && die "Automatic partitioning failed. Rerun installer and try to perform manual partitioning."

    DISK_SIZE_WO_SWAP=$(( $DISK_SIZE - $SWAP_SIZE ))
    [ $DISK_SIZE_WO_SWAP -lt 30000 ] && SEPARATE_HOME=0


    if [ $SEPARATE_HOME -eq 1 ]
    then
        ROOT_PERCENT=$(( ( 100 - $SWAP_PERCENT ) / 3 ))
        ROOT_SIZE=$(( $DISK_SIZE * $ROOT_PERCENT / 100 ))
        [ $ROOT_SIZE -gt 100000 ] && ROOT_SIZE=100000
        ROOT_PERCENT=$(( $ROOT_SIZE * 100 / $DISK_SIZE ))

        [ $ROOT_PERCENT -lt 1 ] && ROOT_PERCENT=1
        ROOT_SIZE=$(( $DISK_SIZE * $ROOT_PERCENT / 100 ))

        HOME_PERCENT=$(( 100 - $SWAP_PERCENT -$ROOT_PERCENT ))
        HOME_SIZE=$(( $DISK_SIZE * $HOME_PERCENT / 100 ))

        [ $HOME_PERCENT -lt 50 ] && die "Automatic partitioning failed. Rerun installer and try to perform manual partitioning."
    else
        ROOT_PERCENT=$(( ( 100 - $SWAP_PERCENT ) ))
        ROOT_SIZE=$(( $DISK_SIZE * $ROOT_PERCENT / 100 ))

        [ $ROOT_PERCENT -lt 1 ] && ROOT_PERCENT=1
        ROOT_SIZE=$(( $DISK_SIZE * $ROOT_PERCENT / 100 ))

        [ $ROOT_SIZE -lt 3000 ] && die "Automatic partitioning failed. Rerun installer and try to perform manual partitioning."
    fi

    echo "Mem size: $MEM_SIZE"
    echo "Disk size: $DISK_SIZE_WITH_SUFFIX"
    echo "Disk size: $DISK_SIZE"
    echo "Swap size: $SWAP_SIZE"
    echo "Disk size w/o swap: $DISK_SIZE_WO_SWAP"
    echo "======"
    echo "root: $ROOT_SIZE MB ( $ROOT_PERCENT % )"
    if [ $SEPARATE_HOME -eq 1 ]
    then
        echo "home: $HOME_SIZE MB ( $HOME_PERCENT % )"
    fi
    echo "swap: $SWAP_SIZE MB ( $SWAP_PERCENT % )"

    whiptail \
        --title "Confirmation" \
        --yes-button "Continue" \
        --no-button "Abort" \
        --yesno \
        "I am going to *ERASE* the disk contents *NOW*\n\nЯ собираюсь *УНИЧТОЖИТЬ* данные на выбранном диске *СЕЙЧАС*" \
    25 80
    [ ! $? -eq 0 ] && echo "Aborted by user." && exit 1

    echo "Erasing disk contents"
    parted -s -a optimal $DEVICE mklabel msdos || die "automatic partitioning failed"

    if [ $SEPARATE_HOME -eq 1 ]
    then
        ROOT_PLUS_HOME_PERCENT=$(( $ROOT_PERCENT + $HOME_PERCENT ))
        parted -s -a optimal $DEVICE mkpart primary "0%" "$ROOT_PERCENT%" || die "automatic partitioning failed"
        parted -s -a optimal $DEVICE mkpart extended "$ROOT_PERCENT%" "100%" || die "automatic partitioning failed"
        parted -s -a optimal $DEVICE mkpart logical "$ROOT_PERCENT%" "$ROOT_PLUS_HOME_PERCENT%" || die "automatic partitioning failed"
        parted -s -a optimal $DEVICE mkpart logical linux-swap "$ROOT_PLUS_HOME_PERCENT%" "100%" || die "automatic partitioning failed"

        PARTROOT="$DEVICE"1
        PARTHOME="$DEVICE"5
        PARTSWAP="$DEVICE"6
    else
        parted -s -a optimal $DEVICE mkpart primary "0%" "$ROOT_PERCENT%" || die "automatic partitioning failed"
        parted -s -a optimal $DEVICE mkpart extended "$ROOT_PERCENT%" "100%" || die "automatic partitioning failed"
        parted -s -a optimal $DEVICE mkpart logical linux-swap "$ROOT_PERCENT%" "100%" || die "automatic partitioning failed"

        PARTROOT="$DEVICE"1
        PARTHOME=none
        PARTSWAP="$DEVICE"5
    fi

fi

partprobe

[ -e "$PARTROOT" ] || die "root preparation failed"
[ -e "$PARTSWAP" ] || die "swap preparation failed"
if [ $SEPARATE_HOME -eq 1 ]
then
    [ -e "$PARTHOME" ] || die "home preparation failed"
fi

#$( parted -m -s -a optimal $PARTSWAP print | tail -n 1 | awk -F':' '{print $2 }' )

PARTROOT_INFO=$( get_part_info $PARTROOT )
PARTSWAP_INFO=$( get_part_info $PARTSWAP )

if [ $SEPARATE_HOME -eq 1 ]
then
    PARTHOME_INFO=$( get_part_info $PARTHOME )
else
    PARTHOME_INFO="N/A"
fi

whiptail \
    --title "Confirmation" \
    --yes-button "Continue" \
    --no-button "Abort" \
    --yesno \
    "I am going to format these partitions NOW:\nЯ отформатирую эти разделы СЕЙЧАС:\n\n
 /     partition : $PARTROOT ( $PARTROOT_INFO )
 /home partition : $PARTHOME ( $PARTHOME_INFO )
 swap  partition : $PARTSWAP ( $PARTSWAP_INFO )
\n\n
This will take some time.\nЭто займёт некоторое время." \
    25 80
[ ! $? -eq 0 ] && echo "Aborted by user." && exit 1

mkswap $PARTSWAP || die "format swap failed"
swapon $PARTSWAP || die "turning swap on failed"

if [ $BTRFS -eq 1 ]
then
    mkfs.btrfs -f -L "$INSTALL_TAG"root $PARTROOT || die "format root failed"
else
    mkfs.ext4 "${EXTRA_MKFS_EXT4_OPTIONS[@]}" -L "$INSTALL_TAG"root $PARTROOT || die "format root failed"
fi

mkdir /mnt/fsroot || die "fsroot mount point creation failed"
if [ $BTRFS -eq 1 ]
then
    mount -o compress,ssd,discard $PARTROOT /mnt/fsroot || die "fsroot mount failed"
#    btrfs fi balance start -dusage=5 /mnt/fsroot || die "btrfs balancing failed"
else
    mount $PARTROOT /mnt/fsroot || die "fsroot mount failed"
fi

echo "Extracting / contents"

pv --force "$IMGDIR/fs_root.tar.gz" | \
    tar x --numeric-owner \
    -C /mnt/fsroot \
    -z \
    -f - \
    || die "/ unpacking failed"

[ -f "$IMGDIR/fs_root.files-with-caps" ] && \
    restore_file_capabilities "$IMGDIR/fs_root.files-with-caps" /mnt/fsroot

if [ $SEPARATE_HOME -eq 1 ]
then
    mkfs.ext4 "${EXTRA_MKFS_EXT4_OPTIONS[@]}" -L "$INSTALL_TAG"home $PARTHOME || die "format home failed"
    mount $PARTHOME /mnt/fsroot/home || die "fshome mount failed"
fi

echo "Extracting /home contents"

pv --force "$IMGDIR/fs_home.tar.gz" | \
    tar x --numeric-owner \
    -C /mnt/fsroot/home \
    -z \
    -f - \
    || die "/home unpacking failed"

[ -f "$IMGDIR/fs_home.files-with-caps" ] && \
    restore_file_capabilities "$IMGDIR/fs_home.files-with-caps" /mnt/fsroot/home

SWAP_UUID=$( blkid -s UUID -o value $PARTSWAP )
[ ! -z "$SWAP_UUID" -a "$SWAP_UUID" != " " ] || die "Can't get SWAP UUID"

if [ $SEPARATE_HOME -eq 1 ]
then
    HOME_UUID=$( blkid -s UUID -o value $PARTHOME )
    [ ! -z "$HOME_UUID" -a "$HOME_UUID" != " " ] || die "Can't get HOME UUID"
fi

ROOT_UUID=$( blkid -s UUID -o value $PARTROOT )
[ ! -z "$ROOT_UUID" -a "$ROOT_UUID" != " " ] || die "Can't get ROOT UUID"

CONF_FILE=/mnt/fsroot/etc/initramfs-tools/conf.d/resume
[ -f "$CONF_FILE" ] || \
    echo "RESUME=UUID=xyz" > "$CONF_FILE"
sed -i "s/UUID=.*/UUID=$SWAP_UUID/g" $CONF_FILE \
    || die "resume partition info update failed"

CONF_FILE=/mnt/fsroot/etc/fstab
[ -f "$CONF_FILE" ] \
    || die "Target fstab does not exist"
grep -q 'UUID=.*[[:blank:]]\+none[[:blank:]]\+swap' "$CONF_FILE" \
    || echo "UUID=xyz none            swap    sw              0       0" >> "$CONF_FILE"
sed -i "s/UUID=.* none /UUID=$SWAP_UUID none /g" $CONF_FILE \
    || die "swap partition info update failed"

sed -i "s/UUID=.* \/ /UUID=$ROOT_UUID \/ "/g $CONF_FILE \
    || die "/ partition info update failed"
if [ $BTRFS -eq 1 ]
then
    sed -i "s/ \/               ext4    noatime,errors=remount-ro"/" \/               btrfs   compress,noatime,ssd,discard"/g $CONF_FILE \
        || die "/ partition btrfs info update failed"
fi

if [ $SEPARATE_HOME -eq 1 ]
then
    sed -i "s/UUID=.* \/home /UUID=$HOME_UUID \/home /g" $CONF_FILE \
    || die "/home partition info update failed"
else
    sed -i "s/UUID=.* \/home /\#UUID=xyz \/home /g" $CONF_FILE \
    || die "/home partition disabling failed"
fi

# prepare chroot in /mnt/fsroot
for i in /dev /dev/pts /proc /sys /run; do
    mount -B $i /mnt/fsroot$i || die "mount /mnt/fsroot$i failed"
done

#chroot /mnt/fsroot grub-install $DEVICE || die "grub-install failed"

if [ ! ${#devices[@]} -eq 1 ]
then
    chroot /mnt/fsroot dpkg-reconfigure grub-pc || die "dpkg-reconfigure grub-pc failed"
else
    DEVICE_BY_ID=$( get_devbyid_symlink $DEVICE )
    [ ! -z "$DEVICE_BY_ID" -a "$DEVICE_BY_ID" != " " ] || DEVICE_BY_ID=$DEVICE
    [ ! -z "$DEVICE_BY_ID" -a "$DEVICE_BY_ID" != " " ] || die "Device is invalid"
    chroot /mnt/fsroot /bin/bash -c "echo \"grub-pc grub-pc/install_devices string $DEVICE_BY_ID\" | debconf-set-selections" || die "grub-pc debconf-set-selection failed"
    chroot /mnt/fsroot dpkg-reconfigure -f noninteractive grub-pc || die "dpkg-reconfigure grub-pc failed"
fi

chroot /mnt/fsroot update-grub || die "update-grub failed"
chroot /mnt/fsroot update-initramfs -k all -u || die "update-initramfs failed"
chroot /mnt/fsroot update-grub || die "update-grub failed"

hash dmidecode 2>/dev/null && \
    dmidecode | grep -i product | grep -q VirtualBox || \
    chroot /mnt/fsroot apt-get -y purge \
           virtualbox-guest-dkms virtualbox-guest-utils virtualbox-guest-x11
chroot /mnt/fsroot apt-get -y purge mlocate

if [ $ENABLE_PROXY -eq 1 ]
then
    system_proxy_setup /mnt/fsroot
    firefox_proxy_setup /mnt/fsroot/home/user
fi

if [ -e "$IMGDIR/etc_skel_patch.tar.gz" ]
then
    tar x --numeric-owner \
        -C /mnt/fsroot/etc/skel \
        -f "$IMGDIR/etc_skel_patch.tar.gz" \
        --strip-components=1 \
        || die "/etc/skel patching failed"

    chroot /mnt/fsroot chown -R root:root /etc/skel || die "/etc/skel patching failed"
fi

# unprepare chroot in /mnt/fsroot
for i in /dev/pts /dev /proc /sys /run; do
    umount /mnt/fsroot$i || die "unmount /mnt/fsroot$i failed"
done

if [ $SEPARATE_HOME -eq 1 ]
then
    umount /mnt/fsroot/home || die "unmount /mnt/fsroot/home failed"
fi

umount /mnt/fsroot || die "fsroot umount failed"
rmdir /mnt/fsroot || die "fsroot mount point removal failed"

swapoff $PARTSWAP || die "turning swap on failed"

sync

echo "Installation completed successfully."
whiptail \
    --title "Congrats!" \
    --msgbox \
    "Installation completed successfully.\n\nУстановка завершена успешно." \
    25 80

#shutdown now -h

exit 0
