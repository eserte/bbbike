#!/usr/bin/perl -w
# -*- perl -*-

#
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
use BBBikeTest qw(get_std_opts $do_xxx eq_or_diff create_temporary_content);

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

my $have_nowarnings;
BEGIN {
    $have_nowarnings = 1;
    eval 'use Test::NoWarnings ":early"';
    if ($@) {
	$have_nowarnings = 0;
    }
}

sub non_streaming_loop ($);
sub tie_ixhash_hidden ();

my $datadir = "$FindBin::RealBin/../data";
my $doit; # Note that the -doit tests currently fail, because the
          # roundtrip produces correct data which is not exact like
          # the original data
GetOptions(get_std_opts("xxx"),
	   "doit!" => \$doit,
	  ) or die "usage";

my $basic_tests = 75;
my $doit_tests = 6;
my $strassen_orig_tests = 5;
my $zebrastreifen_tests = 4;
my $zebrastreifen2_tests = 2;
my $zebrastreifen3_tests = 2;
my $encoding_tests = 10;
my $multistrassen_tests = 11;
my $initless_tests = 3;
my $global_directive_tests = 10;
my $tied_global_directive_tests = 1;
my $strict_and_syntax_tests = 12;
my $get_conversion_tests = 9;

plan tests => $basic_tests + $have_nowarnings + $doit_tests + $strassen_orig_tests + $zebrastreifen_tests + $zebrastreifen2_tests + $zebrastreifen3_tests + $encoding_tests + $multistrassen_tests + $initless_tests + $global_directive_tests + $tied_global_directive_tests + $strict_and_syntax_tests + $get_conversion_tests;

goto XXX if $do_xxx;

{
    my $s = Strassen->new;
    ok($s->isa("Strassen"));

    my $ms = MultiStrassen->new($s, $s);
    ok($ms->isa("Strassen"));
    ok($ms->isa("MultiStrassen"), "MultiStrassen isa MultiStrassen");
}

{
    my $s;

    $s = eval { Strassen->new("$FindBin::RealBin/../data/this-file-does-not-exist") };
    like $@, qr{Can't open .*this-file-does-not-exist}, 'error on non-existing strassen file (constructor new)';
    is $s, undef;

    $s = eval { Strassen->new_stream("$FindBin::RealBin/../data/this-file-does-not-exist") };
    like $@, qr{Can't open .*this-file-does-not-exist}, 'error on non-existing strassen file (constructor new_stream)';
    is $s, undef;
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
    {
	my $rec = $s->get(0);
	is($rec->[Strassen::NAME], 'Dudenstr.', 'get on first record, check name');
	is($rec->[Strassen::CAT], 'H', 'get on first record, check category');
	like($rec->[Strassen::COORDS]->[0], qr{^-?\d+,-?\d+$}, 'get on first record, check first coordinate');
    }
    is($s->get(2)->[Strassen::NAME], 'Mehringdamm', 'get on another record');
    {
	my @w; local $SIG{__WARN__} = sub { push @w, @_ };
	{
	    local $TODO = "Currently negative indices are not implemented";
	    is_deeply($s->get(-1), $s->get(2), 'negative index should count from end');
	}
	like "@w", qr{\Qnegative index (-1) in get};
    }
    is_deeply($s->get(4), [undef,[],undef], 'get past end');
    is(scalar @{$s->data}, 3, 'data length unchanged after get past end');

    {
	# init_for_prev and prev: iterate backwards
	$s->init_for_prev;
	my $r;
	$r = $s->prev;
	is $r->[Strassen::NAME], 'Mehringdamm', '1st prev call';
	$s->prev;
	$r = $s->prev;
	is $r->[Strassen::NAME], 'Dudenstr.', 'prev call on first element';
	$r = $s->prev;
	is_deeply $r->[Strassen::COORDS], [], 'prev beyond first element';
	is_deeply $r, Strassen::UNDEF_RECORD, 'alternative check for undef record';
    }

    {
	# init and next: iterate forwards
	$s->init;
	my $r;
	$r = $s->peek;
	is $r->[Strassen::NAME], 'Dudenstr.', 'call peek (would not change the pointer)';
	$r = $s->next;
	is $r->[Strassen::NAME], 'Dudenstr.', '1st next call';
	$s->next;
	$r = $s->next;
	is $r->[Strassen::NAME], 'Mehringdamm', 'next call on last element';
	$r = $s->next;
	is_deeply $r->[Strassen::COORDS], [], 'next beyond last element';
	is_deeply $r, Strassen::UNDEF_RECORD, 'alternative check for undef record';
    }
}

{
    my $data =<<EOF;
#:
#: local_directive: yes!
Stra�e A	? 6353,22515
EOF
    my $s = Strassen->new_from_data_string($data, UseLocalDirectives => 1);
    isa_ok $s, 'Strassen';
    $s->init;
    my $r = $s->next;
    is $r->[Strassen::NAME], 'Stra�e A', 'Got street name';
    is $r->[Strassen::CAT], '?', 'Got category';
    is_deeply $r->[Strassen::COORDS], ['6353,22515'], 'Got coordinates';
    my $dir = $s->get_directives;
    is_deeply $dir->{local_directive}, ['yes!'], 'Got local directive';
    is scalar(keys %$dir), 1, 'Only one local directive';
}

{
    my $data =<<EOF;
#:
#: unclosed_local_directive: yes vvv
Stra�e A	? 6353,22515
EOF
    my $s = Strassen->new_data_string_stream($data); # , UseLocalDirectives => 1);
    eval { $s->read_stream(sub{}) };
    like $@, qr{\QThe following block directives were not closed: 'unclosed_local_directive yes' (start at line 2)\E}, 'unclosed local directive error';
}

{
    my $data =<<EOF;
Stra�e A	? 6353,22515
#: stray_local_directive: yes
EOF
    my $s = Strassen->new_data_string_stream($data); # , UseLocalDirectives => 1);
    eval { $s->read_stream(sub{}) };
    like $@, qr{\QERROR: Stray line directive `stray_local_directive' at end of file\E}, 'stray line directive at end of file error';
}

{
    my $data = <<EOF;
#: title: Testing global directives
#: complex.key: Testing complex global directives
#:
#: section projektierte Radstreifen der Verkehrsverwaltung vvv
#: by http://www.berlinonline.de/berliner-zeitung/berlin/327989.html?2004-03-26 vvv
Heinrich-Heine	? 10885,10928 10939,11045 11034,11249 11095,11389 11242,11720
Leipziger Stra�e zwischen Leipziger Platz und Wilhelmstra�e (entweder beidseitig oder nur auf der S�dseite)	? 8733,11524 9046,11558
Pacelliallee	? 2585,5696 2609,6348 2659,6499 2711,6698 2733,7039
#: by ^^^
#: by Tagesspiegel 2004-07-25 (obige waren auch dabei) vvv
Reichsstr.	H 1391,11434 1239,11567 1053,11735 836,11935 653,12109 504,12293 448,12361 269,12576 147,12640 50,12695 -112,12866 -120,12915
#: by ^^^
#: section ^^^
#
#: section Stra�en in Planung vvv
Magnus-Hirschfeld-Steg: laut Tsp geplant	? 7360,12430 7477,12374
Uferweg an der Kongre�halle: laut Tsp im Fr�hjahr 2005 fertig	?::inwork 7684,12543 7753,12578
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
		ok(grep { /Stra�en in Planung/ } @{ $dir->{section} });
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

 SKIP: {
	skip "Known to fail without Tie::IxHash (unexpected ordering)", 1 if tie_ixhash_hidden;

	is $new_s->global_directives_as_string, <<'EOF', 'get_global_directives -> set_global_directives keeps tied-ness';
#: title: Testing global directives
#: complex.key: Testing complex global directives
#:
EOF
    }

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

{ # Iterators
    my $data = <<EOF;
Dudenstr.	H 9222,8787 8982,8781 8594,8773 8472,8772 8425,8771 8293,8768 8209,8769
#: test_directive: yes
Methfesselstr.	N 8982,8781 9057,8936 9106,9038 9163,9209 9211,9354
Mehringdamm	HH 9222,8787 9227,8890 9235,9051 9248,9350 9280,9476 9334,9670 9387,9804 9444,9919 9444,10000 9401,10199 9395,10233
EOF
    my $s = Strassen->new_from_data_string($data, UseLocalDirectives => 1);
    $s->init;
    $s->init_for_iterator('test_iterator');
    $s->next; # standard iterator is one record further
    {
	my $r = $s->next;
	is $r->[Strassen::NAME], 'Methfesselstr.', 'standard iterator, get record';
	my $dirs = $s->get_directives;
	is $dirs->{test_directive}[0], 'yes', 'standard iterator, get directives';
    }
    {
	my $r = $s->next_for_iterator('test_iterator');
	is $r->[Strassen::NAME], 'Dudenstr.', 'custom iterator, get record';
	my $dirs = $s->get_directives_for_iterator('test_iterator');
	ok !exists $dirs->{test_directive}, 'custom iterator, get record without result';
	$s->next_for_iterator('test_iterator');
	$dirs = $s->get_directives_for_iterator('test_iterator');
	is $dirs->{test_directive}[0], 'yes', 'custom iterator, get record with result';
    }
}

SKIP: {
    skip "Known to fail without Tie::IxHash (unexpected ordering)", 2 if tie_ixhash_hidden;

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
	    SKIP: {
		    skip("No orig file for $file", 1);
		}
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
    my $f = "$datadir/zebrastreifen";
    skip("$f not available", $zebrastreifen_tests)
	if !-r $f;

    my $s = Strassen->new($f, NoRead => 1);
    $s->read_data(ReadOnlyGlobalDirectives => 1);
    my $glob_dir = $s->get_global_directives;
    my $glob_dir2 = Strassen->get_global_directives($f);
    is_deeply($glob_dir2, $glob_dir, 'static and object usage of get_global_directives');
    like($glob_dir->{"category_image.Zs"}->[0], qr{\Qverkehrszeichen/Zeichen_350.svg:\E\d+x\d+});
    is($glob_dir->{"title"}->[0], "Zebrastreifen in Berlin");
    is($glob_dir->{"emacs-mode"}->[0], "-*- bbbike -*-", "Test the emacs-mode hack");
}

SKIP: {
    my $f = "$datadir/zebrastreifen";
    skip("$f not available", $zebrastreifen2_tests)
	if !-r $f;

    my $s = Strassen->new($f, NoRead => 1);
    my $seek_pos;
    $s->read_data(ReadOnlyGlobalDirectives => 1, ReturnSeekPosition => \$seek_pos);
    ok $seek_pos, 'seek position was returned';
    open my $fh, $f or die "Can't open $f: $!";
    seek $fh, $seek_pos, 0 or die "Can't seek: $!";
    chomp(my($first_non_global_directive_line) = <$fh>);
    is $first_non_global_directive_line, '# Die Sammlung hier ist bei weiten nicht vollst�ndig und wird',
	"expected seek position, first line in $f after global directives";
}

SKIP: {
    my $f = "$datadir/zebrastreifen";
    skip("$f not available", $zebrastreifen3_tests)
	if !-r $f;
    skip("no gzip available", $zebrastreifen3_tests)
	if !is_in_path('gzip');

    my(undef,$outfilename) = tempfile(UNLINK => 1, SUFFIX => ".gz");
    my $gzip_cmd = "gzip -c $datadir/zebrastreifen > $outfilename";
    system($gzip_cmd);
    if ($? != 0 || !-s $outfilename) {
	skip("Running '$gzip_cmd' apparently failed", $zebrastreifen3_tests);
    }

    my $s_uncompressed = Strassen->new($f);
    my $s_compressed   = Strassen->new($outfilename);
    is_deeply $s_compressed->data, $s_uncompressed->data, 'compressed and uncompressed data are the same';

    (my $outfilename_without_gz_suffix = $outfilename) =~ s{\.gz$}{};
    my $s_compressed_2 = Strassen->new($outfilename_without_gz_suffix);
    is_deeply $s_compressed->data, $s_uncompressed->data, 'loading without .gz suffix works';
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

    my($tmpfh,$tmpfile) = create_temporary_content($octet_data, SUFFIX => ".bbd");

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
	my($tmpfh,$tmpfile) = create_temporary_content($data);
	my $s = Strassen->new($tmpfile);
	my $r = $s->next;
	is $r->[Strassen::NAME], 'Heinrich-Heine';
    }
}

SKIP: {
    skip "Known to fail without Tie::IxHash (unexpected ordering)", 1 if tie_ixhash_hidden;

    my $data =<<EOF;
#:
#: XXX: value1 vvv
#: XXX: value2 vvv
#: by: http://www.example.org vvv
Stra�e A	? 6353,22515 6301,22581
Stra�e B	? 16353,22515 16301,22581
#: by: ^^^
#: XXX: ^^^
#: XXX: ^^^
EOF
    my $s = Strassen->new_from_data_string($data, UseLocalDirectives => 1);
    my $data2 = $s->as_string;
    eq_or_diff $data2, $data, 'Nested local block directives after serializing';
}

SKIP: {
    skip "Known to fail without Tie::IxHash (unexpected ordering)", 1 if tie_ixhash_hidden;

    my $data = <<EOF;
#:
#: by: http://www.example.org
#: XXX: value1 vvv
#: last_checked: 2011-06-25 vvv
#: next_check: 2012-03-01 vvv
Stra�e A	?::inwork 26289,12772
Stra�e B	?::inwork 26289,12772
#: XXX: value2 vvv
Stra�e C	?::inwork 26289,12772
Stra�e D	?::inwork 26289,12772
#: XXX: ^^^
#: next_check: ^^^
#: last_checked: ^^^
#: XXX: ^^^
EOF
    my $s = Strassen->new_from_data_string($data, UseLocalDirectives => 1);
    my $data2 = $s->as_string;
    eq_or_diff $data2, $data, 'Nested local block directives after serializing (complicated case)';
}

{
    # A complicated nested case. The following will be turned into not
    # cleanly nested block directives.
    my $data = <<EOF;
#:
#: by: http://www.potsdam.de/cms/dokumente/10073161_1189396/13ef9d53/AblPdm1_11.pdf
#: note: Privatstra�e
#: XXX fehlt in Potsdam.coords.data
Bienenwinkel (Potsdam): Qualit�t? Genauer Verlauf der Stra�e?   ? -13345,1962 -13316,2003 -13279,1958
#: by: http://www.potsdam.de/cms/dokumente/10073161_1189396/13ef9d53/AblPdm1_11.pdf
#: note: Privatstra�e
#: XXX fehlt in Potsdam.coords.data
Zum Exerzierhaus (Potsdam): Qualit�t? Genauer Verlauf der Stra�e?       ? -13108,2010 -12981,2014
#: by: http://www.potsdam.de/cms/dokumente/10072610_974248/9aba6281/abl16_10.pdf
#: note: Privatstra�e
#: XXX fehlt in Potsdam.coords.data
Zum M�hlenteich (Potsdam-Golm): Qualit�t? Genauer Verlauf der Stra�e?   ? -19211,-677 -19249,-605
EOF

    my $s = Strassen->new_from_data_string($data, UseLocalDirectives => 1);
    my $data2 = $s->as_string;
    my @warnings;
    local $SIG{__WARN__} = sub { push @warnings, @_ };
    my $s2 = Strassen->new_from_data_string($data2, UseLocalDirectives => 1);
    is_deeply(\@warnings, [], 'No warnings in complicated nested case');
}

{ # $global_directive_tests
    my $s = Strassen->new;
    ok !$s->exists_global_directive('not_existing'), 'check if global directive does not exist';
    $s->set_global_directive('some' => 'thing');
    is $s->get_global_directive('some'), 'thing', 'set/get global directive';
    ok $s->exists_global_directive('some'), 'check if global directive exists';
    $s->set_global_directive('some' => 'thing', 'else');
    is $s->get_global_directive('some'), 'thing', 'after setting multiple values';
    is_deeply $s->get_global_directives, { some => [qw(thing else)] }, 'get_global_directives';
    my $expected_string = <<'EOF';
#: some: thing
#: some: else
#:
EOF
    is $s->global_directives_as_string, $expected_string, 'global_directives_as_string on object';
    my $glob_dir = $s->get_global_directives;
    is Strassen::global_directives_as_string($glob_dir), $expected_string, 'global_directives_as_string on hash';

    $s->add_global_directive(some => qw(three four));
    $s->add_global_directive(new => qw(one));
    eq_or_diff $s->get_global_directives, {
					   some => [qw(thing else three four)],
					   new => [qw(one)],
					  }, 'expected global directives after add_global_directive calls';

    ok !eval { Strassen::global_directives_as_string([]); 0 }, 'global_directives_as_string on non-hash is an error';
    like $@, qr/Unexpected argument to global_directives_as_string/, 'error message';
}

SKIP: {
    skip "Known to fail without Tie::IxHash (unexpected ordering)", $tied_global_directive_tests if tie_ixhash_hidden;

    my $s = Strassen->new;
    $s->set_global_directive('first'  => '1');
    $s->add_global_directive('second' => '2'); # add_* or set_* shouldn't make a difference
    $s->set_global_directive('third'  => '3');
    is $s->global_directives_as_string, <<'EOF', 'global directives are ordered (if Tie::IxHash is available)';
#: first: 1
#: second: 2
#: third: 3
#:
EOF
}

{ # Strict
    my $gooddata = <<"EOF";
Street\tX1,2 3,4
EOF
    my $baddata = <<"EOF";
Street\tX1,2 3,4
Bad line
EOF
    my(undef, $goodfile) = create_temporary_content($gooddata, SUFFIX => '.bbd');
    my(undef, $badfile) = create_temporary_content($baddata, SUFFIX => '.bbd');

    # syntax check is implemented using Strict=>1 behind the scenes
    ok(Strassen->syntax_check_on_file($goodfile), 'no syntax errors for good file');
    ok(Strassen->syntax_check_on_data_string($gooddata), 'no syntax errors for good data string');

    {
	local $Strassen::STRICT = 1;

	my $s;

	$s = Strassen->new($goodfile);
	non_streaming_loop $s;
	pass 'strict check with global var (file, non-streaming, good data)';

	$s = Strassen->new_from_data_string($gooddata);
	non_streaming_loop $s;
	pass 'strict check with global var (data, non-streaming, good data)';

	$s = Strassen->new($badfile);
	eval { non_streaming_loop $s };
	like $@, qr{ERROR: Probably tab character is missing}, 'strict check with global var (file, non-streaming)';

	$s = Strassen->new_from_data_string($baddata);
	eval { non_streaming_loop $s };
	like $@, qr{ERROR: Probably tab character is missing}, 'strict check with global var (data string, non-streaming)';

	eval { Strassen->new_stream($badfile)->read_stream(sub {}) };
	like $@, qr{ERROR: Probably tab character is missing}, 'strict check with global var (file)';

	eval { Strassen->new_data_string_stream($baddata)->read_stream(sub {}) };
	like $@, qr{ERROR: Probably tab character is missing}, 'strict check with global var (data string)';
    }

    # note: no Strict => 1 for non-streaming variants implemented
    eval { Strassen->new_stream($badfile, Strict => 1)->read_stream(sub {}) };
    like $@, qr{ERROR: Probably tab character is missing}, 'strict check with option (file)';
    eval { Strassen->new_data_string_stream($baddata, Strict => 1)->read_stream(sub {}) };
    like $@, qr{ERROR: Probably tab character is missing}, 'strict check with option (data string)';

    ok !Strassen->syntax_check_on_file($badfile);
    ok !Strassen->syntax_check_on_data_string($baddata);
}

{
    # push
    my $s = Strassen->new;
    $s->push(["name",  ["0,0", "1,1"],     "X"]);
    $s->push(["name2", ["10,10", "21,21"], "X"]);
    is_deeply $s->data, ["name\tX 0,0 1,1\n", "name2\tX 10,10 21,21\n"];
}

{
    # get_conversion, get_karte, without map directive
    my $data = <<EOF;
#:
#: note: no global directives
Street 42	H 1000,1000 2000,1000
EOF
    my $s = Strassen->new_from_data_string($data);
    my $k = $s->get_karte;
    isa_ok $k, 'Karte';
    isa_ok $k, 'Karte::Standard';
    is $s->get_conversion, undef, 'no conversion needed (implicit standard)';
    is $s->get_conversion(-tomap => 'standard'), undef, 'no conversion needed (explicit standard)';
    my $conv = $s->get_conversion(-tomap => 'polar');
    isa_ok $conv, 'CODE', 'got conversion function';
}

{
    # get_conversion, get_karte, with map directive
    my $data = <<EOF;
#: map: polar
#:
Street 42	H 13.5,52.5 13.6,52.5
EOF
    my $s = Strassen->new_from_data_string($data);
    my $k = $s->get_karte;
    isa_ok $k, 'Karte';
    isa_ok $k, 'Karte::Polar';
    is $s->get_conversion(-tomap => 'polar'), undef, 'no conversion needed';
    my $conv = $s->get_conversion;
    isa_ok $conv, 'CODE', 'got conversion function';
}

sub non_streaming_loop ($) {
    my $s = shift;
    $s->init;
    while() {
	my $r = $s->next;
	last if !@{ $r->[Strassen::COORDS] || [] };
    }
}

# Note: this test script will fail if Tie::IxHash is not installed,
# after all, it's a prereq. However, when called with Devel::Hide it
# should still pass.
sub tie_ixhash_hidden () {
    return 1 if defined &Devel::Hide::_is_hidden && Devel::Hide::_is_hidden("Tie/IxHash.pm");
}

__END__
