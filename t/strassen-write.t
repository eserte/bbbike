use strict;

use FindBin;
use lib ("$FindBin::RealBin/..",
	 "$FindBin::RealBin/../lib",
	 "$FindBin::RealBin",
	);

BEGIN {
    if (!eval q{
	use Encode qw(encode);
	use File::Temp qw(tempdir);
	use IO::File ();
	use Test::More;
	1;
    }) {
	print "1..0 # skip no Encode, File::Temp, IO::File and/or Test::More module\n";
	exit;
    }
}

use Strassen;

my $have_nowarnings;
BEGIN {
    $have_nowarnings = 1;
    eval 'use Test::NoWarnings ":early"';
    if ($@) {
	$have_nowarnings = 0;
    }
}

plan 'no_plan';

sub slurp { join '', IO::File->new(shift)->getlines }

my $tempdir = tempdir("bbbike-strassen-write-t-XXXXXXXX", TMPDIR => 1, CLEANUP => 1);

{
    my $bbddata = <<"EOF";
\xdcmlaut street	X 1,1 2,2
EOF
    my $s = Strassen->new_from_data_string($bbddata);
    is $s->write("$tempdir/test1"), 1, 'successful write';
    is slurp("$tempdir/test1"), $bbddata, 'bbd file with latin1 umlauts';

    my $appenddata = <<"EOF";
Another street	X 3,3 4,4
EOF
    my $append_s = Strassen->new_from_data_string($appenddata);
    is $append_s->append("$tempdir/test1"), 1, 'successful append';
    is slurp("$tempdir/test1"), "$bbddata$appenddata", 'appended bbd data';

    {
	my @warnings;
	local $SIG{__WARN__} = sub { push @warnings, @_ };
	is $s->write, 0, 'no write done';
	like "@warnings", qr{No filename specified}, 'expected warning';
    }

 SKIP: {
	skip "permissions probably work differently on Windows", 1 if $^O eq 'MSWin32';
	skip "permissions probably work differently on cygwin", 1 if $^O eq 'cygwin';
	skip "non-writable files not a problem for the superuser", 1 if $> == 0;

	open my $ofh, '>', "$tempdir/no-write" or die $!;
	close $ofh or die $!;
	chmod 0400, "$tempdir/no-write" or die $!;
	is $s->write("$tempdir/no-write"), 0, 'silent non-success';

	{
	    my @warnings;
	    local $SIG{__WARN__} = sub { push @warnings, @_ };
	    local $Strassen::VERBOSE = 1;
	    is $s->write("$tempdir/no-write"), 0, 'non-success';
	    like "@warnings", qr{Can't write/append to }, 'expected warning';
	}
    }
}

{
    my $bbddata = encode("utf-8", <<"EOF");
#: encoding: utf-8
#:
\xdcmlaut street	X 1,1 2,2
EOF
    my $s = Strassen->new_from_data_string($bbddata);
    is $s->get_global_directive('encoding'), 'utf-8', 'encoding set';
    $s->write("$tempdir/test2");
    is slurp("$tempdir/test2"), $bbddata, 'bbd file with utf8 umlauts';

    my $s_file = Strassen->new("$tempdir/test2");
    unlink "$tempdir/test2";
    $s_file->write;
    is slurp("$tempdir/test2"), $bbddata, 'use default filename for write';
}

{
    open my $ofh, ">", "$tempdir/test3" or die $!;
    $ofh->autoflush(1);

    my $bbddata = <<"EOF";
Some street	X 1,1 2,2
EOF
    my $s = Strassen->new_from_data_string($bbddata);
    $s->write($ofh);
    is slurp("$tempdir/test3"), $bbddata, 'filehandle write';

    my $appenddata = <<"EOF";
Another street	X 3,3 4,4
EOF
    my $append_s = Strassen->new_from_data_string($appenddata);
    $append_s->append($ofh);
    is slurp("$tempdir/test3"), "$bbddata$appenddata", 'appended bbd data using filehandle';
}
