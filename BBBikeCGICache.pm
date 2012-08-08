# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2012 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

package BBBikeCGICache;

use strict;
use vars qw($VERSION);
$VERSION = '0.01';

# $datadir:     $Strassen::datadirs[0]
# $cacheprefix: $Strassen::Util::cacheprefix
sub new {
    my($class, $datadir, $cacheprefix) = @_;
    $cacheprefix or die "cacheprefix is missing";
    my $rootdir = "/tmp/bbbike-cgicache-$</$cacheprefix";

    my $modified_file = "$datadir/.modified";
    my(@stat) = stat $modified_file;
    if ($stat[9]) {
	$rootdir .= "/" . $stat[9];
    } else {
	warn "Cannot open $modified_file ($!), fallback to '0'";
	$rootdir .= "/0";
    }

    if (!-d $rootdir) {
	require File::Path;
	File::Path::mkpath($rootdir)
		or die "Can't create $rootdir: $!";
    }

    bless { rootdir => $rootdir }, $class;
}

sub get_content {
    my($self, $q) = @_;
    my $digest = $self->make_digest($q);
    my $rootdir = $self->rootdir;
    my $content_file = $rootdir . "/" . $digest . ".content";
    my $content = do {
	if (open my $fh, $content_file) {
	    local $/;
	    <$fh>;
	} else {
	    warn "Can't open $content_file: $!";
	    undef;
	}
    };
    my $meta_file = $rootdir . "/" . $digest . ".meta";
    require Storable;
    my $meta = eval { Storable::retrieve($meta_file) };
    if ($@) {
	warn "Can't retrieve $meta_file: $!";
    }
    ($content, $meta);
}

sub exists_content {
    my($self, $q) = @_;
    my $digest = $self->make_digest($q);
    my $rootdir = $self->rootdir;
    my $content_file = $rootdir . "/" . $digest . ".content";
    if (-e $content_file) {
	my $meta_file = $rootdir . "/" . $digest . ".meta";
	if (-e $meta_file) {
	    return 1;
	}
    }
    0;
}

sub put_content {
    my($self, $q, $content, $meta) = @_;
    my $digest = $self->make_digest($q);
    my $rootdir = $self->rootdir;
    my $content_file = $rootdir . "/" . $digest . ".content";
    my $meta_file = $rootdir . "/" . $digest . ".meta";
    if (open my $ofh, ">", "$content_file.$$") {
	print $ofh $content;
	if (!close $ofh) {
	    warn "Error while closing $content_file.$$: $!";
	    return;
	}
    } else {
	warn "Can't write to $content_file: $!";
	return;
    }
    require Storable;
    eval { Storable::nstore($meta, "$meta_file.$$") };
    if ($@) {
	warn "Error while writing $meta_file.$$: $!";
	return;
    }

    if (!rename "$content_file.$$", $content_file) {
	warn "Error while renaming $content_file.$$ to $content_file: $!";
	return;
    }
    if (!rename "$meta_file.$$", $meta_file) {
	warn "Error while renaming $meta_file.$$ to $meta_file: $!";
	return;
    }

    1;
}

sub clean_cache {
    my $self = shift;
    my $rootdir = $self->rootdir;
    opendir my $DIR, $rootdir
	or die "Can't open $rootdir: $!";
    while(defined(my $file = readdir $DIR)) {
	next if $file eq '.' || $file eq '..';
	my $path = "$rootdir/$file";
	unlink $path
	    or warn "Cannot unlink $path: $!";
    }
}

sub clean_expired_cache {
    my $self = shift;
    require File::Basename;
    require File::Path;
    my $rootdir = $self->rootdir;
    my $rootbase = File::Basename::basename($rootdir);
    my $uprootdir = File::Basename::dirname($rootdir);
    opendir my $DIR, $uprootdir
	or die "Can't open $uprootdir: $!";
    my $count_success = 0;
    my $count_error = 0;
    while(defined(my $file = readdir $DIR)) {
	next if $file eq '.' || $file eq '..';
	next if $file eq $rootbase; # keep the current one
	if (!File::Path::rmtree("$uprootdir/$file")) {
	    $count_error++;
	    warn "Cannot rmtree $uprootdir/$file: $!";
	} else {
	    $count_success++;
	}
    }
    return {
	    count_success => $count_success,
	    count_errors  => $count_error,
	   };
}

sub rootdir { shift->{rootdir} }

sub make_digest {
    my(undef, $q) = @_;
    my $qs = $q->query_string;
    require Digest::MD5;
    Digest::MD5::md5_hex($qs);
}

1;

__END__
