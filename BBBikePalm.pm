# -*- perl -*-

#
# $Id: BBBikePalm.pm,v 1.10 2003/11/18 23:37:20 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2000 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: eserte@cs.tu-berlin.de
# WWW:  http://user.cs.tu-berlin.de/~eserte/
#

# Palm-Routinen für BBBike

# in main muss definiert sein: is_in_path

use strict;
# main bbbike variables
use vars qw($os $tmpdir %tmpfiles $palm_doc_format $top);

my @prog_order = qw(txt2pdbdoc /usr/local/txt2pdbdoc/bin/txt2pdbdoc
		    pilot_makedoc
		    iSiloBSD iSiloLinux iSiloDOS
		    );

# module-private variables
use vars qw($win32_pdb_installer);

sub can_create_and_transfer_palm_docs {
    ((is_in_path("pilot_makedoc") ||
      is_in_path("iSiloBSD")      ||
      is_in_path("iSiloLinux")    ||
      is_in_path("iSiloDOS")      ||
      is_in_path("txt2pdbdoc")    ||
      -x "/usr/local/txt2pdbdoc/bin/txt2pdbdoc")
     &&
     can_transfer_palm_docs());
}

sub can_transfer_palm_docs {
    if ($os eq 'win') {
	require Win32Util;
	my $class = Win32Util::get_class_by_ext(".pdb") || "pdbfile";
	$win32_pdb_installer = Win32Util::get_reg_cmd($class);
	return (defined $win32_pdb_installer &&
		$win32_pdb_installer ne "");
    } else {
	return 1 if (is_in_path("pilot-xfer"));
    }
}

sub create_palm_button {
    my $parent = shift;
    my $get_endpoints_sub = shift;
    $parent->Button
	(-text => 'Palm',
	 -command => \&create_palm_doc,
	);
}

sub create_palm_doc {
    my $f   = "$tmpdir/palmdoc-$$.";
    my $doc = "$tmpdir/palmdoc-$$.pdb";
    my $is_empty = sub {
	if (!-r $f || -z $f) {
	    die "Datei $f existiert nicht bzw. ist leer";
	}
    };
    if ($palm_doc_format eq 'isilo') {
	BBBikePalm::to_top(\@prog_order,
			   qw(iSiloBSD iSiloLinux iSiloDOS));
    }

    foreach my $check_sys (@prog_order) {
	my $full_path = is_in_path($check_sys);
	if (defined $full_path) {
	    if ($check_sys =~ /isilo/i) {
		if ($os eq 'win') {
		    # isilodos is a real DOS program ... only understanding 8.3
		    $f = "$tmpdir\\palmtmp.htm";
		    $doc = "$tmpdir\\palmtmp.pdb";
		} else {
		    $f .= "html";
		}
		open(PALM, ">$f") or
		    die "$f kann nicht geschrieben werden: $!";
		print PALM route_info_to_html();
		close PALM;
		$is_empty->();
		my @cmd;
		if ($os eq 'win') {
		    @cmd = "$full_path -y $f $doc";
		} else {
		    @cmd = ($full_path, "-y", $f, $doc);
		}
		#warn "Executing @cmd\n";
		system @cmd;
	    } else {

		# XXX better move to bbbike?
		my $route_name = "BBBike-Route";
		if (defined $main::show_route_start and
		    defined $main::show_route_ziel) {
		    my($start, $ziel);
		    $start = Strasse::short(Strassen::strip_bezirk($main::show_route_start), 3); # Start besser abkürzen --- ist meist immer der Gleiche
		    $ziel  = Strasse::short(Strassen::strip_bezirk($main::show_route_ziel), 2);
		    $route_name = "BBBike: $start-$ziel";
		}

		$f .= "txt";
		open(PALM, ">$f") or
		    die "$f kann nicht geschrieben werden: $!";
		print PALM BBBikePalm::strip_html_tags(route_info_to_html()); # or route_info_to_text???
		close PALM;
		$is_empty->();
		if ($check_sys =~ /pilot_makedoc/) {
		    system($full_path, $f, $doc, $route_name);
		} elsif ($check_sys =~ /txt2pdbdoc/) {
		    system($full_path, $route_name, $f, $doc);
		}
	    }
	    last;
	}
    }
    if (!-r $doc) {
	die "Doc-Datei $doc konnte nicht erzeugt werden";
    }
    if (defined $win32_pdb_installer) {
	Win32Util::start_cmd($win32_pdb_installer, $doc);
    } else {
	system("pilot-xfer -i $doc &");
	BBBikePalm::hot_sync_message($top);
    }
    $tmpfiles{$doc}++;
}

sub BBBikePalm::strip_html_tags {
    my $text = shift;
    $text =~ s/<[^>]+>//gs;
    $text;
}

sub BBBikePalm::to_top {
    my($listref, @to_top) = @_;
    my(%to_top) = map { ($_ => 1) } @to_top;
    my @new_list = @to_top;
    foreach (@$listref) {
	push @new_list, $_ if !exists $to_top{$_};
    }
    @$listref = ();
    foreach (@new_list) {
	push @$listref, $_;
    }
}

sub BBBikePalm::hot_sync_message {
    my $top = shift;
    $top->messageBox(-title => "Hotsync",
		     -text => "Hotsync-Button drücken!");
}

######################################################################
# Routines for bbbike.cgi using Palm::PalmDoc

sub BBBikePalm::route2palm {
    require Route::Descr;
    require Palm::PalmDoc;
    my(%args) = @_;
    my $fh = delete $args{-fh};
    my $file = delete $args{-file};
    my $out = Route::Descr::convert(%args);
    my $doc = Palm::PalmDoc->new;
    if ($out->{Goal}) {
	# Who is causing the bug behind this restriction?
	my $title = substr("$out->{Start} - $out->{Goal}", 0, 31);
	$doc->title($title);
    } else {
	$doc->title("BBBike-Route");
    }
    $doc->body(join("\n\n", map { join("\t", @$_) } @{$out->{Lines}}, $out->{Footer}));
    #$doc->compression(1); # XXX no effect?
    if ($fh) {
	binmode $fh;
	print $fh $doc->pdb_header,$doc->body;
    } elsif ($file) {
	open(F, ">$file") or die "Can't write to $file: $!";
	binmode F;
	print F $doc->pdb_header,$doc->body;
	close F;
    } else {
	return $doc->pdb_header . $doc->body;
    }
}

1;

__END__
