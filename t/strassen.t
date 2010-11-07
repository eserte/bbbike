#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: strassen.t,v 1.22 2008/09/26 20:31:44 eserte Exp $
# Author: Slaven Rezic
#

use strict;

use FindBin;
use lib ("$FindBin::RealBin/..",
	 "$FindBin::RealBin/../lib",
	 "$FindBin::RealBin/../data",
	 "$FindBin::RealBin",
	);
use File::Temp qw(tempfile);
use Getopt::Long;

use Strassen;
use BBBikeUtil qw(is_in_path);
use BBBikeTest qw(get_std_opts $do_xxx eq_or_diff);

BEGIN {
    if (!eval q{
	use Test::More;
	use File::Temp qw(tempfile);
	1;
    }) {
	print "1..0 # skip no Test::More and/or File::Temp module\n";
	exit;
    }
}

my $datadir = "$FindBin::RealBin/../data";
my $doit; # Note that the -doit tests currently fail, because the
          # roundtrip produces correct data which is not exact like
          # the original data
GetOptions(get_std_opts("xxx"),
	   "doit!" => \$doit,
	  ) or die "usage";

my $basic_tests = 36;
my $doit_tests = 6;
my $strassen_orig_tests = 5;
my $zebrastreifen_tests = 3;
my $encoding_tests = 10;
my $multistrassen_tests = 11;
my $initless_tests = 3;

plan tests => $basic_tests + $doit_tests + $strassen_orig_tests + $zebrastreifen_tests + $encoding_tests + $multistrassen_tests + $initless_tests;

goto XXX if $do_xxx;

{
    my $s = Strassen->new;
    ok($s->isa("Strassen"));

    my $ms = MultiStrassen->new($s, $s);
    ok($ms->isa("Strassen"));
    ok($ms->isa("MultiStrassen"), "MultiStrassen isa MultiStrassen");
}

{
    my $s = Strassen->new("strassen");
    my $count = scalar @{$s->data};
    ok($count > 0);
    is($s->id, "strassen", "Non-empty data");

    my %seen;

    my $i = 0;
    $s->init;
    while(1) {
	my $r = $s->next;
	last if !@{ $r->[Strassen::COORDS] };
	$i++;
	$seen{"Sonntagstr."}++   if $r->[Strassen::NAME] eq 'Sonntagstr.';
	$seen{"Dudenstr."}++     if $r->[Strassen::NAME] eq 'Dudenstr.';
	$seen{"Comeniusplatz"}++ if $r->[Strassen::NAME] eq 'Comeniusplatz';
    }
    is($count, $i, "Checking iteration");
    is(scalar keys %seen, 3, "Streets seen");
}

{
    my $ms = MultiStrassen->new(qw(strassen landstrassen landstrassen2));
    is($ms->id, "strassen_landstrassen_landstrassen2", "Checking id");
}

{
    my $data = <<EOF;
A	A 0,0
#: global directive
# should be ignored	B 1,1
C	C 2,2
EOF
    my $s = Strassen->new_from_data_string($data);
    is(scalar @{$s->data}, 2, "Constructing from string data (containing comments and directives)");
}

{
    my $data = <<EOF;
Dudenstr.	H 9222,8787 8982,8781 8594,8773 8472,8772 8425,8771 8293,8768 8209,8769
Methfesselstr.	N 8982,8781 9057,8936 9106,9038 9163,9209 9211,9354
Mehringdamm	HH 9222,8787 9227,8890 9235,9051 9248,9350 9280,9476 9334,9670 9387,9804 9444,9919 9444,10000 9401,10199 9395,10233
EOF
    my $s = Strassen->new_from_data_string($data);
    is(scalar @{$s->data}, 3, "Constructing from string data");
}

{
    my $data = <<EOF;
#: title: Testing global directives
#: complex.key: Testing complex global directives
#:
#: section projektierte Radstreifen der Verkehrsverwaltung vvv
#: by http://www.berlinonline.de/berliner-zeitung/berlin/327989.html?2004-03-26 vvv
Heinrich-Heine	? 10885,10928 10939,11045 11034,11249 11095,11389 11242,11720
Leipziger Straße zwischen Leipziger Platz und Wilhelmstraße (entweder beidseitig oder nur auf der Südseite)	? 8733,11524 9046,11558
Pacelliallee	? 2585,5696 2609,6348 2659,6499 2711,6698 2733,7039
#: by ^^^
#: by Tagesspiegel 2004-07-25 (obige waren auch dabei) vvv
Reichsstr.	H 1391,11434 1239,11567 1053,11735 836,11935 653,12109 504,12293 448,12361 269,12576 147,12640 50,12695 -112,12866 -120,12915
#: by ^^^
#: section ^^^
#
#: section Straßen in Planung vvv
Magnus-Hirschfeld-Steg: laut Tsp geplant	? 7360,12430 7477,12374
Uferweg an der Kongreßhalle: laut Tsp im Frühjahr 2005 fertig	?::inwork 7684,12543 7753,12578
#: section ^^^
EOF
    for my $preserve_line_info (0, 1) {
	my $s = Strassen->new_from_data_string
	    ($data,
	     UseLocalDirectives => 1,
	     PreserveLineInfo => $preserve_line_info,
	    );
	is(scalar @{ $s->data }, 6, "Constructing from string data with directives (PreserveLineInfo=$preserve_line_info)");
	$s->init_for_iterator("bla");
	while(1) {
	    my $r = $s->next_for_iterator("bla");
	    last if !@{ $r->[Strassen::COORDS] };
	    my $dir = $s->get_directive_for_iterator("bla");
	    my $name = $r->[Strassen::NAME];
	    if ($name eq 'Heinrich-Heine') {
		ok(grep { /projektierte Radstreifen/ } @{ $dir->{section} });
		ok(grep { /berliner-zeitung/ } @{ $dir->{by} });
	    } elsif ($name eq 'Reichsstr.') {
		ok(grep { /projektierte Radstreifen/ } @{ $dir->{section} });
		ok(grep { /Tagesspiegel/ } @{ $dir->{by} } );
	    } elsif ($name =~ /^Magnus-Hirschfeld-Steg/) {
		ok(grep { /Straßen in Planung/ } @{ $dir->{section} });
		is($dir->{by}, undef);
	    }
	}
    }

    my $s = Strassen->new_from_data_string($data);
    my $new_s = Strassen->new;
    $new_s->set_global_directives($s->get_global_directives);
    my $new_global_directives = $new_s->get_global_directives;
    my $old_global_directives = $s->get_global_directives;
    is_deeply($new_global_directives, $old_global_directives, "Copied global directives");
    is($new_global_directives, $old_global_directives, "It's really the same referenced object");

    is($s->get_global_directive("title"), "Testing global directives");
    is($s->get_global_directive("complex.key"), "Testing complex global directives");
}

{
    # empty global directives
    my $data = <<EOF;
#:
#: section projektierte Radstreifen der Verkehrsverwaltung vvv
Heinrich-Heine	? 10885,10928 10939,11045 11034,11249 11095,11389 11242,11720
#: section ^^^
EOF
    for my $preserve_line_info (0, 1) {
	my $s = Strassen->new_from_data_string
	    ($data,
	     UseLocalDirectives => 1,
	     PreserveLineInfo => $preserve_line_info,
	    );
	is(scalar @{ $s->data }, 1, "Constructing from string data with directives (PreserveLineInfo=$preserve_line_info)");
	$s->init_for_iterator("bla");
	while(1) {
	    my $r = $s->next_for_iterator("bla");
	    last if !@{ $r->[Strassen::COORDS] };
	    my $dir = $s->get_directive_for_iterator("bla");
	    my $name = $r->[Strassen::NAME];
	    if ($name eq 'Heinrich-Heine') {
		ok(grep { /projektierte Radstreifen/ } @{ $dir->{section} });
	    }
	}
	is_deeply($s->get_global_directives, {}, "No global directives");
    }
}

{
    for my $preserve_line_info (0, 1) {
	my $s = Strassen->new_from_data_string(<<EOF, UseLocalDirectives => 1, PreserveLineInfo => $preserve_line_info)
#:
#: XXX block vvv
1	1 1,1
2	2 2,2
#: XXX ^^^
#: XXX line
3	3 3,3
#: XXX line
4	4 4,4
5	5 5,5
#: XXX block vvv
6	6 6,6
#: XXX ^^^
7	7 7,7
#: XXX multiple1
#: XXX multiple2
8	8 8,8
#: XXX1 multiple
#: XXX2 multiple
9	9 9,9
EOF
	    or diag "This test may fail if Tie::IxHash is not installed; then the ordering of directives cannot be preserved";

	eq_or_diff($s->as_string, <<EOF, "block directives are preserved (PreserveLineInfo=$preserve_line_info)")
#:
#: XXX: block vvv
1	1 1,1
2	2 2,2
#: XXX: ^^^
#: XXX: line vvv
3	3 3,3
4	4 4,4
#: XXX: ^^^
5	5 5,5
#: XXX: block
6	6 6,6
7	7 7,7
#: XXX: multiple1
#: XXX: multiple2
8	8 8,8
#: XXX1: multiple
#: XXX2: multiple
9	9 9,9
EOF
	    or diag "This test may fail if Tie::IxHash is not installed; then the ordering of directives cannot be preserved";
    }
}

{
    # See comment above (-doit)
 SKIP: {
	skip("Enable more tests with -doit option", $doit_tests) if !$doit;
	skip("No diff", $doit_tests) if !is_in_path("diff");
	my $preserve_comments = 1;
	my $preserve_line_info = 1;
	for my $file (qw(strassen landstrassen landstrassen2 fragezeichen qualitaet_s handicap_s)) {
	    my $orig_file = "$datadir/$file-orig";
	    if (-e $orig_file) {
		my $s = Strassen->new($orig_file,
				      UseLocalDirectives => 1,
				      PreserveLineInfo => $preserve_line_info,
				      PreserveComments => $preserve_comments,
				     );
		my($outfh,$outfilename) = tempfile(UNLINK => 1);					       
		close $outfh;
		$s->write($outfilename);
		system("diff", "-u", $orig_file, $outfilename);
		is($?, 0, "Roundtrip with $orig_file ok (PreserveLineInfo=$preserve_line_info, PreserveComments=$preserve_comments)");
	    } else {
		skip("No orig file", $doit_tests);
	    }
	}
    }
}

SKIP: {
    my $f = "strassen-orig";
    skip("$f not available", $strassen_orig_tests)
	if (!-r "$FindBin::RealBin/../data/$f");

    my $s = Strassen->new($f, NoRead => 1);
    my $data = $s->{Data};
    ok(!$data || !@$data, "No data read");
    $s->read_data(ReadOnlyGlobalDirectives => 1);
    ok(!$data || !@$data, "Still no data read");

    my $glob_dir = Strassen->get_global_directives($f);
    is_deeply($s->{GlobalDirectives}, $glob_dir, "Expected global directives");

    like(join(",", @{$glob_dir->{"title.de"}}), qr{stra.*en.*berlin}i, "German title");

    # test write and append
    my($outfh,$outfilename) = tempfile(UNLINK => 1);					       
    close $outfh;
    $s->write($outfilename);
    my $size1 = -s $outfilename;
    $s->append($outfilename);
    my $size2 = -s $outfilename;
    is($size1*2, $size2, "write and append");
}

SKIP: {
    my $f = "$FindBin::RealBin/../misc/zebrastreifen";
    skip("$f not available", $zebrastreifen_tests)
	if !-r $f;

    my $s = Strassen->new($f, NoRead => 1);
    $s->read_data(ReadOnlyGlobalDirectives => 1);
    my $glob_dir = Strassen->get_global_directives($f);
    like($glob_dir->{"category_image.Zs"}->[0], qr{^\Qverkehrszeichen/Zeichen_350.svg:24x24});
    is($glob_dir->{"title"}->[0], "Zebrastreifen in Berlin");
    is($glob_dir->{"emacs-mode"}->[0], "-*- bbbike -*-", "Test the emacs-mode hack");
}

SKIP: {
    skip("Need utf-8 (very!) capable perl", $encoding_tests)
	if $] < 5.008;
    skip("Need Encode module", $encoding_tests)
	if !eval { require Encode; 1 };

    my $data = <<EOF;
#: encoding: utf-8
#:
\x{20ac}	X 2,2
Nonumlaut	X 1,1
EOF
    my $octet_data = Encode::encode("utf-8", $data);
    my $s = Strassen->new_from_data_string($octet_data);
    my $global_dirs = $s->get_global_directives;
    is($global_dirs->{encoding}->[0], "utf-8", "Encoding directive");
    is($s->get_global_directive("encoding"), "utf-8", "get_global_directive shortcut");
    is(scalar @{$s->data}, 2);
    $s->init;
    my $rec = $s->next;
    is($rec->[Strassen::NAME], "\x{20ac}", "Got unicode character");

    my($tmpfh,$tmpfile) = tempfile(SUFFIX => ".bbd",
				   UNLINK => 1);
    binmode $tmpfh, ":utf8";
    print $tmpfh $data or die $!;
    close $tmpfh or die $!;

    my $s2 = Strassen->new($tmpfile);
    my $global_dirs2 = $s2->get_global_directives;
    is_deeply($global_dirs2, $global_dirs, "Global directives do not differ when loading from file");
    is_deeply($s2->data, $s->data, "Data does not differ when loading from file");

    my($tmpfh2,$tmpfile2) = tempfile(SUFFIX => ".bbd",
				     UNLINK => 1);
    $s2->write($tmpfile2);
    my $tmpcontent  = do { open my $fh, $tmpfile  or die $!; local $/; <$fh> };
    my $tmpcontent2 = do { open my $fh, $tmpfile2 or die $!; local $/; <$fh> };
    eq_or_diff($tmpcontent2, $tmpcontent, "File contents from $tmpfile the same after write ($tmpfile2)");

    my $ms = MultiStrassen->new($s, $s2);
    my $global_dirs_multi = $ms->get_global_directives;
    is($global_dirs_multi->{encoding}->[0], "utf-8", "Encoding directive for MultiStrassen object");

    my($tmpfh3,$tmpfile3) = tempfile(SUFFIX => ".bbd",
				     UNLINK => 1);
    $ms->write($tmpfile3);

    my $ms2 = Strassen->new($tmpfile3);
    my $global_dirs_multi2 = $ms2->get_global_directives;
    is_deeply($global_dirs_multi2, $global_dirs_multi, "Global directives do not differ when loading from file (MultiStrassen)");
    is_deeply($ms2->data, $ms->data, "Data does not differ when loading from file (MultiStrassen)");
}

{
    # directive-less
    my @data;
    $data[0] = <<EOF;
Z	Z 0,0
Y	Y 0,0
EOF
    # with directives
    $data[1] = <<EOF;
A	A 0,0
#: local: 1
B	B 0,0
EOF
    # also with
    $data[2] = <<EOF;
C	C 0,0
#: local: 2
D	D 0,0
EOF
    my @s;
    for my $i (0..2) {
	push @s, Strassen->new_from_data_string($data[$i], UseLocalDirectives => 1);
    }

    {
	my $ms = MultiStrassen->new($s[0], $s[1]);
	is_deeply($ms->get_directives(0), {}, "No directives in first dataset");
	is_deeply($ms->get_directives(3), { local => [1] }, "Found directive in second dataset");
    }

    {
	my $ms = MultiStrassen->new($s[1], $s[2]);
	is_deeply($ms->get_directives(0), {});
	is_deeply($ms->get_directives(1), { local => [1] });
	is_deeply($ms->get_directives(2), {});
	is_deeply($ms->get_directives(3), { local => [2] });
    }

    {
	my $ms = MultiStrassen->new($s[1], $s[0]);
	is_deeply($ms->get_directives(1), { local => [1] });
	is_deeply($ms->get_directives(3), {});
    }

    {
	my $ms = MultiStrassen->new($s[1], $s[0], $s[2]);
	is_deeply($ms->get_directives(1), { local => [1] });
	is_deeply($ms->get_directives(3), {});
	is_deeply($ms->get_directives(5), { local => [2] });
    }

}

{
    # init-less operation
    my $data = <<EOF;
Heinrich-Heine	? 10885,10928 10939,11045 11034,11249 11095,11389 11242,11720
EOF
    {
	my $s = Strassen->new_from_data_string($data);
	my $r = $s->next;
	is $r->[Strassen::NAME], 'Heinrich-Heine';
    }

    {
	my $s = Strassen->new_from_data_ref([split /\n/, $data]);
	my $r = $s->next;
	is $r->[Strassen::NAME], 'Heinrich-Heine';
    }

    {
	my($tmpfh,$tmpfile) = tempfile(UNLINK => 1);
	print $tmpfh $data;
	close $tmpfh or die $!;
	my $s = Strassen->new($tmpfile);
	my $r = $s->next;
	is $r->[Strassen::NAME], 'Heinrich-Heine';
    }
}

__END__
