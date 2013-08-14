#!/usr/bin/perl -w
# -*- cperl -*-

#
# Author: Slaven Rezic
#

use strict;
use FindBin;
use lib $FindBin::RealBin, "$FindBin::RealBin/../miscsrc";

use Test::More 'no_plan';
use BBBikeTest qw(eq_or_diff);

use Getopt::Long;
use File::Temp qw(tempdir);

use Typ2Legend::XPM;

sub maybe_montage ($$);

my $do_montage;
GetOptions("montage" => \$do_montage)
    or die "$0 [-montage]";

my $montage_dir;
my @montage_args;
if ($do_montage) {
    $montage_dir = tempdir("typ2legend-test-montage-XXXXXXXX",
			   CLEANUP => 1, TMPDIR => 1)
	or die "Can't create temporary directory: $!";
}

######################################################################
# POLYGONS

######################################################################
# day+night: one-color bitmap (type 6)
{
    my $raw = <<'EOF';
XPM="0 0 1 2",
"XX  c #000000",
EOF

    my $xpm = Typ2Legend::XPM->new([parse_into_lines($raw)]);
    my $ret = $xpm->transform;
    my $day_night_xpm = $ret->{'day+night'}->as_string;
    maybe_montage $day_night_xpm, 'polygon 6, day+night';
    eq_or_diff $day_night_xpm, <<'EOF'
/* XPM */
static char *XPM[] = {
"32 32 1 2",
"XX c #000000",
EOF
	. solid_block_32_and_end();
}

######################################################################
# day: one-color bitmap, night: one-color bitmap (type 7)
{
    my $raw = <<'EOF';
XPM="0 0 2 2",
"XX  c #000000",
"==  c #800000",
EOF

    my $xpm = Typ2Legend::XPM->new([parse_into_lines($raw)]);
    my $ret = $xpm->transform;
    my $day_xpm = $ret->{'day'}->as_string;
    my $night_xpm = $ret->{'night'}->as_string;
    maybe_montage $day_xpm, 'polygon 7, day';
    maybe_montage $night_xpm, 'polygon 7, night';
    eq_or_diff $day_xpm, <<'EOF'
/* XPM */
static char *XPM[] = {
"32 32 1 2",
"XX c #000000",
EOF
	. solid_block_32_and_end();

    eq_or_diff $night_xpm, <<'EOF'
/* XPM */
static char *XPM[] = {
"32 32 1 2",
"XX c #800000",
EOF
	. solid_block_32_and_end();
}

######################################################################
# day+night: two-color bitmap (type 8)
{
    my $raw = <<'EOF'
XPM="32 32 2 2",
"XX  c #000000",
"==  c #f00000",
EOF
	. some_image_data_and_end();

    my $xpm = Typ2Legend::XPM->new([parse_into_lines($raw)]);
    my $ret = $xpm->transform;
    my $day_night_xpm = $ret->{'day+night'}->as_string;
    maybe_montage $day_night_xpm, 'polygon 8, day+night';
    eq_or_diff $day_night_xpm, <<'EOF'
/* XPM */
static char *XPM[] = {
"32 32 2 2",
"XX c #f00000",
"== c #000000",
EOF
	. some_image_data_and_end();
}

######################################################################
# day: two-color bitmap, night: two-color bitmap (type 9)
{
    my $raw = <<'EOF'
XPM="32 32 4 2",
"XX  c #ffff80",
"==  c #80ffff",
"**  c #000000",
"##  c #008000",
EOF
	. some_image_data_and_end();
    
    my $xpm = Typ2Legend::XPM->new([parse_into_lines($raw)]);
    my $ret = $xpm->transform;
    my $day_xpm = $ret->{'day'}->as_string;
    my $night_xpm = $ret->{'night'}->as_string;
    maybe_montage $day_xpm, 'polygon 9, day';
    maybe_montage $night_xpm, 'polygon 9, night';
    eq_or_diff $day_xpm, <<'EOF'
/* XPM */
static char *XPM[] = {
"32 32 2 2",
"XX c #80ffff",
"== c #ffff80",
EOF
	. some_image_data_and_end();
    eq_or_diff $night_xpm, <<'EOF'
/* XPM */
static char *XPM[] = {
"32 32 2 2",
"XX c #008000",
"== c #000000",
EOF
	. some_image_data_and_end();
}

######################################################################
# day: one-color transparent bitmap, night: two-color bitmap (type 11)
{
    my $raw = <<'EOF'
XPM="32 32 3 2",
"XX  c #cccccc",
"==  c #000000",
"**  c #006000",
EOF
    . some_image_data_and_end();

    my $xpm = Typ2Legend::XPM->new([parse_into_lines($raw)]);
    my $ret = $xpm->transform;
    my $day_xpm = $ret->{'day'}->as_string;
    my $night_xpm = $ret->{'night'}->as_string;
    maybe_montage $day_xpm, 'polygon 11, day';
    maybe_montage $night_xpm, 'polygon 11, night';
    eq_or_diff $day_xpm, <<'EOF'
/* XPM */
static char *XPM[] = {
"32 32 2 2",
"XX c none",
"== c #cccccc",
EOF
	. some_image_data_and_end();
    eq_or_diff $night_xpm, <<'EOF'
/* XPM */
static char *XPM[] = {
"32 32 2 2",
"XX c #006000",
"== c #000000",
EOF
	. some_image_data_and_end();
}

######################################################################
# day: two-color bitmap, night: one-color transparent bitmap (type 13)
{
    my $raw = <<'EOF'
XPM="32 32 3 2",
"XX  c #cccccc",
"==  c #aaaaaa",
"**  c #000000",
EOF
    . some_image_data_and_end();

    my $xpm = Typ2Legend::XPM->new([parse_into_lines($raw)]);
    my $ret = $xpm->transform(prefer13 => 1);
    my $day_xpm = $ret->{'day'}->as_string;
    my $night_xpm = $ret->{'night'}->as_string;
    maybe_montage $day_xpm, 'polygon 13, day';
    maybe_montage $night_xpm, 'polygon 13, night';
    eq_or_diff $day_xpm, <<'EOF'
/* XPM */
static char *XPM[] = {
"32 32 2 2",
"XX c #aaaaaa",
"== c #cccccc",
EOF
	. some_image_data_and_end();
    eq_or_diff $night_xpm, <<'EOF'
/* XPM */
static char *XPM[] = {
"32 32 2 2",
"XX c none",
"== c #000000",
EOF
	. some_image_data_and_end();
}

######################################################################
# day+night: one-color transparent bitmap (type 14)
{
    my $raw = <<'EOF'
XPM="32 32 2 2",
"XX  c #000000",
"==  c none",
EOF
    . some_image_data_and_end();

    my $xpm = Typ2Legend::XPM->new([parse_into_lines($raw)]);
    my $ret = $xpm->transform;
    my $day_night_xpm = $ret->{'day+night'}->as_string;
    maybe_montage $day_night_xpm, 'polygon 14, day+night';
    eq_or_diff $day_night_xpm, <<'EOF'
/* XPM */
static char *XPM[] = {
"32 32 2 2",
"XX c none",
"== c #000000",
EOF
	. some_image_data_and_end();
}

######################################################################
# day: one-color transparent bitmap, night: one-color transparent bitmap (type 15)
{
    my $raw = <<'EOF'
XPM="32 32 2 2",
"XX  c #cccccc",
"==  c #000000",
EOF
    . some_image_data_and_end();

    my $xpm = Typ2Legend::XPM->new([parse_into_lines($raw)]);
    my $ret = $xpm->transform(prefer15 => 1);
    my $day_xpm = $ret->{'day'}->as_string;
    my $night_xpm = $ret->{'night'}->as_string;
    maybe_montage $day_xpm, 'polygon 15, day';
    maybe_montage $night_xpm, 'polygon 15, night';
    eq_or_diff $day_xpm, <<'EOF'
/* XPM */
static char *XPM[] = {
"32 32 2 2",
"XX c none",
"== c #cccccc",
EOF
	. some_image_data_and_end();
    eq_or_diff $night_xpm, <<'EOF'
/* XPM */
static char *XPM[] = {
"32 32 2 2",
"XX c none",
"== c #000000",
EOF
	. some_image_data_and_end();
}

######################################################################
# LINES WITH BITMAPS

######################################################################
# day+night: two colors (type 0)
{
    my $raw = <<'EOF'
XPM="32 2 2 2",
"XX  c #00fff0",
"==  c #555555",
EOF
    . some_line_data_and_end();

    my $xpm = Typ2Legend::XPM->new([parse_into_lines($raw)]);
    my $ret = $xpm->transform;
    my $day_night_xpm = $ret->{'day+night'}->as_string;
    maybe_montage $day_night_xpm, 'line+bmap 0, day+night';
    eq_or_diff $day_night_xpm, <<'EOF'
/* XPM */
static char *XPM[] = {
"32 2 2 2",
"XX c #555555",
"== c #00fff0",
EOF
	. some_line_data_and_end();
}

######################################################################
# day: two colors, night: two colors (type 1)
{
    my $raw = <<'EOF'
XPM="32 2 4 2",
"XX  c #ffff00",
"==  c #00ff00",
"**  c #aaaaaa",
"##  c #cccccc",
EOF
    . some_line_data_and_end();

    my $xpm = Typ2Legend::XPM->new([parse_into_lines($raw)]);
    my $ret = $xpm->transform;
    my $day_xpm = $ret->{'day'}->as_string;
    my $night_xpm = $ret->{'night'}->as_string;
    maybe_montage $day_xpm, 'line+bmap 1, day';
    maybe_montage $night_xpm, 'line+bmap 1, night';
    eq_or_diff $day_xpm, <<'EOF'
/* XPM */
static char *XPM[] = {
"32 2 2 2",
"XX c #00ff00",
"== c #ffff00",
EOF
	. some_line_data_and_end();
    eq_or_diff $night_xpm, <<'EOF'
/* XPM */
static char *XPM[] = {
"32 2 2 2",
"XX c #cccccc",
"== c #aaaaaa",
EOF
	. some_line_data_and_end();
}

######################################################################
# day: one color, night: two colors (type 3)
{
    my $raw = <<'EOF'
XPM="32 2 3 2",
"XX  c #00ffff",
"==  c #ff00ff",
"**  c #bbbbbb",
EOF
    . some_line_data_and_end();

    my $xpm = Typ2Legend::XPM->new([parse_into_lines($raw)]);
    my $ret = $xpm->transform;
    my $day_xpm = $ret->{'day'}->as_string;
    my $night_xpm = $ret->{'night'}->as_string;
    maybe_montage $day_xpm, 'line+bmap 3, day';
    maybe_montage $night_xpm, 'line+bmap 3, night';
    eq_or_diff $day_xpm, <<'EOF'
/* XPM */
static char *XPM[] = {
"32 2 2 2",
"XX c none",
"== c #00ffff",
EOF
	. some_line_data_and_end();
    eq_or_diff $night_xpm, <<'EOF'
/* XPM */
static char *XPM[] = {
"32 2 2 2",
"XX c #bbbbbb",
"== c #ff00ff",
EOF
	. some_line_data_and_end();
}

######################################################################
# day: two colors, night: one color (type 5)
{
    my $raw = <<'EOF'
XPM="32 2 3 2",
"XX  c #ff00a0",
"==  c #a0ffa0",
"**  c #777777",
EOF
    . some_line_data_and_end();

    my $xpm = Typ2Legend::XPM->new([parse_into_lines($raw)]);
    my $ret = $xpm->transform(prefer13 => 1);
    my $day_xpm = $ret->{'day'}->as_string;
    my $night_xpm = $ret->{'night'}->as_string;
    maybe_montage $day_xpm, 'line+bmap 5, day';
    maybe_montage $night_xpm, 'line+bmap 5, night';
    eq_or_diff $day_xpm, <<'EOF'
/* XPM */
static char *XPM[] = {
"32 2 2 2",
"XX c #a0ffa0",
"== c #ff00a0",
EOF
	. some_line_data_and_end();
    eq_or_diff $night_xpm, <<'EOF'
/* XPM */
static char *XPM[] = {
"32 2 2 2",
"XX c none",
"== c #777777",
EOF
	. some_line_data_and_end();
}

######################################################################
# day+night: one color, transparent (type 6)
{
    my $raw = <<'EOF'
XPM="32 2 2 2",
"XX  c #804040",
"==  c none",
EOF
    . some_line_data_and_end();

    my $xpm = Typ2Legend::XPM->new([parse_into_lines($raw)]);
    my $ret = $xpm->transform;
    my $day_night_xpm = $ret->{'day+night'}->as_string;
    maybe_montage $day_night_xpm, 'line+bmap 6, day+night';
    eq_or_diff $day_night_xpm, <<'EOF'
/* XPM */
static char *XPM[] = {
"32 2 2 2",
"XX c none",
"== c #804040",
EOF
	. some_line_data_and_end();
}

######################################################################
# day: one color, transparent, night: one color, transparent (type 7)
{
    my $raw = <<'EOF'
XPM="32 2 2 2",
"XX  c #408040",
"==  c #404080",
EOF
    . some_line_data_and_end();

    my $xpm = Typ2Legend::XPM->new([parse_into_lines($raw)]);
    my $ret = $xpm->transform(prefer15 => 1);
    my $day_xpm = $ret->{'day'}->as_string;
    my $night_xpm = $ret->{'night'}->as_string;
    maybe_montage $day_xpm, 'line+bmap 7, day';
    maybe_montage $night_xpm, 'line+bmap 7, night';
    eq_or_diff $day_xpm, <<'EOF'
/* XPM */
static char *XPM[] = {
"32 2 2 2",
"XX c none",
"== c #408040",
EOF
	. some_line_data_and_end();
    eq_or_diff $night_xpm, <<'EOF'
/* XPM */
static char *XPM[] = {
"32 2 2 2",
"XX c none",
"== c #404080",
EOF
	. some_line_data_and_end();
}

######################################################################
# LINES WITH LINE/BORDERWIDTH

######################################################################
# day+night: line color, border color (type 0)
{
    my $raw = <<'EOF';
XPM="0 0 2 2",
"XX  c #000000",
"==  c #ffffff",
EOF

    my $xpm = Typ2Legend::XPM->new([parse_into_lines($raw)]);
    my $ret = $xpm->transform(linewidth => 2, borderwidth => 1);
    my $day_night_xpm = $ret->{'day+night'}->as_string;
    maybe_montage $day_night_xpm, 'line 0, day+night';
    eq_or_diff $day_night_xpm, <<'EOF'
/* XPM */
static char *XPM[] = {
"32 4 2 2",
"XX c #000000",
"== c #ffffff",
EOF
	. solid_line_data_and_end();
}

######################################################################
# day: line color, border color, night: line color, border color (type 1)
{
    my $raw = <<'EOF';
XPM="0 0 4 2",
"XX  c #ff0000",
"==  c #ffffff",
"**  c #888888",
"##  c #000000",
EOF

    my $xpm = Typ2Legend::XPM->new([parse_into_lines($raw)]);
    my $ret = $xpm->transform(linewidth => 2, borderwidth => 1);
    my $day_xpm = $ret->{'day'}->as_string;
    my $night_xpm = $ret->{'night'}->as_string;
    maybe_montage $day_xpm, 'line 1, day';
    maybe_montage $night_xpm, 'line 1, night';
    eq_or_diff $day_xpm, <<'EOF'
/* XPM */
static char *XPM[] = {
"32 4 2 2",
"XX c #ff0000",
"== c #ffffff",
EOF
	. solid_line_data_and_end();
    eq_or_diff $night_xpm, <<'EOF'
/* XPM */
static char *XPM[] = {
"32 4 2 2",
"XX c #888888",
"== c #000000",
EOF
	. solid_line_data_and_end();
}

######################################################################
# day: line+border color, night: line color, border color (type 3)
{
    my $raw = <<'EOF';
XPM="0 0 3 2",
"XX  c #00ff00",
"==  c #ffffff",
"**  c #666666",
EOF

    my $xpm = Typ2Legend::XPM->new([parse_into_lines($raw)]);
    my $ret = $xpm->transform(linewidth => 2, borderwidth => 1);
    my $day_xpm = $ret->{'day'}->as_string;
    my $night_xpm = $ret->{'night'}->as_string;
    maybe_montage $day_xpm, 'line 3, day';
    maybe_montage $night_xpm, 'line 3, night';
    eq_or_diff $day_xpm, <<'EOF';
/* XPM */
static char *XPM[] = {
"32 4 1 2",
"XX c #00ff00",
"XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX",
"XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX",
"XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX",
"XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
};
EOF
    eq_or_diff $night_xpm, <<'EOF'
/* XPM */
static char *XPM[] = {
"32 4 2 2",
"XX c #ffffff",
"== c #666666",
EOF
	. solid_line_data_and_end();
}

######################################################################
# day: line color, border color, night: line+border color (type 5)
{
    my $raw = <<'EOF';
XPM="0 0 3 2",
"XX  c #0000ff",
"==  c #ffffff",
"**  c #777777",
EOF

    my $xpm = Typ2Legend::XPM->new([parse_into_lines($raw)]);
    my $ret = $xpm->transform(linewidth => 2);
    my $day_xpm = $ret->{'day'}->as_string;
    my $night_xpm = $ret->{'night'}->as_string;
    maybe_montage $day_xpm, 'line 5, day';
    maybe_montage $night_xpm, 'line 5, night';
    eq_or_diff $day_xpm, <<'EOF';
/* XPM */
static char *XPM[] = {
"32 2 2 2",
"XX c #0000ff",
"== c #ffffff",
"XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX",
"XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
};
EOF
    eq_or_diff $night_xpm, <<'EOF';
/* XPM */
static char *XPM[] = {
"32 2 1 2",
"XX c #777777",
"XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX",
"XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
};
EOF
}

######################################################################
# day+night: line color (type 6)
{
    my $raw = <<'EOF';
XPM="0 0 1 2",
"XX  c #000000",
EOF

    my $xpm = Typ2Legend::XPM->new([parse_into_lines($raw)]);
    my $ret = $xpm->transform(linewidth => 2);
    my $day_night_xpm = $ret->{'day+night'}->as_string;
    maybe_montage $day_night_xpm, 'line 6, day+night';
    eq_or_diff $day_night_xpm, <<'EOF';
/* XPM */
static char *XPM[] = {
"32 2 1 2",
"XX c #000000",
"XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX",
"XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
};
EOF
}

######################################################################
# day: line color, night: line color (type 7)
{
    my $raw = <<'EOF';
XPM="0 0 2 2",
"XX  c #00ffff",
"==  c #aaaaaa",
EOF

    my $xpm = Typ2Legend::XPM->new([parse_into_lines($raw)]);
    my $ret = $xpm->transform(linewidth => 2);
    my $day_xpm = $ret->{'day'}->as_string;
    my $night_xpm = $ret->{'night'}->as_string;
    maybe_montage $day_xpm, 'line 7, day';
    maybe_montage $night_xpm, 'line 7, night';
    eq_or_diff $day_xpm, <<'EOF';
/* XPM */
static char *XPM[] = {
"32 2 1 2",
"XX c #00ffff",
"XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX",
"XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
};
EOF
    eq_or_diff $night_xpm, <<'EOF';
/* XPM */
static char *XPM[] = {
"32 2 1 2",
"XX c #aaaaaa",
"XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX",
"XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
};
EOF
}

######################################################################
if ($do_montage) {
    chdir $montage_dir
	or die $!;
    system("montage", '-background', 'transparent', '-label', '%f', @montage_args, "montage.xpm");
    system("display", "montage.xpm");
    chdir "/"; # for File::Temp cleanup
}

sub solid_block_32 {
    join(",\n", map { '"' . join("", (map { 'XX' } (1..32))) . '"' } 1..32)
}

sub solid_block_32_and_end {
    solid_block_32() . "\n};\n";
}

sub some_image_data_and_end {
    <<'EOF';
"XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX",
"XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX",
"XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX",
"XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX",
"XXXXXXXXXXXXXX==XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX",
"XXXXXXXXXXXXXXXX==XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX",
"XXXXXXXXXXXXXXXX==XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX==XXXXXXXX",
"XXXXXXXXXXXXXXXX==XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX==XXXXXXXX",
"XXXXXXXXXXXXXXXXXX==XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX==XXXXXXXXXX",
"XXXXXXXXXXXXXXXXXX==XXXXXXXXXXXXXXXXXXXXXXXXXXXXXX==XXXXXXXXXXXX",
"XXXXXXXXXXXXXXXXXXXX==XXXXXXXXXXXXXXXXXXXXXXXXXXXX==XXXXXXXXXXXX",
"XXXXXXXXXXXXXXXXXXXX==XXXXXXXXXXXXXXXXXXXXXXXXXX==XXXXXXXXXXXXXX",
"XXXXXXXXXXXXXXXXXXXXXX==XXXXXXXXXXXXXXXXXXXXXXXX==XXXXXXXXXXXXXX",
"XXXXXXXXXXXXXXXXXXXXXX==XXXXXXXXXXXXXXXXXXXXXX==XXXXXXXXXXXXXXXX",
"XXXXXXXXXXXXXXXXXXXXXX==XXXXXXXXXXXXXXXXXXXXXX==XXXXXXXXXXXXXXXX",
"XXXXXXXXXXXXXXXXXXXXXX==XXXXXXXXXXXXXXXXXXXX==XXXXXXXXXXXXXXXXXX",
"XXXXXXXXXXXXXXXXXXXXXXXX==XXXXXXXXXXXXXXXXXX==XXXXXXXXXXXXXXXXXX",
"XXXXXXXXXXXXXXXXXXXXXXXX==XXXXXXXXXXXXXXXX==XXXXXXXXXXXXXXXXXXXX",
"XXXXXXXXXXXXXXXXXXXXXXXX==XXXXXXXXXXXXXXXX==XXXXXXXXXXXXXXXXXXXX",
"XXXXXXXXXXXXXXXXXXXXXXXX==XXXXXXXXXXXXXX==XXXXXXXXXXXXXXXXXXXXXX",
"XXXXXXXXXXXXXXXXXXXXXXXXXX==XXXXXXXXXXXX==XXXXXXXXXXXXXXXXXXXXXX",
"XXXXXXXXXXXXXXXXXXXXXXXXXX==XXXXXXXXXXXX==XXXXXXXXXXXXXXXXXXXXXX",
"XXXXXXXXXXXXXXXXXXXXXXXXXX==XXXXXXXXXX==XXXXXXXXXXXXXXXXXXXXXXXX",
"XXXXXXXXXXXXXXXXXXXXXXXXXXXX==XXXXXXXX==XXXXXXXXXXXXXXXXXXXXXXXX",
"XXXXXXXXXXXXXXXXXXXXXXXXXXXX==XXXXXX==XXXXXXXXXXXXXXXXXXXXXXXXXX",
"XXXXXXXXXXXXXXXXXXXXXXXXXXXX==XXXXXX==XXXXXXXXXXXXXXXXXXXXXXXXXX",
"XXXXXXXXXXXXXXXXXXXXXXXXXXXXXX==XX==XXXXXXXXXXXXXXXXXXXXXXXXXXXX",
"XXXXXXXXXXXXXXXXXXXXXXXXXXXXXX======XXXXXXXXXXXXXXXXXXXXXXXXXXXX",
"XXXXXXXXXXXXXXXXXXXXXXXXXXXXXX====XXXXXXXXXXXXXXXXXXXXXXXXXXXXXX",
"XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX",
"XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX",
"XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
};
EOF
}

sub some_line_data_and_end {
    <<'EOF';
"======XXXX==========XXXX===========XXXX==========XXXX==========",
"======XXXX==========XXXX===========XXXX==========XXXX=========="
};
EOF
}

sub solid_line_data_and_end {
    <<'EOF';
"================================================================",
"XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX",
"XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX",
"================================================================"
};
EOF
}

sub parse_into_lines {
    my $s = shift;
    $s =~ s<^XPM=><>;
    $s =~ s<};$><>;
    split /\n/, $s;
}

sub maybe_montage ($$) {
    return if !$do_montage;
    my($xpm_data, $label) = @_;
    open my $ofh, ">", "$montage_dir/$label.xpm" or die $!;
    print $ofh $xpm_data;
    close $ofh or die $!;
    push @montage_args, "$label.xpm";
}

__END__
