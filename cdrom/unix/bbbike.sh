#! /bin/sh

SYSTEM=`uname -s || unknown`
BBBIKEROOT=${BBBIKEROOT:-`pwd`}
SYSTEM=`echo $SYSTEM | tr '[A-Z]' '[a-z]'`

echo "Your system is $SYSTEM"

if [ \( "$SYSTEM" = "freebsd" \) \
   ]
then
    # use linux emulation if no native version available
    if [ ! -d "$BBBIKEROOT/$SYSTEM" ]
    then
        SYSTEM=linux
    fi
fi

# No Perl/Tk bundled for this system
if [ ! -d "$BBBIKEROOT/$SYSTEM" ]
then
    perl $BBBIKEROOT/BBBike/bbbike $*
    exit $?
fi

case "$SYSTEM" in
    freebsd)
	env LD_LIBRARY_PATH=$BBBIKEROOT/freebsd/lib \
	    PERL5LIB=$BBBIKEROOT/freebsd/lib/perl/5.00503/mach:$BBBIKEROOT/freebsd/lib/perl/5.00503:$BBBIKEROOT/freebsd/lib/perl/site/5.005/i386-freebsd:$BBBIKEROOT/freebsd/lib/perl/site/5.005 \
	    $BBBIKEROOT/freebsd/bin/perl $BBBIKEROOT/BBBike/bbbike $*
    ;;

    linux)
	env LD_LIBRARY_PATH=$BBBIKEROOT/linux/lib \
	    PERL5LIB=$BBBIKEROOT/linux/lib/5.6.1/linux:$BBBIKEROOT/linux/lib/5.6.1:$BBBIKEROOT/linux/lib/site_perl/5.6.1/linux:$BBBIKEROOT/linux/lib/site_perl/5.6.1 \
	    $BBBIKEROOT/linux/bin/perl $BBBIKEROOT/BBBike/bbbike $*
    ;;

    *)
	perl $BBBIKEROOT/BBBike/bbbike $*
    ;;
esac
