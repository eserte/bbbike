/*
 * $Id: transpose.h,v 1.2 2000/12/12 01:48:21 eserte Exp $
 * Author: Slaven Rezic
 *
 * Copyright (C) 2000 Slaven Rezic. All rights reserved.
 *
 * Mail: eserte@cs.tu-berlin.de
 * WWW:  http://user.cs.tu-berlin.de/~eserte/
 *
 */

#ifndef transpose_h
#define transpose_h

extern int scale;

void transpose(int inx, int iny, int &outx, int &outy);
void anti_transpose(int inx, int iny, int &outx, int &outy);

#endif
