/* -*- c-basic-offset:2 -*- */
#ifdef __cplusplus
extern "C" {
#endif
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#ifdef __cplusplus
}
#endif

/* berechnet StrassenNetz mit KoordXY-Komponente, wenn definiert */
#undef WITH_KOORDXY

/* XXX andere Compiler ? */
#ifndef __inline__
#ifndef __GNUC__
#define __inline__
#endif /* __GNUC__ */
#endif /* __inline__ */

#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "sqrt.h"

#if PERL_REVISION > 5 || (PERL_REVISION == 5 && (PERL_VERSION > 5 || (PERL_VERSION == 5 && (PERL_SUBVERSION > 57))))
# define MODERN_PERL
#endif

#if !defined(PL_na) && !defined(MODERN_PERL)
# define PL_na na
#endif
#if !defined(PL_sv_undef) && !defined(MODERN_PERL)
# define PL_sv_undef sv_undef
#endif

#undef MYDEBUG

/* INT_SQRT and !USE_HYPOT is restricted to dist of approx. 100 km */
#define USE_HYPOT

/* Check whether the longest line in the database files does not
 * overflow the buffer. Current longest:
 * wasserumland2 with 8821 bytes.
 * See rule "check-line-lengths" in data/Makefile
 */
#define MAXBUF 12288
#define MAXPOINTS 1024

/* should be the same as in BBBikeTrans.pm */
#define X_DELTA -200.0
#define X_MOUNT 1
#define Y_DELTA 600.0
#define Y_MOUNT -1

#define TRANSPOSE_X(x) (X_DELTA+X_MOUNT*x/25.0)*canvas_scale+0.5
#define TRANSPOSE_Y(y) (Y_DELTA+Y_MOUNT*y/25.0)*canvas_scale+0.5

/* Define TRANSPOSE_USE_INTS if you do not need the accuracy
 * (important for zooms!) or your machine is lacking a floating
 * point processor
 */
#ifdef TRANSPOSE_USE_INTS
# define TRANSPOSE_X_SCALAR(x) (newSViv(TRANSPOSE_X(x)))
# define TRANSPOSE_Y_SCALAR(y) (newSViv(TRANSPOSE_Y(y)))
#else
# define TRANSPOSE_X_SCALAR(x) (newSVnv(TRANSPOSE_X(x)))
# define TRANSPOSE_Y_SCALAR(y) (newSVnv(TRANSPOSE_Y(y)))
#endif

/* targ stuff does not work with 5.005 */
#ifdef dXSTARG
#define LOAD_AMPEL_IMAGE(tag,var)	{			\
    dSP;							\
    dXSTARG; /* XXX why is this necessary? */			\
    int count;							\
    ENTER;							\
    SAVETMPS;							\
    PUSHMARK(SP);						\
    XPUSHp(tag, strlen(tag));					\
    PUTBACK;							\
    count = call_pv("main::get_symbol_scale", G_SCALAR);	\
    SPAGAIN;							\
    if (count != 1) {						\
	croak("Unsuccesful call to get_symbol_scale");		\
    }								\
    var = newSVsv(POPs);					\
    PUTBACK;							\
    FREETMPS;							\
    LEAVE;							\
}
#endif

typedef SV* StrassenNetz;

double canvas_scale = 1;

#define TO_KOORD1(func_name,newsv_func,ato_func) \
    __inline__ static void					\
    func_name(s, x, y)						\
    char *s;							\
    SV **x, **y;						\
    {								\
        char *p;						\
    								\
        p = s;							\
        while(*p != ',' && *p != 0) p++;			\
        if (*p == 0) {						\
          warn("%s is expected to be of the format x,y\n", s);	\
          *x = newSVsv(&PL_sv_undef);				\
          *y = newSVsv(&PL_sv_undef);				\
          return;						\
        }							\
    								\
        p++;							\
    								\
        *x = newsv_func(ato_func(s));				\
        *y = newsv_func(ato_func(p));				\
    }

TO_KOORD1(to_koord1,newSViv,atoi)
TO_KOORD1(to_koord_f1,newSVnv,atof)

#define TO_KOORD(func_name,to_koord1_func) \
    __inline__ static AV*			\
    func_name(raw_coords)			\
    AV* raw_coords;				\
    {						\
        int i = 0;				\
        int len = av_len(raw_coords);		\
        AV *res = newAV();			\
    						\
        for(; i<=len; i++) {			\
          SV **tmp;				\
          SV *x, *y;				\
          AV *elem;				\
          char *s;				\
    						\
          tmp = av_fetch(raw_coords, i, 0);	\
          s = SvPV(*tmp, PL_na);		\
    						\
          to_koord1_func(s, &x, &y);		\
          elem = newAV();			\
          av_extend(elem, 2);			\
          av_store(elem, 0, x);			\
          av_store(elem, 1, y);			\
          av_push(res, newRV_noinc((SV*)elem));	\
        }					\
        return res;				\
    }

TO_KOORD(to_koord,to_koord1)
TO_KOORD(to_koord_f,to_koord_f1)

static int
strecke(kreuz_coord, i)
AV* kreuz_coord;
int i;
{
#if defined(INT_SQRT) || defined(MAYBE_INT_SQRT)
    long a1, a2;
#else
    float a1, a2;
#endif
    SV *tmp1, *tmp2;

    tmp1 = SvRV(*av_fetch(kreuz_coord, i, 0));
    tmp2 = SvRV(*av_fetch(kreuz_coord, i+1, 0));

    a1 = SvIV(*(av_fetch((AV*)tmp1, 0, 0))) -
         SvIV(*(av_fetch((AV*)tmp2, 0, 0)));
    a2 = SvIV(*(av_fetch((AV*)tmp1, 1, 0))) -
         SvIV(*(av_fetch((AV*)tmp2, 1, 0)));
#if defined(INT_SQRT) || defined(MAYBE_INT_SQRT)
    return eyal(a1*a1 + a2*a2);
#else
#  ifdef USE_HYPOT
    /* what's faster/better: hypot or sqrt(sqr ...) ? */
    return hypotf(a1,a2);
#  else
    return sqrtf(a1*a1 + a2*a2);
#  endif
#endif
}

void get_restrict_ignore_array(SV* ref, char*** array, char** array_strings) {
  AV* ref_a;
  int i, len = 0;
  char *p;
  if (!SvROK(ref) || SvTYPE(SvRV(ref)) != SVt_PVAV)
    croak("usage: argument must be an array reference");
  ref_a = (AV*)SvRV(ref);
  /* get length for malloc'ed memory */
  for (i=0; i<=av_len(ref_a); i++) {
    SV** tmp = av_fetch(ref_a, i, 1);
    int thislen;
    SvPV(*tmp, thislen);
    len += thislen + 1;
  }
  New(12, *array_strings, len, char);
  /* size for the pointers */
  New(13, *array, av_len(ref_a)+2, char*);
  /* set the restrict array */
  p = *array_strings;
  for (i=0; i<=av_len(ref_a); i++) {
    SV** tmp = av_fetch(ref_a, i, 1);
    char *s;
    int thislen;
    s = SvPV(*tmp, thislen);
    strncpy(p, s, thislen);
    *(p+thislen) = 0;
    (*array)[i] = p;
    p += (thislen + 1);
  }
  (*array)[av_len(ref_a)+1] = NULL;
}

static void
check_utf8_encoding(char* buf, int* do_utf8_decoding_ref) {
  if (buf[1] == ':') {
    char* p = strstr(buf+2, "encoding");
    if (p) {
      p += strlen("encoding");
      if (*p == ':') p++;
      while(*p && *p == ' ') p++;
      if (strstr(p, "utf-8")) {
	*do_utf8_decoding_ref = 1;
      } else if (strstr(p, "iso-8859-1") ||
		 strstr(p, "latin1")) {
	*do_utf8_decoding_ref = 0;
      } else {
	warn("Cannot handle encoding '%s' with fast implementation, output may be garbled", p);
      }
    }
  }
}

MODULE = BBBikeXS		PACKAGE = main

PROTOTYPES: DISABLE


void
set_canvas_scale_XS(scale)
	double scale;

	PPCODE:
	canvas_scale = scale;


void
transpose_ls_XS(x, y)
	int x;
	int y;

	PPCODE:
	EXTEND(sp, 2);
	PUSHs(sv_2mortal(TRANSPOSE_X_SCALAR(x)));
	PUSHs(sv_2mortal(TRANSPOSE_Y_SCALAR(y)));



MODULE = BBBikeXS		PACKAGE = Strassen::Util

PROTOTYPES: DISABLE

double
strecke_XS(p1, p2)
	SV *p1;
	SV *p2;
	PREINIT:
	SV **sv1;
	SV **sv2;
#ifdef INT_SQRT
#  define MySvGET(x) SvIV((x))
	long a1, a2;
#else
#  define MySvGET(x) SvNV((x))
	double a1,a2;
#endif
	CODE:
	sv1 = av_fetch((AV*)SvRV(p1), 0, 0);
	sv2 = av_fetch((AV*)SvRV(p2), 0, 0);
	if (!sv1 || !sv2) croak("Invalid arguments in strecke_XS");
	a1 = MySvGET(*sv1) - MySvGET(*sv2);
	sv1 = av_fetch((AV*)SvRV(p1), 1, 0);
	sv2 = av_fetch((AV*)SvRV(p2), 1, 0);
	if (!sv1 || !sv2) croak("Invalid arguments in strecke_XS");
	a2 = MySvGET(*sv1) - MySvGET(*sv2);
#ifdef INT_SQRT
	RETVAL = eyal(a1*a1 + a2*a2);
#else
#  ifdef USE_HYPOT
	RETVAL = hypot(a1, a2);
#  else
	RETVAL = sqrt(a1*a1 + a2*a2);
#  endif
#endif
	OUTPUT:
	RETVAL


double
strecke_s_XS(p1, p2)
	char *p1;
	char *p2;
	PREINIT:
#ifdef INT_SQRT
	long x1 = 0;
	long y1 = 0;
	long x2 = 0;
	long y2 = 0;
#else
	double x1 = 0.0;
	double y1 = 0.0;
	double x2 = 0.0;
	double y2 = 0.0;
#endif
	char *new_p;
	CODE:
	new_p = strchr(p1, ',');
	if (new_p) {
#ifdef INT_SQRT
	  x1 = atoi(p1);
	  y1 = atoi(new_p + 1);
#else
	  x1 = atof(p1);
	  y1 = atof(new_p + 1);
#endif
	} else {
	  warn("%s is not a point", p1);
	  goto error;
	}
	new_p = strchr(p2, ',');
	if (new_p) {
#ifdef INT_SQRT
	  x2 = atoi(p2);
	  y2 = atoi(new_p + 1);
#else
	  x2 = atof(p2);
	  y2 = atof(new_p + 1);
#endif
	} else {
	  warn("%s is not a point", p2);
	  goto error;
	}
	error:
#ifdef INT_SQRT
	RETVAL = eyal((x1-x2)*(x1-x2) + (y1-y2)*(y1-y2));
#else
#  ifdef USE_HYPOT
	RETVAL = hypot(x1-x2, y1-y2);
#  else
	RETVAL = sqrt((x1-x2)*(x1-x2) + (y1-y2)*(y1-y2));
#  endif
#endif
	OUTPUT:
	RETVAL

MODULE = BBBikeXS		PACKAGE = Strassen

PROTOTYPES: DISABLE


SV*
to_koord1_XS(s)
	char *s;

	PREINIT:
	AV *elem;
	SV *x, *y;

	CODE:
	to_koord1(s, &x, &y);
	elem = newAV();
	av_extend(elem, 2);
	av_store(elem, 0, x);
	av_store(elem, 1, y);
	RETVAL = newRV_noinc((SV*)elem);

	OUTPUT:
	RETVAL

SV*
to_koord_XS(raw)
	SV *raw;

	CODE:
	if (!SvROK(raw) || SvTYPE(SvRV(raw)) != SVt_PVAV)
            croak("argument to to_koord_XS should be a ref to an array.\n");
	RETVAL = newRV_noinc((SV*)to_koord(SvRV(raw)));

        OUTPUT:
	RETVAL

SV*
to_koord_f1_XS(s)
	char *s;

	PREINIT:
	AV *elem;
	SV *x, *y;

	CODE:
	to_koord_f1(s, &x, &y);
	elem = newAV();
	av_extend(elem, 2);
	av_store(elem, 0, x);
	av_store(elem, 1, y);
	RETVAL = newRV_noinc((SV*)elem);

	OUTPUT:
	RETVAL

SV*
to_koord_f_XS(raw)
	SV *raw;

	CODE:
	if (!SvROK(raw) || SvTYPE(SvRV(raw)) != SVt_PVAV)
            croak("argument to to_koord_f_XS should be a ref to an array.\n");
	RETVAL = newRV_noinc((SV*)to_koord_f(SvRV(raw)));

        OUTPUT:
	RETVAL


MODULE = BBBikeXS		PACKAGE = StrassenNetz

PROTOTYPES: DISABLE

void
make_net_XS(self, ...)
	StrassenNetz self;

	PREINIT:
	HV *net, *net2name, *wegfuehrung, *penalty;
#ifdef WITH_KOORDXY
	HV *koordxy;
#endif
	int item_i;
	SV *strassen, *ret;
	SV** tmp;
        /* int dbg_i = 0; */
	char *k0_s, *k1_s;
	STRLEN k0_slen, k1_slen;
	SV* progress = &PL_sv_undef;
	int prefer_cache = 0;
	int count = 0;
	HV *self_hash;

	CODE:
	if (sv_derived_from(self, "StrassenNetz"))
	    self_hash = (HV*)SvRV(self);
	else
	    croak("self is not of type StrassenNetz");

	if (items > 2) {
	  for(item_i = 1; item_i < items; item_i+=2) {
	    char *tmp = SvPV(ST(item_i), PL_na);
	    if (strcmp(tmp, "Progress") == 0) {
	      progress = ST(item_i+1);
	    } else if (strcmp(tmp, "PreferCache") == 0) {
	      prefer_cache = SvTRUE(ST(item_i+1));
	    }
	  }
	}
	SP -= items;

	if (prefer_cache) {
	  SV* ret;
	  ENTER;
	  SAVETMPS;
	  PUSHMARK(sp);
	  XPUSHs(self);
	  PUTBACK;
	  perl_call_method("net_read_cache", G_SCALAR);
	  SPAGAIN;
	  ret = newSVsv(POPs);
	  PUTBACK;
	  FREETMPS;
	  LEAVE;
	  if (SvTRUE(ret)) {
	    return;
	  }
	}

	net         = newHV();
	net2name    = newHV();
	wegfuehrung = newHV();
	penalty     = newHV();
#ifdef WITH_KOORDXY
	koordxy  = newHV();
#endif
	hv_store(self_hash, "Net",      strlen("Net"),
		       newRV_noinc((SV*) net), 0);
	hv_store(self_hash, "Net2Name", strlen("Net2Name"),
		       newRV_noinc((SV*) net2name), 0);
	hv_store(self_hash, "Wegfuehrung", strlen("Wegfuehrung"),
		       newRV_noinc((SV*) wegfuehrung), 0);
	hv_store(self_hash, "Penalty", strlen("Penalty"),
		       newRV_noinc((SV*) penalty), 0);
#ifdef WITH_KOORDXY
	hv_store(self_hash, "KoordXY",  strlen("KoordXY"),
		       newRV_noinc((SV*) koordxy), 0);
#endif
	tmp = hv_fetch(self_hash, "Strassen", strlen("Strassen"), 0);
	if (tmp == NULL)
	    croak("Missing $self->{Strassen}.\n");
	if (!SvROK(*tmp) || SvTYPE(SvRV(*tmp)) != SVt_PVHV)
	    croak("$self->{Strassen} is not a valid reference.\n");
	strassen = *tmp;

	PUSHMARK(sp);
	XPUSHs(strassen);
	PUTBACK;
	perl_call_method("init", G_DISCARD|G_VOID);
	SPAGAIN;

	while(1) {
	  AV *kreuzungen, *kreuz_coord;
	  int i, kreuzungen_len;
	
	  ENTER;
	  SAVETMPS;
	  PUSHMARK(sp);
	  XPUSHs(strassen);
	  PUTBACK;
	  perl_call_method("next", G_SCALAR);
	  SPAGAIN;
	  ret = newSVsv(POPs);
	  PUTBACK;
	  FREETMPS;
	  LEAVE;

	  tmp = av_fetch((AV*)SvRV(ret), 1, 0);
	  
	  if (tmp == NULL) break; /* XXX error? */
	  kreuzungen = (AV*)SvRV(*tmp);
	  if (kreuzungen == NULL || av_len(kreuzungen) == -1) break;
	  kreuz_coord = to_koord(kreuzungen);

	  kreuzungen_len = av_len(kreuzungen);
	  for(i = 0; i < kreuzungen_len; i++) {
	    SV **tmp, *k0, *k1;
	    HV *hashtmp;
	    int entf = strecke(kreuz_coord, i);
	    k0 = *av_fetch(kreuzungen, i, 0);
	    k1 = *av_fetch(kreuzungen, i+1, 0);
	    k0_s = SvPV(k0, k0_slen);
	    k1_s = SvPV(k1, k1_slen);

	    tmp = hv_fetch(net, k0_s, k0_slen, 0);
	    if (tmp == NULL) {
	      hashtmp = newHV();
	      hv_store(net, k0_s, k0_slen, newRV_noinc((SV*)hashtmp), 0);
	    } else
	      hashtmp = (HV*)SvRV(*tmp);
	    hv_store(hashtmp, k1_s, k1_slen, newSViv(entf), 0);

	    tmp = hv_fetch(net, k1_s, k1_slen, 0);
	    if (tmp == NULL) {
	      hashtmp = newHV();
	      hv_store(net, k1_s, k1_slen, newRV_noinc((SV*)hashtmp), 0);
	    } else
	      hashtmp = (HV*)SvRV(*tmp);
	    hv_store(hashtmp, k0_s, k0_slen, newSViv(entf), 0);
#ifdef WITH_KOORDXY
	    if (!hv_exists(koordxy, k0_s, k0_slen)) {
	      tmp = av_fetch(kreuz_coord, i, 0);
	      hv_store(koordxy, k0_s, k0_slen, newSVsv(*tmp), 0);
	    }
#endif
	    tmp = hv_fetch(net2name, k0_s, k0_slen, 0);
	    if (tmp == NULL) {
	      hashtmp = newHV();
	      hv_store(net2name, k0_s, k0_slen, newRV_noinc((SV*)hashtmp), 0);
	    } else
	      hashtmp = (HV*)SvRV(*tmp);
	    tmp = hv_fetch((HV*)SvRV(strassen),
			   "Pos", strlen("Pos"), 0);
#if 0 /* NOT_YET? */
	    if (hv_exists(hashtmp, k1_s, k1_slen)) {
	      AV *arrtmp;
	      SV **tmp2;
	      tmp2 = hv_fetch(hashtmp, k1_s, k1_slen, 0);
	      if (SvTYPE(*tmp2) != SVt_PVAV) {
		arrtmp = newAV();
		av_push(arrtmp, *tmp2);
		hv_store(hashtmp, k1_s, k1_slen, (SV*)arrtmp, 0);
	      } else {
		arrtmp = (AV*)*tmp2;
	      }
	      av_push(arrtmp, newSVsv(*tmp));
	    } else {
#endif /* NOT_YET */
	      hv_store(hashtmp, k1_s, k1_slen, newSVsv(*tmp), 0);
#if 0 /* NOT_YET? */
	    }
#endif /* NOT_YET */
	  }
#ifdef WITH_KOORDXY
	  /* letztes $i */
	  if (!hv_exists(koordxy, k1_s, k1_slen)) {
	    tmp = av_fetch(kreuz_coord, i, 0);
	    hv_store(koordxy, k1_s, k1_slen, newSVsv(*tmp), 0);
	  }
#endif

	  SvREFCNT_dec((SV*)kreuz_coord);
	  /* memleak: XXX	  av_undef(kreuz_coord); */
	  SvREFCNT_dec(ret); /* XXX ja? */
	  if (++count % 150 == 0 && SvTRUE(progress)) {
	    PUSHMARK(sp);
	    XPUSHs(progress);
	    PUTBACK;
	    perl_call_method("UpdateFloat", G_DISCARD);
	    SPAGAIN;
	  }
	}
	
	if (prefer_cache) {
	  PUSHMARK(sp);
	  XPUSHs(self);
	  PUTBACK;
	  perl_call_method("net_write_cache", G_DISCARD|G_VOID);
	  SPAGAIN;
	}

	hv_store(self_hash, "UseMLDBM",      strlen("UseMLDBM"),
		       newSViv(0), 0);

MODULE = BBBikeXS		PACKAGE = BBBike

PROTOTYPES: DISABLE

void
fast_plot_str(canvas, abk, fileref, ...)
	SV *canvas;
	char *abk;
	SV *fileref;

	PREINIT:
	SV *progress = &PL_sv_undef;
	FILE *f;
	char buf0[MAXBUF];
	char *buf;
	char abkcat[24];
	struct {
	  int x, y;
	} point[MAXPOINTS];
	AV *tags, *outline_tags;
	int count;
	int file_count = 0;
	int total_file_count;
	long currpos;
	int do_utf8_decoding = 0;
	AV* fileref_array = NULL;
	AV* data_array = NULL;
	int data_pos = 0;

	int outline;
	SV** sv_outline;
	HV* str_outline;

	SV** sv_sv_outline_color;
	SV* sv_outline_color;
	HV* outline_color;

	HV* category_width = NULL;
	HV* category_color = NULL;

	SV *tags_sv, *fill_sv, *joinstyle_sv, *bevel_sv, *width_sv, *mounds_sv;

	char** restr_array = NULL;
	char* restr_array_strings = NULL;
	char** ignore_array = NULL;
	char* ignore_array_strings = NULL;

	int has_draw_bridge = -1;
	int has_draw_tunnel_entrance = -1;

	CODE:
	if (items > 3)
	  progress = ST(3);
	if (items > 4 && SvTRUE(ST(4))) {
	  /* get the restrict array and convert it to a C array */
	  get_restrict_ignore_array(ST(4), &restr_array, &restr_array_strings);
#if 0
	  SV* restr = ST(4);
	  AV* restr_a;
	  int i, len = 0;
	  char *p;
	  if (!SvROK(restr) || SvTYPE(SvRV(restr)) != SVt_PVAV)
	    croak("usage: argument must be an array reference");
	  restr_a = (AV*)SvRV(restr);
	  /* get length for malloc'ed memory */
	  for (i=0; i<=av_len(restr_a); i++) {
	    SV** tmp = av_fetch(restr_a, i, 1);
	    int thislen;
	    SvPV(*tmp, thislen);
	    len += thislen + 1;
	  }
	  New(12, restr_array_strings, len, char);
	  /* size for the pointers */
	  New(13, restr_array, av_len(restr_a)+2, char*);
	  /* set the restrict array */
	  p = restr_array_strings;
	  for (i=0; i<=av_len(restr_a); i++) {
	    SV** tmp = av_fetch(restr_a, i, 1);
	    char *s;
	    int thislen;
	    s = SvPV(*tmp, thislen);
	    strncpy(p, s, thislen);
	    *(p+thislen) = 0;
	    restr_array[i] = p;
	    p += (thislen + 1);
	  }
	  restr_array[av_len(restr_a)+1] = NULL;
#endif
        }
	if (items > 5 && SvTRUE(ST(5))) {
	  // category_width
	  SV* cw = ST(5);
	  if (!SvROK(cw) || SvTYPE(SvRV(cw)) != SVt_PVHV)
	    croak("usage: argument must be an hash reference");
	  category_width = (HV*)SvRV(cw);
	}
	if (items > 6 && SvTRUE(ST(6))) {
	  /* get the restrict array and convert it to a C array */
	  get_restrict_ignore_array(ST(6), &ignore_array, &ignore_array_strings);
	}
	SP -= items;

 /* muß noch zur Serienreife verfeinert werden ... scheint aber *wesentlich*
    schneller als der perl-Part zu sein?! */

	tags = newAV();
	av_push(tags, newSVpv(abk, 0));
	outline_tags = newAV();
	strcpy(abkcat, abk);
	strcat(abkcat, "-out");
	av_push(outline_tags, newSVpv(abkcat, 0));

	if (SvROK(fileref) && SvTYPE(SvRV(fileref)) == SVt_PVAV) {
	  fileref_array = (AV*)SvRV(fileref);
	  total_file_count = av_len(fileref_array)+1;
	} else {
	  total_file_count = 1;
	}

	str_outline = perl_get_hv("main::str_outline", TRUE);
	sv_outline = hv_fetch(str_outline, abk, strlen(abk), 0);
	if (sv_outline)
	  outline = SvTRUE(*sv_outline);
	else
	  outline = 0;

	outline_color = perl_get_hv("main::outline_color", TRUE);
	sv_sv_outline_color = hv_fetch(outline_color, abk, strlen(abk), 0);
	if (sv_sv_outline_color)
	  sv_outline_color = *sv_sv_outline_color;
	else
	  sv_outline_color = newSVpv("grey50", 0); /* wird unten freigegeben */

	category_color = perl_get_hv("main::category_color", TRUE);

	tags_sv = newSVpv("-tags", 0);
	fill_sv = newSVpv("-fill", 0);
	joinstyle_sv = newSVpv("-joinstyle", 0);
	bevel_sv = newSVpv("bevel", 0);
	width_sv = newSVpv("-width", 0);
	mounds_sv = newSVpv("-mounds", 0);

	count = 0;
	while(1) {
	  char *file = NULL;
	  SV* file_or_object;
	  long file_size = -1;
	  if (fileref_array) {
	    SV **s = av_fetch(fileref_array, file_count, 0);
	    file_or_object = *s;
	  } else
	    file_or_object = fileref;

	  if (sv_derived_from(file_or_object, "Strassen")) {
	    SV **tmp;
	    tmp = hv_fetch((HV*)SvRV(file_or_object), "Data", strlen("Data"), 0);
	    if (tmp == NULL)
	      croak("No Data member in Strassen object.\n");
	    if (!SvROK(*tmp) || SvTYPE(SvRV(*tmp)) != SVt_PVAV)
	      croak("{Data} member is not a valid array reference.\n");
	    data_array = (AV*)SvRV(*tmp);
	    data_pos = 0;
	    f = NULL;
	    buf = NULL;
	  } else {
	    file = SvPV(file_or_object, PL_na);
	    f = fopen(file, "r");
	    if (!f) croak("Can't open %s: %s\n", file, strerror(errno));
	    if (fseek(f, 0, SEEK_END) == 0) {
	      file_size = ftell(f);
	      fseek(f, 0, SEEK_SET);
	    } else {
	      warn("Cannot fseek file '%s'?", file);
	      file_size = -1;
	    }
	    currpos = 0;
	    buf = buf0;
	  }

	  /*count = 0;*/
	  while((f && !feof(f)) ||
		(data_array && data_pos <= av_len(data_array))) {
	    char *p, *cat, *cat_attrib;
	    int i, point_i;

	    /* get line from file or data array */
	    if (f) {
	      if (fgets(buf, MAXBUF, f) == NULL)
		break;
	      currpos += strlen(buf);
	    } else {
	      SV **tmp = av_fetch(data_array, data_pos, 0);
	      if (tmp == NULL)
		croak("Error while fetching %d-nth element from {Data}.\n", data_pos);
	      buf = SvPV(*tmp, PL_na);
	      data_pos++;
	    }

	    /* It seems that the eof condition is only detected now,
	     * after trying to read again (?!) */
	    if (f && feof(f)) {
	      break;
	    }

	    if (buf[0] == '#') {
	      check_utf8_encoding(buf, &do_utf8_decoding);
	    } else {
	      p = strchr(buf, '\t');
	      if (p) {
		*p = 0;
#ifdef MYDEBUG
		fprintf(stderr, "%d: %s\n", count, buf);
#endif
		cat = p+1;
		p = strchr(p+1, ' ');
		if (p) {
		  *p = 0;
		  if (!*(++p)) break;

		  {
		    char *p = strchr(cat, ':');
		    if (p && *(p+1) == ':' && *(p+2) != 0) {
		      *p = 0;
		      cat_attrib = p+2;
		    } else {
		      cat_attrib = NULL;
		    }
		  }

		  /* check ignore, if needed */
		  if (ignore_array) {
		    char **p = ignore_array;
		    int found = 0;
		    while(*p) {
		      if (strcmp(cat, *p) == 0) {
			found++;
			break;
		      }
		      p++;
		    }
		    if (found) {
		      count++; // so the tags are correctly created
		      continue;
		    }
		  }

		  /* check restriction, if needed */
		  if (restr_array) {
		    char **p = restr_array;
		    int found = 0;
		    while(*p) {
		      if (strcmp(cat, *p) == 0) {
			found++;
			break;
		      }
		      p++;
		    }
		    if (!found) {
		      count++; // so the tags are correctly created
		      continue;
		    }
		  }

		  point_i = 0;
		  while(*p) {
		    char *new_p = strchr(p, ',');
		    if (new_p) {
		      point[point_i].x = atoi(p);
		      p = new_p + 1;
		      new_p = strchr(p, ' ');
		      point[point_i].y = atoi(p);
		      point_i++;
		      if (new_p)
			p = new_p + 1;
		      else
			break;
		    }
		  }

		  if (point_i > 1) {
		    int width = 1;
		    char *fill = "white";
		    SV* name;
		    AV *coords;

		    if (category_width) {
		      SV** sv_sv_category_width = hv_fetch(category_width,
							   cat, strlen(cat), 0);
		      if (sv_sv_category_width) {
			width = SvIV(*sv_sv_category_width);
		      }
		    }
		    if (category_color) {
		    SV** sv_sv_category_color = hv_fetch(category_color,
							 cat, strlen(cat), 0);
		    if (sv_sv_category_color)
		      fill = SvPV(*sv_sv_category_color, PL_na);
		    }

		    if (!category_width || !category_color) {
		      // fallbacks ...
		      switch (*cat) {
		      case 'H':
			if (*(cat+1) == 0)
			  fill = "yellow";
			else
			  fill = "yellow2";
			width = 3;
			break;

		      case 'N':
			if (*(cat+1) == 0)
			  fill = "grey99";
			else
			  fill = "#bdffbd";
			width = 2;
			break;

		      case 'B':
			fill = "red3";
			width = 3;
			break;

		      default:
			fill = "white";
			width = 2;
		      }
		    }

		    coords = newAV();
		    for(i = 0; i < point_i; i++) {
		      av_push(coords, TRANSPOSE_X_SCALAR(point[i].x));
		      av_push(coords, TRANSPOSE_Y_SCALAR(point[i].y));
		    }

		    if (outline) {
		      strcpy(abkcat, abk);
		      strcat(abkcat, "-");
		      strcat(abkcat, cat);
		      strcat(abkcat, "-out");
		      av_store(outline_tags, 1, newSVpv(abkcat, 0));

		      PUSHMARK(sp);
		      XPUSHs(canvas);
		      XPUSHs(sv_2mortal(newRV_inc((SV*)coords)));
		      XPUSHs(tags_sv);
		      XPUSHs(sv_2mortal(newRV_inc((SV*)outline_tags)));
		      XPUSHs(fill_sv);
		      XPUSHs(sv_outline_color);
		      XPUSHs(joinstyle_sv);
		      XPUSHs(bevel_sv);
		      XPUSHs(width_sv);
		      XPUSHs(sv_2mortal(newSViv(width+2)));

		      PUTBACK;
		      perl_call_method("createLine", G_DISCARD|G_VOID);
		      SPAGAIN;
		    }

		    name = newSVpv(buf, 0);
		    if (do_utf8_decoding) {
		      if (is_utf8_string(buf, 0)) {
			SvUTF8_on(name);
		      } else {
			warn("'%s' does not look like an utf-8 string", SvPV(name, PL_na));
		      }
		    }
		    av_store(tags, 1, name);
		    strcpy(abkcat, abk);
		    strcat(abkcat, "-");
		    strcat(abkcat, cat);
		    av_store(tags, 2, newSVpv(abkcat, 0));
		    sprintf(abkcat, "%s-%d", abk, count);
		    av_store(tags, 3, newSVpv(abkcat, 0));

		    PUSHMARK(sp);
		    XPUSHs(canvas);
		    XPUSHs(sv_2mortal(newRV_inc((SV*)coords)));
		    XPUSHs(tags_sv);
		    XPUSHs(sv_2mortal(newRV_inc((SV*)tags)));
		    XPUSHs(fill_sv);
		    XPUSHs(sv_2mortal(newSVpv(fill,0)));
		    XPUSHs(width_sv);
		    XPUSHs(sv_2mortal(newSViv(width)));

		    PUTBACK;
		    perl_call_method("createLine", G_DISCARD|G_VOID);
		    SPAGAIN;

		    if (cat_attrib) {
		      if (strcmp(cat_attrib, "Br") == 0) {
			if (has_draw_bridge == -1) {
			  CV* sub = get_cv("main::draw_bridge", 0);
			  if (sub) {
			    has_draw_bridge = 1;
			  } else {
			    warn("main::draw_bridge is not defined, cannot draw bridges.\n");
			    has_draw_bridge = 0;
			  }
			}
			if (has_draw_bridge) {
			  PUSHMARK(sp);
			  XPUSHs(sv_2mortal(newRV_inc((SV*)coords)));
			  XPUSHs(width_sv);
			  XPUSHs(sv_2mortal(newSViv(width+4)));
			  XPUSHs(tags_sv);
			  XPUSHs(sv_2mortal(newRV_inc((SV*)tags)));

			  PUTBACK;
			  call_pv("main::draw_bridge", G_DISCARD|G_VOID);
			  SPAGAIN;
			}
		      } else if (strcmp(cat_attrib, "Tu") == 0) {
			if (has_draw_tunnel_entrance == -1) {
			  CV* sub = get_cv("main::draw_tunnel_entrance", 0);
			  if (sub) {
			    has_draw_tunnel_entrance = 1;
			  } else {
			    warn("main::draw_tunnel_entrance is not defined, cannot draw tunnel_entrances.\n");
			    has_draw_tunnel_entrance = 0;
			  }
			}
			if (has_draw_tunnel_entrance) {
			  PUSHMARK(sp);
			  XPUSHs(sv_2mortal(newRV_inc((SV*)coords)));
			  XPUSHs(width_sv);
			  XPUSHs(sv_2mortal(newSViv(width+4)));
			  XPUSHs(tags_sv);
			  XPUSHs(sv_2mortal(newRV_inc((SV*)tags)));
			  XPUSHs(mounds_sv);
			  XPUSHs(sv_2mortal(newSVpv(cat_attrib, 0)));

			  PUTBACK;
			  call_pv("main::draw_tunnel_entrance", G_DISCARD|G_VOID);
			  SPAGAIN;
			}
		      }
		    }

		    av_undef(coords);
		    SvREFCNT_dec(coords);
		  }
		  count++;
		} else {
		  warn("Line %d of file %s is incomplete (SPACE character after category expected)\n", count+1, file ? file : "<data>");
		}
	      } else {
		warn("Line %d of file %s is incomplete (TAB character expected)\n", count+1, file ? file : "<data>");
	      }

	      if (count % 150 == 0 && SvTRUE(progress)) {
		PUSHMARK(sp) ;
		XPUSHs(progress);
		if (file_size > 0) {
		  SV* frac = sv_2mortal(newSVnv((double)file_count/total_file_count + (double)currpos/(total_file_count*file_size)));
		  XPUSHs(frac);
		  PUTBACK;
		  perl_call_method("Update", G_DISCARD);
		} else {
		  PUTBACK;
		  perl_call_method("UpdateFloat", G_DISCARD);
		}
		SPAGAIN; /* XXX benötigt? */
	      }
	    }
	  }

	  if (f) 
	    fclose(f);

	  file_count++;
	  if (!fileref_array) break;
	  if (av_len(fileref_array) < file_count) break;

	}

	SvREFCNT_dec(tags_sv);
	SvREFCNT_dec(fill_sv);
	SvREFCNT_dec(joinstyle_sv);
	SvREFCNT_dec(bevel_sv);
	SvREFCNT_dec(width_sv);
	SvREFCNT_dec(mounds_sv);

	av_undef(tags);
	av_undef(outline_tags);
	if (!sv_sv_outline_color)
	  SvREFCNT_dec(sv_outline_color);
	if (restr_array) safefree(restr_array);
	if (restr_array_strings) safefree(restr_array_strings);
	if (ignore_array) safefree(ignore_array);
	if (ignore_array_strings) safefree(ignore_array_strings);
	/* Stacking der Canvas-Items muß mit restack() korrigiert werden */


void
fast_plot_point(canvas, abk, fileref, progress)
	SV *canvas;
	char *abk;
	SV *fileref;
	SV *progress;

	PREINIT:
	FILE *f;
	char buf[MAXBUF];
	char abkcat[24];
	struct {
	  int x, y;
	} point;
	AV* tags;
	SV *andreaskreuz, *ampel, *ampelf, *zugbruecke;
	char *file;
	int file_count = 0;
	int total_file_count;
	long currpos;
	int do_utf8_decoding = 0;
	AV* fileref_array = NULL;
	int count = 0;
	SV *tags_sv, *image_sv;

	PPCODE:
 /* muß noch zur Serienreife verfeinert werden ... scheint aber *wesentlich*
   schneller als der perl-Part zu sein?! */

	tags = newAV();
	strcpy(abkcat, abk);
	strcat(abkcat, "-fg");
	av_push(tags, newSVpv(abkcat, 0));
#ifdef LOAD_AMPEL_IMAGE
	LOAD_AMPEL_IMAGE("lsa-B", andreaskreuz);
	LOAD_AMPEL_IMAGE("lsa-X", ampel);
	LOAD_AMPEL_IMAGE("lsa-F", ampelf);
	LOAD_AMPEL_IMAGE("lsa-Zbr", zugbruecke);
#else
	andreaskreuz = perl_get_sv("main::andreaskr_klein_photo", 0);
	ampel        = perl_get_sv("main::ampel_klein_photo", 0);
	ampelf       = perl_get_sv("main::ampelf_klein_photo", 0);
	zugbruecke   = perl_get_sv("main::zugbruecke_klein_photo", 0);
#endif
	if (!andreaskreuz) croak("Can't get andreaskr_klein_photo\n");
	if (!ampel) croak("Can't get ampel_klein_photo\n");
	if (!ampelf) croak("Can't get ampelf_klein_photo\n");
	if (!zugbruecke) croak("Can't get zugbruecke_klein_photo\n");

	if (SvROK(fileref) && SvTYPE(SvRV(fileref)) == SVt_PVAV) {
	  fileref_array = (AV*)SvRV(fileref);
	  total_file_count = av_len(fileref_array)+1;
	} else {
	  total_file_count = 1;
	}

	tags_sv = newSVpv("-tags", 0);
	image_sv = newSVpv("-image", 0);

	while(1) {
	  long file_size = -1;
	  if (fileref_array) {
	    SV **s = av_fetch(fileref_array, file_count, 0);
	    file = SvPV(*s, PL_na);
	  } else
	    file = SvPV(fileref, PL_na);

	  f = fopen(file, "r");
	  if (!f) croak("Can't open %s: %s in fast_plot_point\n", file, strerror(errno));
#ifdef MYDEBUG
	  fprintf(stderr, "Reading from <%s>\n", file);
#endif
	  if (fseek(f, 0, SEEK_END) == 0) {
	    file_size = ftell(f);
	    fseek(f, 0, SEEK_SET);
	  } else {
	    warn("Cannot fseek file '%s'?", file);
	    file_size = -1;
	  }
	  currpos = 0;

	  while(!feof(f)) {
	    if (fgets(buf, MAXBUF, f) == NULL)
	      break;
	    currpos += strlen(buf);
#ifdef MYDEBUG
	    /* fprintf(stderr, "%s", buf); */
#endif
	    if (buf[0] == '#') {
	      check_utf8_encoding(buf, &do_utf8_decoding);
	    } else {
	      char* p = strchr(buf, '\t');
	      if (p) {
		SV* pointnameSV;
		char* pointname = buf;
		char* cat;
		*p = 0;
		cat = p+1;
		if (*cat != 'B' && *cat != 'X' && *cat != 'Z' /* br */ && *cat != 'F'
		) *cat = 'X';
		p = strchr(p+1, ' ');
		if (p) {
		  char *new_p;
		  *p = 0;
		  if (!*(++p)) break;
		  new_p = strchr(p, ',');
		  if (new_p) {
		    point.x = atoi(p);
		    p = new_p + 1;
		    point.y = atoi(p);
#ifdef MYDEBUG
		    fprintf(stderr, "%d: %d/%d\n", count, point.x, point.y);
#endif
		  }

		  sprintf(abkcat, "%d,%d", point.x, point.y);
		  av_store(tags, 1, newSVpv(abkcat, 0));
		  pointnameSV = newSVpv(pointname, 0);
		  if (do_utf8_decoding) {
		    if (is_utf8_string(buf, 0)) {
		      SvUTF8_on(pointnameSV);
		    } else {
		      warn("'%s' does not look like an utf-8 string", SvPV(pointnameSV, PL_na));
		    }
		  }
		  av_store(tags, 2, pointnameSV);
		  strcpy(abkcat, abk);
		  strcat(abkcat, "-");
		  strcat(abkcat, cat);
		  strcat(abkcat, "-fg");
		  av_store(tags, 3, newSVpv(abkcat, 0));
		  sprintf(abkcat, "%s-%d", abk, count);
		  av_store(tags, 4, newSVpv(abkcat, 0));

		  PUSHMARK(sp);
		  XPUSHs(canvas);
		  XPUSHs(sv_2mortal(TRANSPOSE_X_SCALAR(point.x)));
		  XPUSHs(sv_2mortal(TRANSPOSE_Y_SCALAR(point.y)));
		  XPUSHs(tags_sv);
		  XPUSHs(sv_2mortal(newRV_inc((SV*)tags)));
		  XPUSHs(image_sv);
		  switch (*cat) {
		  case 'B':
		    XPUSHs(andreaskreuz);
		    break;
		  case 'Z':
		    /* Zbr */
		    XPUSHs(zugbruecke);
		    break;
		  case 'F':
		    XPUSHs(ampelf);
		    break;
		  default:
		    XPUSHs(ampel);
		  }

		  PUTBACK;
		  perl_call_method("createImage", G_DISCARD|G_VOID);
		  SPAGAIN;

		  count++;
		}
	      }

	      if (count % 150 == 0 && SvTRUE(progress)) {
		PUSHMARK(sp) ;
		XPUSHs(progress);
		if (file_size > 0) {
		  SV* frac = sv_2mortal(newSVnv((double)file_count/total_file_count + (double)currpos/(total_file_count*file_size)));
		  XPUSHs(frac);
		  PUTBACK;
		  perl_call_method("Update", G_DISCARD);
		} else {
		  PUTBACK;
		  perl_call_method("UpdateFloat", G_DISCARD);
		}
		SPAGAIN;
	      }

	    }
	  }
	  fclose(f);

	  file_count++;
	  if (!fileref_array) break;
	  if (av_len(fileref_array) < file_count) break;
	}

	SvREFCNT_dec(tags_sv);
	SvREFCNT_dec(image_sv);
#ifdef LOAD_AMPEL_IMAGE
	SvREFCNT_dec(ampel);
	SvREFCNT_dec(ampelf);
	SvREFCNT_dec(andreaskreuz);
	SvREFCNT_dec(zugbruecke);
#endif

	av_undef(tags);

BOOT:
#if defined(INT_SQRT) || defined(MAYBE_INT_SQRT)
	set_eyal();
#endif
#ifdef MYDEBUG
	{
	  /* XXX
	   * This piece of code is to check the consistency of the
	   * values for macros X_DELTA etc. and the
	   * perl variables in the main code. This is disabled for
	   * now, because
	   * 1) there are no $x_delta ... vars in the
	   *    main bbbike program (yet, maybe when expanding to
	   *    other cities)
	   * 2) bbbike.cgi uses BBBikeXS too, but makes no
	   *    use of the transpose function, so the
	   *    warning would be redundant (maybe it's better to
	   *    seperate the transpose and drawing functions
	   *    and the Strassen/StrassenNetz methods)
	   */
	  SV *x_delta, *y_delta, *x_mount, *y_mount;

	  x_delta = perl_get_sv("main::x_delta", FALSE);
	  if (!x_delta)
	    warn("x_delta not defined");
	  else if (SvNV(x_delta) != X_DELTA)
	    warn("x_delta value does not match");

	  y_delta = perl_get_sv("main::y_delta", FALSE);
	  if (!y_delta)
	    warn("y_delta not defined");
	  else if (SvNV(y_delta) != Y_DELTA)
	    warn("y_delta value does not match");

	  x_mount = perl_get_sv("main::x_mount", FALSE);
	  if (!x_mount)
	    warn("x_mount not defined");
	  else if (SvNV(x_mount) != X_MOUNT)
	    warn("x_mount value does not match");

	  y_mount = perl_get_sv("main::y_mount", FALSE);
	  if (!y_mount)
	    warn("y_mount not defined");
	  else if (SvNV(y_mount) != Y_MOUNT)
	    warn("y_mount value does not match");

	}
#endif
