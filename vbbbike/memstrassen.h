/*
 * $Id: memstrassen.h,v 1.1 2000/12/12 01:47:30 eserte Exp $
 * Author: Slaven Rezic
 *
 * Copyright (C) 2000 Slaven Rezic. All rights reserved.
 *
 * Mail: eserte@cs.tu-berlin.de
 * WWW:  http://user.cs.tu-berlin.de/~eserte/
 *
 */

#ifndef _memstrassen_h
#define _memstrassen_h

#include "strassen.h"
#include "bbbike.h"

class MemStrassen : public Strassen {
 public:
  MemStrassen();
};

#endif
