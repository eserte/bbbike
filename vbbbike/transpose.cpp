/*
 * $Id: transpose.cpp,v 1.2 2000/12/12 01:48:15 eserte Exp $
 * Author: Slaven Rezic
 *
 * Copyright (C) 2000 Slaven Rezic. All rights reserved.
 *
 * Mail: eserte@cs.tu-berlin.de
 * WWW:  http://user.cs.tu-berlin.de/~eserte/
 *
 */

#include "transpose.h"

int scale = 2;

void transpose(int inx, int iny, int &outx, int &outy) {
  outx = (-200+inx/25)*scale;
  outy = (600-iny/25)*scale;
}

void anti_transpose(int inx, int iny, int &outx, int &outy) {
  outx = (inx/scale+200)*25;
  outy = (600-iny/scale)*25;
}
