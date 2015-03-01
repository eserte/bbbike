#!/usr/bin/perl -w
# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2015 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

use strict;
use Getopt::Long;
use List::Util qw(max);

{
    package Bundle2Task;
    use base 'Pod::Simple';
    use strict;
    our $VERSION = '1.01';

    sub new {
	my($class, @opts) = @_;
	my $parser = $class->SUPER::new(@opts);
	$parser->{MODULEDEFS} = [];
	$parser;
    }

    sub _handle_element_start {
	my($parser, $element_name) = @_;
	if ($element_name eq 'head1') {
	    $parser->{INHEAD} = 1;
	}
    }

    sub _handle_element_end {
        my($parser, $element_name, $attr_hash_r) = @_;
	$parser->{INHEAD} = 0;
    }

    sub _handle_text {
	my($parser, $text) = @_;
	if ($parser->{INHEAD}) {
	    if ($text eq 'CONTENTS') {
		$parser->{INCONTENTS} = 1;
	    } else {
		$parser->{INCONTENTS} = 0;
	    }
	} elsif ($parser->{INCONTENTS}) {
	    $text =~ s{^(\S+)\s*}{};
	    my($mod, $modver, $desc);
	    if ($1) {
		$mod = $1;
		if ($text !~ m{^\s*$}) {
		    if ($text !~ m{^-}) {
			$text =~ s{^(\S+)\s*}{};
			$modver = $1;
		    }
		    $text =~ s{^-\s*}{};
		    if ($text !~ m{^\s*$}) {
			$desc = $text;
		    }
		}
	    }
	    push @{ $parser->{MODULEDEFS} }, [$mod, $modver, $desc];
	}
    }

    sub get_module_defs {
	shift->{MODULEDEFS};	
    }
}

my $action = 'list';
my $encoding;
GetOptions(
	   'action=s' => \$action,
	   'encoding=s' => \$encoding,
	  )
    or die "usage?";
my $bundle_file = shift or die "Bundle file?";

my $converter = Bundle2Task->new;
$converter->parse_file($bundle_file);
my $contents = $converter->get_module_defs;

if ($action eq 'list') {
    for (@$contents) {
	print $_->[0], "\n";
    }
} elsif ($action eq 'prereq_pm') {
    if ($encoding) {
	binmode STDOUT => ":encoding($encoding)";
    }
    my $maxlen = max map { length $_->[0] } @$contents;
    for (@$contents) {
	my($mod, $ver, $desc) = @$_;
	print "\t";
	printf '%-' . ($maxlen+2) . 's', "'$mod'";
	print ' => ';
	if (defined $ver) { print $ver } else { print 0 }
	print ",";
	if (defined $desc) {
	    $desc =~ s{\s+}{ }g; # especially remove newlines
	    print " # $desc";
	}
	print "\n";
    }
} elsif ($action eq 'dump') {
    require Data::Dumper;
    print Data::Dumper::Dumper($contents);
} else {
    die "Invalid action '$action'";
}

__END__
