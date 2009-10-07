#!/usr/bin/perl -w
# -*- mode:perl; coding:raw-text -*-

#
# $Id: utf8.t,v 1.4 2008/08/20 21:08:20 eserte Exp $
# Author: Slaven Rezic
#

# Intentionally NO use utf8;!
use strict;

BEGIN {
    if (!eval q{
	use File::Temp qw(tempfile);
	use Test::More;
	use Tk;
	1;
    }) {
	print "1..0 # skip no File::Temp, Tk and/or Test::More module\n";
	CORE::exit(0);
    }
}

use FindBin;
BEGIN {
    # Don't use "use lib", so we are sure that the real BBBikeXS.pm/so is
    # loaded first
    push @INC, "$FindBin::RealBin/../../..", "$FindBin::RealBin/../../../lib";
}
use Strassen;
use BBBikeXS;

my $imgdir = "$FindBin::RealBin/../../../images";

if (!defined $ENV{BATCH}) {
    $ENV{BATCH} = 1;
}

my $mw = eval { tkinit };
if (!$mw) {
    plan skip_all => 'Cannot create MainWindow';
    CORE::exit(0);
}
plan tests => 7;

$mw->geometry("+10+10");
$mw->Button(-text => "Close", -command => sub { $mw->destroy })->pack(-side => "bottom");
my $c = $mw->Scrolled("Canvas")->pack(qw(-fill both -expand 1));
my @restr = ('HH', 'H', 'N', 'NN');
my $category_width = {'HH' => 6, 'H' => 4, 'N' => 2, 'NN' => 1};

{
    my $datafile = write_data(<<'EOF');
#: encoding: unknown
EOF
    my @w;
    local $SIG{__WARN__} = sub { push @w, @_ };
    BBBike::fast_plot_str($c, "s", [$datafile], 0, \@restr, $category_width); # warns!
    like("@w", qr{Cannot handle encoding}, "unknown encoding");
}

{
    my $datafile = write_data(<<'EOF');
#: encoding: iso-8859-1
Dudenstra�e	HH 8263,8779 8285,8779 8305,8779 8432,8779 8480,8781 8596,8778 8606,8778 8770,8777 8990,8776 9088,8775 9157,8775
EOF
    my @w;
    local $SIG{__WARN__} = sub { push @w, @_ };
    BBBike::fast_plot_str($c, "s", [$datafile], 0, \@restr, $category_width); # warns!
    my($item) = $c->find("all");
    is(($c->gettags($item))[1], "Dudenstra�e", "iso-8859-1 OK");
    $c->delete("all");
    is("@w", "", "No warnings");
}

{
    my $datafile = write_data(<<'EOF');
#: encoding:iso-8859-1
Dudenstra�e	HH 8263,8779 8285,8779 8305,8779 8432,8779 8480,8781 8596,8778 8606,8778 8770,8777 8990,8776 9088,8775 9157,8775
EOF
    my @w;
    local $SIG{__WARN__} = sub { push @w, @_ };
    BBBike::fast_plot_str($c, "s", [$datafile], 0, \@restr, $category_width); # warns!
    is("@w", "", "No warnings (encoding spec with missing space)");
    $c->delete("all");
}

{
    my $strfile = write_data(<<'EOF');
#: encoding: utf-8
#:
Dudenstraße	HH 8263,8779 8285,8779 8305,8779 8432,8779 8480,8781 8596,8778 8606,8778 8770,8777 8990,8776 9088,8775 9157,8775
Manfred-von-Richthofen-Straße	N 8729,7938 8741,7875 8769,7796 8796,7744 8811,7724 8853,7670 8895,7637 8955,7591 9027,7537 9077,7483 9098,7462 9139,7416 9151,7411
Manfred-von-Richthofen-Straße	H 8735,7990 8734,7955
	N 8259,7029 8290,7065 8289,7078 8282,7083 8274,7084
Wiesenerstraße	N 8920,7668 8903,7649 8895,7637 8826,7551 8812,7516 8806,7483 8804,7376
Katzbachstraße	H 8596,9494 8595,9490 8595,9460 8593,9264 8594,9213 8594,9074 8599,8821
Manfred-von-Richthofen-Straße	H 9226,8715 9220,8715 9156,8711 9017,8604 8916,8513 8842,8436 8802,8358 8775,8288 8723,8098 8727,8077 8727,8051 8730,7998 8735,7990
Bayernring	N 8614,8598 8622,8600 8748,8594 8850,8573 8916,8513 8929,8501 9038,8419 9132,8413 9228,8417
Mussehlstraße	N 8990,8776 8925,8679 8850,8573
Paradestraße	N 8783,8023 8834,8024 8919,8026 9034,8028 9135,8027 9231,8024 9245,8024
Adolf-Scheidt-Platz	N 8735,7990 8741,7991 8767,7993 8780,8002 8783,8023 8778,8044 8764,8051 8738,8050 8727,8051
# Something in Copenhagen
Nældebjergvej	N 13572,8531 13498,8554 13477,8612
Tværås	N 13572,8131 13498,8154 13477,8312
Per Døvers Vej	N 13572,8331 13498,8354 13477,8412
EOF

    my $pointfile = write_data(<<'EOF');
#: encoding: utf-8
#:
Plätz der Lüftbrücke	X 8263,8779
EOF

    my @w;
    local $SIG{__WARN__} = sub { push @w, @_ };

    BBBike::fast_plot_str($c, "s", [$strfile], 0, \@restr, $category_width);
    BBBike::fast_plot_point($c, "lsa", [$pointfile], 0);

    is("@w", "", "No utf8 or other warnings");

    $c->configure(-scrollregion => [$c->bbox("all")]);

    {
	my $found_dudenstr;
	my %seen_name;
	for my $item ($c->find("all")) {
	    my(@tags) = $c->gettags($item);
	    my $name = $tags[1];
	    if ($name eq 'Dudenstra�e') {
		$found_dudenstr++;
	    }
	    next if $seen_name{$name}++;
	    my @c = $c->coords($item);
	    $c->createText(@c[0,1], -text => $name, -anchor => "w");
	}
	ok($found_dudenstr, "Found Dudenstr.");

    }

    {
	my($item) = $c->find(withtag => "lsa-fg");
	is(($c->gettags($item))[2], "Pl�tz der L�ftbr�cke", "Point item with correct name");
    }
}

if ($ENV{BATCH}) {
    $mw->after(1000, sub { $mw->destroy;});
}
MainLoop;

sub write_data {
    my $data = shift;
    my($datafh,$datafile) = tempfile(UNLINK => 1, SUFFIX => "_utf8.bbd");
    print $datafh $data
	or die $!;
    close $datafh
	or die $!;
    $datafile;
}

sub get_symbol_scale {
    my $p = {"lsa-X" => $mw->Photo(-file => "$imgdir/ampel.gif"),
	    }->{$_[0]};
    $p;
}

__END__
