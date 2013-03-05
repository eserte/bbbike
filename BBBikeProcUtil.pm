# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2013 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

package BBBikeProcUtil;

use strict;
use vars qw($VERSION);
$VERSION = '0.02';

use Exporter 'import';
use vars qw(@EXPORT_OK);
@EXPORT_OK = qw(double_fork double_forked_exec);

sub double_fork (&) {
    my($cb) = @_;

    my $pid = fork;
    if (!defined $pid) {
	die "Fork failed: $!";
    }
    if ($pid == 0) {
	my $pid2 = fork;
	if (!defined $pid2) {
	    _hard_die("Inner fork failed: $!");
	}
	if ($pid2 == 0) {
	    eval {
		$cb->();
	    };
	    if ($@) {
		_hard_die("Failure while running callback: $@");
	    } else {
		_hard_exit(0);
	    }
	}
	_hard_exit(0);
    }
    waitpid $pid, 0;
}

sub double_forked_exec (@) {
    my(@cmd_and_args) = @_;
    double_fork {
	{ exec @cmd_and_args }
	_hard_die("@cmd_and_args failed: $!");
    };
}

sub _hard_die {
    my $msg = shift;
    warn $msg;
    _hard_exit(1);
}

sub _hard_exit {
    my $code = shift;
    if (eval { require POSIX; 1 }) {
	POSIX::_exit($code);
    } else {
	CORE::exit($code);
    }
}

1;

__END__
