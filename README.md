# Инициализация системы. Systemd
Система инициализации. Systemd

# **Систмное окружение**
- Host OS: Arch Linux 64-bit Wayland kernel 6.8.7-zen1-2-zen
- Guest OS: CentOS 7.8.2003
- VirtualBox: 7.0.16 r162802
- Vagrant: 2.4.1

# **Содержание ДЗ**

* Создание сервиса, выполняющего периодический мониторинг лога на предмет ключевого слова
* Создание unit-файла сервиса из init-скрипта
* Конфигурация для запуска нескольких инстансов сервиса apache httpd

# **Выполнение**

### Создание сервиса, выполняющего периодический мониторинг лога на предмет ключевого слова

Создание файла конфигурации сервиса, используется ключевое слово `ALERT`:
```
cat >> /etc/sysconfig/watchlog << EOF
WORD="ALERT"
LOG=/var/log/watchlog.log
EOF
```

Исполняемый модуль сервиса:
```
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
chmod +x /opt/watchlog.sh
```

Unit-файл сервиса:
```
cat >> /lib/systemd/system/watchlog.service << EOF
[Unit]
Description=Test watchlog service

[Service]
Type=oneshot
EnvironmentFile=/etc/sysconfig/watchlog
ExecStart=/opt/watchlog.sh \$WORD \$LOG
EOF
```

Unit-файл таймера, запускающего сервис каждые 30 секунд:
```
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
```
При запуске таймера и записи ключевого слова в лог:
```
[root@otus ~]# systemctl start watchlog.timer
[root@otus ~]# echo 'ALERT' > /var/log/watchlog.log
```

В системном журнале сообщения:
```
[root@otus ~]# tail -f /var/log/messages
Apr 28 12:04:24 otus systemd: Created slice User Slice of vagrant.
Apr 28 12:04:24 otus systemd: Started Session 2 of user vagrant.
Apr 28 12:04:24 otus systemd-logind: New session 2 of user vagrant.
Apr 28 12:10:41 otus chronyd[375]: Selected source 206.189.8.121
Apr 28 12:18:10 otus systemd: Starting Cleanup of Temporary Directories...
Apr 28 12:18:10 otus systemd: Started Cleanup of Temporary Directories.
Apr 28 12:40:59 otus systemd: Started Run watchlog script every 30 second.
Apr 28 12:40:59 otus systemd: Starting Test watchlog service...
Apr 28 12:40:59 otus root: Sun Apr 28 12:40:59 UTC 2024: Maestro i found word
Apr 28 12:40:59 otus systemd: Started Test watchlog service.
```

Состояние сервисов:
```
[root@otus ~]# systemctl status watchlog.service
● watchlog.service - Test watchlog service
   Loaded: loaded (/usr/lib/systemd/system/watchlog.service; static; vendor preset: disabled)
   Active: inactive (dead) since Sun 2024-04-28 12:44:10 UTC; 6s ago
  Process: 2100 ExecStart=/opt/watchlog.sh $WORD $LOG (code=exited, status=0/SUCCESS)
 Main PID: 2100 (code=exited, status=0/SUCCESS)

Apr 28 12:44:10 otus systemd[1]: Starting Test watchlog service...
Apr 28 12:44:10 otus systemd[1]: Started Test watchlog service.
[root@otus ~]# systemctl status watchlog.timer
● watchlog.timer - Run watchlog script every 30 second
   Loaded: loaded (/usr/lib/systemd/system/watchlog.timer; disabled; vendor preset: disabled)
   Active: active (waiting) since Sun 2024-04-28 12:40:59 UTC; 4min 18s ago

Apr 28 12:40:59 otus systemd[1]: Started Run watchlog script every 30 second.
[root@otus ~]# systemctl list-timers
NEXT                         LEFT     LAST                         PASSED    UNIT             
Sun 2024-04-28 12:46:40 UTC  21s left Sun 2024-04-28 12:46:10 UTC  8s ago    watchlog.timer   
Mon 2024-04-29 12:18:10 UTC  23h left Sun 2024-04-28 12:18:10 UTC  28min ago systemd-tmpfiles-

2 timers listed.
Pass --all to see loaded but inactive timers, too.

[root@otus ~]# systemctl list-timers
NEXT                         LEFT     LAST                         PASSED    UNIT             
Sun 2024-04-28 12:47:40 UTC  15s left Sun 2024-04-28 12:47:10 UTC  14s ago   watchlog.timer   
Mon 2024-04-29 12:18:10 UTC  23h left Sun 2024-04-28 12:18:10 UTC  29min ago systemd-tmpfiles-

2 timers listed.
Pass --all to see loaded but inactive timers, too.
```

### Создание unit-файла сервиса из init-скрипта

Установка spawn-fcgi и необходимых пакетов:
```
yum install -y epel-release && yum install -y spawn-fcgi php php-cli mod_fcgid httpd
```

Unit-файл сервиса `spawn-fcgi`:
```
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
```

Раскомментирование опций в конфиг-файле:
```
sed -i 's/#SOCKET/SOCKET/' /etc/sysconfig/spawn-fcgi
sed -i 's/#OPTIONS/OPTIONS/' /etc/sysconfig/spawn-fcgi
```

Запуск сервиса и его статус:
```
[root@otus ~]# systemctl start spawn-fcgi.service
[root@otus ~]#
[root@otus ~]# systemctl status spawn-fcgi.service
● spawn-fcgi.service - Spawn-fcgi startup service by Otus
   Loaded: loaded (/usr/lib/systemd/system/spawn-fcgi.service; disabled; vendor preset: disabled)
   Active: active (running) since Sun 2024-04-28 12:59:03 UTC; 10s ago
 Main PID: 2178 (php-cgi)
   CGroup: /system.slice/spawn-fcgi.service
           ├─2178 /usr/bin/php-cgi
           ├─2179 /usr/bin/php-cgi
           ├─2180 /usr/bin/php-cgi
           ├─2181 /usr/bin/php-cgi
           ├─2182 /usr/bin/php-cgi
           ├─2183 /usr/bin/php-cgi
           ├─2184 /usr/bin/php-cgi
           ├─2185 /usr/bin/php-cgi
           ├─2186 /usr/bin/php-cgi
           ├─2187 /usr/bin/php-cgi
           ├─2188 /usr/bin/php-cgi
           ├─2189 /usr/bin/php-cgi
           ├─2190 /usr/bin/php-cgi
           ├─2191 /usr/bin/php-cgi
           ├─2192 /usr/bin/php-cgi
           ├─2193 /usr/bin/php-cgi
           ├─2194 /usr/bin/php-cgi
           ├─2195 /usr/bin/php-cgi
           ├─2196 /usr/bin/php-cgi
           ├─2197 /usr/bin/php-cgi
           ├─2198 /usr/bin/php-cgi
           ├─2199 /usr/bin/php-cgi
           ├─2200 /usr/bin/php-cgi
           ├─2201 /usr/bin/php-cgi
           ├─2202 /usr/bin/php-cgi
           ├─2203 /usr/bin/php-cgi
           ├─2204 /usr/bin/php-cgi
           ├─2205 /usr/bin/php-cgi
           ├─2206 /usr/bin/php-cgi
           ├─2207 /usr/bin/php-cgi
           ├─2208 /usr/bin/php-cgi
           ├─2209 /usr/bin/php-cgi
           └─2210 /usr/bin/php-cgi

Apr 28 12:59:03 otus systemd[1]: Started Spawn-fcgi startup service by Otus.
```

### Конфигурация для запуска нескольких инстансов сервиса apache httpd

Подготовка Unit-файла:
```
cp /lib/systemd/system/httpd.service /lib/systemd/system/httpd@.service
sed -i 's|EnvironmentFile=/etc/sysconfig/httpd|&-%i|' /lib/systemd/system/httpd@.service
```

Создание файлов окружений из стандартного путём копирования и изменения опций конфиг-файлов:
```
cp /etc/sysconfig/httpd /etc/sysconfig/httpd-first
cp /etc/sysconfig/httpd /etc/sysconfig/httpd-second
sed -i 's|#OPTIONS=|OPTIONS=-f conf/first.conf|' /etc/sysconfig/httpd-first
sed -i 's|#OPTIONS=|OPTIONS=-f conf/second.conf|' /etc/sysconfig/httpd-second
```

Создание файлов конфигов для каждого экземпляра сервиса, явно указываются используемые порты (8081,8082) и Pid-файлы:
```
cp /etc/httpd/conf/httpd.conf /etc/httpd/conf/first.conf
cp /etc/httpd/conf/httpd.conf /etc/httpd/conf/second.conf
sed -i 's|Listen 80|&81\nPidFile /var/run/httpd-first.pid|' /etc/httpd/conf/first.conf
sed -i 's|Listen 80|&82\nPidFile /var/run/httpd-second.pid|' /etc/httpd/conf/second.conf
```

Запуск сервисов и их состояние после запуска:
```
[root@otus ~]# systemctl start httpd@first
[root@otus ~]# systemctl start httpd@second
[root@otus ~]# systemctl status httpd*
● httpd@first.service - The Apache HTTP Server
   Loaded: loaded (/usr/lib/systemd/system/httpd@.service; disabled; vendor preset: disabled)
   Active: active (running) since Sun 2024-04-28 13:35:07 UTC; 28s ago
     Docs: man:httpd(8)
           man:apachectl(8)
 Main PID: 21156 (httpd)
   Status: "Total requests: 0; Current requests/sec: 0; Current traffic:   0 B/sec"
   CGroup: /system.slice/system-httpd.slice/httpd@first.service
           ├─21156 /usr/sbin/httpd -f conf/first.conf -DFOREGROUND
           ├─21157 /usr/sbin/httpd -f conf/first.conf -DFOREGROUND
           ├─21158 /usr/sbin/httpd -f conf/first.conf -DFOREGROUND
           ├─21159 /usr/sbin/httpd -f conf/first.conf -DFOREGROUND
           ├─21160 /usr/sbin/httpd -f conf/first.conf -DFOREGROUND
           ├─21161 /usr/sbin/httpd -f conf/first.conf -DFOREGROUND
           └─21162 /usr/sbin/httpd -f conf/first.conf -DFOREGROUND

Apr 28 13:35:07 otus systemd[1]: Starting The Apache HTTP Server...
Apr 28 13:35:07 otus httpd[21156]: AH00558: httpd: Could not reliably determine the serv...age
Apr 28 13:35:07 otus systemd[1]: Started The Apache HTTP Server.

● httpd@second.service - The Apache HTTP Server
   Loaded: loaded (/usr/lib/systemd/system/httpd@.service; disabled; vendor preset: disabled)
   Active: active (running) since Sun 2024-04-28 13:35:18 UTC; 18s ago
     Docs: man:httpd(8)
           man:apachectl(8)
 Main PID: 21169 (httpd)
   Status: "Total requests: 0; Current requests/sec: 0; Current traffic:   0 B/sec"
   CGroup: /system.slice/system-httpd.slice/httpd@second.service
           ├─21169 /usr/sbin/httpd -f conf/second.conf -DFOREGROUND
           ├─21170 /usr/sbin/httpd -f conf/second.conf -DFOREGROUND
           ├─21171 /usr/sbin/httpd -f conf/second.conf -DFOREGROUND
           ├─21172 /usr/sbin/httpd -f conf/second.conf -DFOREGROUND
           ├─21173 /usr/sbin/httpd -f conf/second.conf -DFOREGROUND
           ├─21174 /usr/sbin/httpd -f conf/second.conf -DFOREGROUND
           └─21175 /usr/sbin/httpd -f conf/second.conf -DFOREGROUND

Apr 28 13:35:18 otus systemd[1]: Starting The Apache HTTP Server...
Apr 28 13:35:18 otus httpd[21169]: AH00558: httpd: Could not reliably determine the serv...age
Apr 28 13:35:18 otus systemd[1]: Started The Apache HTTP Server.
Hint: Some lines were ellipsized, use -l to show in full.
```

Сконфигурированные ранее порты прослушиваются сервисами:
```
[root@otus ~]# ss -tnlp | grep httpd
LISTEN     0      128       [::]:8081                  [::]:*                   users:(("httpd",pid=21162,fd=4),("httpd",pid=21161,fd=4),("httpd",pid=21160,fd=4),("httpd",pid=21159,fd=4),("httpd",pid=21158,fd=4),("httpd",pid=21157,fd=4),("httpd",pid=21156,fd=4))
LISTEN     0      128       [::]:8082                  [::]:*                   users:(("httpd",pid=21175,fd=4),("httpd",pid=21174,fd=4),("httpd",pid=21173,fd=4),("httpd",pid=21172,fd=4),("httpd",pid=21171,fd=4),("httpd",pid=21170,fd=4),("httpd",pid=21169,fd=4))
```

# **Результаты**

Выполняемые при конфигурировании сервера команды перенесены в bash-скрипт для автоматического конфигурирования машины при развёртывании.
После развёртывания машины стартуют сервисы `watchlog.timer`, `spawn-fcgi.service`, `httpd@first.service`, `httpd@second.service`.

Полученный в ходе работы `Vagrantfile` и внешний скрипт `init.sh` для shell provisioner помещены в публичный репозиторий: 
- https://github.com/d4rkgh0m/systemd

