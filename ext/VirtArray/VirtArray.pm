package VirtArray;

use strict;
use Carp;
use vars qw(@ISA
	    $VERSION $formatversion $magic
	    $VERBOSE $portable);

use constant VAR_LEN => 1;
use constant FREEZED => 2;

require DynaLoader;

@ISA = qw(DynaLoader);
$VERSION = '0.03';

$magic = "VARR";
$formatversion = "0.02"; # should always be exactly 4 characters
$VERBOSE = 0;
$portable = 0; # set to true if data should be portable (use network order)
# XXX this flag is not implemented
# all pack's/unpack's should be changed
# Storable::freeze should be Storable::nfreeze

bootstrap VirtArray $VERSION;

sub retrieve {
    my($file) = @_;
    my $buf;
    my @res;
    open(F, $file) or croak "Can't open $file: $!";
    read F, $buf, 8;
    croak "Wrong magic" if ($buf ne "$magic$formatversion");

    my($is_var_len, $freezed);
    read F, $buf, 4;
    my $flags = unpack("l", $buf);
    $is_var_len = $flags & VAR_LEN;
    $freezed    = $flags & FREEZED;
    if ($freezed) {
	require Storable;
    }

    my $len;
    read F, $buf, 4;
    $len = unpack("l", $buf);
    if (!$is_var_len) {
	read F, $buf, 4;
	my $reclen = unpack("l", $buf);
	print STDERR "Reading fixed data (len=$reclen, rec=$len)\n"
	  if $VERBOSE;
	for(my $i=0; $i<$len; $i++) {
	    read F, $buf, $reclen;
	    push @res, $buf;
	}
    } else {
	print STDERR "Reading variable " . ($freezed ? "complex " : "") . 
	  "data (rec=$len)\n" if $VERBOSE;
	my @index;
	for(my $i=0; $i<=$len; $i++) {
	    read F, $buf, 4;
	    push @index, unpack("l", $buf);
	}
	for(my $i=0; $i<$len; $i++) {
	    my $reclen = $index[$i+1]-$index[$i];
	    read F, $buf, $reclen;
	    if ($freezed) {
		push @res, Storable::thaw($buf);
	    } else {
		push @res, $buf;
	    }
	}
    }
    close F;
    \@res;
}

sub store {
    my($array_ref, $file) = @_;
    croak "Not an array reference" if (!ref $array_ref eq 'ARRAY');
    croak "Empty array" if (@$array_ref == 0);
    $file = "-" if !defined $file;

    # Check if the data should be freezed (because of references in the
    # array elements) and if the data has variable record size.
    my $is_var_len = 0;
    my $freezed = 0;
    my $reclen = length($array_ref->[0]);
    for(my $i=1; $i<=$#$array_ref; $i++) {
	if (length($array_ref->[$i]) != $reclen) {
	    $is_var_len = 1;
	    last if $freezed;
	}
	if (ref $array_ref->[$i]) {
	    $freezed = 1;
	    $is_var_len = 1;
	    last;
	}
    }

    if ($freezed) {
	require Storable;
    }

    # Format:
    # magic
    # long (0: fixed length, 1: var length)
    # long (number of records)
    open(F, ">$file") or croak "Can't open $file: $!";
    print STDERR "Writing to $file\n" if $VERBOSE;
    print F "$magic$formatversion";
    my $flags =
      ($is_var_len ? VAR_LEN : 0) |
      ($freezed    ? FREEZED : 0);
    print F pack("l", $flags);
    my $len = scalar @$array_ref;
    print F pack("l", $len);
    if (!$is_var_len) {
	print STDERR "Writing fixed data (len=$reclen, rec=$len)\n"
	  if $VERBOSE;
	# Format:
	# long (length of record)
	# data
	print F pack("l", $reclen);
	foreach (@$array_ref) {
	    print F $_;
	}
    } else {
	print STDERR "Writing variable " . ($freezed ? "complex " : "") .
	  "data (rec=$len)\n" if $VERBOSE;
	my $data = '';
	my $i = 0; # $i == length($data)
	foreach (@$array_ref) {
	    my $elem;
	    if ($freezed) {
		$elem = Storable::freeze($_);
	    } else {
		$elem = $_;
	    }
	    $data .= $elem;
	    print F pack("l", $i);
	    $i += length($elem);
	}
	print F pack("l", $i); # letzter Index
	print F $data;
    }
    close F;
}

sub is_valid {
    my $filename = shift;

    if (open(F, $filename)) {
	my $read_magic;
	read(F, $read_magic, 4);
	close F;
	return $magic eq $read_magic;
    }

    undef;
}

1;
__END__
# Below is the stub of documentation for your module. You better edit it!

=head1 NAME

VirtArray - Perl extension for blah blah blah

=head1 SYNOPSIS

  use VirtArray;
  blah blah blah

=head1 DESCRIPTION

Stub documentation for VirtArray was created by h2xs. It looks like the
author of the extension was negligent enough to leave the stub
unedited.

Blah blah blah.

=head1 AUTHOR

A. U. Thor, a.u.thor@a.galaxy.far.far.away

=head1 SEE ALSO

perl(1).

=cut
