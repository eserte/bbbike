# -*- perl -*-

#
# $Id: CommonMLDBM.pm,v 1.6 2002/07/13 21:07:04 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2000 Online Office Berlin. All rights reserved.
#
# Mail: slaven.rezic@berlin.de
# WWW:  http://bbbike.sourceforge.net
#

package CommonMLDBM;

use strict;
use vars qw($VERSION $target);
$VERSION = sprintf("%d.%02d", q$Revision: 1.6 $ =~ /(\d+)\.(\d+)/);

sub open {
    my %args = @_;
    my $hash;

    if (!defined $args{-RW})   { $args{-RW}   = 'r' }
    if (!defined $args{-Mode}) { $args{-Mode} = 0664 }

    # defaults
#$MLDBM::Serializer = 'FreezeThaw'; # too slow... even Data::Dumper is faster
    $MLDBM::Serializer = 'Data::Dumper';
    $MLDBM::UseDB      = 'DB_File';

    my @args;

    eval {
	require MLDBM;
	if (defined $target && $target eq 'herceg') {
	    require BerkeleyDB;
	    $MLDBM::UseDB = 'BerkeleyDB::Hash'; # to use version 2
	}

	if ($MLDBM::UseDB =~ /^BerkeleyDB::/) {
	    @args = ("-Filename", $args{-Filename},
		     "-Mode",     $args{-Mode},
		    );
	    if ($args{-RW} eq 'w') {
		push @args, "-Flags", &BerkeleyDB::DB_CREATE;
	    }
	} else {
	    eval q{
		   use Fcntl;
		   @args = ($args{-Filename},
			    ($args{-RW} eq 'r' ? O_RDONLY : O_CREAT|O_RDWR),
			    $args{-Mode},
			   );
		  };
	    die $@ if $@;
	}

	my $tied = tie %$hash, 'MLDBM', @args;
	if (!$tied) {
	    die "Can't open MLDBM file $args{-Filename} with db method <$MLDBM::UseDB>, serializer <$MLDBM::Serializer> and args <@args>: $!";
	}
    }; warn $@ if $@;
    goto OK if (!$@);

    # try it with Storable
    eval {
	die "Storable not supported with -RW eq 'w'"
	    if $args{-RW} eq 'w';
	require Storable;
	my $file = $args{-Filename};
	die "File $file not found" if (!-r $file);
	if ($file =~ /\.gz$/) {
	    require File::Basename;
	    my $dest = "/tmp/CommonMLDBM-" . File::Basename::basename($file);
	    if (!-e $dest || -M $dest < -M $file) {
		system("zcat $file > $dest");
	    }
	    $file = $dest;
	}
	warn "Storable::retrieve $file\n";
	$hash = Storable::retrieve($file);
    };
    goto OK if (!$@);

#      # Data::Dumper? is too slow
#      eval {
#  	die "Data::Dumper not supported with -RW eq 'w'"
#  	    if $args{-RW} eq 'w';
#  	my $file = $args{-Filename};
#  	if ($file =~ /\.gz$/) {
#  	    require File::Basename;
#  	    my $dest = "/tmp/CommonMLDBM-" . File::Basename::basename($file);
#  	    if (!-e $dest || -M $dest < -M $file) {
#  		system("zcat $file > $dest");
#  	    }
#  	    $file = $dest;
#  	}
#  #XXX no Safe/Opcode on iPAQ
#  	$hash=do $file;if (0) {
#  	require Safe;
#  	undef $CommonMLDBM::Data::hash;
#  	my $s = Safe->new("CommonMLDBM::Data");
#  	warn "rdo $file\n";
#  	$s->rdo($file);
#  	if (ref $CommonMLDBM::Data::hash ne 'HASH') {
#  	    die "Can't get hash reference from $file";
#  	}
#  	$hash = $CommonMLDBM::Data::hash;
#      }
#      }; warn $@ if $@;
#      goto OK if (!$@);

    die "Can't open file $args{-Filename}: $@";

 OK:
    $hash;
}

1;

__END__

=head1 NAME

CommonMLDBM - wrapper class to use the right MLDBM configuration

=head1 SYNOPSIS


=head1 DESCRIPTION

=head1 AUTHOR

Slaven Rezic - slaven.rezic@berlin.de

=head1 SEE ALSO

MLDBM(3).

=cut

