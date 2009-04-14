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

package BBBikeRouteLister;

use strict;
use vars qw($VERSION);
$VERSION = 1.00;

use Cwd qw(cwd realpath);
use File::Basename qw(dirname);
use File::Path qw(mkpath);
use Tk qw(Ev);
use Tk::PNG;

use constant WIDTH  => 120;
use constant HEIGHT => 120;

my $bbbike_root = realpath(dirname(realpath(dirname(__FILE__))));
my $bbbikedraw_pl = "$bbbike_root/miscsrc/bbbikedraw.pl";
if (!-e $bbbikedraw_pl) {
    warn "$bbbikedraw_pl does not exist!";
}

sub new {
    my($class, $parent, %args) = @_;
    my $self = bless {}, $class;
    my $directory = delete $args{-directory} || cwd;
    $self->{directory} = $directory;
    $self->{raw_files} = [];
    my $t = $parent->Toplevel;
    $self->{toplevel} = $t;

    {
	my $f = $t->Frame->pack(qw(-fill both -expand 1));
	my $lb = $f->Scrolled('Listbox', -scrollbars => 'osoe')->pack(qw(-fill both -expand 1 -side left));
	$self->{list} = $lb->Subwidget('scrolled');
	$self->{list}->bind('<Double-1>' => [sub { $self->select_item($_[0]->index($_[1])) }, Ev('@')]);
	$self->{list}->bind('<1>' => [sub { $self->update_preview($_[0]->index($_[1])) }, Ev('@')]);
	my $p = $self->{preview} = $t->Photo(-width => WIDTH, -height => HEIGHT);
	my $pv = $f->Label(-image => $p)->pack(qw(-side left));
    }
    {
	my $f = $t->Frame->pack(qw(-fill x));
	my $okb     = $f->Button(-text => 'OK', -command => sub { $self->{wait} = +1 });
	my $cancelb = $f->Button(-text => 'Cancel', -command => sub { $self->{wait} = -1 });
	$cancelb->pack(-side => 'right');
	$okb->pack(-side => 'right');
    }

    $self;
}

sub Show {
    my $self = shift;
    $self->{wait} = 0;
    $self->{preview}->blank;
    $self->update_directory($self->{directory});
    $self->{toplevel}->waitVariable(\$self->{wait});
    if ($self->{wait} == +1) {
	my $lb = $self->{list};
	my($sel) = $lb->curselection;
	if (defined $sel) {
	    my $entry = $self->{raw_files}->[$sel];
	    if (-f $entry) {
		return $self->{directory} . "/" . $entry;
	    }
	}
    }
    return undef;
}

sub update_directory {
    my($self, $directory) = @_;
    if (!-d $directory) {
	die "$directory is not a directory";
    }
    chdir $directory
	or die "Cannot change into directory $directory: $!";
    my $lb = $self->{list};

    $lb->delete(0, 'end');
    $lb->selectionClear(0, 'end');

    my @dirs;
    my @files;
    opendir my $DIR, "."
	or die "Cannot open current directory: $!";
    while(defined(my $entry = readdir($DIR))) {
	next if $entry eq '.';
	if (-d $entry) {
	    push @dirs, $entry;
	} elsif (-f $entry) {
	    push @files, $entry;
	} # ignore other filetypes
    }

    my @raw_files;

    for my $dir (sort @dirs) {
	push @raw_files, $dir;
	$lb->insert('end', "$dir/");
    }
    for my $file (sort @files) {
	push @raw_files, $file;
	$lb->insert('end', $file);
    }

    $self->{directory} = cwd;
    $self->{raw_files} = \@raw_files;
}

sub select_item {
    my($self, $inx) = @_;
    my $lb = $self->{list};
    my $entry = $self->{raw_files}->[$inx];
    if ($entry =~ s{/$}{}) {
	$self->update_directory($entry);
    } else {
	$self->{wait} = +1;
    }
}

sub update_preview {
    my($self, $inx) = @_;
    my $lb = $self->{list};
    my $entry = $self->{raw_files}->[$inx];
    if ($entry !~ m{/$}) {
	my $thumbnail = ".thumbnails/$entry";
	if (!-r $thumbnail) {
	    if ($entry =~ m{\.(bbr|gpx|trk|xml)$}) {
		$self->do_update_preview($entry, $thumbnail);
	    }
	} elsif (-M $thumbnail > -M $entry) {
	    ## XXX no, do not update yet
	    #$self->do_update_preview($entry, $thumbnail);
	}
	if (-r $thumbnail) {
	    $self->{preview}->read($thumbnail);
	    return
	}
    }
    $self->{preview}->blank;
}

sub do_update_preview {
    my($self, $entry, $thumbnail) = @_;
    if (!-d dirname($thumbnail)) {
	mkpath dirname($thumbnail);
    }
    $self->{toplevel}->Busy(-recurse => 1);
    system($^X, $bbbikedraw_pl,
	   '-geometry', WIDTH.'x'.HEIGHT,
	   '-outtype', 'png',
	   '-drawtypes', 'all',
	   '-o', $thumbnail,
	   '-scope', 'wideregion',
	   '-routefile', $entry,
	  );
    $self->{toplevel}->Unbusy;
}

1;

__END__

=head1 NAME

BBBikeRouteLister - a file selector for routes with automatic preview

=head1 SYNOPSIS

    use BBBikeRouteLister;
    $file = BBBikeRouteLister->new($mw, -directory => "...")->Show;

=head1 DESCRIPTION

B<BBBikeRouteLister> is a file selection widget which can be used to
select BBBike route files (e.g. bbr, gpx and other file formats).
Previews are generated and stored on the fly. The selected full
filename is returned, or C<undef>.

=head1 EXAMPLES

    perl -MTk -MBBBikeRouteLister -e '$mw=tkinit;$l=BBBikeRouteLister->new($mw,-directory=>".");warn $l->Show'

=head1 TODO

 * do updating in background, and display once the image is ready (and block other updates)

 * update in advance

 * maybe turn into a "real" Perl/Tk widget

=cut
