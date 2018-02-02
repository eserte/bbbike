#!/usr/bin/env perl
# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2015,2017 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

use strict;
use ExtUtils::MakeMaker ();
use FindBin;
use File::Path qw(mkpath);
use Getopt::Long;
use POSIX qw(strftime);

my $o;
my $bundle;
my $name;
my $minimize;
my $debug;
GetOptions(
	   "o=s"      => \$o,
	   "bundle=s" => \$bundle,
	   "name=s"   => \$name,
	   "minimize" => \$minimize,
	   "debug!"   => \$debug,
	  )
    or die "usage?";

$o      or die "Please specify output directory (-o option)";
$bundle or die "Please specify bundle file (-bundle option)";
$name   or die "Please specify task name (-name option)";

my $prereq_pm;
{
    my @cmd = ($^X, "$FindBin::RealBin/parse_bundle.pl", ($minimize ? '-minimize' : ()), -encoding => 'utf-8', -action => 'prereq_pm', $bundle);
    open my $fh, "-|", @cmd
	or die "Error starting to run '@cmd': $!";
    binmode $fh, ':encoding(utf-8)';
    while(<$fh>) {
	$prereq_pm .= $_;
    }
    close $fh
	or die "Error while running '@cmd': $!";
}

if (!-e $o) {
    mkpath $o;
} else {
    if (!-d $o) {
	die "Output destination '$o' exists, but is not a directory";
    }
}

(my $pm_base = $name) =~ s{.*::}{};
$pm_base .= '.pm';

my $need_update = 0;
if (open my $fh, "$o/Makefile.PL") {
    my $in_prereq_pm;
    my $old_prereq_pm;
    while(<$fh>) {
	if ($in_prereq_pm) {
	    if (m<^\s*}>) {
		$in_prereq_pm = 0;
	    } else {
		$old_prereq_pm .= $_;
	    }
	} elsif (m{\bPREREQ_PM => }) {
	    $in_prereq_pm = 1;
	} elsif (m{\bNAME => '(.+?)'}) {
	    my $parsed_name = $1;
	    if ($parsed_name ne $name) {
		die "Parsed name in $o/Makefile.PL '$parsed_name' does not match given name '$name'";
	    }
	}
    }

    if ($prereq_pm ne $old_prereq_pm) {
	if ($debug) {
	    require Test::Differences;
	    require Test::More;
	    Test::More->import('no_plan');
	    Test::Differences::eq_or_diff($prereq_pm, $old_prereq_pm);
	}
	$need_update = 1;
    }
}

my $old_version;
if (-r "$o/$pm_base") {
    $old_version = MM->parse_version("$o/$pm_base");
}

if ($need_update || !defined $old_version) {
    my $version;
 TRY_VERSION: {
	for my $min_ver (0..99) {
	    my $new_version = strftime '%Y%m%d', localtime;
	    $new_version .= sprintf '.%02d', $min_ver;
	    if (!defined $old_version || $new_version > $old_version) {
		$version = $new_version;
		last TRY_VERSION;
	    }
	}
	die "Cannot find new version, conflicting with $old_version";
    }

    my $makefile_pl_contents = <<"EOF";
# Generated automatically by make_task.pl
use strict;
use ExtUtils::MakeMaker;
WriteMakefile(
    NAME => '$name',
    VERSION_FROM => '$pm_base',
    PREREQ_PM => {
$prereq_pm    },
);
EOF

    my $pm_contents = <<"EOF";
# Generated automatically by make_task.pl
package $name;
our \$VERSION = $version;
1;
EOF

    open my $ofh1, ">", "$o/Makefile.PL~"
	or die "Can't write to $o/Makefile.PL~: $!";
    print $ofh1 $makefile_pl_contents;
    close $ofh1
	or die "Error writing to Makefile.PL~: $!";

    open my $ofh2, ">", "$o/$pm_base~"
	or die "Can't write to $o/$pm_base~: $!";
    print $ofh2 $pm_contents;
    close $ofh2
	or die "Error writing to $pm_base~: $!";

    rename "$o/Makefile.PL~", "$o/Makefile.PL"
	or die "Error renaming to Makefile.PL: $!";
    print STDERR "Generated $o/Makefile.PL\n";

    rename "$o/$pm_base~", "$o/$pm_base"
	or die "Error renaming to $pm_base: $!";
    print STDERR "Generated $o/$pm_base\n";
} else {
    print STDERR "No changes.\n";
}

__END__
