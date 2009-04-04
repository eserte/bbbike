#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: newstreetform_data.pl,v 1.30 2009/04/04 11:24:49 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2004 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

# NOTE! This script is not in use anymore. I found a shared imap
# account more appropriate!

# Process the newstreetform mails (from a mbox file or a
# one-mail-per-message folder) and create HTML pages

use strict;
use FindBin;
use Template;
use Safe;
use File::Basename qw(basename);
use File::Temp qw(tempdir);
use File::Path qw(mkpath);
use Getopt::Long;
use Data::Dumper qw(Dumper);
use HTML::Entities qw(encode_entities);
use lib ("$FindBin::RealBin/..",
	 "$FindBin::RealBin/../lib",
	);
use PLZ;

my $backup_file;
my $destdir = "/var/tmp/newstreetformdata";
my $bbd = "/tmp/newstreetform.bbd";
my $ignore_empty;
my $ignore_replied;
my $mail_dir;
my $start_mail_id;
my $v;
GetOptions("usebackupfile=s" => \$backup_file,
	   "destdir=s" => \$destdir,
	   "bbd=s" => \$bbd,
	   "ignoreempty!" => \$ignore_empty,
	   "ignorereplied!" => \$ignore_replied,
	   "maildir=s" => \$mail_dir,
	   "startmailid=i" => \$start_mail_id,
	   "v!" => \$v,
	  ) or die <<EOF;
usage: $0 [-usebackupfile file] [-destdir dir] [-bbd file]
	  [-maildir directory -startmailid number]
	  [-ignoreempty] [-ignorereplied] [-v]
EOF

# REPO BEGIN
# REPO NAME save_pwd /home/e/eserte/work/srezic-repository 
# REPO MD5 0f7791cf8e3b62744d7d5cfbd9ddcb07

=head2 save_pwd(sub { ... })

=for category File

Save the current directory and assure that outside the block the old
directory will still be valid.

=cut

sub save_pwd (&) {
    my $code = shift;
    require Cwd;
    my $pwd = Cwd::cwd();
    eval {
	$code->();
    };
    my $err = $@;
    chdir $pwd or die "Can't chdir back to $pwd: $!";
    die $err if $err;
}
# REPO END

mkpath $destdir if !-d $destdir;
# This symlink is for my webaccess (/~eserte/tmp/newstreetformdata)
symlink $destdir, "/tmp/newstreetformdata" if !-l "/tmp/newstreetformdata";

my $plz = PLZ->new;
my $bbd_fh;
if ($bbd) {
    open $bbd_fh, "> $bbd" or die "Can't write to $bbd: $!";
}

my $htmltpl = "$FindBin::RealBin/../html/newstreetform.tpl.html";
die "$htmltpl not found" if !-r $htmltpl;

my %file2header;
my %file2data;
my %file2status;

my $c = Safe->new;

if (!@ARGV && !$backup_file && !$mail_dir) {
    my($header, $data) = parse_fh(\*STDIN);
    if (!keys %$data) {
	die "Keine Daten gefunden";
    }
    output($data, \*STDOUT);
} else {
    if ($backup_file) {
	@ARGV = split_backupfile($backup_file);
    }

    if ($mail_dir) {
	if (!$start_mail_id) {
	    die "-startmailid is missing, mandatory with -maildir!";
	}
	my @files;
	save_pwd {
	    chdir $mail_dir or die "Cannot change to $mail_dir: $!";
	    for my $f (glob("*")) {
		next if $f !~ /^\d+$/;
		next if $f < $start_mail_id;
		push @files, "$mail_dir/$f";
	    }
	};
	if (!@files) {
	    die "No files found";
	}
	@ARGV = @files;
    }

    require Gnus::Newsrc;
    my $newsrc = Gnus::Newsrc->new;
    my(undef, $read, $marks) =
	@{$newsrc->alist_hash->{"nnml+private:bbbike"}};
    my %reply = map { ($_=>1) } split /,/, $marks->{reply};
    my %tick  = map { ($_=>1) } split /,/, $marks->{tick};
    my %read  = map { ($_=>1) } split /,/, $read;

    my $get_status = sub {
	my $mail_id = shift;
	my @status;

	for my $def (["read", \%read],
		     ["tick", \%tick],
		     ["reply", \%reply],
		    ) {
	    my($label, $hash) = @$def;
	    if (exists $hash->{$mail_id}) {
		push @status, $label;
	    } else {
		keys %$hash;	# reset iterator
		while (my($k,$v) = each %$hash) {
		    if ($k =~ /(.*)-(.*)/ &&
			$mail_id >= $1 && $mail_id <= $2) {
			push @status, $label;
			last;
		    }
		}
	    }
	}
	join ", ", @status;
    };

    my @output_files;
    my $prev_link;
    for my $file (@ARGV) {
	print STDERR "$file... ";
	open(my $fh, $file) or die $!;
	my($header, $data) = parse_fh($fh);
	next if (!keys %$data);
	fix_data($data);
	if ($ignore_empty && data_is_empty($data)) {
	    next;
	}
	my $base = basename($file);
	my $status = $get_status->($base);
	if ($ignore_replied && $status =~ /reply/) {
	    if ($v) {
		warn "Ignore status=$status\n";
	    }
	    next;
	}
	my $output_file = $destdir . "/" . $base;
	output($data, $output_file, prev => $prev_link, header => $header, thisid => $base);
	$prev_link = basename $output_file;
	push @output_files, $output_file;
	$file2data{$output_file} = $data;
	$file2header{$output_file} = $header;
	$file2status{$output_file} = $status;
    } continue {
	print STDERR "\n";
    }

    if (@output_files) {

	my $indexfile = $destdir . "/newstreetindex.html";
	open(my $index, "> $indexfile") or die "Can't write to $indexfile: $!";
	print $index (my_html_header());
	print $index "<table>\n";
	foreach my $f (reverse @output_files) {
	    my $date = $file2header{$f}{date};
	    if (eval { require Mail::Field }) {
		my $time = Mail::Field->new(Date => $date)->time;
		my @l = localtime $time;
		$date = sprintf "%04d-%02d-%02d", $l[5]+1900, $l[4]+1, $l[3];
	    }
	    my $base = basename $f;
	    my $status = $file2status{$f};
	    my $email = $file2data{$f}{email} || "";
	    my $css = ($status =~ /\b(tick)\b/  ? "rectick" :
		       $status =~ /\b(reply)\b/ ? "recdone" :
		       $status =~ /\b(read)\b/  ? "recmaybedone" :
		       "recundone"
		      );
	    my $status_html = $status; # no HTML transform yet needed
	    print $index qq{<tr class="$css"><td><a href="$base">$base</a></td><td>$file2data{$f}{strname}</td><td>$date</td><td>$status_html</td><td>$email</td></tr>\n};
	}
	print $index "</table>\n";
	print $index (my_html_footer());
	chmod 0644, $indexfile;
    }
}

sub parse_fh {
    my $header = {};
    my $data = {};
    my $fh = shift;
    my $parsing_header = undef;
    while(<$fh>) {
	chomp;
	if (!defined $parsing_header) {
	    if (/^(.*?):\s*(.*)/) {
		$parsing_header = 1;
	    } else {
		# no mail -> treat as data
		$parsing_header = 0;
	    }
	}
	if ($parsing_header) {
	    if ($_ eq "") {
		$parsing_header = 0;
	    } else {
		if (/^(.*?):\s*(.*)/) {
		    $header->{lc($1)} = $2; # ignore multiple headers and continuation lines
		}
	    }
	} else {
	    if (/^\$(\S+)\s*=\s*(\"?.*\"?);$/) {
		my $key = $1;
		my $val = $c->reval($2);
		$data->{$key} = $val;
	    }
	}
    }
    ($header, $data);
}

sub output {
    my($data, $output, %args) = @_;
    my $t = Template->new({ RELATIVE => 1,
			    ABSOLUTE => 1,
			    COMPILE_EXT => ".ttc",
			    COMPILE_DIR => "/tmp",
			  });

    my $extra_html = "";

    my $bbd_suggestion;
    my $name;
    my $strname = $data->{supplied_strname} || "";
    {
	$name = $data->{author};
	if (!$name) {
	    ($name = $data->{email}) =~ s{\@.*}{...};
	}
	if (!$name) {
	    $name = "anonymous";
	}
	my $cat_text = $data->{Qdesc_1} || "";
	my $cat = $data->{Qcat_1} || "";
	$bbd_suggestion = <<EOF;
#: by: $name:
$strname: $cat_text\t$cat 
EOF
    }
    $extra_html .= "<textarea rows='4' cols='80'>" . encode_entities($bbd_suggestion) . "</textarea><br>";

    my $header = $args{header};
    if (1 && $header) {
	my $reply_to = $header->{"reply-to"};
	my $cc = 'info@bbbike.de';
	my $body =<<EOF;
Hallo $name,

danke für deinen Eintrag. Die Straße "$strname" wird demnächst bei
BBBike verfügbar sein.

Gruß,
    das BBBike-Team

[Eintrag #$args{thisid}]
EOF
	if (!$reply_to) {
	    $reply_to = 'info@bbbike.de';
	    undef $cc;
	    $body = 'Hallo Slaven';
	}
	my $subject = "Re: $header->{subject}";
	my $references = qq{$header->{"message-id"}};
	$extra_html .= <<EOF;
<hr>Mail:<br>
<form action="http://bbbike.de/newstreetformdata/sendmail.cgi">
<textarea rows="4" cols="80" name="emailheader">
To: $reply_to
Subject: $subject
References: $references
</textarea><br>
<textarea rows="4" cols="80" name="emailbody">
$body
</textarea><br>
<input type="submit" value="Mail senden">
</form>
<hr>
EOF
	my $mailto_link = "mailto:$reply_to?";
	require CGI;
	CGI->import('-oldstyle_urls');
	$body =~ s{\n}{ \r\n}g; # really?
	my $q = CGI->new({subject => $subject,
			  references => $references,
			  ($cc ? (cc => $cc) : ()),
			  body => $body,
			 });
	$mailto_link .= $q->query_string;
	$extra_html .= <<EOF;
<div><a href="$mailto_link">Mail per Browser-Mailprogramm eingeben und senden</a> (aber möglichst das Formular verwenden!)</div>
EOF
    }

    local $Data::Dumper::Sortkeys = 1;
    $extra_html .= "\n<pre>" . encode_entities(Dumper($data)) . "</pre>";

    if ($args{prev}) {
	$extra_html .= qq{<br><a href="$args{prev}">&lt;&lt; $args{prev}</a>};
    }
    my $vars = { data => $data,
		 extra_html => $extra_html,
	       };
    if (Dumper($data) =~ /fragezeichenform/) {
	$vars->{is_fragezeichen_form} = 1;
    }
    $t->process($htmltpl, $vars, $output) or die $t->error;
    chmod 0644, $output;

    if ($bbd_fh) {
	my($xy, $strname) = get_from_plzfile($data);
	if (defined $xy) {
	    print $bbd_fh "http://www/~eserte/tmp/newstreetformdata/" . basename($output) . " $strname\tX $xy\n";
	}
    }
}

sub fix_data {
    my($data) = @_;
    while(my($k,$v) = each %$data) {
	my $new_k;
	($new_k = $k) =~ s{^q([^q])}{qq$1};
	if ($new_k ne $k) {
	    $data->{$new_k} = delete $data->{$k};
	}
    }
}

sub split_backupfile {
    my $backup_file = shift;
    my @out;
    my $count = 0;
    my $dir = tempdir(); #CLEANUP => 1);
    my $ofh;
    open(my $ifh, $backup_file) or die "Can't open $backup_file: $!";
    while(<$ifh>) {
	if (/^------------------/) {
	    my $new_file = "$dir/$count";
	    open($ofh, "> $new_file") or die "Can't write to $new_file: $!";
	    push @out, $new_file;
	    $count++;
	    my $date = <$ifh>;
	    print $ofh <<EOF;
From: dummy
Subject: dummy
Date: $date

EOF
	} else {
	    print $ofh $_;
	}
    }
    @out;
}

sub get_from_plzfile {
    my $data = shift;
    my($xy, $strname, $ret);
    if ($data->{supplied_coord}) {
	$xy = $data->{supplied_coord};
	$strname = $data->{supplied_strname};
    } else {
	if ($data->{supplied_strname}) {
	    ($ret) = $plz->look($data->{supplied_strname}, Citypart => $data->{supplied_plz});
	} else {
	    ($ret) = $plz->look($data->{strname});
	}
	if ($ret) {
	    $xy = $ret->[PLZ::LOOK_COORD];
	    $strname = $ret->[PLZ::LOOK_NAME];
	}
    }
    ($xy, $strname);
}

sub data_is_empty {
    my($data) = @_;
    while(my($key,$val) = each %$data) {
	if ($key =~ m{^(strname
		    | supplied_.*
		    | Qrange_1
		    | RWrange_1
		    | qqrange_1
		    | formtype
		   )$}x) {
	    next;
	}
	if ($val) {
	    warn "Non-empty: $key,$val\n" if $v;
	    return 0;
	}
    }
    1;
}

sub my_html_header {
    <<EOF;
<html>
<head>
 <title>Neue Straßen</title>
 <style type="text/css">
.recdone   { color:#00b000; }
.recmaybedone { color:#808000; }
.recundone { color:#b00000; }
.rectick   { color:#ff0000; }
 </style>
</head>
<body>
EOF
}

sub my_html_footer {
    <<EOF;
<h2>Legende der Farben</h2>
<div class="recdone">Mail bereits bearbeitet</div>
<div class="recmaybedone">Mail höchstwahrscheinlich bearbeitet</div>
<div class="recundone">Mail unbearbeitet</div>
<div class="rectick">Genauere Betrachtung erforderlich</div>
<h2>newstreetform_data-Optionen</h2>
<ul>
<li>ignore_empty=$ignore_empty
<li>ignore_replied=$ignore_replied
<li>start_mail_id=$start_mail_id
</ul>
</body>
</html>
EOF
}


__END__

Best called as:

   ~/src/bbbike/miscsrc/newstreetform_data.pl -maildir ~/Mail/bbbike -startmailid 5829 -ignoreempty -ignorereplied

Then direct your browser to:

    file:/tmp/newstreetformdata/newstreetindex.html

Or deploy to radzeit server:

    rsync -avz -e "ssh -2 -p 5022" /var/tmp/newstreetformdata/ root@bbbike.de:/var/www/domains/radzeit.de/www/public/newstreetformdata/

And direct your browser to:

    http://bbbike.de/newstreetformdata/newstreetindex.html

----------------------------------------------------------------------

Formerly I recommended to use

    ~/src/bbbike/miscsrc/newstreetform_data.pl ~/Mail/bbbike/[56789]??? -ignoreempty -ignorereplied
