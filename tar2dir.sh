#!/bin/bash
#
#  tar2dir - restoring local directory from tar image
#
#  Copyright (C) 2014, 2015, 2016, 2017, 2021, 2022 Alexander
#  Yermolenko <yaa.mbox@gmail.com>
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

id=${1:?image id is required}
dir=${2:?target directory name is required}

[[ ${id::1} == "/" ]] || id="`pwd`/$id"

die()
{
    local msg=${1:-"Unknown error"}
    echo "ERROR: $msg" 1>&2
    exit 1
}

require()
{
    local cmd=${1:?"Command name is required"}
    local extra_info=${2:+"\nNote: $2"}
    hash $cmd 2>/dev/null || die "$cmd not found$extra_info"
}

require_root()
{
    [ "$EUID" -eq 0 ] || die "This program is supposed to be run with superuser privileges"
}

restore_file_capabilities()
{
    local GETCAP_OUTPUT="$1"
    local FS_PREFIX="$2"

    [ -f "$GETCAP_OUTPUT" ] || die "Cannot find file capabilities info: $GETCAP_OUTPUT"
    [ -d "$FS_PREFIX" ] || die "Target directory does not exist: $FS_PREFIX"

    echo "Restoring file capabilities from $GETCAP_OUTPUT inside $FS_PREFIX"

    local files=()
    local caps=()
    while IFS='=' read -ra fields; do
        [ ${#fields[@]} -eq 2 ] || die "Wrong format of file capabilities info."
        files+=(${fields[0]})
        caps+=(${fields[1]})
    done < "$GETCAP_OUTPUT"

    for index in "${!files[@]}"; do
        file="${files[$index]}"
        file_caps="${caps[$index]}"
        echo "Setting '$file_caps' on '$FS_PREFIX/$file'"
        setcap "$file_caps" "$FS_PREFIX/$file" || die "Cannot set capabilities on $FS_PREFIX/$file"
    done
}

require_root

require pv
require tar
require setcap

[ -f "$id.tar.gz" ] || die "Directory image file $id.tar.gz does not exist"

[ -e "$dir" ] || mkdir -p "$dir" 2>/dev/null

[ -z "$(ls -A "$dir")" ] || die "Destination directory is not empty"

cd "$dir" || die "Cannot cd to target directory $dir"

echo "Extracting $id.tar.gz contents to $dir"

pv --force "$id.tar.gz" | \
    tar x --numeric-owner \
    -C "$dir" \
    -z \
    -f - \
    || die "$id.tar.gz unpacking failed"

[ -f "$id.files-with-caps" ] && \
    restore_file_capabilities "$id.files-with-caps" "$dir"

[[ -s "$id.files-with-acls" ]] && echo "TODO: restore info from $id.files-with-acls"

[[ -s "$id.files-with-xattrs" ]] && echo "TODO: restore info from $id.files-with-xattrs"
