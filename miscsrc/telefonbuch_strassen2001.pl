#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: telefonbuch_strassen2001.pl,v 1.8 2003/06/02 23:04:58 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2001,2003 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

=head1 NAME

telefonbuch_strassen2001 - fill a mysql database "telbuch" with the contents of Telefonbuch 2001

=head1 DESCRIPTION

Please run C<telefonbuch_strassen2001.pl -h> to get a list of options.

=cut

use FindBin;
use lib "$FindBin::RealBin/../lib";
use UnixUtil;
use IO::Seekable;
use strict;
use Getopt::Long;
use DB_File;
use DBI;

my $user = "bbbike";
my $password = "bbbike";

tie my %str_index, 'DB_File', '/tmp/tel2001_strindex.db', O_RDWR|O_CREAT, 0644;

tie my %mysql_str_index, 'DB_File', '/tmp/tel2001_mysql_str_index.db', O_RDWR|O_CREAT, 0644;
tie my %mysql_citypart_index, 'DB_File', '/tmp/tel2001_mysql_citypart_index.db', O_RDWR|O_CREAT, 0644;

tie my %mysql_str_citypart_index, 'DB_File', '/tmp/tel2001_mysql_str_citypart_index.db', O_RDWR|O_CREAT, 0644;


#my $basef = "rel_st_n";
my $basef = "straverz";
my $fill;
my $db = "mysql";
my $mysql;
my $version = '';
my $createallestr;
my $createtables;
my $createdatabase;
my $v;

if (!GetOptions("base=s" => \$basef,
		"fill!" => \$fill,
		"version=i" => \$version,
		"db=s" => \$db,
		"createallestr" => \$createallestr,
		"createtables!" => \$createtables,
		"createdatabase!" => \$createdatabase,
		"v" => \$v,
	       )) {
    die <<EOF;
usage: $0 [-createdatabase] [-createtables] [-db databasetype] [-fill] [-createallestr] [-version i] [-base basename] [-v]
-createdatabase: create mysql database
-createtables: create tables into mysql database
-db databasetype: mysql or oracle
-fill: fill into database
-createallestr: create bbd file with all streets (coord sys: Karte::T2001)
                the file is created in /tmp/allestrassenberlins
-version: use another version for the examine function
-base: use another basefile than $basef
-v: be verbose

Normal execution order is:
* execute $0 -createdatabase
  * creates database telbuch (on mysql)
  * creates a user bbbike/bbbike with creation rights on telbuch
* execute $0 -createtables -db databasetype
* execute $0 -fill -db databasetype
Note that the Telefonbuch-CDROM 2001/2002 should be in a CDROM drive.

EOF
}

if ($createdatabase) {
    create_database();
    exit 0;
}

if ($createallestr) {
    $fill = 0;
    load_file("rel_st_n");
    load_file("straverz");
    exit 0;
}

if ($createtables) {
    createtables();
    exit 0;
}

load_file("rel_st_n");
load_file("straverz");

#load_file($basef);#XXX für 2002 vorbereitet???

sub load_file {
    my $basef = shift;

    warn "Load file $basef...\n" if $v;
 TRY: {
	foreach my $cd (UnixUtil::get_cdrom_drives()) {
	    warn "Try CDROM drive $cd...\n" if $v;
	    if (open(F, "$cd/32Bit/database/$basef")) {
		examine(\*F, $basef);
		close F;
		last TRY;
	    }
	}
	die "Can't find Telefonbuch 2001. Maybe you have to mount the CDROM?";
    }
}

sub examine {
    my($fh, $basef) = @_;
    eval 'examine_'.$basef.$version.'($fh)';
    die $@ if $@;
}

sub examine_rel_st_n {
    my($fh) = @_;
    seek($fh, 0x243a, SEEK_SET);

    my $street_index = 0;
    my $citypart_index = 0;

    # Ausnahmen:
    # Normalerweise treten die Straßennamen als
    #    Street (Bezirk)
    # auf. Manchmal sind es auch zwei Klammern. Dann kann die erste Klammer
    # ein Unterbezirk oder eine genauere Angabe zu der Straße sein.
    my %is_citypart = map {($_=>1)}
	qw(Hermsdorf Mariendorf Rudow Tegel Wittenau Wannsee Zehlendorf
	   Heilg. Hermsd. Nordend
	  );
    # Abkürzungen bei den Unterbezirken
    my %abk = ('Heilg.' => 'Heiligensee',
	       'Hermsd.' => 'Hermsdorf');

    warn "Parse CDROM file...\n";
    while(!eof $fh && tell($fh)<0x0010FD6B) {
	my $buf;
	read($fh, $buf, 26);

	#warn join(" ", map { sprintf "%02x", ord $_ } split //, $buf)."\n";
	# $flag1 ist immer 2
	$buf =~ /^(..)(.{4})(.{4})(.{4})(.{4})(.{4})(.{4})/s;
	my($sig, $reclen, $rec2len, $flag1, $ptr, $index, $nrs)
	    = ($1,
	       unpack("V", $2), unpack("V", $3), unpack("V", $4),
	       unpack("V", $5), unpack("V", $6), unpack("V", $7),
	      );
	if ($sig ne "\xfa\xfa") {
	    die "Invalid signature: $sig\n";
	}

	my $str = "";
	my $str_i = 0;
	while(!eof $fh) {
	    read($fh, $str, 1, $str_i);
	    last if $str =~ s/\0$//;
	    $str_i++;
	}
	#warn "$str $flag1 $nrs $ptr $index\n";

	$str_index{$index} = $str;

	if ($fill) {
	    if ($str =~ /^([^\(]+)\s+(\(.*\))$/) {
		my($no_parens, $parens) = ($1,$2);
		my($only_str, $citypart);
		if ($parens =~ /^\(([^\)]+)\)\s+\((.*)\)/) {
		    my($paren1, $paren2) = ($1, $2);
		    if ($is_citypart{$paren1}) {
			$only_str = $no_parens;
			$citypart = $paren1;
		    } else {
			$only_str = "$no_parens ($paren1)";
			$citypart = $paren2;
		    }
		} else {
		    $only_str = $no_parens;
		    ($citypart = $parens) =~ s/^.(.*).$/$1/;
		}
		if (exists $abk{$citypart}) {
		    $citypart = $abk{$citypart};
		}
		if (!exists $mysql_str_index{$only_str}) {
		    $mysql_str_index{$only_str} = $street_index++;
		}
		if (!exists $mysql_citypart_index{$citypart}) {
		    $mysql_citypart_index{$citypart} = $citypart_index++;
		}
		if (!exists $mysql_str_citypart_index{$index}) {
		    $mysql_str_citypart_index{$index} =
			$mysql_str_index{$only_str}.",".$mysql_citypart_index{$citypart};
		}
	    } else {
		warn "Can't parse into street/citypart: $str\n";
	    }
	}
    }

    if ($fill) {
	warn "Fill $db database...\n" if $v;
	my $dbh = connect_db();
	$dbh->do("delete from street");
	$dbh->do("delete from citypart");
	my $sth1 = $dbh->prepare("insert into street values(?, ?)");
	my $sth2 = $dbh->prepare("insert into citypart values(?, ?)");
	my(%seen1,%seen2);
	while(my($k,$v) = each %mysql_str_index) {
	    if (!exists $seen1{$v}) {
		$sth1->execute($v,$k);
		$seen1{$v}++;
	    }
	}
	while(my($k,$v) = each %mysql_citypart_index) {
	    if (!exists $seen2{$v}) {
		$sth2->execute($v,$k);
		$seen2{$v}++;
	    }
	}
	$dbh->disconnect;
    }
}

sub examine_straverz {
    my($fh) = @_;
    seek($fh, 0x2c1f, SEEK_SET);

    my $dbh;
    my $sth;
    if ($fill) {
  	$dbh = connect_db();
	$sth = $dbh->prepare("insert into street_hnr values(?,?,?,?,?)");
	$dbh->do("delete from street_hnr");
    } else {
	open(OUT, ">/tmp/allestrassenberlins");
    }

    warn "Parse CDROM file...\n";
    while(!eof $fh) {
	my $buf;
	read($fh, $buf, 2);
	if ($buf ne "\xfa\xfa") {
	    warn "Invalid signature: $buf at " . tell($fh). "\n";
	    last;
	}
	read($fh, $buf, 4);
	my $reclen = unpack("V", $buf) - 2 - 4;

	read($fh, $buf, $reclen);
  	if ($buf !~ /^(.{4})(.{4})(.{4})(.{4})(.{4})(.{4})(.{4})(.*)/s) {
	    warn "Can't parse " . hexdump($buf) . "\n";
	    next;
	}

	#warn hexdump($buf)."\n";

	# $flag1 immer 2
  	my($rec2len, $flag1, $ptr, $index, $str_index, $long, $lat, $hnr)
  	    = (unpack("V", $1), unpack("V", $2), unpack("V", $3),
  	       unpack("V", $4), unpack("V", $5), unpack("V", $6),
	       unpack("V", $7), $8
  	      );

	if (substr($hnr,-1, 1) eq "\0") {
	    $hnr = substr($hnr, 0, -1);
	}

#  	warn "$index $flag1 $str_index $ptr $long,$lat $hnr\n";

	if (exists $str_index{$str_index}) {
	    if ($dbh) {
		my $v = $mysql_str_citypart_index{$str_index};
		if (defined $v) {
		    my($str_index, $citypart_index) = split /,/, $v;
		    $sth->execute($str_index, $citypart_index, $hnr, $long, $lat);
		} else {
		    warn "Can't find data for index=$str_index\n";
		}
	    } else {
		print OUT "$str_index{$str_index} $hnr\tX $long,$lat\n";
	    }
	} else {
	    warn "Index $str_index unknown\n";
	}
    }

    if ($dbh) {
	$dbh->disconnect;
    } else {
	close OUT;
    }
}

# XXX nur ein Index oder was?
sub examine_straverz2 {
    my($fh) = @_;
    seek($fh, 0x00E6B400, SEEK_SET);

    while(!eof $fh) {
	my $buf;
	read($fh, $buf, 2);
	if ($buf ne "\xfa\xfa") {
	    warn "Invalid signature: $buf at " . tell($fh). "\n";
	    last;
	}

	read($fh, $buf, 4);
	# $reclen always 1018 (0x400 - 2 - 4)
	my $reclen = unpack("V", $buf) - 2 - 4;

	read($fh, $buf, $reclen);

	$buf =~ /^(.{4})(.{4})(.{4})/s;
	# $flag2 always 0
	my($rec2len, $flag1, $flag2) =
	    (unpack("V", $1), unpack("V", $2), unpack("V", $3));
	if ($flag2 != 0) {
	    warn hexdump($buf)."\n";
	}
    }
}

sub hexdump {
    join(" ", map { sprintf "%02x", ord $_ } split //, $_[0])
}

sub connect_db {
    if ($db eq 'mysql') {
	DBI->connect("dbi:mysql:telbuch", $user, $password) or die $!;
    } elsif ($db eq 'oracle') {
	DBI->connect("dbi:oracle:host=dad;sid=db", $user, $password) or die $!;
    } else {
	die "Unsupported: $db";
    }
}

sub createtables {
    my $sql_statements = <<'EOF';
# The mysql support requires a database called telbuch with user/password =
# bbbike/bbbike. The structure of the database is as follows:

# phpMyAdmin MySQL-Dump
# http://phpwizard.net/phpMyAdmin/
#
# Host: localhost Database : telbuch

# --------------------------------------------------------
#
# Table structure for table 'citypart'
#

CREATE TABLE citypart (
   nr int(11) NOT NULL,
   name text NOT NULL,
   PRIMARY KEY (nr)
);


# --------------------------------------------------------
#
# Table structure for table 'street'
#

CREATE TABLE street (
   nr int(11) NOT NULL,
   name text NOT NULL,
   PRIMARY KEY (nr)
);


# --------------------------------------------------------
#
# Table structure for table 'street_hnr'
#

CREATE TABLE street_hnr (
   street int(11) NOT NULL,
   citypart int(11) NOT NULL,
   hnr char(10) NOT NULL,
   longitude int(11) NOT NULL,
   latitude int(11) NOT NULL,
   KEY hnr (hnr),
   KEY street (street)
);

EOF
    if ($db eq 'mysql') {
	if (!is_in_path("mysql")) {
	    die "The mysql program should be in the PATH";
	}
	open(MYSQL, "|mysql --user=$user --password=$password telbuch");
	print MYSQL $sql_statements;
	close MYSQL;
    } elsif ($db eq 'oracle') {
	if (!is_in_path("sqlplus")) {
	    die "The sqlplus program should be in the PATH";
	}
	open(ORACLE, "|sqlplus"); # XXX
	print ORACLE $sql_statements;
	close ORACLE;
    } else {
	die;
    }
}

sub create_database {
    print STDERR "This will create the <telbuch> database. Continue? ";
    my $answer = <>;
    exit 0 unless $answer =~ /^y/i;

    print STDERR "Enter the mysql root password\n";
    open(MYSQL, "| mysql -u root -p") or die $!;
    print MYSQL <<EOF;
use mysql;
insert into user (host,user,password)
	values ('localhost','$user',password('$password'));
insert into db values ('%','telbuch','$user','Y','Y','Y','Y','Y','Y','Y','Y','Y','Y');
flush privileges;
create database telbuch;
EOF
    close MYSQL;

    print STDERR "Done.\n";
}

# REPO BEGIN
# REPO NAME is_in_path /home/e/eserte/src/repository 
# REPO MD5 1aa226739da7a8178372aa9520d85589
sub is_in_path {
    my($prog) = @_;
    return $prog if (file_name_is_absolute($prog) and -x $prog);
    require Config;
    my $sep = $Config::Config{'path_sep'} || ':';
    foreach (split(/$sep/o, $ENV{PATH})) {
	return "$_/$prog" if -x "$_/$prog";
    }
    undef;
}
# REPO END

# REPO BEGIN
# REPO NAME file_name_is_absolute /home/e/eserte/src/repository 
# REPO MD5 a77759517bc00f13c52bb91d861d07d0
sub file_name_is_absolute {
    my $file = shift;
    my $r;
    eval {
        require File::Spec;
        $r = File::Spec->file_name_is_absolute($file);
    };
    if ($@) {
	if ($^O eq 'MSWin32') {
	    $r = ($file =~ m;^([a-z]:(/|\\)|\\\\|//);i);
	} else {
	    $r = ($file =~ m|^/|);
	}
    }
    $r;
}
# REPO END

__END__

