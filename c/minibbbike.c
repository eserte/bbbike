/*
 * $Id: minibbbike.c,v 2.3 1999/06/29 00:03:57 eserte Exp $
 * Author: Slaven Rezic
 *
 * Copyright (C) 1999 Slaven Rezic. All rights reserved.
 *
 * Mail: eserte@cs.tu-berlin.de
 * WWW:  http://user.cs.tu-berlin.de/~eserte/
 *
 */

#include "bbbike.h"

#ifndef __MINGW32__
#define HAVE_GETOPT
#endif

#define STRDATAFILE  "data/strassen.bin"
#define NETZDATAFILE "data/netz.bin"

static char *progname;

void load_data() {
  FILE *str, *netz;
  if (!(str = fopen(STRDATAFILE, "rb"))) {
    fprintf(stderr, "Can't open " STRDATAFILE "\n");
    exit(2);
  }
  fseek(str, 0, SEEK_END);
  str_buf_len = ftell(str);
  rewind(str);
  str_buf = malloc(str_buf_len+1);
  if (!str_buf)
    exit(3);
  fread(str_buf, sizeof(char), str_buf_len, str);
  fclose(str);

  if (!(netz = fopen(NETZDATAFILE, "rb"))) {
    fprintf(stderr, "Can't open " NETZDATAFILE "\n");
    exit(4);
  }
  fseek(netz, 0, SEEK_END);
  netz_buf_len = ftell(netz);
  rewind(netz);
  netz_buf = malloc(netz_buf_len+1);
  if (!netz_buf)
    exit(3);
  fread(netz_buf, sizeof(char), netz_buf_len, netz);
  fclose(netz);
}

void usage() {
  fprintf(stderr, "usage: %s [-l] start ziel\n", progname);
  exit(1);
}

int main(int argc, char **argv) {
  int loop = 0;
  char c;
  char *start, *ziel;
  strptr_t start_ptr, ziel_ptr;
  koordptr_t start_koord_ptr, ziel_koord_ptr;
  struct route **route;

  progname = argv[0];

#ifdef HAVE_GETOPT
  while ((c = getopt(argc, argv, "l")) != -1)
    switch(c) {
    case 'l':
      loop = 1;
      break;
    case '?':
    default:
      usage();
    }
  argc -= optind;
  argv += optind;
#else
  argc -= 1;
  argv += 1;
#endif

  if (argc != 2)
    usage();
  start = argv[0];
  ziel  = argv[1];
#ifndef DATA_IN_PROG
  load_data();
#endif

  do {
    start_ptr = streetptr_by_name(start);
    if (start_ptr == -1) {
      fprintf(stderr, "Couldn't find %s\n", start);
      exit(6);
    }
    ziel_ptr  = streetptr_by_name(ziel);
    if (ziel_ptr == -1) {
      fprintf(stderr, "Couldn't find %s\n", ziel);
      exit(7);
    }
    start_koord_ptr = choose_koordptr_by_streetptr(start_ptr);
    ziel_koord_ptr  = choose_koordptr_by_streetptr(ziel_ptr);
    route = init_route();
    search_route(route, start_koord_ptr, ziel_koord_ptr);
    free_route(route);
    reset_best_len();
    if (loop) {
      start = malloc(80);
      ziel  = malloc(80);
      printf("Start: ");
      scanf("%s", start);
      printf("Ziel: ");
      scanf("%s", ziel);
    }
  } while(loop);
  return(0);
}

