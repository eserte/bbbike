#!/usr/bin/perl -w
# -*- mode:perl; coding:raw-text -*-

#
# $Id: miscdata.t,v 1.2 2008/08/24 20:48:38 eserte Exp $
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
use Data::Dumper qw(Dumper);
use Strassen;
use BBBikeXS;
use Storable qw(dclone);

if (!defined $ENV{BATCH}) {
    $ENV{BATCH} = 1;
}

use vars qw(@bridge_arguments @tunnel_entrance_arguments);

my $mw = eval { tkinit };
if (!$mw) {
    plan skip_all => 'Cannot create MainWindow';
    CORE::exit(0);
}

plan tests => 17;

$mw->geometry("+10+10");
$mw->Button(-text => "Close", -command => sub { $mw->destroy })->pack(-side => "bottom");
my $c = $mw->Scrolled("Canvas")->pack(qw(-fill both -expand 1));
my @restr = ('HH', 'H', 'N', 'NN');
my $category_width = {'HH' => 6, 'H' => 4, 'N' => 2, 'NN' => 1};

# Incomplete line (no category)
{
    my $datafile = write_data(<<'EOF');
Incomplete
EOF
    my @w;
    local $SIG{__WARN__} = sub { push @w, @_ };
    BBBike::fast_plot_str($c, "s", [$datafile], 0, \@restr, $category_width);
    like($w[0], qr{Line 1 of file .*\.bbd is incomplete \(TAB character expected\)}, "Incomplete line warning");
    is(@w, 1, "Only one warning expected")
	or diag(join("", @w));
}

# Incomplete line (no coords)
{
    my $datafile = write_data(<<'EOF');
Incomplete	CAT
EOF
    my @w;
    local $SIG{__WARN__} = sub { push @w, @_ };
    BBBike::fast_plot_str($c, "s", [$datafile], 0, \@restr, $category_width);
    like($w[0], qr{Line 1 of file .*\.bbd is incomplete \(SPACE character after category expected\)}, "Incomplete line (after category) warning");
    is(@w, 1, "Only one warning expected")
	or diag(join("", @w));
}

{
    my $datafile = write_data(<<'EOF');
Street with attrib	HH::Attribute 0,0 1000,0
Street without attrib	HH 0,400 1000,400
Street with bridge	HH::Br 0,800 1000,800
Street with tunnel	HH::Tu 0,1200 1000,1200
EOF
    my @w;
    local $SIG{__WARN__} = sub { push @w, @_ };
    local @bridge_arguments = ();
    local @tunnel_entrance_arguments = ();
    BBBike::fast_plot_str($c, "s", [$datafile], 0, \@restr, $category_width);

    is(scalar @{$bridge_arguments[0]}, 4, "Expected bridge coordinates")
	or diag(Dumper(\@bridge_arguments));
    is($bridge_arguments[1], "-width");
    is($bridge_arguments[2], $category_width->{HH}+4, "Expected width");
    is($bridge_arguments[3], "-tags");
    is($bridge_arguments[4]->[0], "s", "Expected first tag");
    is($bridge_arguments[4]->[1], "Street with bridge", "Expected second tag (name)");

    is(scalar @{$tunnel_entrance_arguments[0]}, 4, "Expected tunnel_entrance coordinates")
	or diag(Dumper(\@tunnel_entrance_arguments));
    is($bridge_arguments[1], "-width");
    is($tunnel_entrance_arguments[2], $category_width->{HH}+4, "Expected width");
    is($bridge_arguments[3], "-tags");
    is($tunnel_entrance_arguments[4]->[0], "s", "Expected first tag");
    is($tunnel_entrance_arguments[6], "Tu", "Expected tunnel mound attrib");

    is(@w, 0, "No warnings expected")
	or diag(join("", @w));
}

$c->itemconfigure("s-HH", -fill => "yellow");
$c->configure(-scrollregion => [$c->bbox("all")]);

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

# XXX It is not completely clear if cloning should be necessary here.
sub draw_bridge          {
    @bridge_arguments = @{ dclone \@_ };
    my($cl,%args) = @_;
    $c->createLine($cl, -fill=>"red", -dash=>".-", -tags=>$args{-tags});
}
sub draw_tunnel_entrance {
    @tunnel_entrance_arguments = @{ dclone \@_ };
    my($cl,%args) = @_;
    $c->createLine($cl, -fill=>"blue", -dash=>".-", -tags=>$args{-tags});
}

__END__
