/*
 * $Id: setup.c,v 1.3 2002/02/11 17:32:02 eserte Exp $
 * Author: Slaven Rezic
 *
 * Copyright (C) 2000,2002 Slaven Rezic. All rights reserved.
 *
 * Mail: eserte@cs.tu-berlin.de
 * WWW:  http://user.cs.tu-berlin.de/~eserte/
 *
 */

main() {
#ifdef ACTIVEPERL
  system("windows/bin/perl -Iwindows/lib -Iwindows/lib/site setup.pl");
#else
  system("windows/5.6.1/bin/MSWin32-x86/perl -Iwindows/5.6.1/lib -Iwindows/site/5.6.1/lib setup.pl");
#endif
}
