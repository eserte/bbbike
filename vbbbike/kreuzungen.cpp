/*
 * $Id: kreuzungen.cpp,v 1.3 2001/12/09 21:05:06 eserte Exp $
 * Author: Slaven Rezic
 *
 * Copyright (C) 2000 Slaven Rezic. All rights reserved.
 *
 * Mail: eserte@cs.tu-berlin.de
 * WWW:  http://user.cs.tu-berlin.de/~eserte/
 *
 */

#include "kreuzungen.h"
#include <math.h>

// REPO BEGIN
// REPO NAME sqr /home/e/eserte/src/repository 
// REPO MD5 cfa1424f42fd64877c9d0c32823eb508

#define SQR(i) (i)*(i)
// REPO END

void Kreuzungen::add(int x, int y) {
  long long key = x;
  key <<= 32;
  key |= y;

  Map.push_back(key);
}

void Kreuzungen::find_nearest(int x, int y, int& nearest_x, int& nearest_y) {
  int nearest_dist = 99999999; // XXX
  for(int i = 0; i < Map.size(); i++) {
    long long xx = Map[i];
    long long lx = xx;
    lx >>= 32;
    int x1 = (long)(lx);
    int y1 = xx & 0xffffffff;
    int dist1 = (int)sqrt(SQR((long long)(x-x1))+SQR((long long)(y-y1)));
    if (dist1 < nearest_dist) {
      nearest_x = x1;
      nearest_y = y1;
      nearest_dist = dist1;
    }
  }
}
