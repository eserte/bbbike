#!/usr/bin/perl -w
# -*- mode:cperl; -*-

#
# Author: Slaven Rezic
#

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

if (!defined $ENV{BATCH}) {
    $ENV{BATCH} = 1;
}

my $mw = eval { tkinit };
if (!$mw) {
    plan skip_all => 'Cannot create MainWindow';
    CORE::exit(0);
}
plan 'no_plan';

$mw->geometry("+10+10");
$mw->Button(-text => "Close", -command => sub { $mw->destroy })->pack(-side => "bottom");
my $c = $mw->Scrolled("Canvas")->pack(qw(-fill both -expand 1));
my @restr = ('HH', 'H', 'NH', 'N', 'NN');
my $category_width = {'HH' => 6, 'H' => 4, 'NH' => 3, 'N' => 2, 'NN' => 1};

{
    my $coords = "8263,8779 8285,8779 8305,8779 8432,8779 8480,8781 8596,8778 8606,8778 8770,8777 8990,8776 9088,8775 9157,8775 9229,8785 9229,8718 9158,8706 9099,8670 9006,8602 8919,8508 8851,8424 8807,8353 8776,8285 8730,8079 8731,8050 8731,8020 8731,7990 8731,7956 8757,7841 8796,7751 8812,7730 8864,7676 8900,7643 8947,7601 8994,7639 9040,7648 9035,7810 8959,7824 8940,7835 8942,7865 8952,8030 8941,8186 8969,8278 9032,8254 9027,8431 9128,8414 9238,8410 9292,8404 9268,8331 9268,8029 9240,8028 9239,8099 9238,8253 9128,8251 9130,8029 9130,7810 9132,7661 9115,7645 9120,7600 9145,7522 9097,7469 9070,7493 9042,7462 8982,7438 8971,7359 9051,7340 9107,7297 9242,7286 9302,7294 9351,7241 9461,7190 9509,7195 9545,7426 9525,7558 9431,7425 9386,7326 9300,7312 9281,7651 9362,7616 9522,7624 9562,7796 9372,7798 9281,7795 9240,7811 9330,7911 9424,8248 9458,7925 9619,7930 9709,8127 9784,8209 9884,8265 10037,8269 10298,8245 10360,8521 10644,8363 10803,8251 11005,8064 11143,8139 11303,8089 11327,8007 11418,8015 11439,7894 11458,7897 11489,7748 11498,7750 11516,7654 11507,7647 11528,7528 11540,7534 11558,7438 11547,7432 11554,7382 11593,7314 11596,7280 11608,7267 11596,7280 11555,7314 11518,7314 11332,7305 11438,7371 11460,7447 11388,7777 11279,7768 10204,7680 9653,7635 9522,7624 9525,7558 9545,7426 9509,7195 9681,7075 9792,6964 10023,6806 10282,6692 10558,6661 10746,6693 10944,6790 11128,6967 11310,7071 11407,7198";
    my $datafile = write_data(<<"EOF");
Long street	HH $coords $coords $coords $coords $coords $coords $coords $coords $coords $coords $coords $coords $coords $coords $coords $coords
EOF
    my @w;
    local $SIG{__WARN__} = sub { push @w, @_ };
    BBBike::fast_plot_str($c, "s", [$datafile], 0, \@restr, $category_width); # warns!
    my($item) = $c->find("all");
    is(($c->gettags($item))[1], "Long street", "long street OK (data file size is " . (-s $datafile) . ")");
    $c->configure(-scrollregion => [$c->bbox("all")]);
    is("@w", "", "No warnings");
}

if ($ENV{BATCH}) {
    $mw->after(1000, sub { $mw->destroy;});
}
MainLoop;

sub write_data {
    my $data = shift;
    my($datafh,$datafile) = tempfile(UNLINK => 1, SUFFIX => "_longlines.bbd");
    print $datafh $data
	or die $!;
    close $datafh
	or die $!;
    $datafile;
}

sub get_symbol_scale { }

__END__
