#!/bin/bash
#
#  dir2tar - creating an image of local directory
#
#  Copyright (C) 2014, 2015, 2016, 2017, 2021, 2022, 2023, 2024, 2025
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

dir=${1:?directory name is required}
id=${2:?image id is required}
# dir=/srv/nspawn/debian-9
# id=nspawn-debian-9

outputdir=`pwd`
if [[ ${id::1} == "/" ]]
then
    outputdir="${id%/*}"
    id="${id##*/}"
fi

[ -t 0 -a -t 2 ] && \
    echo "Type newline-separated tar-style exclude patterns (e.g. ./home/*/Documents/* ) and press Ctrl+D when finished:"

excluded=$(</dev/stdin)

[ -t 0 -a -t 2 ] && \
    {
        echo "Excluding the following patterns:"
        echo "$excluded"
        echo
        echo "Continuing with image creation"
    }

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

rm_if_empty()
{
    local filename=${1:?filename is required}
    [[ -s "$filename" ]] || { [[ -f "$filename" ]] && rm "$filename"; }
}

test_outputdir()
{
    cd "$dir" || die "Cannot cd to the directory $dir"

    local outputfile_without_dirname="$id.testfile"
    local outputfile="$outputdir/$outputfile_without_dirname"
    [ -e "$outputfile" ] && die "$outputfile already exists"

    touch "$outputfile" 2>/dev/null
    [ -e "$outputfile" ] || die "Cannot create test file $outputfile"
    rm "$outputfile" || die "Cannot remove test file $outputfile"

    [ -e "$outputdir/$id.md5" ] && die "File $outputdir/$id.md5 already exists"
}

create_tar_image()
{
    cd "$dir" || die "Cannot cd to the directory $dir"

    local outputfile_without_dirname="$id.tar.gz"
    local outputfile="$outputdir/$outputfile_without_dirname"
    [ -e "$outputfile" ] && die "$outputfile already exists"

    echo "$excluded" | \
        tar --create --file - \
            --no-wildcards-match-slash \
            --exclude-backups \
            --exclude-from=- \
            --use-compress-program gzip \
            --one-file-system --preserve-permissions --numeric-owner --sparse \
            ./ \
            > "$outputfile" 2> "$outputfile-stderr" && \
        echo "`md5sum "$outputfile" | awk '{ print $1 }'`  $outputfile_without_dirname" >> "$outputdir/$id.md5"

    rm_if_empty "$outputfile-stderr"
}

list_files_with_acls()
{
    cd "$dir" || die "Cannot cd to the directory $dir"

    local outputfile_without_dirname="$id.files-with-acls"
    local outputfile="$outputdir/$outputfile_without_dirname"
    [ -e "$outputfile" ] && die "$outputfile already exists"

    cd "$dir" && \
        getfacl -R -s -p -n ./ \
                > "$outputfile" 2> "$outputfile-stderr" && \
        echo "`md5sum "$outputfile" | awk '{ print $1 }'`  $outputfile_without_dirname" >> "$outputdir/$id.md5"

    rm_if_empty "$outputfile-stderr"
}

list_files_with_e2attrs()
{
    cd "$dir" || die "Cannot cd to the directory $dir"

    local outputfile_without_dirname="$id.files-with-e2attrs"
    local outputfile="$outputdir/$outputfile_without_dirname"
    [ -e "$outputfile" ] && die "$outputfile already exists"

    cd "$dir" && \
        find ./ -type f -exec lsattr {} + \
             > /dev/null 2> "$outputfile-stderr"
    cd "$dir" && \
        find ./ -type d,p,f,s -exec lsattr -d {} + \
            | grep -F -v -- '-----------' \
                   > "$outputfile"
    echo "`md5sum "$outputfile" | awk '{ print $1 }'`  $outputfile_without_dirname" >> "$outputdir/$id.md5"

    rm_if_empty "$outputfile-stderr"
}

list_files_with_caps()
{
    cd "$dir" || die "Cannot cd to the directory $dir"

    local outputfile_without_dirname="$id.files-with-caps"
    local outputfile="$outputdir/$outputfile_without_dirname"
    [ -e "$outputfile" ] && die "$outputfile already exists"

    cd "$dir" && \
        getcap -r ./ \
               > "$outputfile" 2> "$outputfile-stderr" && \
        echo "`md5sum "$outputfile" | awk '{ print $1 }'`  $outputfile_without_dirname" >> "$outputdir/$id.md5"

    rm_if_empty "$outputfile-stderr"
}

[ -d "$dir" ] || die "Directory \"$dir\" does not exist"
dir="$( cd "$dir" && pwd )"
[ -d "$dir" ] || die "Directory \"$dir\" does not exist"
[ "x$dir" == "x$outputdir" ] && die "\"$dir\" and output directory are the same"
echo "dir: $dir"
echo "outputdir: $outputdir"
echo "id: $id"

require_root

require tar
require getfacl
require lsattr
require getcap

test_outputdir

create_tar_image
list_files_with_acls
list_files_with_e2attrs
list_files_with_caps
