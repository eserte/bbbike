# -*- perl -*-

#
# $Id: Fahrinfo.pm,v 2.8 1999/06/28 23:56:43 eserte Exp $
# Author: Slaven Rezic (eserte@cs.tu-berlin.de)
#

package Fahrinfo;
#use AutoLoader 'AUTOLOAD';
use strict;
use vars qw(@fahrinfodirs $VERBOSE $datatype);

$VERBOSE = 0 unless defined $VERBOSE;
$datatype = 0; # XXX Datatype anhand von Datei/Directorynamen bestimmen
# XXX funktioniert nicht mehr mit s99

use FindBin;
use lib ($FindBin::RealBin . "/lib",
	 #"/home/e/eserte/lib/perl",
	);
require MyFile;

foreach (qw(w99 s99)) {
    push @fahrinfodirs,
    "/dos/fahrinfo/vbb.$_", "/dos2/fahrinfo/vbb.$_";
}
foreach (qw(98 97 96)) {
    push @fahrinfodirs,
    "/dos/vbb.$_", "/dos2/vbb.$_", "$ENV{HOME}/wabi/vbb.$_";
}
push @fahrinfodirs,
  '/dos/bvg.95',  '/dos2/bvg.95',
  "$ENV{HOME}/wabi/bvg.95",
  '.', '/tmp', 
  $FindBin::RealBin . "/vbbdata";

sub readonly { die "Fahrinfo data is read-only\n" }

sub cp850_iso88591 {		# convert only german umlauts
    $_[0] =~ tr/\204\224\201\216\231\232\341\202/äöüÄÖÜßé/;
    $_[0];
}

sub exists {
    foreach (@fahrinfodirs) {
	return $_ if -d $_ && -f "$_/planb";
    }
    0;
}

######################################################################

package Fahrinfo::Haltestellen; # planb
#use AutoLoader 'AUTOLOAD';

my $dbfilename = "planb";

sub new {
    my($pkg, $directory, $filename) = @_;
    my $self = {};
    my(@filenames);
    if (defined $directory) {
	@filenames = ("$directory/" . ($filename || $dbfilename));
    } else {
	@filenames = map { "$_/$dbfilename" } @Fahrinfo::fahrinfodirs;
    }
    local($/) = undef;
    my $file = MyFile::openlist(*B, @filenames);
    if (!defined $file) {
	die "Can't open ", join(", ", @filenames);
    }
    binmode B;
    $self->{'data'} = <B>;
    close B;
    $self->{'laenge_header'}    =
      unpack("v", substr($self->{'data'}, 0, 2));
    my $inx = ($Fahrinfo::datatype ? 20 : 6);
    $self->{'anzahl_eindeutig'} =
      unpack("v", substr($self->{'data'}, $inx, 2));
    $inx = ($Fahrinfo::datatype ? 12 : 8);
    $self->{'anzahl_namen'}     =
      unpack("v", substr($self->{'data'}, $inx, 2));
    $self->{'start_pointer'}    =
      $self->{'laenge_header'} + 10 * $self->{'anzahl_eindeutig'};
    $self->{'start_strings'}    =
      $self->{'start_pointer'} + 6 * $self->{'anzahl_namen'};

    if ($Fahrinfo::VERBOSE) {
	warn "Filename: $file\n";
	foreach (qw(laenge_header anzahl_eindeutig anzahl_namen)) {
	    warn "$_ = $self->{$_}\n";
	}
    }
    bless $self, $pkg;
}

sub TIEARRAY { shift->new(@_) }
sub TIEHASH  { shift->new(@_) }

sub FETCH {
    my($self, $key) = @_;
    return undef if $key >= $self->{'anzahl_namen'};
    my $pointer =
      unpack("V", substr($self->{'data'}, 
			 $self->{'start_pointer'} + 2 + $key*6, 4))
	    + $self->{'start_strings'};
    my $i = $pointer;
    while (substr($self->{'data'}, $i, 1) ne "\0") { $i++; }
    &Fahrinfo::cp850_iso88591(substr($self->{'data'}, 
				     $pointer, $i - $pointer));
}

# liefert Index für Fahrinfo::Eind_haltestellen
sub get_eind_index {
    my($self, $key) = @_;
    return undef if $key >= $self->{'anzahl_namen'};
    unpack("v", substr($self->{'data'}, $self->{'start_pointer'} + $key*6, 2));
}

sub FIRSTKEY {
    my $self = shift;
    $self->{'iterpos'} = -1;
    $self->NEXTKEY;
}

sub NEXTKEY {
    my $self = shift;
    if ($self->{'iterpos'} < $self->{'anzahl_namen'}) {
	++$self->{'iterpos'};
    } else {
	undef;
    }
}

sub STORE {
    &Fahrinfo::readonly;
}

#sub DESTROY { }

######################################################################

package Fahrinfo::Eind_haltestellen; # planb
#use AutoLoader 'AUTOLOAD';

sub new {
    my($pkg, $haltestellen) = @_;
    my $self = {};
    if (!defined $haltestellen) {
	my @haltestellen;
	$haltestellen = tie @haltestellen, 'Fahrinfo::Haltestellen';
    } elsif (!$haltestellen->isa('Fahrinfo::Haltestellen')) {
	die "Wrong type: $haltestellen";
    }
    $self->{'haltestellen'} = $haltestellen;
    $self->{'start_pointer'} = $haltestellen->{'laenge_header'};
    bless $self, $pkg;
}

sub TIEARRAY { shift->new(@_) }
sub TIEHASH  { shift->new(@_) }

sub FETCH {
    my($self, $key) = @_;
    return undef if $key >= $self->{'haltestellen'}->{'anzahl_eindeutig'};
    my $index =
      unpack("v", substr($self->{'haltestellen'}->{'data'},
			 $self->{'start_pointer'} + 8 + $key*10, 2));
    $self->{'haltestellen'}->FETCH($index);
}

sub FIRSTKEY {
    my $self = shift;
    $self->{'iterpos'} = -1;
    $self->NEXTKEY;
}

sub NEXTKEY {
    my $self = shift;
    if ($self->{'iterpos'} < $self->{'haltestellen'}{'anzahl_namen'}) {
	++$self->{'iterpos'};
    } else {
	undef;
    }
}

sub STORE {
    &Fahrinfo::readonly;
}

#sub DESTROY {}

######################################################################

package Fahrinfo::Lauf;			# planlauf
#use AutoLoader 'AUTOLOAD';

sub new {
    my($pkg, $eind_haltestellen, $extra_filename) = @_;
    my $self = {};
    if (!defined $eind_haltestellen) {
	my @eind_haltestellen;
	$self->{'eind_haltestellen'} 
	    = tie @eind_haltestellen, 'Fahrinfo::Eind_haltestellen';
    } elsif (!$eind_haltestellen->isa('Fahrinfo::Eind_haltestellen')) {
	die "Wrong type: $eind_haltestellen";
    } else {
	$self->{'eind_haltestellen'} = $eind_haltestellen;
    }

    my(@filenames) = map { "$_/planlauf" } @Fahrinfo::fahrinfodirs;
    if (defined $extra_filename) {
	unshift(@filenames, $extra_filename);
    }
    local($/) = undef;
    MyFile::openlist(*B, @filenames)
      || die "Can't open ", join(", ", @filenames);
    binmode B;
    $self->{'data'} = <B>;
    close(B);

    $self->{'laenge_header'} = unpack("v", substr($self->{'data'}, 0, 2));
    $self->{'anzahl_lauf'}   = unpack("v", substr($self->{'data'}, 2, 2));

    bless $self, $pkg;
}

# usage: $lauf->get($i)
sub get {
    my $self = shift;
    my $key = shift;
    ($key >= $self->{'anzahl_lauf'}) && return undef;
    my $pointer = unpack("V", substr($self->{'data'},
				     $self->{'laenge_header'} + $key*4, 4));
    my $num = unpack("v", substr($self->{'data'}, $pointer, 2));
    my $i;
    my @res = ();
    
    for($i = 1; $i <= $num; $i++) {
	push(@res,
	     $self->{'eind_haltestellen'}->FETCH
	     (unpack("v", substr($self->{'data'}, $pointer+$i*2, 2)))
	    );
    }
    @res;
}

######################################################################

package Fahrinfo::Koord;	# plank32
#use AutoLoader 'AUTOLOAD';

my $koorddbfilename = "plank32";

sub new {
    my($pkg, $eind_haltestellen, $directory, $filename) = @_;
    my $self = {};

    if (!defined $eind_haltestellen) {
	my %eind_haltestellen;
	$eind_haltestellen 
	  = tie %eind_haltestellen, 'Fahrinfo::Eind_haltestellen';
    } elsif (!$eind_haltestellen->isa('Fahrinfo::Eind_haltestellen')) {
	die "Wrong type: $eind_haltestellen";
    }
    $self->{'eind_haltestellen'} = $eind_haltestellen;

    my(@filenames);
    if (defined $directory) {
	@filenames = ("$directory/" . ($filename || $koorddbfilename));
    } else {
	@filenames = map { "$_/$koorddbfilename" } @Fahrinfo::fahrinfodirs;
    }
    local($/) = undef;
    MyFile::openlist(*B, @filenames)
      || die "Can't open ", join(", ", @filenames);
    binmode B;
    $self->{'data'} = <B>;
    close B;
    $self->{'laenge_header'} = unpack("v", substr($self->{'data'}, 0, 2));
    $self->{'anzahl_eindeutig'}
      = $self->{'eind_haltestellen'}{'haltestellen'}{'anzahl_eindeutig'};
    bless $self, $pkg;
}

sub TIEARRAY { shift->new(@_) }
sub TIEHASH  { shift->new(@_) }

sub get {
    my($self, $i) = @_;
    my $pointer = $self->{'laenge_header'} + $i * 8;
    
    (unpack("l", substr($self->{'data'}, $pointer, 4)),
     unpack("l", substr($self->{'data'}, $pointer+4, 4)));
}

sub FETCH {
    my($self, $i) = @_;
    my $pointer = $self->{'laenge_header'} + $i * 8;
    [unpack("l", substr($self->{'data'}, $pointer, 4)),
     unpack("l", substr($self->{'data'}, $pointer+4, 4))];
}

sub STORE { Fahrinfo::readonly() }

sub safeget {
    my($self, $i) = @_;
    return undef
      if $i >= $self->{'anzahl_eindeutig'};
    $self->get($i);
}

sub first {
    my $self = shift;
    $self->{'prevpos'} = 0;
    $self->get($self->{'prevpos'});
}

sub FIRSTKEY {
    my $self = shift;
    $self->{'prevpos'} = -1;
    $self->NEXTKEY;
}
    
sub next {
    my $self = shift;
    $self->get(++$self->{'prevpos'});
}

sub NEXTKEY {
    my $self = shift;
    return undef if $self->{'prevpos'}+1 >= $self->{'anzahl_eindeutig'};
    ++$self->{'prevpos'};
}

# Verwendung von initnextdirect ist wohl besser
sub firstdirect {
    my $self = shift;
    $self->{'pos'} = $self->{'laenge_header'};
    (unpack("l", substr($self->{'data'}, $self->{'pos'}, 4)),
     unpack("l", substr($self->{'data'}, $self->{'pos'}+4, 4)));
}

sub initnextdirect {
    my $self = shift;
    $self->{'pos'} = $self->{'laenge_header'} - 8;
}

sub nextdirect {
    my $self = shift;
    $self->{'pos'}+=8;
    (unpack("l", substr($self->{'data'}, $self->{'pos'}, 4)),
     unpack("l", substr($self->{'data'}, $self->{'pos'}+4, 4)));
}

sub safenext {
    my $self = shift;
    $self->safeget(++$self->{'prevpos'});
}

sub getx {
    (&get(@_))[0];
}

sub gety {
    (&get(@_))[1];
}

######################################################################

1;
