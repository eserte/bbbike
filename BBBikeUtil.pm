# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 1998-2016,2018,2020,2023,2024 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://bbbike.de
#

package BBBikeUtil;

$VERSION = 1.42;

use strict;
use vars qw(@ISA @EXPORT @EXPORT_OK);

require Exporter;
@ISA = qw(Exporter);

@EXPORT = qw(is_in_path is_in_path_cached catfile file_name_is_absolute
             int_round sqr s2hm s2ms h2hm m2km
	     pi deg2rad rad2deg schnittwinkel float_prec
	     cp850_iso iso_cp850 nil
	     kmh2ms
	     STAT_MODTIME);
@EXPORT_OK = qw(min max first sum ceil ms2kmh clone bbbike_root bbbike_aux_dir
		s2hms s2hm_or_s save_pwd save_pwd2 uri_with_query
		module_path module_exists);

use constant STAT_MODTIME => 9;

# REPO BEGIN
# REPO NAME is_in_path /home/e/eserte/src/repository 
# REPO MD5 ccab6618d5af7a1e314eb8e0e448ff2c
sub is_in_path {
    my($prog) = @_;
    if (file_name_is_absolute($prog)) {
	if ($^O eq 'MSWin32') {
	    return $prog       if (-f $prog && -x $prog);
	    return "$prog.bat" if (-f "$prog.bat" && -x "$prog.bat");
	    return "$prog.com" if (-f "$prog.com" && -x "$prog.com");
	    return "$prog.exe" if (-f "$prog.exe" && -x "$prog.exe");
	    return "$prog.cmd" if (-f "$prog.cmd" && -x "$prog.cmd");
	} else {
	    return $prog if -f $prog and -x $prog;
	}
    }
    require Config;
    %Config::Config = %Config::Config if 0; # cease -w
    my $sep = $Config::Config{'path_sep'} || ':';
    foreach (split(/$sep/o, $ENV{PATH})) {
	if ($^O eq 'MSWin32') {
	    # maybe use $ENV{PATHEXT} like maybe_command in ExtUtils/MM_Win32.pm?
	    return "$_\\$prog"     if (-f "$_\\$prog" && -x "$_\\$prog");
	    return "$_\\$prog.bat" if (-f "$_\\$prog.bat" && -x "$_\\$prog.bat");
	    return "$_\\$prog.com" if (-f "$_\\$prog.com" && -x "$_\\$prog.com");
	    return "$_\\$prog.exe" if (-f "$_\\$prog.exe" && -x "$_\\$prog.exe");
	    return "$_\\$prog.cmd" if (-f "$_\\$prog.cmd" && -x "$_\\$prog.cmd");
	} else {
	    return "$_/$prog" if (-x "$_/$prog" && !-d "$_/$prog");
	}
    }
    undef;
}
# REPO END

use vars qw(%is_in_path_cache);
sub is_in_path_cached {
    my $prog = shift;
    if (exists $is_in_path_cache{$prog}) {
	return $is_in_path_cache{$prog};
    }
    my $res = is_in_path($prog);
    $is_in_path_cache{$prog} = $res;
    $res;
}

sub catfile {
    my(@args) = @_;
    my $path;
    eval {
        require File::Spec;
        $path = File::Spec->catfile(@args);
    };
    if ($@) {
        $path = join("/", @args);
    }
    $path;
}

# REPO BEGIN
# REPO NAME file_name_is_absolute /home/e/eserte/src/repository 
# REPO MD5 47355e35bcf03edac9ea12c6f8fff9a3

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

sub int_round { int($_[0]+0.5) }

# Quadrat
sub sqr {
    $_[0] * $_[0];
}

# Sekunden in HH:MM-Schreibweise
sub s2hm {
    my $s = shift;
    sprintf "%d:%02d", $s/3600, ($s%3600)/60;
}

# Sekunden in HH:MM:SS-Schreibweise
sub s2hms {
    my $s = shift;
    sprintf "%d:%02d:%02d", $s/3600, ($s%3600)/60, $s%60;
}

# Sekunden in MM:SS-Schreibweise
sub s2ms {
    my $s = shift;
    sprintf "%d:%02d", $s/60, int($s%60);
}

# seconds as "HH:MM h" or "SS sec"
sub s2hm_or_s {
    my $s = shift;
    if ($s < 1 || $s >= 60) {
	s2hm($s) . ' h';
    } else {
	int($s%60) . ' sec';
    }
}

# gebrochene Stunden in HH:MM-Schreibweise
sub h2hm {
    my $s = shift;
    sprintf "%d:%02d", $s, 60*($s - int($s));
}

# Meter in Kilometer umwandeln. $dig gibt die Anzahl der
# Nachkommastellen (Default: 1) an. Mit $sigdig (optional) kann die
# Anzahl der signifikaten Nachkommastellen angegeben werden (um
# Scheingenauigkeiten zu vermeiden): Beispiel m2km(1234,3,2) => 1.230.
# Dabei wird nicht gerundet. $sigdig wird nicht verwendet, wenn
# dadurch 0.000 als Ergebnis herauskommen w�rde.
sub m2km {
    my($s, $dig, $sigdig) = @_;
    return 0 unless $s =~ /\d/;
    $dig = 1 unless defined $dig;
    my $r = sprintf "%." . $dig . "f", $s/1000;
    if (defined $sigdig) {
	if ($sigdig == 2 && $s < 10) {
	    # do nothing
	} elsif ($sigdig == 1 && $s < 100) {
	    # do nothing
	} else {
	    $r =~ s/\.(\d{$sigdig})(.*)/".$1" . ("0"x length($2))/e;
	}
    }
    $r . " km";
}

sub kmh2ms { $_[0]/3.6 }
sub ms2kmh { $_[0]*3.6 }

# damit ich nicht Math::Trig und Math::Complex laden mu�
sub pi ()   { 4 * atan2(1, 1) } # 3.141592653
sub deg2rad { ($_[0]*pi)/180 }
sub rad2deg { ($_[0]*180)/pi }

# Calculate intersecting angle
# In:  $p1(x|y) and $p2(x|y): exterior points
#      $pm(x|y): middle point (intersection point)
# Out: (angle in radians, direction l or r)
#      may return (undef, undef) in case there's no angle available (e.g.
#      if $p1==$pm or $p2==$pm)
# See also Strassen::Util::abbiegen for a very similar function.
sub schnittwinkel {
    my($p1x, $p1y, $pmx, $pmy, $p2x, $p2y) = @_;
    return (pi,'l') if $p1x==$p2x && $p1y==$p2y; # avoid nan
    my $acos;
    # XXX do not duplicate code (Strassen::Util)
    if (!eval { require POSIX }) {
	# from Math::Complex
	$acos = sub {
	    my $z = $_[0];
	    return CORE::atan2(CORE::sqrt(1-$z*$z), $z) if (! ref $z) && CORE::abs($z) <= 1;
	    warn "Fallback to Math::Trig::acos because of $z\n";
	    require Math::Trig;
	    Math::Trig::acos($z);
	};
    } else {
	$acos = \&POSIX::acos;
    }
    my $x1 = $pmx-$p1x;
    my $y1 = $pmy-$p1y;
    my $x2 = $p2x-$pmx;
    my $y2 = $p2y-$pmy;
    my $richtung = ($x1*$y2-$y1*$x2 > 0 ? 'l' : 'r');
    my $winkel = 0;
    my $acos_arg = eval {
	($x1*$x2+$y1*$y2) /
	    (sqrt(sqr($x1)+sqr($y1)) *
	     sqrt(sqr($x2)+sqr($y2)));
    };
    if ($@) {
	return (undef, undef);
    }
    # protect from floating point inaccuracies
    if    ($acos_arg >  1) { $acos_arg = 1 }
    elsif ($acos_arg < -1) { $acos_arg = -1 }
    eval {
	$winkel = &$acos($acos_arg);
    };
    ($winkel, $richtung);
}

sub float_prec {
    my($float, $prec) = @_;
    no locale;
    sprintf "%.${prec}f", $float;
}

sub ceil {
    my($val) = @_;
    require POSIX;
    POSIX::ceil($val);
}

# Zeichensatz-Konvertierungen

sub cp850_iso {
    my $s = shift;
    $s =~ tr/\200\201\202\203\204\205\206\207\210\211\212\213\214\215\216\217\220\221\222\223\224\225\226\227\230\231\232\233\234\235\236\237\240\241\242\243\244\245\246\247\250\251\252\253\254\255\256\257\260\261\262\263\264\265\266\267\270\271\272\273\274\275\276\277\300\301\302\303\304\305\306\307\310\311\312\313\314\315\316\317\320\321\322\323\324\325\326\327\330\331\332\333\334\335\336\337\340\341\342\343\344\345\346\347\350\351\352\353\354\355\356\357\360\361\362\363\364\365\366\367\370\371\372\373\374\375\376\377/\307\374\351\342\344\340\345\347\352\353\350\357\356\354\304\305\311\346\306\364\366\362\373\371\377\326\334\370\243\330\327F\341\355\363\372\361\321\252\272\277\256\254\275\274\241\253\273\.\:\?\|\+\301\302\300\251\+\|\+\+\242\245\+\+\+\+\+\-\+\343\303\+\+\+\+\+\=\+\244\360\320\312\313\310i\315\316\317\+\+FL\246\314T\323\337\324\322\365\325\265\336\376\332\333\331\375\335\-\264\255\261\=\276\266\247\367\270\260\250\'\271\263\262f\240/;
    $s;
}

sub iso_cp850 {
    my $s = shift;
    $s =~ tr/\200\201\202\203\204\205\206\207\210\211\212\213\214\215\216\217\220\221\222\223\224\225\226\227\230\231\232\233\234\235\236\237\240\241\242\243\244\245\246\247\250\251\252\253\254\255\256\257\260\261\262\263\264\265\266\267\270\271\272\273\274\275\276\277\300\301\302\303\304\305\306\307\310\311\312\313\314\315\316\317\320\321\322\323\324\325\326\327\330\331\332\333\334\335\336\337\340\341\342\343\344\345\346\347\350\351\352\353\354\355\356\357\360\361\362\363\364\365\366\367\370\371\372\373\374\375\376\377/\ \ \ \ \ \ \ \ \ \ \ \ \ \ \ \ \ \ \ \ \ \ \ \ \ \ \ \ \ \ \ \ \377\255\275\234\317\276\335\365\371\270\246\256\252\360\251\47\370\361\375\374\357\346\364\56\47\373\247\257\254\253\363\250\267\265\266\307\216\217\222\200\324\220\322\323\336\326\327\330\321\245\343\340\342\345\231\236\235\353\351\352\232\355\347\341\205\240\203\306\204\206\221\207\212\202\210\211\215\241\214\213\320\244\225\242\223\344\224\366\233\227\243\226\201\354\350\230/;
    $s;
}

# keine Zeichensatz-Konvertierung
sub nil { $_[0] }

{
    my $BBBIKE_ROOT;
    sub bbbike_root {
	if (!defined $BBBIKE_ROOT) {
	    require File::Basename;
	    require Cwd;
	    $BBBIKE_ROOT = Cwd::realpath(File::Basename::dirname(__FILE__));
	}
	$BBBIKE_ROOT;
    }
}

{
    my $BBBIKE_AUX_DIR;
    sub bbbike_aux_dir { # return undef if there's no bbbike-aux
	if (!defined $BBBIKE_AUX_DIR) {
	TRY: {
		for my $candidate (bbbike_root . '/../bbbike-aux',
				   "$ENV{HOME}/src/bbbike-aux",
				  ) {
		    if (-d $candidate) {
			$BBBIKE_AUX_DIR = $candidate;
			last TRY;
		    }
		}
	    }
	}
	$BBBIKE_AUX_DIR;
    }
}

BEGIN {
    if (eval { require List::Util; 1 }) {
	*min = \&List::Util::min;
	*max = \&List::Util::max;
	*first = \&List::Util::first;
	*sum = \&List::Util::sum;
    } else {
	*min = sub {
	    my $min;
	    for (@_) {
		$min = $_ if (!defined $min || $min > $_);
	    }
	    $min;
	};
	*max = sub {
	    my $max;
	    for (@_) {
		$max = $_ if (!defined $max || $max < $_);
	    }
	    $max;
	};
	*first = sub (&@) {
	    my $code = shift;
	    for (@_) {
		return $_ if &{$code}();
	    }
	    undef;
	};
	*sum = sub (@) {
	    my $sum = shift;
	    for (1..$#_) { $sum += $_[$_] }
	    $sum;
	};
    }
}

use vars qw(%uml $uml_keys $uml_keys_rx
	    %uml_german_locale $uml_german_locale_keys $uml_german_locale_keys_rx
	   );
BEGIN {
    %uml = ('�' => 'ae', '�' => 'oe', '�' => 'ue', '�' => 'ss',
	    '�' => 'Ae', '�' => 'Oe', '�' => 'Ue',
	    '�' => 'e', '�' => 'e', '�' => 'e', '�' => 'a',
	   );
    $uml_keys = join("",keys %uml);
    $uml_keys_rx = qr{[$uml_keys]};

    %uml_german_locale = ('�' => 'a', '�' => 'o', '�' => 'u', '�' => 'ss',
			  '�' => 'A', '�' => 'O', '�' => 'U',
			  '�' => 'e', '�' => 'e', '�' => 'e', '�' => 'a',
			  # some Polish and Czech characters appearing in the bbbike data set
			  # XXX better to use Text::Unidecode maybe?
			  "\x{00DA}" => 'U', "\x{0141}" => 'L', "\x{015A}" => 'S',
			  "\x{0142}" => 'l', "\x{0105}" => 'a',
			  "\x{011B}" => 'e', "\x{0119}" => 'e', "\x{00F3}" => 'o',
			 );
    $uml_german_locale_keys = join("",keys %uml_german_locale);
    $uml_german_locale_keys_rx = qr{[$uml_german_locale_keys]};
}

# Convert umlauts so that sorting with german locale is correct, i.e.
# � => a, � => ss, ...
# Also used for shortening labels for GPS devices, where converting
# a => ae is wasteful
sub umlauts_for_german_locale {
    my $s = shift;
    $s =~ s/($uml_german_locale_keys_rx)/$uml_german_locale{$1}/go;
    $s;
}

# Convert according to german rules e.g. � => ae
sub umlauts_to_german {
    my $s = shift;
    $s =~ s/($uml_keys_rx)/$uml{$1}/go;
    $s;
}

# "xfrm" should resemble strxfrm(3), which is done here:
# create something which may simply be cmp'd.
sub german_locale_xfrm {
    my $val = lc umlauts_for_german_locale($_[0]);
    $val =~ s{[\(\)\"\.]}{}g;
    $val;
}

sub sort_german {
    my($arr_ref) = @_;
    map { $_->[1] }
	sort { $a->[0] cmp $b->[0] }
	    map {
		[ german_locale_xfrm($_), $_]
	    } @$arr_ref;
}

BEGIN {
    if (eval q{ use Storable 2; 1 }) { # need the ability to clone CODE items XXX determine correct Storable version
	*clone = sub ($) {
	    my $o = shift;
	    local $Storable::Deparse = $Storable::Deparse = 1;
	    local $Storable::Eval = $Storable::Eval = 1;
	    Storable::dclone($o);
	};
    } else {
	*clone = sub ($) {
	    my $o = shift;
	    require Data::Dumper;
	    # Seems to segfault with Sieperl 5.6.1 when cloning in show_overview_populate
	    eval Data::Dumper::Dumper($o);
	};
    }
}
    
# REPO BEGIN
# REPO NAME save_pwd /home/e/eserte/work/srezic-repository 
# REPO MD5 0f7791cf8e3b62744d7d5cfbd9ddcb07
sub save_pwd (&) {
    my $code = shift;
    my $pwd;
    if (1) { # test and use fchdir()
	open $pwd, '.'
	    or undef $pwd;
	if (defined $pwd) {
	    eval { chdir $pwd }
		or undef $pwd;
	}
    }
    if (!defined $pwd) {
	require Cwd;
	$pwd = Cwd::getcwd();
	$pwd = undef if defined $pwd && $pwd eq ''; # might be consinstent in older Cwd versions 
    }
    if (!defined $pwd) {
        warn "No known current working directory";
    }
    eval {
	$code->();
    };
    my $err = $@;
    if (defined $pwd) {
        chdir $pwd or die "Can't chdir back to $pwd: $!";
    }
    die $err if $err;
}
# REPO END

{
    package BBBikeUtil::SavePwd2;
    sub new {
	my $pwd;
	if (1) { # test and use fchdir()
	    open $pwd, '.'
		or undef $pwd;
	    if (defined $pwd) {
		eval { chdir $pwd }
		    or undef $pwd;
	    }
	}
	if (!defined $pwd) {
	    require Cwd;
	    $pwd = Cwd::getcwd();
	    $pwd = undef if defined $pwd && $pwd eq ''; # might be consinstent in older Cwd versions 
	}
	if (!defined $pwd) {
	    warn "No known current working directory";
	}
	bless {cwd => $pwd}, shift;
    }
    sub DESTROY {
	my $self = shift;
	if (defined $self->{cwd}) {
	    chdir $self->{cwd}
	        or die "Can't chdir back to $self->{cwd}: $!";
	}
    }
}
sub save_pwd2 { BBBikeUtil::SavePwd2->new }

# Create a URL from a base $uri and an array ref of query parameters
# ($query_array).
#
# Parameters listed in raw_query (as an array ref) are appended
# unaltered to the URL generated so far using $uri and $query_array
# values. This is useful e.g. for GooglePolylineEncoding parameters,
# as characters like @ and ? are left unescaped, making the URL a lot
# smaller
sub uri_with_query {
    my($uri, $query_array, %args) = @_;
    my $encoding = delete $args{encoding} || 'utf-8';
    my $raw_query_array = delete $args{raw_query};
    die "Unhandled arguments: " . join(" ", %args) if %args;

    require Encode;
    my @query_array;
    for my $val (@$query_array) {
	push @query_array, Encode::encode($encoding, $val);
    }

    my $query_string;
    if (!$BBBikeTest::SIMULATE_WITHOUT_URI && eval { require URI; 1 }) {
	my $u = URI->new("", "http");
	$u->query_form(\@query_array);
	$query_string = $u->query;
	if (!defined $query_string) { $query_string = '' }
	$query_string =~ s{\+}{%20}g; # friendly for javascript's decodeURIComponent
    } else {
	require CGI;
	CGI->import('-oldstyle_urls'); # global change!
	my $q = CGI->new;
	for(my $i=0; $i<$#query_array; $i+=2) {
	    $q->param($query_array[$i], $query_array[$i+1]);
	}
	$query_string = $q->query_string;
    }

    if ($raw_query_array) {
	my $sep = $query_string eq '' ? '' : '&';
	for(my $i=0; $i<$#$raw_query_array; $i+=2) {
	    $query_string .= $sep . $raw_query_array->[$i] . '=' . $raw_query_array->[$i+1];
	    if ($i == 0) { $sep = '&' }
	}
    }

    if ($query_string ne '') {
	$uri . '?' . $query_string;
    } else {
	$uri;
    }
}

$BBBikeTest::SIMULATE_WITHOUT_URI = $BBBikeTest::SIMULATE_WITHOUT_URI if 0; # cease -w

# REPO BEGIN
# REPO NAME module_path /home/eserte/src/srezic-repository 
# REPO MD5 ac5f3ce48a524d09d92085d12ae26e8c
# modification: %INC check
sub module_path {
    my($filename) = @_;
    $filename =~ s{::}{/}g;
    $filename .= ".pm";
    return $INC{$filename} if exists $INC{$filename};
    foreach my $prefix (@INC) {
	my $realfilename = "$prefix/$filename";
	if (-r $realfilename) {
	    return $realfilename;
	}
    }
    return undef;
}
# REPO END

sub module_exists { module_path($_[0]) ? 1 : 0 }

1;

