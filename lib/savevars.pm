# -*- perl -*-

#
# $Id: savevars.pm,v 1.13 2002/02/11 00:20:12 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 1998-2001 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: eserte@cs.tu-berlin.de
# WWW:  http://user.cs.tu-berlin.de/~eserte/
#

package savevars;

$VERSION = "0.07";

# parts stolen from "vars.pm"

my $has_data_dumper = 0;
eval {
    require Data::Dumper;
    $has_data_dumper = 1;
};

my @imports;
my $callpack;
my $dont_write_cfgfile = 0;
my $cfgfile;

sub import {
    $callpack = caller;
    my $pack = shift;
    @imports = @_;
    my($sym, $ch);
    foreach my $s (@imports) {
        if ($s =~ /::/) {
            require Carp;
            Carp::croak("Can't declare another package's variables");
        }
        ($ch, $sym) = unpack('a1a*', $s);
        *{"${callpack}::$sym"} =
          (   $ch eq "\$"                       ? \$ {"${callpack}::$sym"}
	   : ($ch eq "\@" and $has_data_dumper) ? \@ {"${callpack}::$sym"}
	   : ($ch eq "\%" and $has_data_dumper) ? \% {"${callpack}::$sym"}
	   : do {
	       require Carp;
	       if (!$has_data_dumper) {
		   Carp::croak("Can't handle variable '$ch$sym' without module Data::Dumper.\n");
	       } else {
		   Carp::croak("Can't handle variable '$ch$sym'.\n");
	       }
	   });
    }

    my $cfgfile = cfgfile();
    if (-r $cfgfile) {
	require Safe;
	my $cpt = new Safe;
	$cpt->permit(qw(:base_core));
	$cpt->share_from($callpack, \@imports);
	$cpt->rdo($cfgfile);
    }
}

sub cfgfile {
    if (!defined $cfgfile) {
	my $basename = ($0 =~ m|([^/\\]+)$| ? $1 : $0);
	$cfgfile = eval { (getpwuid($<))[7] } || $ENV{'HOME'} || '';
	if ($cfgfile eq '' && $^O eq 'MSWin32') {
	    $cfgfile = 'C:';
	}
	$cfgfile .= "/.${basename}rc";
    }
    $cfgfile;
}

sub writecfg {
    my $cfgfile = cfgfile();
    if (open(CFG, ">$cfgfile")) {
	foreach my $_sym (@imports) {
	    my($ch, $sym) = unpack('a1a*', $_sym);
	    if ($has_data_dumper) {
		my($ref, $varname);
		if ($ch eq "\$") {
		    $ref = eval "$ch${callpack}::$sym";
		    $varname = "${callpack}::$sym";
		} else {
		    $ref = eval "\\" . "$ch${callpack}::$sym";
		    $varname = "*${callpack}::$sym";
		}
		print CFG Data::Dumper->Dump([$ref], [$varname]);
	    } else {
		if ($ch eq "\$") {
		    my $var = "${callpack}::$sym";
		    my $val = eval '$$var';
		    next if !defined $val;
		    $val =~ s/([\'\\])/\\$1/g;
		    print CFG "\$" . $callpack . "::" . $sym . " = '$val';\n";
		} else {
		    die;
		}
	    }
	}
	close CFG;
	1;
    } else {
	warn "Can't write configuration file $cfgfile";
	0;
    }
}

sub dont_write_cfgfile {
    $dont_write_cfgfile = 1;
}

END {
    writecfg() unless $dont_write_cfgfile;
}

1;

__END__

=head1 NAME

savevars - Perl pragma to auto-load and save global variables

=head1 SYNOPSIS

    use savevars qw($frob @mung %seen);

=head1 DESCRIPTION

This module will, like C<use vars>, predeclare the variables in the
list. In addition, the listed variables are retrieved from a
per-script configuration file and the values are stored on program
end. The filename of the configuration file is
"$ENV{HOME}/.${progname}rc", where progname is the name of the current
script.

The values are stored using the Data::Dumper module, which is already
installed with perl5.005 and better.

=head1 FUNCTIONS

=head2 cfgfile

Return the pathname of the current configuration file.

=head2 writecfg

Write the variables to the configuration file. This method is called
at END.

=head2 dont_write_cfgfile

If this function is called, then the configuration file will not be
written at END.

=head1 NOTES

If you want to be nice to your users and do not want to require them
to install this module, you can use this snippet of code to use the
savevars or the vars module, whatever is available:

    BEGIN {
        my @vars = qw($var1 $var2 @var3 %var4);
        eval           q{ use savevars @vars };
        if ($@) { eval q{ use vars     @vars } }
    }

Just put all the variables to be saved into the @vars array.

=head1 CAVEATS

cfgfile() uses the $< variable to determine the current home
directory. This might not be what you want if using setuid scripts.

=head1 BUGS

Because getpwuid() is used, this module will not work very well on
Windows. Configuration files will be stored in the current drive root
directory or, if the C<$HOME> environment variable exists, in the
C<$HOME> directory.

=head1 AUTHOR

Slaven Rezic <eserte@cs.tu-berlin.de>

Copyright (c) 1998-2001 Slaven Rezic. All rights reserved. This
package is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 SEE ALSO

L<vars>.

=cut
