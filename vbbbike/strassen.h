/* -*- c++ -*-
 * $Id: strassen.h,v 1.3 2000/12/12 01:48:08 eserte Exp $
 * Author: Slaven Rezic
 *
 * Copyright (C) 1998 Slaven Rezic. All rights reserved.
 *
 * Mail: eserte@cs.tu-berlin.de
 * WWW:  http://user.cs.tu-berlin.de/~eserte/
 *
 */

#ifndef strassen_h
#define strassen_h

#include <stdlib.h>
#include "kreuzungen.h"

class Strasse {
  friend class Strassen;

public:
  Strasse();
  Strasse(char *line);
  ~Strasse() {
    delete[] name;
    delete[] category;
    if (x) free(x);
    if (y) free(y);
  }

  char *name;
  char *category;
  int *x;
  int *y;
  int anzahl;
};


class Strassen {
public:
  Strassen();
  Strassen(char* fn);
  ~Strassen() {
    if (data) free(data);
    if (s) {
      for(int i = 0; i<s_anzahl; i++) {
	delete s[i];
      }
    }
  }

  void init()         { pos = 0; }
  Strasse* next()     { return get(pos); }
  Strasse* get(int p) { return s[p]; }

  void add(Strasse *s);
  void dump();

  Strasse **s;
  int s_anzahl;
  Kreuzungen kreuzungen;

protected:
  char **data;
  int pos;
  char *filename;
};

#endif
