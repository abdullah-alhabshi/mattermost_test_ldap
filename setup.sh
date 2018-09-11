#!/bin/bash

echo "Updating and Upgrading"
apt-get -qq -y update > /dev/null
apt-get -qq -y upgrade > /dev/null

export DEBIAN_FRONTEND=noninteractive
debconf-set-selections <<< 'mariadb-server-10.0 mysql-server/root_password password #MYSQL_ROOT_PASSWORD'
debconf-set-selections <<< 'mariadb-server-10.0 mysql-server/root_password_again password #MYSQL_ROOT_PASSWORD'
echo "Installing MariaDB, Docker, and ldapscripts"
apt-get install -y -q mariadb-server docker.io ldapscripts > /dev/null


echo 'Setting up Test LDAP'
docker pull rroemhild/test-openldap
docker run --privileged -d -p 389:389 rroemhild/test-openldap

sed -i 's/MATTERMOST_PASSWORD/#MATTERMOST_PASSWORD/' /vagrant/db_setup.sql
echo "Setting up database"
mysql -uroot -p#MYSQL_ROOT_PASSWORD < /vagrant/db_setup.sql

rm -rf /opt/mattermost

wget --quiet https://releases.mattermost.com/5.2.0/mattermost-5.2.0-linux-amd64.tar.gz

tar -xzf mattermost*.gz

rm mattermost*.gz
mv mattermost /opt

mkdir /opt/mattermost/data
rm /opt/mattermost/config/config.json

cp /vagrant/license.txt /opt/mattermost/license.txt

sed -i -e 's/mostest/#MATTERMOST_PASSWORD/g' /vagrant/config.json
ln -s /vagrant/config.json /opt/mattermost/config/config.json

useradd --system --user-group mattermost
chown -R mattermost:mattermost /opt/mattermost
chmod -R g+w /opt/mattermost

cp /vagrant/mattermost.service /lib/systemd/system/mattermost.service
systemctl daemon-reload

cd /opt/mattermost
bin/mattermost user create --email admin@planetexpress.com --username admin --password admin
bin/mattermost team create --name planet-express --display_name "Planet Express"
bin/mattermost team add planet-express admin@planetexpress.com

service mysql start
service mattermost start

IP_ADDR=`/sbin/ifconfig eth0 | grep 'inet addr' | cut -d: -f2 | awk '{print $1}'`

chmod +x /vagrant/update_leela.sh
printf '=%.0s' {1..80}
echo 
echo '                     VAGRANT UP!'
echo "GO TO http://${IP_ADDR}:8065 and log in with \`fry\`"
echo
printf '=%.0s' {1..80}
