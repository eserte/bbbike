CDROMDIR=	/tmp/cdrom
CDROMIMAGE=	/tmp/cdromimage
# XXX don't hardcode!
CWD=		$(HOME)/src/bbbike/cdrom
CDROMSPEED?=	8

all:
	@echo Follow the instructions:
	@echo Start cdrom.pl from a freebsd machine
	@echo Start cdrom.pl from a linux machine
	@echo type make image for building an ISO image in /tmp
	@echo type make cdrom for burning the cdrom

onlywindows:
	./cdrom.pl -destdir /usr/tmp/cdrom -bbbikecommon -bbbike -windows -f

image:
	@echo Please check the correct version number
	rm -f ${CDROMIMAGE}
#	cd ${CDROMDIR}; mkisofs -A "BBBike-2.65-0000" -L -r -J -P "Slaven Rezic <eserte@cs.tu-berlin.de>" -V "BBBike" -o ${CDROMIMAGE} .
	cd ${CDROMDIR}; mkhybrid -A "BBBike-2.65-0000" -L -r -J -P "Slaven Rezic <eserte@cs.tu-berlin.de>" -V "BBBike" -o ${CDROMIMAGE} -hfs -map ${CWD}/mac/afpfile -auto index.html .

checkimage:
	@echo You must be root
	mount ${CDROMIMAGE} -r -t iso9660 -o loop /mnt
	@echo Do not forget to do
	@echo	umount /mnt

checkraw:
#	cdrecord-1.6.1 -vv speed=1 dev=4,0 -dummy ${CDROMIMAGE}
	cdrecord -vv speed=1 dev=4,0 -dummy ${CDROMIMAGE}

cdrom:
	@echo Now burn the disk
	@echo This will work only as root
#	cdrecord -v blank=fast speed=1 dev=4,0 ${CDROMIMAGE}
#	cdrecord-1.6.1 -vv speed=1 dev=4,0 ${CDROMIMAGE}
#	cdrecord -vv speed=1 dev=4,0 ${CDROMIMAGE}
#	cdwrite -v --speed 1 --dummy --philips --device /dev/sg0 --data ${CDROMIMAGE}
	cdwrite -v --speed 1 --device /dev/sg0 --data ${CDROMIMAGE}

checkburned:
	mount -t iso9660 -r /dev/scd0 /mnt

clean:
	rm -rf /servertmp/cdrom

######################################################################

BURNDIR=/var/tmp/burn

# a small distribution containing the bbbike sources only
smalldistcdrom:
	copynewer -all -list -dir .. |\
	    perl -nle 's/=/\\=/g; print "$$_=$$_"' > /tmp/bbbike-smalldistcdrom-filelist
	cd .. && mkisofs -graft-points -J -R -f -o ${BURNDIR}/bbbike-small.iso9660 -path-list /tmp/bbbike-smalldistcdrom-filelist

# a complete distribution containing binaries for various platforms
distcdrom:
	# XXX

# A development distribution containing the bbbike sources and all
# supporting data and scripts
# Usage of -joliet-long is necessary because of long names in the tmp
# directory. See the comment in the mkisofs manpage.
develdistcdrom:
	copynewer -nomanifest -nomanifestskip -all -list -dir .. |\
	    perl -nle 's/=/\\=/g; print "$$_=$$_"' > /tmp/bbbike-develdistcdrom-filelist
	cd .. && mkisofs -graft-points -J -joliet-long -R -f -o ${BURNDIR}/bbbike-devel.iso9660 -path-list /tmp/bbbike-develdistcdrom-filelist

# XXX only FreeBSD
check-develdistcdrom:	check-root
	vnconfig /dev/vn0 ${BURNDIR}/bbbike-devel.iso9660
	mount_cd9660 /dev/vn0 /mnt

uncheck-develdistcdrom:	check-root
	-umount /mnt
	vnconfig -u /dev/vn0

check-root:
	@[ `id -u` -eq 0 ] || (echo You must be root; false) && true

burn-develdistcdrom:
	sudo cdrecord -v -eject speed=${CDROMSPEED} dev=5,0 ${BURNDIR}/bbbike-devel.iso9660

burn-cdrw-develdistcdrom:
	sudo cdrecord -v -eject blank=fast speed=${CDROMSPEED} dev=5,0 ${BURNDIR}/bbbike-devel.iso9660

verify-develdistcdrom:
	sudo cat /dev/cd0c | cmp ${BURNDIR}/bbbike-devel.iso9660 /dev/stdin
