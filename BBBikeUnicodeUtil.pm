# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2011 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

package BBBikeUnicodeUtil;

=head1 NAME

BBBikeUnicodeUtil - a collection of unicode related utility functions

=head1 SYNOPSIS

   use BBBikeUnicodeUtil;
   $string_with_latin1_codepoints = BBBikeUnicodeUtil::unidecode_string($string_with_nonlatin1_codepoints);

=head1 DESCRIPTION

=cut

use strict;
use vars qw($VERSION);
$VERSION = '0.01';

=head2 unidecode_string($string)

Convert the supplied string to contain only characters in the latin1
character set.

NOTE: currently, if codepoints > 255 exist in the string, then even
the codepoints between 128 and 255 will be converted to ASCII (this
will be fixed in the future).

This function requires L<Text::Unidecode>. If this module is missing,
then a warning will be issued (only once!) and no conversion is done
at all. The warning may be ceased by defining the variable
$BBBikeUnicodeUtil::unidecode_warning_shown.

=cut

use vars qw($unidecode_warning_shown);
sub unidecode_string {
    my($str) = @_;
    if (grep { ord($_) > 255 } split //, $str) {
	if (!eval { require Text::Unidecode; 1 }) {
	    if (!$unidecode_warning_shown++) {
		warn <<EOF;
Unicode characters > 255 detected, but no Text::Unidecode module available,
continuing with undefined results. This warning will be shown only once.
EOF
	    }
	} else {
	    $str =~ s{\x{2190}}{->}g;
	    # XXX Should preserve at least the latin1 characters.
	    return Text::Unidecode::unidecode($str);
	}
    }
    $str;
}

1;

__END__

=head1 AUTHOR

Slaven Rezic

=cut
