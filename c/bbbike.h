/*
 * $Id: bbbike.h,v 2.5 2000/12/12 01:51:47 eserte Exp $
 * Author: Slaven Rezic
 *
 * Copyright (C) 1999 Slaven Rezic. All rights reserved.
 *
 * Mail: eserte@cs.tu-berlin.de
 * WWW:  http://user.cs.tu-berlin.de/~eserte/
 *
 */

#ifndef _bbbike_h
#define _bbbike_h

#if __cplusplus
extern "C" {
#endif

#ifdef __palmos__

# define DOUBLE float
# define DATA_IN_PROG
# pragma pack(2)

# define exit(x) 
# define strncasecmp(x,y,z) StrNCaselessCompare(x,y,z)
# define strlen(s) StrLen(s)

# include <Common.h>
# include <System/SysAll.h>
/*# include <math.h>*/
# include <unix_stdio.h>
# include <unix_stdlib.h>
# include <unix_string.h>

#else

# define DOUBLE double

# include <math.h>
# include <stdio.h>
# include <stdlib.h>
# include <string.h>
# include <unistd.h>

#endif


#define DEBUG 1

typedef unsigned short	koordlen_t;
#define KOORDLENSIZE	sizeof(koordlen_t)
typedef unsigned long	koordptr_t;
#define KOORDPTRSIZE	sizeof(koordptr_t)
typedef short		koord_t; /* doppelt */
#define KOORDSIZE    	sizeof(koord_t)*2
typedef unsigned short	bestlen_t;
#define BESTLENSIZE  	sizeof(dist_t)
typedef unsigned short	neighbourlen_t;
#define NEIGHBOURLENSIZE sizeof(neighbourlen_t)
typedef	koordptr_t	neighbour_t;
#define NEIGHBOURSIZE   KOORDPTRSIZE
typedef bestlen_t	dist_t;
#define DISTSIZE     	BESTLENSIZE
typedef unsigned short	strlen_t;
#define STRLENSIZE      sizeof(strlen_t)
typedef unsigned long	strptr_t;
#define STRPTRSIZE      sizeof(strptr_t)

#define STR_STRUCTLEN2(namelen,koordlen) ((namelen)+sizeof(char)+\
					  KOORDLENSIZE+koordlen*KOORDPTRSIZE)
#define STR_NAME(p) ((char*)p)
#define STR_KOORDPTR2(p,len,i) (*(koordptr_t*)(p+len+sizeof(char)+\
					       KOORDLENSIZE+(i)*KOORDPTRSIZE))

#define NETZ_BESTLEN(p) (*(bestlen_t*)(p+KOORDSIZE))
#define NETZ_NEIGHBOURPTRLEN(p) (*(neighbourlen_t*)(p+KOORDSIZE+BESTLENSIZE))
#define NETZ_NEIGHBOURPTR(p,i) (*(neighbour_t*)(p+KOORDSIZE+BESTLENSIZE+\
					      NEIGHBOURLENSIZE+\
					      (i)*(NEIGHBOURSIZE+DISTSIZE)))
#define NETZ_NEIGHBOURDIST(p,i) (*(neighbour_t*)(p+KOORDSIZE+BESTLENSIZE+\
						 NEIGHBOURLENSIZE+\
						 (i)*(NEIGHBOURSIZE+DISTSIZE)+\
						 NEIGHBOURSIZE))
#define NETZ_STRPTRLEN(p)      (NETZ_STRPTRLEN2(p,NETZ_NEIGHBOURPTRLEN(p)))
#define NETZ_STRPTRLEN2(p,len) (*(strlen_t*)(p+KOORDSIZE+BESTLENSIZE+\
					     NEIGHBOURLENSIZE+\
					     (len)*(NEIGHBOURSIZE+DISTSIZE)))
#define NETZ_STRPTR2(p,len,i) (*(strptr_t*)(p+KOORDSIZE+BESTLENSIZE \
					    +NEIGHBOURLENSIZE \
					    +(len)*(NEIGHBOURSIZE+DISTSIZE) \
					    +STRLENSIZE+(i)*STRPTRSIZE))
#define NETZ_SIZEOF(p) (KOORDSIZE+BESTLENSIZE+NEIGHBOURLENSIZE\
		       +NETZ_NEIGHBOURPTRLEN(p)*(NEIGHBOURSIZE+DISTSIZE)\
		       +STRLENSIZE + NETZ_STRPTRLEN(p)*STRPTRSIZE)

#define KOORDLEN(str_p)      KOORDLEN2(str_p, strlen(str_p))
#define KOORDLEN2(str_p,len) (*(koordlen_t*)(str_p+len+sizeof(char)))

#define GETXY(koordptr,x1,y1) \
  x1 = *(koord_t*)(netz_buf+koordptr); \
  y1 = *(koord_t*)(netz_buf+koordptr+KOORDSIZE/2);

#define SQR(x)		((x)*(x))
#define PI		(3.141592653)
#define RAD2DEG(x)	(((x)*180)/PI)
#define NORM10WINKEL(x)	(int)((x)/10*10+((x)%10>=5?10:0))

#define MAXROUTE 100
#define MAXKOORDINROUTE 2048
struct route {
  long len;
  long virt_len;
  int arrlen;
  koordptr_t *data;
};

extern char *str_buf;
extern char  str_buf_data[];
extern long  str_buf_len;
extern char *netz_buf;
extern long  netz_buf_len;
extern char  netz_buf_data[];

#ifdef DEBUG
char* streetptr_to_name(strptr_t ptr);
char* koordptr_to_street(koordptr_t ptr);
#endif

strptr_t streetptr_by_name(char *name);
koordptr_t choose_koordptr_by_streetptr(strptr_t str_ptr);
koordptr_t koordptr_by_koord(koord_t x, koord_t y);
strptr_t street_between(koordptr_t from, koordptr_t to);
void reset_best_len();
long _strecke(koordptr_t koord1, koordptr_t koord2);
char turn(koordptr_t p0, koordptr_t p1, koordptr_t p2, int* winkel);
struct route **init_route();
void free_route(struct route **route);
int _sort_routes_cmp(const void *a, const void *b);
int _find_new_slot(struct route **route, long virt_len);
void _copy_route(struct route **route, int index_from, int index_to);
int search_route(struct route **route,
		 koordptr_t from, koordptr_t to);

void cp850_iso(char *s);
void iso_cp850(char *s);

#if __cplusplus
}
#endif

#endif
