# /etc/cron.d/mapserver-brb: crontab fragment for mapserver-brb

# cleanup every hour
27 * * * * [% WWW_USER %] [% MAPSERVER_DIR %]/cleanup -f -agehours 1
