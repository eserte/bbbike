#!/bin/sh

# Cleanup plethora of temporary files created by bbbike or related
# tools

# Run only on development machines, not on live www machines, because
# precious session data would be deleted.

deleteall=

if [ $# != 0 ]
then
    case "$1" in
        -all)
	    deleteall=1
            ;;
        *)
	    echo "usage: $0 [-all]"
	    exit 1
	    ;;
    esac
fi

case "`hostname`" in
    biokovo-amd64.herceg.de | biokovo-amd64.rezic.de | mosor | devpc01-debian )
        ;;
    *)
        echo "Should only run on biokovo or mosor"
	exit 1
	;;
esac

# Used for various cache files if no cache directory is provided (as
# seems to be the case in some test scripts, in data/Makefile etc.,
# maybe also in the cgi implementations)
rm /tmp/*.cache
rm /tmp/b_de_*
rm /tmp/bbbike_b_de_*
# last * is a pid file - unfinished creation of cache file
rm /tmp/bbbike_*.cache.*
# Various temporary files created by data/Makefile
rm /tmp/XXX_*-orig.bbd
rm /tmp/fragezeichen_*.bbd
# Probably files created by the bbbikedraw test scripts, to be checked XXX
rm /tmp/bbbikedraw-mapserver-*
rm /tmp/bbbikedraw_*
rm /tmp/bbbikedraw.*
# Images created by bbbike test scripts (-display option)
rm /tmp/*_BBBikeViewImages
# Temporary files for mapserver
rm /tmp/bbbikems-xxx-*
# Sessions for bbbike, precious on the live www machine
rm -r /tmp/bbbike-sessions-*
rm /tmp/bbbike-counter-*
rm -r /tmp/coordssession
# Temporary files for uploads for the cgi implementation
rm /tmp/bbbike.cgi.upload.*
# Sessions for wapbbbike
rm /tmp/wapbbbike_sessions_*.db
# Created by the group of newstreetform formulars, precious on the
# live www machine
rm /tmp/newstreetform-backup
# Created by the tpage calls in mapserver/brb
rm -r /tmp/bbbikettc
# TODO: automatic mount calculation is broken, these are the files
# with the "problematic" line segments:
rm /tmp/problematic_*.bbd
# Log of the cgpsmapper runs
rm /tmp/cgpsmapper-images.log
# Temporary shape files, unknown origin
rm /tmp/??????????.dbf
rm /tmp/??????????.shp
rm /tmp/??????????.shx
# Snapshot zips (data and prog)
rm /tmp/??????????-bbbike-snapshot.zip
rm /tmp/??????????-bbbike-data.zip
# session files
rm /tmp/Apache-Session-????????????????????????????????.lock
# ???
rm /tmp/bbbikems-*.bbd
## Created by BBBikeGPS
rm /tmp/2???????.wpt-gpspoints.bbd-orig
rm /tmp/2???????.trk-gpsspeed.bbd-orig
rm /tmp/2???????.trk-gpspoints.bbd-orig
rm /tmp/2???????.wpt-gpspoints.bbd
rm /tmp/2???????.trk-gpsspeed.bbd
rm /tmp/2???????.trk-gpspoints.bbd

if [ "$deleteall" ]
then
    ## Original files when using the bbbike editor. Not deleted by default,
    ## because it's likely that a bbbike session is still running
    rm -r /tmp/bbbike-orig
    ## Possible precious information about failing tests
    rm /tmp/??????????.bbbike_test.html
    rm /tmp/??????????.bbbike_test
fi
