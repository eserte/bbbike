/*
 * $Id: memstrassen.cpp,v 1.1 2000/12/12 01:47:27 eserte Exp $
 * Author: Slaven Rezic
 *
 * Copyright (C) 2000 Slaven Rezic. All rights reserved.
 *
 * Mail: eserte@cs.tu-berlin.de
 * WWW:  http://user.cs.tu-berlin.de/~eserte/
 *
 */

#include "memstrassen.h"

MemStrassen::MemStrassen() {
  char *str_p = STR_NAME(str_buf);
  char *str_end = str_buf + str_buf_len;
  int str_len;
  koordlen_t koord_len;
  while(str_p < str_end) {
    str_len = strlen(str_p);
    koord_len = KOORDLEN2(str_p, str_len);
    Strasse *str = new Strasse();
    str->name = str_p;
    str->category = "N"; // XXX
    str->x = new int[koord_len];
    str->y = new int[koord_len];
    str->anzahl = koord_len;
    for(int i=0; i < koord_len; i++) {
      koordptr_t koordptr = STR_KOORDPTR2(str_p,str_len,i);
      int x1, y1;
      GETXY(koordptr,x1,y1);
      str->x[i] = x1;
      str->y[i] = y1;
    }
    this->add(str);
    str_p += STR_STRUCTLEN2(str_len,koord_len);
  }

}
