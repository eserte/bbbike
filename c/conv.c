/*
 * $Id: conv.c,v 1.1 2001/05/20 11:01:05 eserte Exp $
 * Author: Slaven Rezic
 *
 * Copyright (C) 1999 Slaven Rezic. All rights reserved.
 *
 * Mail: eserte@cs.tu-berlin.de
 * WWW:  http://user.cs.tu-berlin.de/~eserte/
 *
 */

#include "bbbike.h"

// XXX verwenden!

void cp850_iso(char *s) {
  while(*s) {
    switch (*s) {
    case '\204': *s = 'ä'; break;
    case '\224': *s = 'ö'; break;
    case '\201': *s = 'ü'; break;
    case '\216': *s = 'Ä'; break;
    case '\231': *s = 'Ö'; break;
    case '\232': *s = 'Ü'; break;
    case '\341': *s = 'ß'; break;
    case '\202': *s = 'é'; break;
    case '\370': *s = '°'; break;
    }
    s++;
  }
}

void iso_cp850(char *s) {
  while(*s) {
    switch (*s) {
    case 'ä': *s = '\204'; break;
    case 'ö': *s = '\224'; break;
    case 'ü': *s = '\201'; break;
    case 'Ä': *s = '\216'; break;
    case 'Ö': *s = '\231'; break;
    case 'Ü': *s = '\232'; break;
    case 'ß': *s = '\341'; break;
    case 'é': *s = '\202'; break;
    case '°': *s = '\370'; break;
    }
    s++;
  }
}
