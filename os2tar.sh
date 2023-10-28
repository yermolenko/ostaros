#!/bin/bash
#
#  os2tar - creating an image of GNU/Linux installation, a template
#
#  Copyright (C) 2014, 2015, 2016, 2017, 2023 Alexander Yermolenko
#  <yaa.mbox@gmail.com>
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

EXTRA_SSH_OPTIONS=""
EXTRA_SSH_OPTIONS=",Cipher=arcfour"

part2tar()
{
    ssh -o UserKnownHostsFile=\"$tmp_known_hosts\"$EXTRA_SSH_OPTIONS "root@$host" "\
mkdir \"/mnt/zzz$name\" && \
mount $dev \"/mnt/zzz$name\" -o ro && \
cd \"/mnt/zzz$name\" && \
echo \"$excluded\" | \
tar --create --file - \
--exclude-backups \
--exclude-from=- \
--use-compress-program gzip --one-file-system --preserve-permissions --numeric-owner \
./" \
        > "fs_$name.tar.gz" 2> "fs_$name.stderr.txt" && touch "fs_$name.ok"

    ssh -o UserKnownHostsFile=\"$tmp_known_hosts\"$EXTRA_SSH_OPTIONS "root@$host" "\
cd \"/mnt/zzz$name\" && \
getfacl -R -s -p ./ " \
        > "fs_$name.files-with-acls"

    ssh -o UserKnownHostsFile=\"$tmp_known_hosts\"$EXTRA_SSH_OPTIONS "root@$host" "\
cd \"/mnt/zzz$name\" && \
find ./ -type f  -iname \"*\" -exec lsattr {} + | grep  -v '\-\-\-\-\-\-\-\-\-\-\-\-\-'" \
        > "fs_$name.files-with-xattrs"

    ssh -o UserKnownHostsFile=\"$tmp_known_hosts\"$EXTRA_SSH_OPTIONS "root@$host" "\
cd \"/mnt/zzz$name\" && \
getcap -r ./" \
        > "fs_$name.files-with-caps"

    ssh -o UserKnownHostsFile=\"$tmp_known_hosts\"$EXTRA_SSH_OPTIONS "root@$host" "\
umount \"/mnt/zzz$name\" && \
rmdir \"/mnt/zzz$name\" "
}

host=127.0.0.1

tmp_known_hosts=./tmp_known_hosts
ssh-copy-id -o UserKnownHostsFile=\"$tmp_known_hosts\"$EXTRA_SSH_OPTIONS "root@$host"

dev=/dev/sda1
name=root
read -d '' excluded <<"EOF"
./lost\+found
./swapfile
./media/*
./var/cache/apt/archives/*
./var/lib/snapd/cache/*
./var/log/journal/*
EOF
part2tar

dev=/dev/sda5
name=home
read -d '' excluded <<"EOF"
./lost\+found
EOF
part2tar

rm $tmp_known_hosts

md5sum ./* > MD5SUMS
