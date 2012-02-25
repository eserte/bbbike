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

add:	install-repo add-repo-key

install-repo:
	install -c -m 644 mydebs.bbbike.list /etc/apt/sources.list.d/mydebs.bbbike.list

add-repo-key:
	apt-key add mydebs.bbbike.key

######################################################################

remove:	uninstall-repo del-repo-key

uninstall-repo:
	rm -f /etc/apt/sources.list.d/mydebs.bbbike.list

del-repo-key:
	apt-key del `cat mydebs.bbbike.key | gpg --no-options | perl -nle 'm{^pub *[^/]+/(\S+)} and print $$1'`
