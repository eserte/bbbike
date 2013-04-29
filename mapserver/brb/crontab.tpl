# /etc/cron.d/mapserver-brb: crontab fragment for mapserver-brb

# cleanup every hour
27 * * * * [% WWW_USER %] [% BBBIKE_MISCSRC_DIR %]/cron-wrapper [% MAPSERVER_DIR %]/cleanup -f -agehours 1
