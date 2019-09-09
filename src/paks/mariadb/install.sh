#!/bin/bash
############################################################################
#                                                                          #
# This file is part of the IPFire Firewall.                                #
#                                                                          #
# IPFire is free software; you can redistribute it and/or modify           #
# it under the terms of the GNU General Public License as published by     #
# the Free Software Foundation; either version 2 of the License, or        #
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

MARIADB_ETC = /etc/mysql
MARIADB_MYCNF = ${MARIADB_ETC}/my.cnf
MARIADB_RUN_DIR = /run/mysql
MARIADB_GROUP = mysql
MARIADB_USER = mysql
MARIADB_LOG_DIR = /var/log/mariadb
MARIADB_LOG_FILE = ${MARIADB_LOG_DIR}/mariadb.log
MARIADB_DATA_DIR = /var/lib/mysql
MARIADB_INIT_FILE = /etc/rc.d/init.d/mariadb

# stop service for update
if [ -e /etc/rc.d/init.d/mysql ]; then /etc/rc.d/init.d/mysql stop; fi
if [ -e ${MARIADB_INIT_FILE} ]; then ${MARIADB_INIT_FILE} stop; fi

# removing old libs
/bin/rm -f \
/usr/lib/libmysqlclient.so.18 \
/usr/lib/libmysqlclient.so.18.0.0 \
/usr/lib/libmysqlclient_r.so.18 \
/usr/lib/libmysqlclient_r.so.18.0.0 \
/usr/lib/mysql/libmysqlclient.so.18 \
/usr/lib/mysql/libmysqlclient.so.18.0.0 \
/usr/lib/mysql/libmysqlclient_r.so.18 \
/usr/lib/mysql/libmysqlclient_r.so.18.0.0

# save password on update
if [ -f ${MARIADB_MYCNF} ]; then
  pass=$(grep -m1 password ${MARIADB_MYCNF} |awk '{printf($3)}');
  extract_files
  /bin/sed -i "0,/password/ s/^password.*/password                = ${pass}/" ${MARIADB_MYCNF};
  unset pass;
else
  extract_files
fi;

/bin/rm -f /etc/rc.d/rc0.d/???mysql
/bin/rm -f /etc/rc.d/rc3.d/???mysql
/bin/rm -f /etc/rc.d/rc6.d/???mysql
/bin/ln -sf  ../init.d/mariadb /etc/rc.d/rc0.d/K26mariadb
/bin/ln -sf  ../init.d/mariadb /etc/rc.d/rc3.d/S43mariadb
/bin/ln -sf  ../init.d/mariadb /etc/rc.d/rc6.d/K26mariadb
/bin/chmod 0754 ${MARIADB_INIT_FILE}

restore_backup ${NAME}

# create user and group
if [[ $(/usr/bin/getent group ${MARIADB_GROUP}) = "" ]]; then /usr/sbin/groupadd -fg 41 ${MARIADB_GROUP}; fi;
if [[ $(/usr/bin/getent passwd ${MARIADB_USER}) = "" ]]; then 
   /usr/sbin/useradd -c "SQL Server" -d /dev/null -u 41 -g ${MARIADB_GROUP} -s /bin/false ${MARIADB_USER};
fi;

/usr/bin/install -v -m 755 -o ${MARIADB_USER} -g ${MARIADB_GROUP} -d ${MARIADB_RUN_DIR}

# Set rights on pid file
/bin/chmod -R mysql ${MARIADB_RUN_DIR};
/bin/chmod -R 777 ${MARIADB_RUN_DIR};

# create logdir and files
echo "Create logfiles dir ";
/bin/mkdir -p ${MARIADB_LOG_DIR};
/bin/chmod -R ${MARIADB_USER}:${MARIADB_GROUP} ${MARIADB_LOG_DIR};
/bin/chmod -R 755 ${MARIADB_LOG_DIR};

# remove old binary if exist
/bin/rm -f /usr/libexec/mysqld

# check if new installation or update
if [[ ! -d ${MARIADB_DATA_DIR} ]]; then
  # create dirs
  /bin/mkdir -p ${MARIADB_DATA_DIR};
  /bin/chmod -R ${MARIADB_USER}:${MARIADB_GROUP} ${MARIADB_DATA_DIR};
 
  # installing system tables
  echo "Installing System Tables to ${MARIADB_DATA_DIR} ";
  /usr/bin/mysql_install_db --basedir=/usr --datadir=${MARIADB_DATA_DIR} --user=${MARIADB_USER}

  echo "Add logrotate configuration ";
  LOGROTATE=$(grep -A 1 '/var/log/mariadb/mariadb.log' /etc/logrotate.conf);

  if [[ "${LOGROTATE}" ]]; then
    echo "Logrotate configuration is present";
  else
    cat >> /etc/logrotate.conf << "EOF"
# MariaDB
/var/log/mariadb/*.log {
    daily
    rotate 7
    copytruncate
    compress
    notifempty
    sharedscripts
    missingok
    postrotate
    if [ -f /run/mysql/mysql.pid ]; then
      /usr/bin/mysqladmin flush-logs
    fi
    endscript
}

EOF
  fi;

  unset LOGROTATE;

  # start service
  ${MARIADB_INIT_FILE} start >> /dev/null;
  sleep 1;

  # set default server password
  /usr/bin/mysqladmin -u root --password='' password 'mysqlfire';
  echo "The fresh installation is finished! ";
else

  echo "Start updating current databeses ";

  # start service 
  ${MARIADB_INIT_FILE} start >> /dev/null;
  sleep 1;

  # start update current databeses
  /usr/bin/mysql_upgrade --force

  echo "The update installation is finished!";
fi;

exit 0
