/*
 * $Id: kreuzungen.h,v 1.1 2000/12/12 01:47:17 eserte Exp $
 * Author: Slaven Rezic
 *
 * Copyright (C) 2000 Slaven Rezic. All rights reserved.
 *
 * Mail: eserte@cs.tu-berlin.de
 * WWW:  http://user.cs.tu-berlin.de/~eserte/
 *
 */

#ifndef kreuzungen_h
#define kreuzungen_h

#include <vector>

class Kreuzungen {
  vector<long long> Map;

 public:
  void add(int x, int y);
  void find_nearest(int x, int y, int& out_x, int& out_y);
};

#endif
