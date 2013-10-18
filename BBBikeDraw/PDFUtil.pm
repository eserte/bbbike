# -*- mode:perl; coding:iso-8859-1; -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2011,2013 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

package BBBikeDraw::PDFUtil;

# "Mixin" methods for BBBikeDraw::PDF*

use strict;
use vars qw($VERSION);
$VERSION = '0.01';

# Check if a pdf compressing tool like pdftk is available, and setup
# everything for using later flush_compress(). Call this in the init()
# method of the BBBikeDraw::PDF* class.
sub init_compress {
    my($self) = @_;

    if ($self->{Compress}) {
	require BBBikeUtil;
	if (BBBikeUtil::is_in_path("pdftk")) {
	    $self->{_CompressTool} = "pdftk";
	} elsif (0 && eval { require PDF::API2; require File::Temp; 1 }) {# XXX does not work, see below XXX
	    $self->{_CompressTool} = "PDF::API2";
	} elsif (eval { require CAM::PDF; require File::Temp; 1 }) {
	    $self->{_CompressTool} = "CAM::PDF";
	} else {
	    warn "No pdftk in PATH available, don't compress...";
	    undef $self->{Compress};
	}
	if ($self->{_CompressTool}) {
	    require File::Temp;
	    my($fh,$filename) = File::Temp::tempfile(SUFFIX => ".pdf", UNLINK => 1);
	    die "Cannot create temporary file: $!" if !$filename;
	    $self->{_CompressOriginalFilename} = $self->{Filename};
	    $self->{_CompressTemporaryFilename} = $filename;
	    $self->{Filename} = $filename;
	}
    }
}

# If compression was setup in init_compress(), then do steps to
# finalize the compression.
# 
# Named parameters:
#   -v => 1: be verbose
sub flush_compress {
    my($self, %args) = @_;

    if ($self->{Compress}) {
	my $VERBOSE = delete $args{-v};

	my $compress_message = sub {
	    my($before, $after) = @_;
	    $before = ref $before ? $$before : -s $before;
	    $after  = ref $after  ? $$after  : -s $after;
	    "Compressed " . (100-int(100*($after)/($before))) .
		"% (original " . ($before) . " bytes, compressed " . ($after) . " bytes)...\n";
	};

	if ($self->{_CompressTool} eq 'pdftk') {
	    if (defined $self->{_CompressOriginalFilename}) {
		system("pdftk", $self->{Filename}, "output", $self->{_CompressOriginalFilename}, "compress");
		warn eval { $compress_message->($self->{Filename}, $self->{_CompressOriginalFilename}) }
		    if $VERBOSE;
		unlink $self->{_CompressTemporaryFilename};
	    } else {
		require File::Temp;
		my($fh,$filename) = File::Temp::tempfile(SUFFIX => ".pdf", UNLINK => 1);
		system("pdftk", $self->{Filename}, "output", $filename, "compress");
		seek $fh, 0, 0;
		local $/ = \4096;
		my $ofh = $self->{Fh};
		while(<$fh>) {
		    print $ofh $_;
		}
		close $fh;
		warn eval { $compress_message->($self->{Filename}, $filename) }
		    if $VERBOSE;
		unlink $filename;
		unlink $self->{_CompressTemporaryFilename};
	    }
	} elsif ($self->{_CompressTool} eq 'PDF::API2') {
	    # XXX Does not work!!!
	    my $pdf = PDF::API2->open($self->{Filename});
 	    my $page = $pdf->openpage(1)
 		or die "Cannot open page 1";
	    $page->fixcontents;
	    # XXX Especially this part does not work
 	    warn("compressing"),$_->compressFlate for $page->{Contents}->elementsof;
	    if (defined $self->{_CompressOriginalFilename}) {
		$pdf->saveas($self->{_CompressOriginalFilename});
		warn eval { $compress_message->($self->{Filename}, $self->{_CompressOriginalFilename}) }
		    if $VERBOSE;
	    } else {
		my $ofh = $self->{Fh};
		my $pdf_contents = $pdf->stringify;
		print $ofh $pdf_contents;
		warn eval { $compress_message->($self->{Filename}, \length $pdf_contents) }
		    if $VERBOSE;
	    }
	    unlink $self->{_CompressTemporaryFilename};
	} elsif ($self->{_CompressTool} eq 'CAM::PDF') {
	    my $pdf = CAM::PDF->new($self->{Filename});
	    # XXX It's purely coincidence that the map drawing is objnum=3
	    # XXX But how to get it reliably?
	    $pdf->encodeObject(3, 'FlateDecode');
	    $pdf->clean;
	    if (defined $self->{_CompressOriginalFilename}) {
		$pdf->output($self->{_CompressOriginalFilename});
		warn eval { $compress_message->($self->{Filename}, $self->{_CompressOriginalFilename}) }
		    if $VERBOSE;
	    } else {
		my $ofh = $self->{Fh};
		my $pdf_contents = $pdf->toPDF;
		print $ofh $pdf_contents;
		warn eval { $compress_message->($self->{Filename}, \length $pdf_contents) }
		    if $VERBOSE;
	    }
	    unlink $self->{_CompressTemporaryFilename};
	} else {
	    die "Unhandled compression tool <$self->{_CompressTool}>";
	}
    }
}

1;

__END__

=head1 NAME

BBBikeDraw::PDFUtil - pdf utilities for BBBike map creation

=head1 SYNOPSIS

   package BBBikeDraw::PDF...;
   use BBBikeDraw::PDFUtil ();

   sub init {
       ...
       $self->init_compress;
       ...
   }

   sub flush {
       ...
       $self->flush_compress;
       ...
   }

=head2 COMPRESSION

Some benchmarks and data about using compression together with
L<BBBikeDraw::PDFCairo>. The following cmdlines

    perl5.12.3 ./miscsrc/bbbikedraw.pl -compress -routefile /tmp/diagonal.bbr -routelist -drawtypes all -imagetype pdf -module PDFCairo -o ...
    perl5.12.3 ./miscsrc/bbbikedraw.pl -nocompress -routefile /tmp/diagonal.bbr -routelist -drawtypes all -imagetype pdf -module PDFCairo -o ...

with diaginal.bbr, which is a route diagonally across Berlin's center
(approx. Jungfernheide - Köllnische Heide) takes

    6.7..7.0s wallclock time with -nocompress
    10.2..11.1s wallclock time with pdftk compression enabled

As L<Cairo> already does some compression, the saved ratio is not so
high: 1380696 vs. 1575675 bytes, so some 12% savings.

With C<-module PDF> (using L<BBBikeDraw::PDF>) the timings are:

    8.3..8.6s wallclock time with -nocompress
    8.9..9.4s wallclock time with pdftk compression enabled

Here the time difference is not so large, but savings are much higher:
513825 vs. 2355866 bytes.

=cut
