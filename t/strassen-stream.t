#!/usr/bin/perl -w
# -*- perl -*-

#
# Author: Slaven Rezic
#

use strict;

use FindBin;
use lib ("$FindBin::RealBin/..",
	 "$FindBin::RealBin/../lib",
	);

use Data::Dumper;

use Strassen::Core;

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

plan tests => 28 * 2 + 9;

my $complex_data = <<'EOF';
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
# Just a comment.

Reichsstr.	H 1391,11434 1239,11567 1053,11735 836,11935 653,12109 504,12293 448,12361 269,12576 147,12640 50,12695 -112,12866 -120,12915
#: by ^^^
#: section ^^^
#
#: section Stra�en in Planung vvv
Magnus-Hirschfeld-Steg: laut Tsp geplant	? 7360,12430 7477,12374
Uferweg an der Kongre�halle: laut Tsp im Fr�hjahr 2005 fertig	?::inwork 7684,12543 7753,12578
#: section ^^^
EOF
my $complex_data_line_number = 19;

for my $mode ('file', 'data_string') {
    {
	my $data = <<'EOF';
Dudenstr.	H 9222,8787 8982,8781 8594,8773 8472,8772 8425,8771 8293,8768 8209,8769
Methfesselstr.	N 8982,8781 9057,8936 9106,9038 9163,9209 9211,9354
Mehringdamm	HH 9222,8787 9227,8890 9235,9051 9248,9350 9280,9476 9334,9670 9387,9804 9444,9919 9444,10000 9401,10199 9395,10233
EOF
	my $s = $mode eq 'file' ? Strassen->new_stream(makebbd($data)) : Strassen->new_data_string_stream($data);
	isa_ok($s, "Strassen");
	my @data;
	$s->read_stream(sub { push @data, [@_] });
	is(@data, 3, "Three records read");

	is($data[0][0][Strassen::NAME], "Dudenstr.", "First record, name");
	is($data[0][0][Strassen::CAT], "H");
	is($data[0][0][Strassen::COORDS][0], "9222,8787");
	is($data[0][1], undef, "no local directives");
	is($data[0][2], 1, "First line");

	is($data[-1][0][Strassen::NAME], "Mehringdamm", "Last record, name");
	is($data[-1][0][Strassen::CAT], "HH");
	is($data[-1][0][Strassen::COORDS][-1], "9395,10233");
	is($data[-1][1], undef, "no local directives");
	is($data[-1][2], 3, "Third line");
    }

    {
	my $data = $complex_data;
	my $s = $mode eq 'file' ? Strassen->new_stream(makebbd($data)) : Strassen->new_data_string_stream($data);
	isa_ok($s, "Strassen");
	my @data;
	$s->read_stream(sub { push @data, [@_] });

	is(@data, 6, "Six records read");
	is($s->get_global_directives->{title}[0], "Testing global directives", "Global directives look OK");
	is($s->get_global_directives->{"complex.key"}[0], "Testing complex global directives", "Complex global directives look OK");

	is($data[0][0][Strassen::NAME], "Heinrich-Heine", "First record, name");
	is($data[0][0][Strassen::CAT], "?");
	is($data[0][0][Strassen::COORDS][0], "10885,10928");
	is($data[0][1]{section}[0], "projektierte Radstreifen der Verkehrsverwaltung", "Block directive")
	    or diag(Dumper($data[0]));
	is($data[0][1]{by}[0], "http://www.berlinonline.de/berliner-zeitung/berlin/327989.html?2004-03-26", "Another block directive");
	is($data[0][2], 6, "Line number");

	is($data[-1][0][Strassen::NAME], "Uferweg an der Kongre�halle: laut Tsp im Fr�hjahr 2005 fertig", "Last record, name");
	is($data[-1][0][Strassen::CAT], "?::inwork");
	is($data[-1][0][Strassen::COORDS][-1], "7753,12578");
	is($data[-1][1]{section}[0], "Stra�en in Planung", "Block directive")
	    or diag(Dumper($data[0]));
	ok(!exists $data[-1][1]{by}, "This directive is missing here");
	is($data[-1][2], $complex_data_line_number, "Line number of last line");
    }
}

{
    my $s = Strassen->new_data_string_stream($complex_data);
    isa_ok($s, 'Strassen');
    my @data;
    my @comment_records;
    $s->read_stream(sub {
			if (UNIVERSAL::isa($_[0], 'HASH')) {
			    push @comment_records, $_[0];
			} else {
			    push @data, [@_];
			}
		    }, PreserveComments => 1);
    is($data[-1][2], $complex_data_line_number, "Line number of last line");
    is_deeply(\@comment_records, [
				  {
				   line => "# Just a comment.\n",
				   type => 'comment',
				  },
				  {
				   line => "\n",
				   type => 'emptyline',
				  },
				  {
				   line => "#\n",
				   type => 'comment',
				  },
				 ])
	or diag explain(\@comment_records);
}

######################################################################
# various error conditions
{
    my $error_data = <<'EOF';
#: 
#: next_check: 1970-01-01 vvv
Street A	H 1,1 2,2
EOF
    my $s_inmem = Strassen->new_data_string_stream($error_data);
    eval { $s_inmem->read_stream(sub { }); };
    like $@, qr{\QThe following block directives were not closed: 'next_check 1970-01-01' (start at line 2)}, 'expected error (directive not closed)';

    my $s_file = Strassen->new_stream(makebbd($error_data));
    eval { $s_file->read_stream(sub { }); };
    like $@, qr{\QThe following block directives were not closed: 'next_check 1970-01-01' (start at \E.*\Q.bbd line 2)}, 'expected error (directive not closed), with file/line location';
}

{
    local $Strassen::STRICT = 1;

    my $error_data = <<'EOF';
#: 
Street A	H 1,1 2,2
#: next_check ^^^
EOF
    my $s_inmem = Strassen->new_data_string_stream($error_data);
    eval { $s_inmem->read_stream(sub { }); };
    like $@, qr{\QUnexpected closed directive 'next_check' at line 3, but expected one of:}, 'expected error (unexpected closed directive)';

    my $s_file = Strassen->new_stream(makebbd($error_data));
    eval { $s_file->read_stream(sub { }); };
    like $@, qr{\QUnexpected closed directive 'next_check' at \E.*\Q.bbd line 3, but expected one of:}, 'expected error (unexpected closed directive), with file/line location';
}

{
    local $Strassen::STRICT = 1;

    my $error_data = <<'EOF';
#: 
#: last_checked: 1970-01-01 vvv
Street A	H 1,1 2,2
#: next_check ^^^
#: last_checked: ^^^
EOF
    my $s_inmem = Strassen->new_data_string_stream($error_data);
    eval { $s_inmem->read_stream(sub { }); };
    like $@, qr{\QUnexpected closed directive 'next_check' at line 4, but expected one of: last_checked}, 'expected error (unexpected closed directive)';

    my $s_file = Strassen->new_stream(makebbd($error_data));
    eval { $s_file->read_stream(sub { }); };
    like $@, qr{\QUnexpected closed directive 'next_check' at \E.*\Q.bbd line 4, but expected one of: last_checked}, 'expected error (unexpected closed directive), with file/line location';
}

sub makebbd {
    my $data = shift;
    my($tmpfh,$tmpfile) = tempfile(UNLINK => 1, SUFFIX => ".bbd");
    print $tmpfh $data;
    close $tmpfh
	or die $!;
    $tmpfile;
}

__END__
