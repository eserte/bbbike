# -*- perl -*-

#
# $Id: UAProf.pm,v 1.3 2005/01/02 18:16:47 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2005 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

package BrowserInfo::UAProf;

use strict;
use vars qw($VERSION);
$VERSION = sprintf("%d.%02d", q$Revision: 1.3 $ =~ /(\d+)\.(\d+)/);

sub new {
    my($class, %args) = @_;
    my $self = bless {}, $class;
    $self->{uaprofdir} = delete $args{uaprofdir} || "/tmp";
    $self->{uaprofurl} = delete $args{uaprofurl} || $self->get_prof_url || die "No Profile HTTP header available";
    $self->{ua} = delete $args{ua};
    die "Unhandled arguments: " . join(" ", %args) if %args;
    #dump_header(); # XXX
    $self;

}

sub get_prof_url {
    my($self) = @_;
    my $uaprofurl;
    if ($ENV{HTTP_X_WAP_PROFILE}) {
	($uaprofurl = $ENV{HTTP_X_WAP_PROFILE}) =~ s/^\"//;
	$uaprofurl =~ s/\"$//;
	$uaprofurl;
    } elsif ($ENV{HTTP_PROFILE}) {
	$uaprofurl = $ENV{HTTP_PROFILE};
    } else {
	undef;
    }
}

sub get_cap {
    my($self, $cap) = @_;

    if (exists $self->{cached}{$cap}) {
	return $self->{cached}{$cap};
    }

    require File::Basename;
    require File::Spec;
    my $path = $self->{uaprofurl};
    $path =~ s{^(ftp|https?)://}{};
    $path = File::Spec->catdir($self->{uaprofdir},
			       File::Spec->no_upwards(File::Spec->splitdir($path)));
    if (!-e File::Basename::dirname($path)) {
	require File::Path;
	File::Path::mkpath([File::Basename::dirname($path)], 0, 0777);
    }
    
    $self->{uaprofdb} = $path . ".db";
    if (-r $self->{uaprofdb}) {
	require DB_File;
	tie my %db, "DB_File", $self->{uaprofdb}, &Fcntl::O_RDONLY, 0644
	    or die "Can't open $self->{uaprofdb}: $!";
	if (exists $db{$cap}) {
	    $self->{cached}{$cap} = $db{$cap};
	    return $self->{cached}{$cap};
	}
    }

    $self->{uaproffile} = $path;
    if (-r $self->{uaproffile}) {
	$self->parse_xml($cap);
	return $self->cache_and_get($cap);
    }

    require LWP::UserAgent;
    my $ua = $self->{ua};
    if (!$ua) {
	$ua = LWP::UserAgent->new;
	$ua->timeout(5); # keep it short
	$self->{ua} = $ua;
    }
    my $resp = $ua->get($self->{uaprofurl});
    if (!$resp->is_success) {
	die "While fetching $self->{uaprofurl}: " . $resp->content;
    }

    open(UAPROFFILE, "> $self->{uaproffile}") or
	die "Can't write to $self->{uaproffile}: $!";
    binmode UAPROFFILE;
    print UAPROFFILE $resp->content;
    close UAPROFFILE;

    $self->parse_xml($cap);
    $self->cache_and_get($cap);
}

sub cache_and_get {
    my($self, $cap) = @_;
    if (exists $self->{cached}{$cap}) {
	my $old_umask = umask 0;
	eval {
	    require DB_File;
	    tie my %db, "DB_File", $self->{uaprofdb}, &Fcntl::O_RDWR|&Fcntl::O_CREAT, 0666
		or die "Can't write to $self->{uaprofdb}: $!";
	    $db{$cap} = $self->{cached}{$cap};
	};
	warn $@ if $@;
	umask $old_umask;
	return $self->{cached}{$cap};
    } else {
	return;
    }
}

sub parse_xml {
    my($self, $cap) = @_;
    use XML::Parser;
    my $p = XML::Parser->new
	(Handlers => {Start => sub { $self->p_start_tag(@_) },
		      End   => sub { $self->p_end_tag(@_) },
		      Char  => sub { $self->p_char(@_) },
		     }
	);
    $self->{p_path} = [];
    $self->{p_look_for} = $cap;
    $p->parsefile($self->{uaproffile});
}

sub p_start_tag {
    my($self, $expat, $elem, %attr) = @_;
    push @{ $self->{p_path} }, { element => $elem,
				 attributes => \%attr ,
			       };
}

sub p_end_tag {
    my($self, $expat, $elem) = @_;
    pop @{ $self->{p_path} };
}

sub p_char {
    my($self, $expat, $char) = @_;
    if ($self->{p_path}[-1]{element} eq 'prf:' . $self->{p_look_for}) {
	$self->{cached}{$self->{p_look_for}} = $char;
    }
}

sub dump_header {
    while(my($k,$v) = each %ENV) {
	next if $k !~ /^HTTP_(.*)/;
	print STDERR "$1: $v\n";
    }
}

return 1 if caller;

# Example: perl UAProf.pm http://nds.nokia.com/uaprof/N6100r100.xml ScreenSize

require File::Spec;
require File::Basename;

my $uaprofurl = shift || die "UAProf URL?";
my $cap = shift || die "Capability?";
my $uaprof = __PACKAGE__->new
    (uaprofurl => $uaprofurl,
     uaprofdir => File::Spec->rel2abs(File::Basename::dirname(__FILE__)) . "/../../tmp/uaprof",
    );
print $uaprof->get_cap($cap), "\n";

__END__
