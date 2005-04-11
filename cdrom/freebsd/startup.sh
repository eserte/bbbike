#! /bin/sh
#
# $Id: startup.sh,v 1.2 1999/02/22 20:45:12 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 1999 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: eserte@cs.tu-berlin.de
# WWW:  http://user.cs.tu-berlin.de/~eserte/
#

me=$0
medir=`dirname $0`
topdir="$medir"

: option parsing
while test $# -gt 0; do
	case "$1" in
	-v) shift; verbose=yes;;
	--) break;;
	-*) echo "$me: unknown option $1" >&2; shift; error=true;;
	*) break;;
	esac
done

case "$error" in
true)
	cat >&2 <<EOM
Usage: $me [-v]
  -v : verbose
EOM
	exit 1
	;;
esac

# XXX check machine!
case "`uname`" in
FreeBSD)
	arch="i386-freebsd";;
Linux)
	arch="i386-linux";;
esac

case "$verbose" in
yes)
	echo "ARCH=$arch" ;;
esac

bindir="$topdir/bin/$arch"

case "$arch" in
"") ;;
*)
	if `perl -e 'exit !($] >= 5.004)'`; then
		case "$verbose" in
		yes)
			echo "Mindestens Perl 5.004 gefunden." ;;
		esac
	else
		export PATH="$bindir:$PATH"
		case "$verbose" in
		yes)
			echo "Keine geeignete Perl-Version gefunden."
			echo "Perl wird von der CD-ROM geladen."
			echo "PATH=$PATH"
			;;
		esac
	fi

	export PERL5LIB=`perl -e 'print join(":", @INC, "'$topdir'/perl/lib/site_perl/5.005", "'$topdir'/perl/lib/5.00502")'`
	;;
esac

case "$verbose" in
yes)
	echo "PERL5LIB=$PERL5LIB" ;;
esac

perl $topdir/BBBike/bbbike
