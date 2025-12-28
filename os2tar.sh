#!/bin/bash
#
#  os2tar - creating an image of GNU/Linux installation, a template
#
#  Copyright (C) 2014, 2015, 2016, 2017, 2023, 2024, 2025 Alexander
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

part2tar()
{
    ssh -o UserKnownHostsFile="\"$tmp_known_hosts\"" "${extra_ssh_options[@]}" "root@$host" "\
test -e \"/mnt/zzz$name\"" && \
        { echo "ERROR: \"/mnt/zzz$name\" exists on the remote host. Exiting"; exit 1; }

    ssh -o UserKnownHostsFile="\"$tmp_known_hosts\"" "${extra_ssh_options[@]}" "root@$host" "\
mkdir \"/mnt/zzz$name\" && \
mount ${extra_mount_options[*]} $dev \"/mnt/zzz$name\" -o ro && \
cd \"/mnt/zzz$name\" && \
echo \"$excluded\" | \
tar --create --file - \
--no-wildcards-match-slash \
--exclude-backups \
--exclude-from=- \
--use-compress-program gzip \
--one-file-system --preserve-permissions --numeric-owner --sparse \
./" \
        > "fs_$name.tar.gz" 2> "fs_$name.stderr" && touch "fs_$name.ok" || \
            { echo "ERROR: tar creation for \"$name\" failed. Exiting"; exit 1; }

    rm_if_empty "fs_$name.stderr"

    ssh -o UserKnownHostsFile="\"$tmp_known_hosts\"" "${extra_ssh_options[@]}" "root@$host" "\
cd \"/mnt/zzz$name\" && \
getfacl -R -s -p -n ./ " \
        > "fs_$name.files-with-acls" 2> "fs_$name.files-with-acls.stderr"

    rm_if_empty "fs_$name.files-with-acls.stderr"

    ssh -o UserKnownHostsFile="\"$tmp_known_hosts\"" "${extra_ssh_options[@]}" "root@$host" "\
cd \"/mnt/zzz$name\" && \
find ./ -type d,p,f,s -exec lsattr -d {} + | grep -F -v -- '-----------'" \
        > "fs_$name.files-with-e2attrs" 2> "fs_$name.files-with-e2attrs.stderr"

    rm_if_empty "fs_$name.files-with-e2attrs.stderr"

    ssh -o UserKnownHostsFile="\"$tmp_known_hosts\"" "${extra_ssh_options[@]}" "root@$host" "\
cd \"/mnt/zzz$name\" && \
getcap -r ./" \
        > "fs_$name.files-with-caps" 2> "fs_$name.files-with-caps.stderr"

    rm_if_empty "fs_$name.files-with-caps.stderr"
}

part2tar_cleanup()
{
    ssh -o UserKnownHostsFile="\"$tmp_known_hosts\"" "${extra_ssh_options[@]}" "root@$host" "\
umount \"/mnt/zzz$name\" && \
rmdir \"/mnt/zzz$name\" "
}

rm_if_empty()
{
    local filename=${1:?filename is required}
    [[ -s "$filename" ]] || { [[ -f "$filename" ]] && rm "$filename"; }
}

host=127.0.0.1

# extra_ssh_options+=(-o Ciphers=arcfour)

tmp_known_hosts="./tmp_known_hosts"
ssh-copy-id -o UserKnownHostsFile="\"$tmp_known_hosts\"" "${extra_ssh_options[@]}" "root@$host"
# ssh-copy-id -i "$HOME/hosts/zz-ids/sample_id_rsa" -o UserKnownHostsFile="\"$tmp_known_hosts\"" "${extra_ssh_options[@]}" "root@$host"

ssh -o UserKnownHostsFile="\"$tmp_known_hosts\"" "${extra_ssh_options[@]}" "root@$host" hostname || \
    { echo "ERROR: cannot ssh to the remote host. Exiting"; exit 1; }

dev=/dev/sda1
name=root
extra_mount_options=()
read -d '' excluded <<"EOF"
./lost\+found
./swapfile
./media/*
./var/cache/apt/archives/*
./var/lib/snapd/cache/*
./var/log/journal/*
./boot/images/*
./root/c11n
./home/*
./home-in-root
./home_in_root
EOF
part2tar
part2tar_cleanup

dev=/dev/sda5
#dev="/mnt/zzz$name/home"
name=home
extra_mount_options=()
#extra_mount_options+=(--bind)
read -d '' excluded <<"EOF"
*~
~$*
~WRL*.tmp
./lost\+found
./*/.cache*
./*/.thumbnails
EOF
part2tar
part2tar_cleanup

#name=root
#part2tar_cleanup

rm "$tmp_known_hosts"

md5sum ./* > MD5SUMS
