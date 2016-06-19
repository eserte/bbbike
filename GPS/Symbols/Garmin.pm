# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2013,2014,2015,2016 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

package GPS::Symbols::Garmin;

use strict;
use vars qw($VERSION);
$VERSION = '0.05';

use File::Glob qw();
use File::Temp qw();

use BBBikeUtil qw();

my %cached_symbol_to_img;

# This is returning a cached singleton hashref, which is normally not
# recreated.
sub get_cached_symbol_to_img {
    my %opts = @_;
    my $portable = delete $opts{portable} ? 1 : 0;
    die "Unhandled options: " . join(" ", %opts) if %opts;

    my $must_recreate = 1;
    if ($cached_symbol_to_img{$portable}) {
	$must_recreate = 0;
	for my $file (values %{ $cached_symbol_to_img{$portable} }) {
	    if (!-f $file) {
		$must_recreate = 1;
		last;
	    }
	}
    }

    if ($must_recreate) {
	$cached_symbol_to_img{$portable} = get_symbol_to_img(portable => $portable);
    }

    $cached_symbol_to_img{$portable};
}

# This is returning a fresh hashref
sub get_symbol_to_img {
    my %opts = @_;
    my $portable = delete $opts{portable};
    die "Unhandled options: " . join(" ", %opts) if %opts;

    my $symbol_to_img = {};
    # Try to find a gpsman gmicons directory for "official" Garmin
    # symbols
    {
	my @gmicons;
	my $gpsman_rc_directory = gpsman_rc_directory(\@gmicons);
	if (!$gpsman_rc_directory) {
	    warn "NOTE: no gpsman/gmicons directory found, no support for Garmin symbols.\n";
	} else {
	    my $make_filename = sub ($) {
		my $f = shift;
		if ($portable) {
		    substr($f, 0, length($gpsman_rc_directory), '$GPSMANDIR');
		}
		$f;
	    };
	    require File::Basename;
	    for my $gmicon (@gmicons) {
		my $iconname = File::Basename::basename($gmicon);
		$iconname =~ s{15x15.gif$}{};
		$symbol_to_img->{$iconname} = $make_filename->($gmicon);
	    }
	}
    }

    {
	# Now the user-defined symbols. Here's room for different "userdef
	# symbol sets", which may be per-vehicle, per-user, per-year etc.
	my $make_filename = sub ($) {
	    my $f = shift;
	    if ($portable) {
		substr($f, 0, length(BBBikeUtil::bbbike_root()), '$BBBIKEDIR');
	    }
	    $f;
	};
	{
	    #my $userdef_symbol_dir = BBBikeUtil::bbbike_root()."/misc/garmin_userdef_symbols/bike2008";
	    my $userdef_symbol_dir = BBBikeUtil::bbbike_root()."/misc/garmin_userdef_symbols/bike2014";
	    if (!-d $userdef_symbol_dir) {
		warn "NOTE: directory <$userdef_symbol_dir> with userdefined garmin symbols not found.\n";
	    } else {
		for my $f (File::Glob::bsd_glob("$userdef_symbol_dir/*.bmp")) {
		    my($inx) = $f =~ m{(\d+)\.bmp$};
		    next if !defined $inx; # non parsable bmp filename
		    $symbol_to_img->{"user:" . (7680 + $inx)} = $make_filename->($f);
		}
	    }
	}
	{
	    my $userdef_symbol_dir = BBBikeUtil::bbbike_root()."/misc/garmin_userdef_symbols/bike2015";
	    if (!-d $userdef_symbol_dir) {
		# XXX don't warn, this is not (yet) public
	    } else {
		for my $f (File::Glob::bsd_glob("$userdef_symbol_dir/*.bmp")) {
		    my($inx) = $f =~ m{/(\d+).*\.bmp$};
		    next if !defined $inx; # non parsable bmp filename
		    $symbol_to_img->{"user:" . (7745 + $inx)} = $make_filename->($f);
		}
	    }
	}
    }

    # bbd: IMG:... syntax cannot handle whitespace, so create symlinks
    # without whitespace if necessary (may happen on Windows systems)
    for my $iconname (keys %$symbol_to_img) {
	my $f = $symbol_to_img->{$iconname};
	if ($f =~ m{\s}) {
	    my($tmpnam) = File::Temp::tmpnam() . ".bmp";
	    symlink $f, $tmpnam
		or die "Can't create symlink $tmpnam -> $f: $!";
	    $f = $tmpnam;
	    $symbol_to_img->{$iconname} = $f;
	}
    }
    $symbol_to_img;
}

sub gpsman_rc_directory {
    my($gmicons_ref) = @_;

    my @gmicons;
    my $gpsman_rc_directory;
    for my $candidate ("/usr/share/gpsman", # Debian default
		       "/usr/local/lib/gpsman/gmsrc", # new FreeBSD location (since 2014)
		       "/usr/local/share/gpsman/gmsrc", # old FreeBSD location (until 2014)
		      ) {
	if (-d $candidate) {
	    @gmicons = File::Glob::bsd_glob("$candidate/gmicons/*15x15.gif");
	    if (@gmicons) {
		if ($gmicons_ref) {
		    @$gmicons_ref = @gmicons;
		}
		return $candidate;
	    }
	}
    }

    undef;
}

1;

__END__

=head1 NAME

GPS::Symbols::Garmin - map Garmin symbol ids to images

=head1 SYNOPSIS

    use GPS::Symbols::Garmin;
    my $symbol_to_img_mapping = GPS::Symbols::Garmin::get_symbol_to_img();

=head1 DESCRIPTION

B<GPS::Symbols::Garmin> provides a mapping of Garmin symbol ids to
image pathnames. The standard images must be provided by gpsman (see
L<http://gpsman.sourceforge.net/> and
L<https://sourceforge.net/projects/gpsman/>). The user-defined symbols
are provided by F<misc/garmin_userdef_symbols/>.

There are two functions:

=over

=item get_symbol_to_img()

Return the hashref Garmin symbol id to image pathname.

=item get_cached_symbol_to_img()

Like L</get_symbol_to_img>, but cache and re-use the result.

=back

=head1 AUTHOR

Slaven Rezic

=head1 SEE ALSO

L<gpsman(1)>.

=cut
