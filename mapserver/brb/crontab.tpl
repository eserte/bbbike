# /etc/cron.d/bbbike-mapserver-cleanup: crontab file for cleaning temporary mapserver files

# cleanup every hour, but keep temporary files for 12 hours
27 * * * * [% WWW_USER %] [% BBBIKE_MISCSRC_DIR %]/cron-wrapper [% MAPSERVER_DIR %]/cleanup -f -agehours 12
