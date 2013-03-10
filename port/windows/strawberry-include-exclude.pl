#!/usr/bin/perl -w
# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2011,2012 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

use strict;
use warnings;
use FindBin;
use lib "$FindBin::RealBin/inc"; # for Algorithm::IncludeExclude
use Algorithm::IncludeExclude;
use File::Basename qw(dirname);
use File::Copy qw(cp);
use File::Path qw(mkpath);
use Getopt::Long;

my($src,$dest);
my $doit;
my $v;
my $filelist;
GetOptions("src=s" => \$src,
	   "dest=s" => \$dest,
	   "doit!" => \$doit,
	   "fl=s" => \$filelist,
	   "v" => \$v,
	  )
    or die "usage?";

my $say = !$doit || $v;
my $do  =  $doit;

for ($src, $dest) {
    s{/+$}{} if defined;
}

if (!$filelist) {
    if (!$src) {
	die "Please specify -src or -filelist";
    }
    require File::Find;
    require File::Temp;
    my($tmpfh,$tmpfile) = File::Temp::tempfile(UNLINK => 1) or die $!;
    my $rootdir_len = length($src) + 1;
    File::Find::find(sub {
			 if (-f $_) {
			     no warnings 'once';
			     print $tmpfh substr($File::Find::name, $rootdir_len), "\n";
			 }
		     }, $src);
    close $tmpfh or die $!;
    $filelist = $tmpfile;
}

my $need_include_hack = $Algorithm::IncludeExclude::VERSION < 0.01_50;
if ($need_include_hack) {
    warn "Algorithm::IncludeExclude version $Algorithm::IncludeExclude::VERSION detected, need a hack for RT #75695...\n";
}

my %exclude;
my $ie = Algorithm::IncludeExclude->new;
$ie->include;
$ie->exclude('c');
$ie->include(qw(c bin libxml2-2_.dll));
$ie->include(qw(c bin libiconv-2_.dll));
$ie->include(qw(c bin libz_.dll));
$ie->include(qw(c bin libexpat-1_.dll));
$ie->include(qw(c bin libpng15-15_.dll)); # probably needed by Tk
$ie->include(qw(c bin libjpeg-8_.dll));   # dito
$ie->exclude('cpan');
$ie->exclude('cpanplus');
$ie->exclude('data');
$ie->exclude('licenses');
$ie->exclude('ppm');
$ie->exclude('win32');
$ie->exclude('DISTRIBUTIONS.txt');
$ie->exclude('README.portable.txt');
$ie->exclude('README.txt');
$ie->include('perl') if $need_include_hack;
$ie->include(qw(perl bin)) if $need_include_hack;
$ie->exclude(qw(perl bin a2p.exe));
$ie->exclude(qw(perl bin cpan));
$ie->exclude(qw(perl bin cpan.bat));
$ie->exclude(qw(perl bin cpan2dist.bat));
$ie->exclude(qw(perl bin dprofpp.bat));
$ie->exclude(qw(perl bin h2xs.bat));
$ie->exclude('perl', qr{.*\.pod$});
$ie->exclude('perl', qr{\.packlist$});
$ie->include(qw(perl lib)) if $need_include_hack;
$ie->include(qw(perl lib App)) if $need_include_hack;
$ie->exclude(qw(perl lib App Prove.pm));
$ie->exclude(qw(perl lib App Prove));
$ie->exclude(qw(perl lib CORE));
$ie->include(qw(perl lib CORE arpa inet.h)); # XXX why?
$ie->include(qw(perl lib CORE sys socket.h)); # XXX why?
$ie->exclude(qw(perl lib CPAN));
$ie->exclude(qw(perl lib CPAN.pm));
$ie->exclude(qw(perl lib CPANPLUS));
$ie->exclude(qw(perl lib CPANPLUS.pm));
$ie->include(qw(perl lib Encode)) if $need_include_hack;
$ie->exclude(qw(perl lib Encode CN.pm));
# XXX what about CN/?
$ie->exclude(qw(perl lib Encode CN HZ.pm));
$ie->exclude(qw(perl lib Encode EBCDIC.pm));
$ie->exclude(qw(perl lib Encode JP.pm));
# XXX what about JP/?
$ie->exclude(qw(perl lib Encode JP H2Z.pm));
$ie->exclude(qw(perl lib Encode JP JIS7.pm));
$ie->exclude(qw(perl lib Encode KR.pm));
# XXX what about KR/?
$ie->exclude(qw(perl lib Encode KR 2022_KR.pm));
$ie->exclude(qw(perl lib Encode TW.pm));
$ie->exclude(qw(perl lib ExtUtils));
$ie->include(qw(perl lib Module)) if $need_include_hack;
$ie->exclude(qw(perl lib Module Build.pm));
$ie->exclude(qw(perl lib Module Build));
$ie->exclude(qw(perl lib Module CoreList.pm));
$ie->exclude(qw(perl lib TAP));
$ie->exclude(qw(perl lib Test));
$ie->include(qw(perl lib Unicode)) if $need_include_hack;
$ie->exclude(qw(perl lib Unicode Collate));
$ie->include(qw(perl lib auto)) if $need_include_hack;
$ie->exclude(qw(perl lib auto Devel));
$ie->include(qw(perl lib auto Encode)) if $need_include_hack;
$ie->exclude(qw(perl lib auto Encode CN CN.bs));
$ie->exclude(qw(perl lib auto Encode CN CN.dll));
$ie->exclude(qw(perl lib auto Encode EBCDIC EBCDIC.bs));
$ie->exclude(qw(perl lib auto Encode EBCDIC EBCDIC.dll));
$ie->exclude(qw(perl lib auto Encode JP JP.bs));
$ie->exclude(qw(perl lib auto Encode JP JP.dll));
$ie->exclude(qw(perl lib auto Encode KR KR.bs));
$ie->exclude(qw(perl lib auto Encode KR KR.dll));
$ie->exclude(qw(perl lib auto Encode TW TW.bs));
$ie->exclude(qw(perl lib auto Encode TW TW.dll));
$ie->include(qw(perl lib unicore)) if $need_include_hack;
$ie->exclude(qw(perl lib unicore), qr{.*\.txt$});
$ie->exclude(qw(perl lib unicore mktables));
$ie->exclude(qw(perl lib unicore TestProp.pl));
$ie->include(qw(perl lib unicore To)) if $need_include_hack;
$ie->exclude(qw(perl lib unicore To NFKCCF.pl));
$ie->include(qw(perl vendor lib)) if $need_include_hack;
$ie->exclude(qw(perl vendor lib Apache)); # all of Apache
$ie->exclude(qw(perl vendor lib Bundle)); # all of Bundle
$ie->exclude(qw(perl vendor lib Crypt)); # all of Crypt
$ie->include(qw(perl vendor lib Crypt SSLeay)); # but add Crypt::SSLeay
$ie->exclude(qw(perl vendor lib DBD)); # all of DBD
$ie->exclude(qw(perl vendor lib Test)); # all of Test
#$ie->exclude(qw(perl vendor lib XML Parser));
#$ie->exclude(qw(perl vendor lib XML Parser.pm));
#$ie->exclude(qw(perl vendor lib XML SAX));
#$ie->exclude(qw(perl vendor lib XML Simple.pm));
$ie->include(qw(perl vendor lib auto)) if $need_include_hack;
$ie->exclude(qw(perl vendor lib auto Math)); # all of Math
$ie->exclude(qw(perl vendor lib auto share));
$ie->exclude(qw(perl vendor lib auto DBD)); # all of DBD
$ie->exclude(qw(perl vendor lib PAR.pm));
$ie->exclude(qw(perl vendor lib PAR)); # all of PAR
#$ie->exclude(qw(perl vendor lib auto DBI));
#$ie->exclude(qw(perl vendor lib auto XML Parser));

#$ie->include(qw(perl vendor lib XML));
#$ie->exclude(qw(perl vendor lib CPAN));
#$ie->exclude(qw(perl vendor lib auto BerkeleyDB));
#$ie->exclude(qw(perl vendor lib auto Imager)); # XXX maybe
#$ie->include(qw(perl vendor lib auto XML));
$ie->exclude(qw(perl vendor lib Crypt));
$ie->include(qw(perl vendor lib Crypt SSLeay.pm));
$ie->include(qw(perl vendor lib Crypt SSLeay));
#$ie->include(qw(perl vendor lib Crypt OpenPGP));
#$ie->exclude(qw(perl vendor lib Crypt OpenPGP.pm));
#$ie->exclude(qw(perl vendor lib Imager.pm)); # XXX maybe
#$ie->exclude(qw(perl vendor lib Imager)); # XXX maybe
#$ie->include(qw(perl vendor lib Data));
#$ie->exclude(qw(perl vendor lib Data Random));
#$ie->exclude(qw(perl vendor lib Data Random.pm));
#$ie->exclude(qw(perl vendor lib XML LibXSLT.pm));
#$ie->exclude(qw(perl vendor lib auto XML LibXSLT));
#$ie->exclude(qw(perl vendor lib DBI.pm));
#$ie->exclude(qw(perl vendor lib DBI));
#$ie->include(qw(perl vendor lib Math));
#$ie->exclude(qw(perl vendor lib Math Pari.pm));
$ie->include(qw(perl site)) if $need_include_hack;
$ie->include(qw(perl site lib)) if $need_include_hack;
$ie->include(qw(perl site lib Tk)) if $need_include_hack;
$ie->exclude(qw(perl site lib Tk demos));
$ie->exclude(qw(perl site lib Tk), qr{\.[hmt]$});
$ie->include(qw(perl site lib Tk pTk)) if $need_include_hack;
$ie->exclude(qw(perl site lib Tk pTk), qr{\.[hmt]$});
$ie->exclude(qw(perl site lib Tk pTk compat));
#
if ($src) {
    for my $mod (qw(
		       Alien::Tidyp
		       BerkeleyDB
		       Compress::Bzip2 Compress::Raw::Lzma Compress::unLZMA CPAN CPAN::SQLite
		       DBI Data::Random DBM::Deep DBIx::Simple
		       FCGI
		       Imager
		       Math::Pari
		       PAR
		       SOAP::Lite
		       XML::LibXSLT
		  )) {
	add_packlist_to_exclude($mod);
    }

    # Following are not part of Strawberry, but may be
    # installed later to help testing
    for my $mod (qw(
		       Image::Info
		       Object::Realize::Later
		       Test::Pod
		  )) {
	eval { add_packlist_to_exclude($mod) };
	warn "No exclude for $mod needed, probably not installed...\n" if $@;
    }
}

my %dir_created;
open my $fh, $filelist
    or die "Can't open $filelist: $!";
while(<$fh>) {
    chomp;
    my $file = $_;
    if ($ie->evaluate(split m{/}, $file)) {
	if ($src && $dest) {
	    my $srcpath = "$src/$file";
	    if ($exclude{$srcpath}) {
		if ($say) {
		    print STDERR "# excluded: $srcpath\n";
		}
	    } else {
		my $destpath = "$dest/$file";
		my $dir = dirname($destpath);
		if (!-d $dir) {
		    if (!$dir_created{$dir}) {
			if ($say) {
			    print STDERR "mkpath $dir\n";
			}
			if ($do) {
			    mkpath $dir or die "Can't create $dir: $!";
			}
			$dir_created{$dir}++;
		    }
		}
		if (-f $srcpath) {
		    my $destpath = "$dest/$file";
		    if ($say) {
			print STDERR "cp $srcpath -> $destpath\n";
		    }
		    if ($do) {
			# XXX preserve permissions?
			# XXX fails if trying to overwrite an existing file without w bit
			cp $srcpath, $destpath
			    or do {
				if (-e $destpath) {
				    require File::Compare;
				    if (File::Compare::compare($srcpath, $destpath) == 0) {
					# warn ignore failure
				    } else {
					die "Can't copy $srcpath to $destpath ($!), and source differs";
				    }
				} else {
				    die "Can't copy $srcpath to $destpath: $!";
				}
			    };
		    }
		}
	    }
	} else {
	    print "$file\n";
	}
    }
}

sub add_packlist_to_exclude {
    my $module = shift;
    (my $file = $module) =~ s{::}{/}g;
    my $vendor_packlist_file = "$src/perl/vendor/lib/auto/$file/.packlist";
    my $core_packlist_file = "$src/perl/lib/auto/$file/.packlist";
    my $fh;
    open $fh, $vendor_packlist_file
	or open $fh, $core_packlist_file
	    or die "Can't open neither $vendor_packlist_file nor $core_packlist_file for module $module: $!";
    while(<$fh>) {
	chomp;
	s{\r}{};
	my $f = $_;
	$f =~ s{^C:\\strawberry\\}{};
	$f =~ s{\\}{/}g;
	$f = $src . "/" . $f;
	$exclude{$f} = 1;
    }
}

__END__

=head1 NAME

strawberry-include-exclude.pl - exclude parts of a standard StrawberryPerl distribution

=head1 SYNOPSIS

   ./strawberry-include-exclude.pl -src /path/to/strawberry -dest /path/to/strawberry-excluded

And if everything looks good, then add the C<-doit> switch to it.

=head1 DESCRIPTION

Other options:

=over

=item -fl filelist

Instead of using the C<-src> option, it's possible to use a filelist
containg files (no directories) of a StrawberryPerl distribution. This
could be done like this:

   cd /path/to/strawberryperl
   find . -type f | perl -pe 's{^./}{}' > /tmp/strawberry-list

=item -v

Be verbose, show what's done.

=back

=cut
