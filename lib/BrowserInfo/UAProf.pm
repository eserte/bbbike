# -*- perl -*-

#
# $Id: UAProf.pm,v 1.7 2008/02/02 17:26:19 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2005,2010 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

package BrowserInfo::UAProf;

use strict;
use vars qw($VERSION $DEBUG);
$VERSION = sprintf("%d.%02d", q$Revision: 1.7 $ =~ /(\d+)\.(\d+)/);

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
    if (-r $self->{uaprofdb} && eval { require DB_File; 1 }) {
	if (tie my %db, "DB_File", $self->{uaprofdb}, &Fcntl::O_RDONLY, 0644) {
	    if (exists $db{$cap}) {
		$self->{cached}{$cap} = $db{$cap};
		return $self->{cached}{$cap};
	    }
	} else {
	    warn "Can't open $self->{uaprofdb}: $!, cannot use cached value...";
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
	# To prevent the
	# "Parsing of undecoded UTF-8 will give garbage when decoding entities at /usr/share/perl5/LWP/Protocol.pm line 137."
	# errors.
	$ua->parse_head(0);
	$self->{ua} = $ua;
    }
    my $resp = $ua->get($self->{uaprofurl});
    if (!$resp->is_success) {
	die "While fetching $self->{uaprofurl}: " . $resp->content;
    }

    my $tmp_uaproffile = "$self->{uaproffile}.$$";
    open(UAPROFFILE, "> $tmp_uaproffile") or
	die "Can't write to $tmp_uaproffile: $!";
    binmode UAPROFFILE;
    print UAPROFFILE $resp->content;
    close UAPROFFILE
	or die "While writing to $tmp_uaproffile: $!";
    rename $tmp_uaproffile, $self->{uaproffile}
	or die "Can't rename $tmp_uaproffile to $self->{uaproffile}: $!";

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
    $self->{p_path} = [];
    $self->{p_look_for} = $cap;
    my $sax_parser;
    if (eval { require XML::LibXML::SAX; 1 }) {
	$sax_parser = 'XML::LibXML::SAX';
    } elsif (eval { require XML::SAX::PurePerl; 1 }) {
	$sax_parser = 'XML::SAX::PurePerl';
    }
    if (!$sax_parser) {
	require XML::Parser;
	my $p = XML::Parser->new
	    (Handlers => {Start => sub { $self->p_start_tag(@_) },
			  End   => sub { $self->p_end_tag(@_) },
			  Char  => sub { $self->p_char(@_) },
			 }
	    );
	$p->parsefile($self->{uaproffile});
    } else {
	{
	    package BrowserInfo::UAProf::SAXHandler;
	    sub new {
		my $class = shift;
		bless { @_ }, $class;
	    }
	    sub start_element {
		my($self, $el) = @_;
		$self->{P}->p_start_tag(undef, $el->{Name}, %{$el->{Attributes}});
	    }
	    sub end_element {
		my($self, $el) = @_;
		$self->{P}->p_end_tag(undef, $el->{Name});
	    }
	    sub characters {
		my($self, $el) = @_;
		$self->{P}->p_char(undef, $el->{Data});
	    }
	}
	my $p = $sax_parser->new
	    (Handler => BrowserInfo::UAProf::SAXHandler->new(P => $self));
	open(UAPROF, $self->{uaproffile}) or die $!;
	$p->parse_file(\*UAPROF);
	close UAPROF;
    }
}

sub p_start_tag {
    my($self, $expat, $elem, %attr) = @_;
    push @{ $self->{p_path} }, { element => $elem,
				 attributes => \%attr ,
			       };
    $self->{p_char} = "";
}

sub p_end_tag {
    my($self, $expat, $elem) = @_;
    my $char = $self->{p_char};
    warn "$elem $char\n" if $DEBUG;
    if ($self->{p_path}[-1]{element} eq 'prf:' . $self->{p_look_for}) {
	warn "got it!\n" if $DEBUG;
	$self->{cached}{$self->{p_look_for}} = $char;
    }
    pop @{ $self->{p_path} };
}

sub p_char {
    my($self, $expat, $char) = @_;
    $char =~ s/^\s+//;
    $char =~ s/\s+$//; # XXX?
    $self->{p_char} .= $char;
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
require Getopt::Long;

my %OPT;
Getopt::Long::GetOptions(\%OPT, "d|debug!") or die "usage: $0 [-d] profile-url capability";

if ($OPT{d}) { $DEBUG = 1 }

my $uaprofurl = shift || die "UAProf URL?";
my $cap = shift || die "Capability?";
my $uaprof = __PACKAGE__->new
    (uaprofurl => $uaprofurl,
     uaprofdir => File::Spec->rel2abs(File::Basename::dirname(__FILE__)) . "/../../tmp/uaprof",
    );
my $ret = eval { $uaprof->get_cap($cap) };
warn $@ if $DEBUG && $@;
if (!defined $ret) {
    $ret = "<undefined>";
}
print $ret, "\n";

__END__
