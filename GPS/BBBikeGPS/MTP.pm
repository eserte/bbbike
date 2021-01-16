# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2021 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  https://github.com/eserte/bbbike
#

package GPS::BBBikeGPS::MTP;
require GPS;
push @GPS::BBBikeGPS::MTP::ISA, 'GPS';

use strict;
use warnings;
our $VERSION = '0.01';

sub has_gps_settings { 1 }

sub transfer_to_file { 0 }

sub ok_label { "Kopieren auf das Gerät" } # M/Mfmt XXX

sub tk_interface {
    my($self, %args) = @_;
    BBBikeGPS::tk_interface($self, %args);
}

sub convert_from_route {
    my($self, $route, %args) = @_;

    require File::Temp;
    require Route::Simplify;
    require Strassen::Core;
    require Strassen::GPX;
    my $simplified_route = $route->simplify_for_gps(%args);
    my $s = Strassen::GPX->new;
    $s->set_global_directives({ map => ["polar"] });
    for my $wpt (@{ $simplified_route->{wpt} }) {
	$s->push([$wpt->{ident}, [ join(",", $wpt->{lon}, $wpt->{lat}) ], "X" ]);
    }
    my($ofh,$ofile) = File::Temp::tempfile(SUFFIX => ".gpx",
					   UNLINK => 1);
    _status_message("Could not create temporary file: $!", "die") if !$ofh;
    print $ofh $s->bbd2gpx(-as => "route",
			   -name => $simplified_route->{routename},
			   -number => $args{-routenumber},
			   #-withtripext => 1,
			  );
    close $ofh;

    my $newfiles_path = 'GARMIN/NewFiles';
    my $newfiles_folder_id = eval { _mtp_get_folder_id($newfiles_path) };
    _status_message("Cannot find folder '$newfiles_path'", "die") if !defined $newfiles_folder_id;

    (my $safe_routename = $simplified_route->{routename}) =~ s{[^A-Za-z0-9_-]}{_}g;
    require POSIX;
    $safe_routename = POSIX::strftime("%Y%m%d_%H%M%S", localtime) . '_' . $safe_routename . '.gpx';

    {
	my @cmd = ('mtp-sendfile', $ofile, $newfiles_folder_id);
	system(@cmd);
	if ($? != 0) {
	    _status_message("Running '@cmd' failed", "die");
	}
    }
}

sub transfer { } # NOP

sub _mtp_get_folder_id {
    my($path) = @_;
    my $fh;
    if (eval { require IPC::Run; 1 }) {
	IPC::Run::run(['mtp-folders'], '2>/dev/null', '>', \my $out)
	    or die "Error while running 'mtp-folders'";
	open $fh, '<', \$out or die $!;
    } else {
	open $fh, '-|', 'mtp-folders'
	    or die "Can't run mtp-folders: $!";
    }
    my $id = _mtp_get_folder_id_parse($path, $fh);
    close $fh
	or die "Error while closing mtp-folders call: $!";
    $id;
}

sub _mtp_get_folder_id_parse {
    my($path, $fh) = @_;
    my @path_segments = split m{/}, lc $path;
    my @indents;
    my $path_depth_check = 0;
    while(<$fh>) {
	chomp;
	if (my($curr_id, $indent_string, $curr_path_segment) = $_ =~ /^(\d+)(\s+)(.*)/) {
	    my $indent_length = length $indent_string;
	    if (!@indents) {
		@indents = $indent_length;
	    } else {
		if ($indent_length > $indents[-1]) {
		    push @indents, $indent_length;
		} elsif ($indent_length < $indents[-1]) {
		    while($indent_length <= $indents[-1]) {
			pop @indents;
			if (!@indents) {
			    die "Parse error: possibly inconsistent indentantion in line '$_'";
			}
		    }
		    if ($path_depth_check < $#indents) {
			die "Cannot find folder '$path'";
		    }
		}
	    }
	    if ($path_depth_check == $#indents && $path_segments[$path_depth_check] eq lc($curr_path_segment)) {
		$path_depth_check++;
		if ($path_depth_check > $#path_segments) {
		    return $curr_id;
		}
	    }
	}
    }
    die "Cannot find folder '$path'";
}

sub _mtp_get_filetree {
    my $fh;
    if (eval { require IPC::Run; 1 }) {
	IPC::Run::run(['mtp-filetree'], '2>/dev/null', '>', \my $out)
	    or die "Error while running 'mtp-filetree'";
	open $fh, '<', \$out or die $!;
    } else {
	open $fh, '-|', 'mtp-filetree'
	    or die "Can't run mtp-filetree: $!";
    }
    my @files = _mtp_get_filetree_parse($fh);
    close $fh
	or die "Error while closing mtp-filetree call: $!";
    @files;
}

sub _mtp_get_filetree_parse {
    my($fh) = @_;
    my @files;
    my @cwd;
    while(<$fh>) {
	chomp;
	if (my($indentantion_string, $id, $path_segment) = $_ =~ /^(\s*)(\d+)\s(.*)/) {
	    my $depth = length($indentantion_string)/2;
	    $cwd[$depth] = $path_segment;
	    if (@cwd > $depth) {
		splice @cwd, $depth+1;
	    }
	    push @files, { path => join("/", @cwd), id => $id };
	}
    }
    @files;
}

sub _mtp_sync_commands {
    my($src, $dest, %opts) = @_;

    my $case_sensitive = delete $opts{casesensitive};
    my $doit           = delete $opts{doit};

    die "Unhandled options: " . join(" ", %opts) if %opts;

    my @files = grep {
	if ($case_sensitive) {
	    index($_->{path}, $src."/") == 0;
	} else {
	    index(lc($_->{path}), lc($src)."/") == 0;
	}
    } _mtp_get_filetree();

    require File::Basename;

    my @sync_cmds;
    for my $file_def (@files) {
	my($path, $id) = @{$file_def}{qw(path id)};
	my $destpath = "$dest/" . File::Basename::basename($path);
	if (!-e $destpath) {
	    push @sync_cmds, ["mtp-getfile", $id, $destpath];
	}
    }

    if ($doit) {
	for my $sync_cmd (@sync_cmds) {
	    warn "Run '@$sync_cmd'...\n";
	    system @$sync_cmd;
	    if ($? != 0) {
		die "Command failed.\n";
	    }
	}
    }

    @sync_cmds;    
}

# Logging, should work within Perl/Tk app and outside
sub _status_message {
    if (defined &main::status_message) {
	main::status_message(@_);
    } else {
	print STDERR "$_[0]\n";
    }
}

1;

__END__

=head1 NAME

GPS::BBBikeGPS::MTP - get/put fit/gpx files from/to a MTP device

=head1 SYNOPSIS

    use GPS::BBBikeGPS::MTP;
    GPS::BBBikeGPS::MTP::_mtp_sync_commands("garmin/activity", "/path/to/destination", doit=>1);

=head1 DESCRIPTION

This module serves two purposes:

=over

=item * an implemention of BBBike's L<GPS> interface for transferring routes on a MTP device

=item * synchronize files from an MTP device 

=back

The transfer of BBBike routes to an MTP device is currently hardcoded
for Garmin devices (e.g. fenix watches). The destination path on the
device is F<Garmin/NewFiles>.

The transfer of files from an MTP device to a local directory can be
done with the C<_mtp_sync_commands> function (see L</SYNOPSIS>).
Without the C<doit> parameter, only the commands for doing the
synchronisation (suitable for feeding a series of C<system> calls) are
returned. With C<< doit=>1 >> an actual synchronization is done. Files
already present in the destination directory are not overwritten (note
that no content check is done, only a presence check).

=head2 EXAMPLES

Run synchronization from commandline:

    cd ~/src/bbbike
    perl -I. -MGPS::BBBikeGPS::MTP -e 'GPS::BBBikeGPS::MTP::_mtp_sync_commands("garmin/activity", "/path/to/destination", doit=>1)'

=cut
