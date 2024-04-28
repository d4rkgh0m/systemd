#!/bin/bash
mkdir -p ~root/.ssh
cp ~vagrant/.ssh/auth* ~root/.ssh
#=======================================================
cat >> /etc/sysconfig/watchlog << EOF
WORD="ALERT"
LOG=/var/log/watchlog.log
EOF
#=======================================================
cat >> /opt/watchlog.sh << EOF
#!/bin/bash

WORD=\$1
LOG=\$2
DATE=\`date\`

if grep \$WORD \$LOG &> /dev/null
then
    logger "\$DATE: Maestro i found word"
else
    exit 0
fi
EOF
#=======================================================
chmod +x /opt/watchlog.sh
#=======================================================
cat >> /lib/systemd/system/watchlog.service << EOF
[Unit]
Description=Test watchlog service

[Service]
Type=oneshot
EnvironmentFile=/etc/sysconfig/watchlog
ExecStart=/opt/watchlog.sh \$WORD \$LOG
EOF
#=======================================================
cat >> /lib/systemd/system/watchlog.timer << EOF
[Unit]
Description=Run watchlog script every 30 second
Requires=watchlog.service

[Timer]
#Run every 30 seconds
OnUnitActiveSec=30
Unit=watchlog.service

[Install]
WantedBy=multi-user.target
EOF
#=======================================================
#systemctl enable watchlog.timer
#systemctl enable watchlog.service
systemctl start watchlog.timer
#tr -dc a-z1-4 </dev/urandom | tr 1-2 ' \n' | awk 'length==0 || length>50' | tr 3-4 ' ' | sed 's/^ *//' | cat -s | sed 's/ / /g' |fmt > /var/log/watchlog.log
echo 'ALERT' > /var/log/watchlog.log
#=======================================================
# disable selinux or permissive 
selinuxenabled && setenforce 0

cat >/etc/selinux/config<<__EOF
SELINUX=disabled
SELINUXTYPE=targeted
__EOF
#=======================================================
yum install -y epel-release && yum install -y spawn-fcgi php php-cli mod_fcgid httpd
cat >> /lib/systemd/system/spawn-fcgi.service << EOF
[Unit]
Description=Spawn-fcgi startup service by Otus
After=network.target

[Service]
Type=simple
PIDFile=/var/run/spawn-fcgi.pid
EnvironmentFile=/etc/sysconfig/spawn-fcgi
ExecStart=/usr/bin/spawn-fcgi -n \$OPTIONS
KillMode=process

[Install]
WantedBy=multi-user.target
EOF
#=======================================================
sed -i 's/#SOCKET/SOCKET/' /etc/sysconfig/spawn-fcgi
sed -i 's/#OPTIONS/OPTIONS/' /etc/sysconfig/spawn-fcgi
#=======================================================
systemctl start spawn-fcgi.service
#=======================================================
cp /lib/systemd/system/httpd.service /lib/systemd/system/httpd@.service
sed -i 's|EnvironmentFile=/etc/sysconfig/httpd|&-%i|' /lib/systemd/system/httpd@.service
cp /etc/sysconfig/httpd /etc/sysconfig/httpd-first
cp /etc/sysconfig/httpd /etc/sysconfig/httpd-second
sed -i 's|#OPTIONS=|OPTIONS=-f conf/first.conf|' /etc/sysconfig/httpd-first
sed -i 's|#OPTIONS=|OPTIONS=-f conf/second.conf|' /etc/sysconfig/httpd-second
cp /etc/httpd/conf/httpd.conf /etc/httpd/conf/first.conf
cp /etc/httpd/conf/httpd.conf /etc/httpd/conf/second.conf
sed -i 's|Listen 80|&81\nPidFile /var/run/httpd-first.pid|' /etc/httpd/conf/first.conf
sed -i 's|Listen 80|&82\nPidFile /var/run/httpd-second.pid|' /etc/httpd/conf/second.conf
systemctl start httpd@first
systemctl start httpd@second
