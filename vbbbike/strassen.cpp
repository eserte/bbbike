/*
 * $Id: strassen.cpp,v 1.6 2000/12/12 01:47:09 eserte Exp $
 * Author: Slaven Rezic
 *
 * Copyright (C) 1998 Slaven Rezic. All rights reserved.
 *
 * Mail: eserte@cs.tu-berlin.de
 * WWW:  http://user.cs.tu-berlin.de/~eserte/
 *
 */

#include "strassen.h"
#include <stdio.h>
#include <string.h>

Strasse::Strasse() {
  name = NULL;
  category = NULL;
  x = NULL;
  y = NULL;
  anzahl = 0;
}

Strasse::Strasse(char *line) {
  char *p = line;
  char *q = p;
  for(; *q != 0 && *q != '\t'; q++);
  if (*q == 0) {
    fprintf(stderr, "Short read %s (no tab)\n", line);
    exit(6);
  }
  name = new char[q-p+1];
  strncpy(name, p, q-p);
  name[q-p] = 0;

  //  if (strcmp(name, "Leberstr.") == 0) { bla(); }

  p = ++q;
  for(; *q != 0 && *q != ' '; q++);
  if (*q == 0) {
    fprintf(stderr, "Short read %s (no coords after category)\n", line);
    exit(7);
  }
  category = new char[q-p+1];
  strncpy(category, p, q-p);
  category[q-p] = 0;

  anzahl = 0;
  x = y = NULL;

  p = ++q;
  while(1) { // *q != 0 && *q != ' ' && *q != '\n') {

    anzahl++;
    x = (int*)realloc(x, sizeof(int)*anzahl);
    y = (int*)realloc(y, sizeof(int)*anzahl);
    if (x == NULL || y == NULL) {
      perror("No memory");
      exit(8);
    }
    x[anzahl-1] = atoi(p);
    for(; *p != 0 && *p != '\n' && *p != ' ' && *p != ','; p++);
    if (*p != ',') {
      fprintf(stderr, "Short read <%s> (comma expected, got <%s>, Anzahl <%d>)\n", line, p, anzahl);
      exit(9);
    }   
    y[anzahl-1] = atoi(p+1);

    for(; *p != 0 && *p != '\n' && *p != ' '; p++);
    if (*p == 0 || *p == '\n') break;

    q = ++p;
  }
}

Strassen::Strassen() {
  pos      = 0;
  s        = NULL;
  s_anzahl = 0;
}

Strassen::Strassen(char* fn) {
  pos      = 0;
  filename = strdup(fn);
  s        = NULL;
  s_anzahl = 0;

  FILE *file;
  if ((file = fopen(filename, "r")) == NULL) {
    perror(filename);
    exit(1); // XXX exception
  }

  int i = 0;
  if ((data = (char**)malloc(sizeof(char*))) == NULL) {
    perror("No memory");
    exit(2); // XXX exception;
  }

  // XXX maximale Größe einer Zeile ist bislang 8821
#define MAXBUF 10000
  char buf[MAXBUF];
  while(fgets(buf, MAXBUF, file)) {
    Strasse *new_s = new Strasse(buf);
    add(new_s);
  }
  fclose(file);
}

void Strassen::add(Strasse *strasse) {
  s = (Strasse**)realloc(s, sizeof(Strasse*) * ++s_anzahl);
  if (s == NULL) {
    perror("No memory");
    exit(5);
  }
  s[s_anzahl-1] = strasse;

  for(int i = 0; i < strasse->anzahl; i++) {
    kreuzungen.add(strasse->x[i], strasse->y[i]);
  }
}

void Strassen::dump() {
  for(int i=0; i<s_anzahl; i++) {
    printf("%-40s %-3s ", s[i]->name, s[i]->category);
    for(int j=0; j<s[i]->anzahl; j++) {
      printf("%d,%d ", s[i]->x[j], s[i]->y[j]);
    }
    printf("\n");
  }
}
