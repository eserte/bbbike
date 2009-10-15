# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2009 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

package BBBikeSuggest;

use strict;
use vars qw($VERSION);
$VERSION = '0.01';

use Tk::PathEntry 2.17;

sub new {
    my($class, %args) = @_;
    my $self = bless {
		      enabled => 0, # disabled until zipfile is set
		     }, $class;
    $self;
}

sub set_zipfile {
    my($self, $zip_file) = @_;
    die "Please provide zipfile" if !$zip_file;
    $self->{zip_file} = $zip_file;
    $self->scan_zip_file;
    $self->{enabled} = 1;
}

sub suggest_widget {
    my($self, $parent, %args) = @_;
    my $selectcmd = delete $args{'-selectcmd'};
    die "Unhandled args: " . join(' ', %args) if %args;
    my $sw;
    $sw = $parent->PathEntry
	(-autocomplete => 1,
	 -choicescmd => sub {
	     my($w, $pathname) = @_;
	     $self->get_street_choices($w, $pathname);
	 },
	 -isdircmd => sub { 0 },
	 -selectcmd => sub {
	     $sw->Finish if $sw->can('Finish');
	     if ($selectcmd) {
		 $selectcmd->($sw);
	     }
	 },
	);
    $sw;
}

sub scan_zip_file {
    my $self = shift;
    my $ZIP;
    if ($] < 5.006) { require Symbol; Symbol::gensym() }
    if (open($ZIP, $self->{zip_file})) {
	while(<$ZIP>) {
	    my $zip_firstch = lc substr($_, 0, 1);
	    if (!exists $self->{zip_firstch}{$zip_firstch}) {
		$self->{zip_firstch}{$zip_firstch} = tell($ZIP)-length($_);
	    }
	}
	seek($ZIP,0,0);
    } else {
	warn "Can't open zip file $self->{zip_file}: $!";
    }
    $self->{ZIP} = $ZIP;
}

sub disable { shift->{enabled} = 0 }
sub enable  { shift->{enabled} = 1 }

sub get_street_choices {
    my($self, $w, $pathname) = @_;
    return if !$self->{enabled};
    my $ZIP = $self->{ZIP};
    my $zip_firstch = lc substr($pathname, 0, 1);
    if (exists $self->{zip_firstch}{$zip_firstch}) {
	seek $ZIP, $self->{zip_firstch}{$zip_firstch}, 0;
    }
    my $conv = sub {
	my(@s) = split(/\|/,$_[0]);
	if (defined $s[3] && $s[3] ne "") {
	    "$s[0] ($s[1])";
	} else {
	    undef;
	}
    };
    my @f;
    local $_;
    while(<$ZIP>) {
	if (/^\Q$pathname/i) {
	    chomp;
	    my $s = $conv->($_);
	    push @f, $s if defined $s;
	    last;
	}
    }
    while(<$ZIP>) {
	chomp;
	my $s = $conv->($_);
	push @f, $s if defined $s && (!@f || $s ne $f[-1]);
	last if @f >= 10;
    }
    \@f;
}

1;

__END__

=head1 NAME

BBBikeSuggest - suggest-like entry for street names

=head1 SYNOPSIS

    use BBBikeSuggest;
    use Tk;
    $suggest = BBBikeSuggest->new;
    $suggest->set_zipfile(".../bbbike/data/Berlin.coords.data");
    $mw = tkinit;
    $w = $suggest->suggest_widget($mw, -selectcmd => sub { ... });
    $w->pack;
    MainLoop;

=head1 AUTHOR

Slaven Rezic

=head1 SEE ALSO

L<Tk::PathEntry>.

=cut
