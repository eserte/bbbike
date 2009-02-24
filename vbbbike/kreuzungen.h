/*
 * $Id: kreuzungen.h,v 1.2 2009/02/22 14:12:14 eserte Exp $
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
  std::vector<long long> Map;

 public:
  void add(int x, int y);
  void find_nearest(int x, int y, int& out_x, int& out_y);
};

#endif
