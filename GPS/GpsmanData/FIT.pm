# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2023 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# WWW: https://github.com/eserte/bbbike
#

package GPS::GpsmanData::FIT;

use strict;
use warnings;
our $VERSION = '0.01';

use File::Basename qw(basename);
use File::Copy qw(cp mv);
use File::Temp;
use IPC::Run qw(run);

use BBBikeUtil qw(is_in_path bbbike_root);

sub load {
    my($class, $file, %args) = @_;
    $class->_load_with_Garmin_FIT($file, %args);
}

sub _load_with_Garmin_FIT {
    my($class, $file, %args) = @_;
    my $debug = delete $args{debug};
    die "Unhandled options: " . join(" ", %args) if %args;

    my $fit2gpx = $class->_find_fit2gpx(debug => $debug);
    if (!defined $fit2gpx) {
	die "Can't find fit2gpx.pl";
    }

    my $tempdir = File::Temp::tempdir("FIT_XXXXXXXX", TMPDIR => 1, CLEANUP => 1);
    cp $file, "$tempdir/"
	or die "Can't copy $file to $tempdir: $!";
    my $fitfile = "$tempdir/" . basename($file);

    my $gpxfile;
    {
	# workaround needed, see https://github.com/mrihtar/Garmin-FIT/issues/37
	local $ENV{LC_ALL} = 'C';
	local $ENV{LANG} = 'C';
	my @cmd = ($^X, $fit2gpx, '-y', $fitfile);
	if (!run [@cmd]) {
	    die "Error while running '@cmd'";
	}
	$gpxfile = "$tempdir/" . basename($fitfile);
	$gpxfile =~ s/\.fit$/.gpx/i;
	if (!-s $gpxfile) {
	    die "Could not generate expected GPX file '$gpxfile' using '@cmd'";
	}
    }
    {
	rename $gpxfile, "$gpxfile.unsplitted.gpx"
	    or die "Error while renaming $gpxfile: $!";
	my @cmd = ($^X, bbbike_root . "/miscsrc/gpx2gpx", '-v', '--trkseg-split-by-time=600', "$gpxfile.unsplitted.gpx");
	if (!run [@cmd], '>', $gpxfile) {
	    die "Error while running '@cmd'";
	}
    }

    require GPS::GpsmanData::Any;
    GPS::GpsmanData::Any->load_gpx($gpxfile);
}

sub _find_fit2gpx {
    my($class, %args) = @_;
    my $debug = delete $args{debug};
    die "Unhandled options: " . join(" ", %args) if %args;

    my $script = 'fit2gpx.pl';

    {
	my $path_candidate = is_in_path($script);
	if (defined $path_candidate) {
	    warn "$script found in PATH\n" if $debug;
	    return $path_candidate;
	}
	warn "$script not found in PATH, try further locations\n" if $debug;
    }
    for my $dir ("$ENV{HOME}/src", "$ENV{HOME}/work", "$ENV{HOME}/work2") { # XXX ~/work and ~/work2 are somewhat obscure
	my $path_candidate = "$dir/Garmin-FIT/$script";
	warn "check $path_candidate...\n" if $debug;
	return $path_candidate if -x $path_candidate;
    }
    undef;
}

1;

__END__

=head1 NAME

GPS::GpsmanData::FIT - read .fit files

=head1 DESCRIPTION

B<GPS::GpsmanData::FIT> adds support for reading F<.fit> files in the
GPS data viewer or doing conversions using C<any2gpsman>.

As a prerequisite, L<https://github.com/mrihtar/Garmin-FIT> needs to
be installed or checked out. The script F<fit2fpx.pl> is expected to
be in user's C<PATH> and runnable, or just do a git-checkout under
F<~/src>:

    mkdir -p ~/src
    cd ~/src
    git clone https://github.com/mrihtar/Garmin-FIT

Note that Garmin-FIT itself has some prerequisites: the CPAN modules
C<POSIX::strftime::GNU> and C<Config::Simple>.

=cut
