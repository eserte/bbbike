#!/bin/sh

function check_prog () {
    while [ $# -gt 0 ]
    do
        if [ -x "$1" ]
        then
	    BBBIKESTRSERVER=$1
	    return 0
	fi
	shift
    done
    echo "No bbbikestrserver script found"
    exit 1
}

# find a suitable server
check_prog "$BBBIKESTRSERVER" \
	/usr/local/BBBike/miscsrc/bbbikestrserver \
	/oo/projekte/bbbike/bbbike-devel/miscsrc/bbbikestrserver \
	/home/e/eserte/src/bbbike/miscsrc/bbbikestrserver \
	/home/srezik/bbbike/miscsrc/bbbikestrserver \

case "$1" in
start)
	[ -x $BBBIKESTRSERVER ] && $BBBIKESTRSERVER && echo -n " bbbike-server"
	;;
stop)
	[ -x $BBBIKESTRSERVER ] && $BBBIKESTRSERVER -stop && echo -n " bbbike-server"
	;;
restart)
	[ -x $BBBIKESTRSERVER ] && $BBBIKESTRSERVER -restart && echo "bbbike-server restarted"
	;;
status)
	[ -x $BBBIKESTRSERVER ] && $BBBIKESTRSERVER -status
	;;
*)
	echo "Usage: `basename $0` {start|stop|restart|status}" >&2
	;;
esac

exit 0
