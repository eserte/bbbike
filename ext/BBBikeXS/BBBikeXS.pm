package BBBikeXS;

# "use BBBikeXS" sollte *nach* use Strassen, use BBBikeTrans etc.
# ausgeführt werden, damit das Override der Perl-Funktionen durch die
# XS-Funktionen funktioniert.

# Warnung: XS ist anscheinend von 5.00503 nach 5.5.640 *nicht* kompatibel
# In diesem Falle gibt es einen Absturz (Floating exception).
# XXX Noch keinen Workaround zur Lösung des Problems gefunden.

use strict;
use vars qw($VERSION @ISA);

require DynaLoader;

@ISA     = qw(DynaLoader);
$VERSION = '0.08';

eval {
    local $SIG{__DIE__};
    bootstrap BBBikeXS $VERSION;
};
if ($@) {
#    warn $@;
    return 1;
}

package Strassen;
{
    local($^W) = 0;
    *to_koord = \&to_koord_XS;
    *to_koord1 = \&to_koord1_XS;
}

package StrassenNetz;
{
    local($^W) = 0;
    if ($StrassenNetz::data_format == $StrassenNetz::FMT_HASH) {
	*make_net = \&make_net_XS;
	*make_net_classic = \&make_net_XS;
    }
}

package main;
{
    local($^W) = 0;
    *transpose_ls = \&transpose_ls_XS;
}

1;
__END__
