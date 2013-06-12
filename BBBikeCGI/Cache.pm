# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2012,2013 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

use strict;

{
package BBBikeCGI::Cache;

use vars qw($VERSION);
$VERSION = '0.02';

my %CACHEINTERVAL = (
		     weekly => 86400*7,
		     daily  => 86400,
		     hourly => 3600,
		    );

# $datadir:     $Strassen::datadirs[0]
# $cacheprefix: $Strassen::Util::cacheprefix
sub new {
    my($class, $datadir, $cacheprefix, $cacheperiod) = @_;
    $cacheprefix or die "cacheprefix is missing";
    my $basedir = "/tmp/bbbike-cgicache-$</$cacheprefix";

    my $modified_file = "$datadir/.modified";
    my(@stat) = stat $modified_file;
    if ($stat[9]) {
	$basedir .= "/" . $stat[9];
    } else {
	warn "Cannot open $modified_file ($!), fallback to '0'";
	$basedir .= "/0";
    }

    my $rootdir = $basedir;
    if ($cacheperiod) {
	$rootdir .= '_' . $class->cacheperiod_to_timestamp($cacheperiod);
    }

    if (!-d $rootdir) {
	require File::Path;
	File::Path::mkpath($rootdir);
	if (!-d $rootdir) {
	    die "Can't create $rootdir: $!";
	}
    }

    bless {
	   basedir     => $basedir,
	   rootdir     => $rootdir,
	   cacheperiod => $cacheperiod,
	  }, $class;
}

sub get_entry {
    my($self, $q) = @_;
    BBBikeCGI::Cache::Entry->new($self, $q);
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
    my $previous_rootdir = $self->previous_rootdir;
    my $previous_rootbase;
    if ($previous_rootdir) {
	$previous_rootbase = File::Basename::basename($previous_rootdir);
    }
    my $uprootdir = File::Basename::dirname($rootdir);
    opendir my $DIR, $uprootdir
	or die "Can't open $uprootdir: $!";
    my $count_success = 0;
    my $count_error = 0;
    while(defined(my $file = readdir $DIR)) {
	next if $file eq '.' || $file eq '..';
	next if $file eq $rootbase; # keep the current one
	next if $previous_rootbase && $file eq $previous_rootbase; # keep also the previous rootbase
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

sub previous_rootdir {
    my $self = shift;
    my $previous_rootdir = $self->{previous_rootdir};
    if (defined $previous_rootdir) {
	if ($previous_rootdir) {
	    return $previous_rootdir;
	} else {
	    # defined but false
	    return undef;
	}
    }
    if ($self->has_cacheperiod) {
	$previous_rootdir = $self->{basedir} . '_' . $self->previous_timestamp;
	if (!-d $previous_rootdir) {
	    undef $previous_rootdir;
	}
    }
    if ($previous_rootdir) {
	$self->{previous_rootdir} = $previous_rootdir;
    } else {
	$self->{previous_rootdir} = 0; # defined but false
	undef;
    }
}

sub has_cacheperiod { defined shift->{cacheperiod} }

sub previous_timestamp {
    my $self = shift;
    my $cacheperiod = $self->{cacheperiod};
    my $timestamp = $self->cacheperiod_to_timestamp($cacheperiod);
    $timestamp - $CACHEINTERVAL{$cacheperiod};
}

######################################################################
# CLASS METHODS

sub cacheperiod_to_timestamp {
    my(undef, $cacheperiod) = @_;
    my $cacheinterval = $CACHEINTERVAL{$cacheperiod};
    if ($cacheinterval) {
	int(time / $cacheinterval) * $cacheinterval;
    } else {
	die "Invalid cacheperiod '$cacheperiod'";
    }
}

}

######################################################################
{
    package BBBikeCGI::Cache::Entry;

    sub new {
	my($class, $cache, $q) = @_;
	require Digest::MD5;
	bless {
	       cache  => $cache,
	       q      => $q,
	       digest => Digest::MD5::md5_hex($q->query_string),
	      }, $class;
    }

    sub digest { shift->{digest} }
    sub cache  { shift->{cache} }

    sub base {
	my $self = shift;
	return $self->{base} if $self->{base};
	$self->cache->rootdir . '/' . $self->digest;
    }

    # Side-effect: cache 'base' member
    sub exists_content {
	my $self = shift;
	my $digest = $self->digest;

	my $check_digest_files = sub {
	    my $dir = shift;
	    my $base = $dir . "/" . $digest;
	    my $content_file = $base . ".content";
	    if (-e $content_file) {
		my $meta_file = $base . ".meta";
		if (-e $meta_file) {
		    return $base;
		}
	    }
	    undef;
	};

	my $base;

	$base = $check_digest_files->($self->cache->rootdir);
	if (!$base) {
	    my $previous_rootdir = $self->cache->previous_rootdir;
	    if ($previous_rootdir) {
		$base = $check_digest_files->($previous_rootdir);
		return 0 if !$base;
	    } else {
		return 0;
	    }
	}

	$self->{base} = $base;
	1;
    }

    # prereq: a call to exists_content before
    sub get_meta {
	my $self = shift;
	my $base = $self->base;
	my $meta_file = $base . ".meta";
	require Storable;
	my $meta = eval { Storable::retrieve($meta_file) };
	if ($@) {
	    warn "Can't retrieve $meta_file: $!";
	}

	$meta;
    }

    sub stream_content {
	my($self, $ofh) = @_;
	$ofh = \*STDOUT if !$ofh;
	my $base = $self->base;
	my $content_file = $base . ".content";
	if (open my $fh, $content_file) {
	    local $/ = \4096;
	    while(<$fh>) {
		print $ofh $_;
	    }
	} else {
	    warn "Can't open $content_file: $!";
	}
    }

    sub put_content {
	my($self, $content, $meta) = @_;
	my $base = $self->base;

	my $content_file;
	if (defined $content) {
	    $content_file = $base . ".content";
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
	}

	my $meta_file;
	if (defined $meta) {
	    $meta_file = $base . ".meta";
	    require Storable;
	    eval { Storable::nstore($meta, "$meta_file.$$") };
	    if ($@) {
		warn "Error while writing $meta_file.$$: $!";
		return;
	    }
	}

	if (defined $content_file) {
	    if (!rename "$content_file.$$", $content_file) {
		warn "Error while renaming $content_file.$$ to $content_file: $!";
		return;
	    }
	}

	if (defined $meta_file) {
	    if (!rename "$meta_file.$$", $meta_file) {
		warn "Error while renaming $meta_file.$$ to $meta_file: $!";
		return;
	    }
	}

	1;
    }

    sub get_content_filename {
	my($self) = @_;
	my $digest = $self->digest;
	my $rootdir = $self->cache->rootdir;
	$rootdir . "/" . $digest . ".content";
    }

}

1;

__END__
