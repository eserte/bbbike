/*
 * $Id: route.c,v 2.3 2000/12/12 01:52:41 eserte Exp $
 * Author: Slaven Rezic
 *
 * Copyright (C) 1999,2000 Slaven Rezic. All rights reserved.
 *
 * Mail: eserte@cs.tu-berlin.de
 * WWW:  http://user.cs.tu-berlin.de/~eserte/
 *
 */

#include "bbbike.h"

#ifndef DATA_IN_PROG
char *str_buf;
long  str_buf_len;
char *netz_buf;
long  netz_buf_len;
#else
# ifndef __palmos__
char *str_buf  = &str_buf_data[0];
char *netz_buf = &netz_buf_data[0];
# endif
#endif

#ifdef DEBUG
char* streetptr_to_name(strptr_t ptr) {
  return STR_NAME(str_buf + ptr);
}

/* gibt nur eine Straße der Koordinate aus, aber das reicht vollkommen aus */
char* koordptr_to_street(koordptr_t ptr) {
  char *netz_p = netz_buf + ptr;
  neighbourlen_t kreuz1_len = NETZ_NEIGHBOURPTRLEN(netz_p);
  return STR_NAME(str_buf + NETZ_STRPTR2(netz_p,kreuz1_len,0));
}

#endif

extern char str_buf_data[];

strptr_t streetptr_by_name(char *name) {
  char *str_p = STR_NAME(str_buf);
  char *str_end = str_buf + str_buf_len;
  int name_len = strlen(name);
  int cmp, this_str_len;
  koordlen_t koord_len;
  while(str_p < str_end) {
    cmp = strncasecmp(name, str_p, name_len);
    if (cmp == 0) {
      return str_p-str_buf;
    } else if (cmp < 0) {
      return -1;
    }
    this_str_len = strlen(str_p);
#ifdef __m68000__
    if ((this_str_len%2) == 0) this_str_len++;
#endif
    koord_len = KOORDLEN2(str_p, this_str_len);
    str_p += STR_STRUCTLEN2(this_str_len,koord_len); /* XXX STR_NAME fehlt */
  }
  return -1;
}

koordptr_t choose_koordptr_by_streetptr(strptr_t str_ptr) {
  char *str_p = str_buf + str_ptr;
  int str_len = strlen(str_p);
  koordlen_t koord_len;
  int i, ret;
  printf("%s Ecke:\n", str_p);
  koord_len = KOORDLEN(str_p);
  for(i=0; i<koord_len; i++) {
    char *netz_p = netz_buf + STR_KOORDPTR2(str_p,str_len,i);
    int j;
    int want_slash = 0;
    neighbourlen_t kreuz1_len = NETZ_NEIGHBOURPTRLEN(netz_p);
    strlen_t kreuz2_len = NETZ_STRPTRLEN2(netz_p,kreuz1_len);
    printf("%3d ", i);
    for(j=0; j<kreuz2_len; j++) {
      char* ecke_str_p = STR_NAME(str_buf+NETZ_STRPTR2(netz_p,kreuz1_len,j));
      if (want_slash)
	printf("/");
      else
	want_slash = 1;
      printf("%s", ecke_str_p);
    }
    printf("\n");
  }

  while(1) {
    printf("> ");
#ifdef __palmos__
    ret = 0;
#else
    scanf("%d", &ret);
#endif
    if (ret >= 0 && ret < koord_len)
      break;
    printf("Bitte eine Zahl von %d bis %d eingeben.\n", 0, koord_len-1);
  }
  return STR_KOORDPTR2(str_p,str_len,ret);
}

koordptr_t koordptr_by_koord(koord_t x, koord_t y) {
  char *str_p = STR_NAME(str_buf);
  char *str_end = str_buf + str_buf_len;
  int str_len;
  koordlen_t koord_len;
  int i;
  while(str_p < str_end) {
    str_len = strlen(str_p);
    koord_len = KOORDLEN2(str_p, str_len);
    for(i=0; i<koord_len; i++) {
      //      char *netz_p = netz_buf + STR_KOORDPTR2(str_p,str_len,i);
      koordptr_t koordptr = STR_KOORDPTR2(str_p,str_len,i);
      int x1, y1;
      GETXY(koordptr,x1,y1);
      if (x == x1 && y == y1) {
	printf("%s: <%d><%d> <=> <%d><%d>\n", str_p, x, y, x1, y1);
	return koordptr;
      }
    }
    str_p += STR_STRUCTLEN2(str_len,koord_len);
  }
  return -1;
}

/* Gibt die Straße zwischen from und to aus, oder -1, falls keine vorhanden */
strptr_t street_between(koordptr_t from, koordptr_t to) {
  int i, j;
  neighbourlen_t kreuz1_from_len = NETZ_NEIGHBOURPTRLEN(netz_buf+from);
  strlen_t kreuz2_from_len = NETZ_STRPTRLEN2(netz_buf+from,kreuz1_from_len);
  neighbourlen_t kreuz1_to_len   = NETZ_NEIGHBOURPTRLEN(netz_buf+to);
  strlen_t kreuz2_to_len   = NETZ_STRPTRLEN2(netz_buf+to,kreuz1_to_len);

  for(i = 0; i < kreuz2_from_len; i++) {
    strptr_t from_str = NETZ_STRPTR2(netz_buf+from,kreuz1_from_len,i);
    for(j = 0; j < kreuz2_to_len; j++) {
      strptr_t to_str = NETZ_STRPTR2(netz_buf+to,kreuz1_to_len,j);
      if (from_str == to_str) return from_str;
    }
  }
  return -1;
}

void reset_best_len() {
  char *p = netz_buf;
  char *end = netz_buf+netz_buf_len;
  while(p < end) {
    NETZ_BESTLEN(p) = 0;
    p+=NETZ_SIZEOF(p);
  }
}

long _strecke(koordptr_t koord1, koordptr_t koord2) {
  koord_t x1,y1, x2,y2;
  GETXY(koord1,x1,y1);
  GETXY(koord2,x2,y2);
  return (long)sqrt(SQR((DOUBLE)x1-x2)+SQR((DOUBLE)y1-y2));
}

char turn(koordptr_t p0, koordptr_t p1, koordptr_t p2, int* winkel) {
  koord_t x0,y0, x1,y1, x2,y2;
  koord_t a1, a2, b1, b2;
  long a_len, b_len;
  DOUBLE arg;

  GETXY(p0, x0,y0);
  GETXY(p1, x1,y1);
  GETXY(p2, x2,y2);

  a1 = x1-x0;
  a2 = y1-y0;
  b1 = x2-x1;
  b2 = y2-y1;

  a_len = _strecke(p0, p1);
  b_len = _strecke(p1, p2);
  arg = ((DOUBLE)a1*b1+a2*b2)/(a_len*b_len);
  if (arg > 1.0) arg = 0.9999999; /* XXX bessere Lösung? */
  if (arg < -1.0) arg = -0.9999999;
  *winkel = (a_len == 0 || b_len == 0 
	     ? 0 
	     : RAD2DEG(acos(arg)));

  return ((DOUBLE)a1*b2-a2*b1 > 0 ? 'l' : 'r');
}

struct route **init_route() {
  struct route **route;
  int i;
  route = (struct route**)malloc(sizeof(char*) * MAXROUTE);
  if (!route) exit(8);
  for(i=0;i<MAXROUTE;i++) {
    route[i] = (struct route*)malloc(sizeof(struct route));
    if (!route[i]) exit(9);
    route[i]->len = -1;
    route[i]->data =
      (koordptr_t*)malloc(sizeof(koordptr_t)*MAXKOORDINROUTE);
    if (!route[i]->data) exit(10);
  }
  return route;
}

void free_route(struct route **route) {
  int i;
  for(i=0;i<MAXROUTE;i++) {
    free(route[i]->data);
    free(route[i]);
  }
  free(route);
}

static struct route **_route_sort;
int _sort_routes_cmp(const void *a, const void *b) {
  int aa = *(int*)a;
  int bb = *(int*)b;
  if (aa == -1) return 1;
  if (bb == -1) return -1;
  if (_route_sort[aa]->virt_len == _route_sort[bb]->virt_len)
    return 0;
  if (_route_sort[aa]->virt_len < _route_sort[bb]->virt_len)
    return -1;
  return 1;
}

int _find_new_slot(struct route **route, long virt_len) {
  int i, max_i;
  long max_len = -1;
  for(i=0; i<MAXROUTE; i++) {
    if (route[i]->len == -1) return i;
  }
  for(i=0; i<MAXROUTE; i++) {
    if (route[i]->virt_len > max_len && route[i]->virt_len > virt_len) {
      max_len = route[i]->virt_len;
      max_i = i;
    }
  }
  if (max_len > -1) {
    return max_i;
  }
  return -1;
}

/* kopiert die Koordinaten der Route aus index_from nach index_to */
void _copy_route(struct route **route, int index_from, int index_to) {
  int i;
  int arrlen = route[index_from]->arrlen;
  for(i=0; i<arrlen; i++) {
    route[index_to]->data[i] = route[index_from]->data[i];
  }
  route[index_to]->arrlen = arrlen;
  /* len und virt_len müssen später gesetzt werden */
}

#if 0
int search_route(struct route **route,
		 koordptr_t from, koordptr_t to) {
}

#else
/* alte Implementation der Suche */
int search_route(struct route **route,
		 koordptr_t from, koordptr_t to) {
  int i, j;
  int sort_routes[MAXROUTE];

  route[0]->len = 0;
  route[0]->virt_len = _strecke(from, to);
  route[0]->arrlen = 1;
  route[0]->data[0] = from;
  
  while(1) {
    /* Routen sortieren */
    int sort_i = 0;
    for(i=0;i<MAXROUTE;i++) {
      if (route[i]->len > -1) {
	sort_routes[sort_i] = i;
	sort_i++;
      }
    }
    for(i=sort_i;i<MAXROUTE;i++) {
      sort_routes[i] = -1;
    }
    _route_sort = route;
    qsort(sort_routes, MAXROUTE, sizeof(int), _sort_routes_cmp);

    /* Schleife nur bis 10 statt MAXROUTE laufen lassen.
       Damit simuliere ich suspend_paths aus der originalen perl-Suchroutine.
       Siehe build_search_code in Strassen.pm
     */
    for(sort_i=0;sort_i<10;sort_i++) {
      i = sort_routes[sort_i];
      if (i == -1) break; /* keine gültigen Routen mehr */

      if (route[i]->len > -1) {
	neighbourlen_t kreuz1_len;
	koordptr_t thisfrom = route[i]->data[route[i]->arrlen-1];
//fprintf(stderr, "<%s>\n", koordptr_to_street(thisfrom));
	kreuz1_len = NETZ_NEIGHBOURPTRLEN(netz_buf+thisfrom);
	for(j=0;j<kreuz1_len;j++) {
	  long new_dist;
	  neighbour_t neighbour = NETZ_NEIGHBOURPTR(netz_buf+thisfrom,j);
	  dist_t dist           = NETZ_NEIGHBOURDIST(netz_buf+thisfrom,j);
	  new_dist = route[i]->len + dist;
//fprintf(stderr, "=> <%s> <%d>\n", koordptr_to_street(neighbour), new_dist);
	  if (NETZ_BESTLEN(netz_buf+neighbour) == 0 ||
	      NETZ_BESTLEN(netz_buf+neighbour) > new_dist) {
	    int new_slot;
	    NETZ_BESTLEN(netz_buf+neighbour) = new_dist;
	    new_slot = _find_new_slot(route, new_dist);
	    if (new_slot > -1) {
	      if (new_slot != i) {
		_copy_route(route, i, new_slot);
	      }
	      route[new_slot]->len = new_dist;
	      route[new_slot]->virt_len = new_dist + _strecke(neighbour, to);
	      route[new_slot]->data[route[new_slot]->arrlen] = neighbour;
	      (route[new_slot]->arrlen)++;
	    }
	  }

	  /* gefunden, Ausgabe */
	  if (neighbour == to) {
	    int j, old_strptr = -1;
	    long len = 0;

	    /* Warum eigentlich noch anfügen?
	       Aber es scheint richtig zu sein... */
	    route[i]->data[route[i]->arrlen] = neighbour;
	    (route[i]->arrlen)++;

	    printf("Strecke von %s nach %s: %6.2f km\n",
		   koordptr_to_street(from),
		   koordptr_to_street(neighbour), (DOUBLE)new_dist/1000);
	    for(j=0; j<route[i]->arrlen; j++) {
	      if (j > 0) {
		strptr_t strptr = street_between(route[i]->data[j-1],
						 route[i]->data[j]);
		len += _strecke(route[i]->data[j-1], route[i]->data[j]);
		if (strptr > 0) {
		  if (old_strptr == -1 || 
		      (old_strptr != strptr &&
		       strcmp(STR_NAME(str_buf+old_strptr),
			      STR_NAME(str_buf+strptr)) != 0)) {
		    char t = ' ';
		    int winkel = 0;
		    if (j > 1 && j < route[i]->arrlen-2) {
		      t = turn(route[i]->data[j-2],
			       route[i]->data[j-1],
			       route[i]->data[j],
			       &winkel);
		    }
		    printf(" ");
		    if (winkel >= 30) {
		      if (winkel <= 45) {
			printf("halb");
		      } else {
			printf("    ");
		      }
		      if (t == 'l') {
			printf("links ");
		      } else {
			printf("rechts");
		      }
		      printf(" (%3d°) ", NORM10WINKEL(winkel));
		    } else {
		      printf("                  ");
		    }
		    printf("%-40s  %6.2f km\n",
			   streetptr_to_name(strptr),
			   (DOUBLE)len/1000);
		  }
		  old_strptr = strptr;
		} else {
		  printf(" ???\n");
		}
	      }
	    }
	    return i; // return "slot"
	  }
	}
	route[i]->len = -1; /* macht diesen Slot ungültig */
      }
    }
  }
}
#endif
