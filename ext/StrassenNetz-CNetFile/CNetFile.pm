# -*- c -*-

#
# $Id: CNetFile.pm,v 1.12 2007/04/22 19:54:33 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2001, 2002, 2003, 2007 Slaven Rezic. All rights reserved.
# This is free software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License, see the file COPYING.
#
# Mail: slaven@rezic.de
# WWW:  http://bbbike.sourceforge.net
#

package StrassenNetz::CNetFile;

BEGIN {
    $VERSION = sprintf("%d.%02d", q$Revision: 1.12 $ =~ /(\d+)\.(\d+)/);
}

use Inline 0.40; # because of API changes
#use Inline Config => CLEAN_AFTER_BUILD => 0; #XXX
#use Inline C => Config => CCFLAGS => "-g"; #XXX
use Inline (C => DATA =>
	    NAME => 'StrassenNetz::CNetFile',
	    VERSION => $VERSION,
	   );

use StrassenNetz::CNetFilePerl;

1;

__DATA__
__C__

#include "ppport.h"
#include <sys/types.h>
#include <sys/mman.h>
#include <fcntl.h>
#include <unistd.h>

long mmap_net_file(SV* self, char* filename) {
    char *buf = NULL;
    int length;
    int version;
    char magic[5];
    HV* self_hash = (HV*)SvRV(self);
    int fd = open(filename, O_RDONLY);
    SV* sv;

    if (fd < 0)
      croak("Cannot open file %s\n", filename);
    length = lseek(fd, 0, SEEK_END);
    if (length < 8)
      croak("Minimal length should be 8\n");
    buf = mmap(NULL, length, PROT_READ, MAP_PRIVATE, fd, 0);
    if (buf == NULL)
      croak("Cannot mmap file %s\n", filename);
    /* check magic and version number */
    strncpy(magic, (char*)buf, 4);
    magic[4] = 0;
    sv = get_sv("StrassenNetz::CNetFile::MAGIC", FALSE);
    if (!sv)
      croak("Can't get $StrassenNetz::CNetFile::MAGIC");
    if (strncmp(magic, SvPV(sv, PL_na), 4) != 0)
      croak("Wrong magic <%s> found in %s\n", magic, filename);
    version = *(((int*)buf)+1);
    sv = get_sv("StrassenNetz::CNetFile::FILE_VERSION", FALSE);
    if (!sv)
      croak("Can't get $StrassenNetz::CNetFile::FILE_VERSION");
    if (SvIV(sv) != version)
      croak("Wrong version <%d> found in %s, expected %d\n", version, filename, SvIV(sv));

    hv_store(self_hash, "CNetMagic", strlen("CNetMagic"), newSVpv(magic,0), 0);
    hv_store(self_hash, "CNetFileVersion", strlen("CNetFileVersion"), newSViv(version), 0);
    hv_store(self_hash, "CNetMmap", strlen("CNetMmap"), newSViv((long)buf), 0);

    return (long)buf;
}

void* translate_pointer(SV* self, int ptr) {
    HV* self_hash = (HV*)SvRV(self);
    long buf;

    {
	SV** tmp = hv_fetch(self_hash, "CNetMmap", strlen("CNetMmap"), 0);
	if (tmp)
	    buf = SvIV(*tmp);
	else
	    croak("No CNetMmap element in object hash");
    }

    return (void*)(buf+ptr);
}

void get_coord_struct(SV* self, void* ptr) {
    int x, y, no_succ;
    int* ptr_i = (int*)ptr;
    int i;
    Inline_Stack_Vars;

    x = *(ptr_i++);
    y = *(ptr_i++);
    no_succ = *(ptr_i++);

    Inline_Stack_Reset;
    /* sv_2mortal obviously needed here: */
    Inline_Stack_Push(sv_2mortal(newSViv(x)));
    Inline_Stack_Push(sv_2mortal(newSViv(y)));
    Inline_Stack_Push(sv_2mortal(newSViv(no_succ)));

    for(i=0; i<no_succ; i++) {
	Inline_Stack_Push(sv_2mortal(newSViv(*(ptr_i++))));
	Inline_Stack_Push(sv_2mortal(newSViv(*(ptr_i++))));
    }

    Inline_Stack_Done;
}
