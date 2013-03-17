# Rules for adding/deleting the bbbike debian repository

all:
	@echo "For adding the bbbike debian repository to your system, do"
	@echo
	@echo "    sudo make add"
	@echo
	@echo "For removing the repository again, do"
	@echo
	@echo "    sudo make remove"
	@echo

######################################################################

MYDEBS_BBBIKE_LIST_PATH=	/etc/apt/sources.list.d/mydebs.bbbike.list
SUPPORTED_DISTS=		squeeze|wheezy|precise
PERL=				perl

add:	install-repo add-repo-key

install-repo:
	@$(PERL) -e 'BEGIN { $$supported_rx = "${SUPPORTED_DISTS}" }; chomp($$codename = `lsb_release -c -s`); $$codename =~ m{^($$supported_rx)$$} or die qq{ERROR: Only distributions $$supported_rx supported,\n       but this is "$$codename",\n       cannot add mydebs.bbbike.de repository.\n}'
	echo "deb http://mydebs.bbbike.de `lsb_release -c -s` main" > ${MYDEBS_BBBIKE_LIST_PATH}~
	chmod 644 ${MYDEBS_BBBIKE_LIST_PATH}~
	mv ${MYDEBS_BBBIKE_LIST_PATH}~ ${MYDEBS_BBBIKE_LIST_PATH}

add-repo-key:
	apt-key add mydebs.bbbike.key

######################################################################

remove:	uninstall-repo del-repo-key

uninstall-repo:
	rm -f ${MYDEBS_BBBIKE_LIST_PATH}

del-repo-key:
	apt-key del `cat mydebs.bbbike.key | gpg --no-options | perl -nle 'm{^pub *[^/]+/(\S+)} and print $$1'`
