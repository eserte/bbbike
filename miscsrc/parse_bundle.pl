#!/usr/bin/env perl
# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2015,2017,2018 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

use strict;
use warnings;
use Getopt::Long;
use List::Util qw(max);

{
    package Bundle2Task;
    use base 'Pod::Simple';
    use strict;
    our $VERSION = '1.02';

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

    sub minimize {
	my $self = shift;

	my @contents = @{ $self->{MODULEDEFS} };

	require Parse::CPAN::Packages::Fast;
	require Tie::IxHash;
	my $pcpf = Parse::CPAN::Packages::Fast->new;
	tie my %seen, 'Tie::IxHash';
	my %found_primary_mod;
	for my $moddef (@contents) {
	    my $m = $pcpf->package($moddef->[0]);
	    if ($m) {
		my $d = $m->distribution;
		my $distvname = $d->distvname;
		if (!$found_primary_mod{$distvname}) {
		    (my $modname2dist = $moddef->[0]) =~ s{::}{-}g;
		    my $is_primary_mod = $modname2dist eq $d->dist;
		    if ($is_primary_mod) {
			$seen{$distvname} = $moddef;
			$found_primary_mod{$distvname} = 1;
		    } elsif ($seen{$distvname}) {
			if (length $moddef->[0] < length $seen{$distvname}->[0]) {
			    $seen{$distvname} = $moddef;
			}
		    } else {
			$seen{$distvname} = $moddef;
		    }
		}
	    }
	}

	@contents = ();
	for my $k (keys %seen) {
	    push @contents, $seen{$k};
	}

	$self->{MODULEDEFS} = \@contents;
    }
}

sub usage (;$) {
    my $msg = shift;
    require Pod::Usage;
    Pod::Usage::pod2usage({
	(-message => $msg) x!! defined $msg,
	-exitval => 2,
    });
}

my $action = 'list';
my $encoding;
my $minimize;
my $sorted;
my $version_less;
my @ignore_modules;
GetOptions(
	   'action=s' => \$action,
	   'encoding=s' => \$encoding,
	   'minimize' => \$minimize,
	   'sorted' => \$sorted,
	   'version-less' => \$version_less,
	   'ignore|ignore-modules=s@' => \@ignore_modules,
	   'help|?' => sub {
	       require Pod::Usage;
	       Pod::Usage::pod2usage(1);
	   },
	  )
    or usage;
my $bundle_file = shift
    or usage "Bundle file is missing";
@ARGV
    and usage "Too many arguments";

my $converter = Bundle2Task->new;
$converter->parse_file($bundle_file);
if ($minimize) {
    $converter->minimize;
}
my @contents = @{ $converter->get_module_defs || [] };
if (@ignore_modules) {
    my %ignore_modules = map {($_,1)} @ignore_modules;
    @contents = grep { !$ignore_modules{$_->[0]} } @contents;
}
if ($sorted) {
    @contents = sort { $a->[0] cmp $b->[0] } @contents;
}

if ($action eq 'list') {
    for (@contents) {
	print $_->[0], "\n";
    }
} elsif ($action eq 'prereq_pm') {
    if ($encoding) {
	binmode STDOUT => ":encoding($encoding)";
    }
    my $maxlen = max map { length $_->[0] } @contents;
    for (@contents) {
	my($mod, $ver, $desc) = @$_;
	print "\t";
	printf '%-' . ($maxlen+2) . 's', "'$mod'";
	print ' => ';
	if ($version_less || !defined $ver || $ver eq 'undef') { print 0 } else { print $ver }
	print ",";
	if (defined $desc) {
	    $desc =~ s{\s+}{ }g; # especially remove newlines
	    print " # $desc";
	}
	print "\n";
    }
} elsif ($action eq 'dump') {
    require Data::Dumper;
    print Data::Dumper::Dumper(\@contents);
} else {
    die "Invalid action '$action'";
}

__END__

=head1 NAME

parse_bundle.pl - parse a CPAN Bundle file and output contained modules

=head1 SYNOPSIS

    parse_bundle.pl [--encoding ...] [--minimize] [--sorted] [--ignore ...] [--action list|prereq_pm|dump] /path/to/Bundle.pm

=head1 DESCRIPTION

Parse a CPAN Bundle file and output contained modules. May be used as
a frontend for L<make_task.pl>.

=head2 OPTIONS

=over

=item C<-action I<action>>

How to output the list of modules. Default is C<list>. The following
actions are known:

=over

=item C<list>

Just list the modules.

=item C<prereq_pm>

Output lines for L<ExtUtils::MakeMaker>'s C<PREREQ_PM> section,
suitable for inclusion in C<Makefile.PL> files.

=item C<dump>

Create a L<Data::Dumper> dump.

=back

=item C<--encoding I<encoding>>

Output encoding, only used with C<prereq_pm> action.

=item C<--minimize>

Only output a "principal" module per CPAN distribution. If a module is
named after the distribution, then this module is preferred.
Otherwise, the shorted module name is picked.

=item C<--sorted>

Sort the list of modules.

=item C<--ignore I<module>>

Ignore the specified module (may be specified multiple times).

=back

=head1 AUTHOR

Slaven Rezic

=head1 SEE ALSO

L<make_task.pl>.

=cut
