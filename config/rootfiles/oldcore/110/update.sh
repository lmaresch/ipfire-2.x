#!/bin/bash
############################################################################
#                                                                          #
# This file is part of the IPFire Firewall.                                #
#                                                                          #
# IPFire is free software; you can redistribute it and/or modify           #
# it under the terms of the GNU General Public License as published by     #
# the Free Software Foundation; either version 3 of the License, or        #
# (at your option) any later version.                                      #
#                                                                          #
# IPFire is distributed in the hope that it will be useful,                #
# but WITHOUT ANY WARRANTY; without even the implied warranty of           #
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the            #
# GNU General Public License for more details.                             #
#                                                                          #
# You should have received a copy of the GNU General Public License        #
# along with IPFire; if not, write to the Free Software                    #
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307 USA #
#                                                                          #
# Copyright (C) 2017 IPFire-Team <info@ipfire.org>.                        #
#                                                                          #
############################################################################
#
. /opt/pakfire/lib/functions.sh
/usr/local/bin/backupctrl exclude >/dev/null 2>&1

core=110

# Remove old core updates from pakfire cache to save space...
for (( i=1; i<=$core; i++ )); do
	rm -f /var/cache/pakfire/core-upgrade-*-$i.ipfire
done

# Stop services
/etc/init.d/squid stop
/etc/init.d/unbound stop

# Extract files
extract_files

# update linker config
ldconfig

# Update Language cache
/usr/local/bin/update-lang-cache

# Remove deprecated options
sed -e "/^RSAAuthentication/d" -i /etc/ssh/sshd_config

# Remove avahi from system and pakfire db
for i in $(cat /opt/pakfire/db/rootfiles/avahi); do
    rm -rfv /${i}
done
rm -fv /opt/pakfire/db/rootfiles/avahi
rm -fv /opt/pakfire/db/*/meta-avahi
rm -fv /etc/rc.d/rc*.d/???avahi

# Start services
/etc/init.d/unbound start
/etc/init.d/sshd restart
/etc/init.d/squid start

# This update need a reboot...
#touch /var/run/need_reboot

# Finish
/etc/init.d/fireinfo start
sendprofile

# Update grub config to display new core version
if [ -e /boot/grub/grub.cfg ]; then
	grub-mkconfig -o /boot/grub/grub.cfg
fi

sync

# Don't report the exitcode last command
exit 0
