#ifdef __cplusplus
extern "C" {
#endif
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#ifdef __cplusplus
}
#endif

#include <sys/types.h>
#include <sys/mman.h>
#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>

#if PERL_REVISION > 5 || (PERL_REVISION == 5 && (PERL_VERSION > 5 || (PERL_VERSION == 5 && (PERL_SUBVERSION > 57))))
# define MODERN_PERL
#endif

#if INTSIZE != 4
# error Works only with INTSIZE=4
#endif

#if !defined(PL_na) && !defined(MODERN_PERL)
# define PL_na na
#endif
#if !defined(PL_sv_undef) && !defined(MODERN_PERL)
# define PL_sv_undef sv_undef
#endif

#define VAR_LEN 1
#define FREEZED 2

struct VirtArray {
  caddr_t filebuf;
  long filebuflen;
  int fd;
  I32 is_var_len;
  I32 freezed;
  I32 len;
  I32 reclen;
  caddr_t start_data;
};
typedef struct VirtArray* VirtArray;

#define MAGIC_LEN 8
#define HEADER_LEN_VAR	 (MAGIC_LEN+sizeof(I32)*2)
#define HEADER_LEN_FIXED (MAGIC_LEN+sizeof(I32)*3)

#ifndef MAP_FAILED
#define MAP_FAILED ((caddr_t)-1)
#endif

static VirtArray dflt_array = NULL;

/* schnelles FETCH: keine Übergabe des Objekts (siehe set_default) */
XS(XS_VirtArray_fast_fetch)
{
    dXSARGS;
    if (items != 1)
        croak("Usage: VirtArray::fast_fetch(i)");
    {
        long    i = (long)SvIV(ST(0));
        SV *    RETVAL;

        if (!dflt_array->is_var_len) {
            RETVAL = newSVpv((char*)(dflt_array->start_data+i*dflt_array->reclen),
                                     dflt_array->reclen);
        } else {
            long i0 = (long)*(I32*)(dflt_array->filebuf+HEADER_LEN_VAR+i*sizeof(I32));
            long i1 = (long)*(I32*)(dflt_array->filebuf+HEADER_LEN_VAR+(i+1)*sizeof(I32));
            RETVAL = newSVpv((char*)(dflt_array->start_data+i0), i1-i0);
        }
        ST(0) = RETVAL;
        if (SvREFCNT(ST(0))) sv_2mortal(ST(0));
    }
    XSRETURN(1);
}

XS(XS_VirtArray_fast_fetch_var)
{
    dXSARGS;
    if (items != 1)
        croak("Usage: VirtArray::fast_fetch_var(i)");
    {
        long    i = (long)SvIV(ST(0));

        long i0 = (long)*(I32*)(dflt_array->filebuf+HEADER_LEN_VAR+i*sizeof(I32));
        long i1 = (long)*(I32*)(dflt_array->filebuf+HEADER_LEN_VAR+(i+1)*sizeof(I32));
        ST(0) = newSVpv((char*)(dflt_array->start_data+i0), i1-i0);
        if (SvREFCNT(ST(0))) sv_2mortal(ST(0));
    }
    XSRETURN(1);
}

XS(XS_VirtArray_fast_fetch_fixed)
{
    dXSARGS;
    if (items != 1)
        croak("Usage: VirtArray::fast_fetch_fixed(i)");
    {
        long    i = (long)SvIV(ST(0));

        ST(0) = newSVpv((char*)(dflt_array->start_data+i*dflt_array->reclen),
                                dflt_array->reclen);
        if (SvREFCNT(ST(0))) sv_2mortal(ST(0));
    }
    XSRETURN(1);
}

MODULE = VirtArray		PACKAGE = VirtArray		

VirtArray
TIEARRAY(package, filename)
	char* package;
	char* filename;
    PREINIT:
	SV* ref;
	SV* magic;
	I32 flags;
    CODE:
	RETVAL = safemalloc(sizeof(struct VirtArray));
	if (RETVAL == NULL)
	    croak("Can't alloc memory for VirtArray");
	RETVAL->filebuf = MAP_FAILED;
	if ((RETVAL->fd = open(filename, O_RDONLY)) < 0)
	    croak("Can't open %s: %s", filename, strerror(errno));
	RETVAL->filebuflen = lseek(RETVAL->fd, 0, SEEK_END);
	if ((RETVAL->filebuf = mmap(0, RETVAL->filebuflen, PROT_READ, MAP_SHARED, RETVAL->fd, 0)) == MAP_FAILED)
	    croak("Can't mmap %s: %s", filename, strerror(errno));

	/* check for magic number */
	magic = newSVsv(perl_get_sv("VirtArray::magic", TRUE));
        sv_catsv(magic, perl_get_sv("VirtArray::formatversion", TRUE));
	if (strncmp(SvPV(magic, PL_na), RETVAL->filebuf, MAGIC_LEN) != 0)
            croak("Got wrong magic number in %s", filename);
	SvREFCNT_dec(magic);

	flags = *(I32*)(RETVAL->filebuf+MAGIC_LEN);
	RETVAL->is_var_len = flags & VAR_LEN;
	RETVAL->freezed = flags & FREEZED;
        if (RETVAL->freezed) {
	    perl_require_pv("Storable.pm");
	}

	RETVAL->len = *(I32*)(RETVAL->filebuf+MAGIC_LEN+sizeof(I32));
	if (!RETVAL->is_var_len) {
	    RETVAL->reclen = *(I32*)(RETVAL->filebuf+MAGIC_LEN+sizeof(I32)*2);
	    RETVAL->start_data = RETVAL->filebuf + HEADER_LEN_FIXED;
	} else
	    RETVAL->start_data = RETVAL->filebuf + HEADER_LEN_VAR + (RETVAL->len+1)*sizeof(I32);

        if (SvTRUE(perl_get_sv("VirtArray::VERBOSE", FALSE)))
	  fprintf(stderr, "File %s is `mmap'ed and contains %s%s data\n",
		  filename,
		  (RETVAL->is_var_len ? "variable" : "fixed"),
		  (RETVAL->freezed ? " complex" : "")
		  );

	ref = newSViv((long)RETVAL);
	/* XXX del: ST(0) = sv_2mortal(newRV_inc(ref)); */
	ST(0) = sv_2mortal(newRV_noinc(ref));
	sv_bless(ST(0), gv_stashpv(package, TRUE));

SV*
FETCH(self, i)
	VirtArray self;
	long i;
    CODE:
	if (!self->is_var_len) {
	    RETVAL = newSVpv((char*)(self->start_data+i*self->reclen),
				     self->reclen);
	} else {
	    SV* tmp;
	    long i0 = (long)*(I32*)(self->filebuf+HEADER_LEN_VAR+i*sizeof(I32));
	    long i1 = (long)*(I32*)(self->filebuf+HEADER_LEN_VAR+(i+1)*sizeof(I32));
	    tmp = newSVpv((char*)(self->start_data+i0), i1-i0);
	    if (self->freezed) {
	        dSP;
	        int count;
		ENTER;
		SAVETMPS;

		PUSHMARK(SP);
		XPUSHs(tmp);
		PUTBACK;

	        count = perl_call_pv("Storable::thaw", G_SCALAR);
		SPAGAIN;

		SvREFCNT_dec(tmp);

		tmp = newSVsv(POPs);
		PUTBACK ;
		FREETMPS ;
		LEAVE ;
	    }
	    RETVAL = tmp;
	}
    OUTPUT:
	RETVAL

void
DESTROY(self)
	VirtArray self;
    CODE:
	if (self->filebuf != MAP_FAILED)
	    if (munmap(self->filebuf, self->filebuflen) != 0)
		croak("Can't free mmap region: %s", strerror(errno));
	if (self->fd >= 0)
	    close(self->fd);
	safefree(self);

int
FETCHSIZE(self)
	VirtArray self;
    CODE:
	/* STORESIZE? */
	RETVAL = self->len;
    OUTPUT:
	RETVAL

void
printinfo(self)
	VirtArray self;
    CODE:
	printf("Filebuf address: %p\n",  self->filebuf);
	printf("Filebuf len:     %ld\n", self->filebuflen);
	printf("File descriptor: %d\n",  self->fd);
	printf("Variable length: %s\n",  (self->is_var_len ? "yes" : "no"));
	printf("Freezed:         %s\n",  (self->freezed    ? "yes" : "no"));
	printf("Length:          %ld\n",  self->len);
	printf("Record length:   %ld\n",  self->reclen);

void
fetch_list_var(self, i)
	VirtArray self;
	long i;
    PREINIT:
/* nur für Arrays mit variabler Länge
 * gibt eine Liste von Integern zurück
 * XXX funktioniert nicht für freezed Dateien
 */
	char *data;
	long i0, i1, len;
	int ii;
    PPCODE:
	i0 = (long)*(I32*)(self->filebuf+HEADER_LEN_VAR+i*sizeof(I32));
	i1 = (long)*(I32*)(self->filebuf+HEADER_LEN_VAR+(i+1)*sizeof(I32));
	data = (char*)(self->start_data+i0);
	len  = (i1-i0)/sizeof(I32);
	EXTEND(sp, len);
	for(ii = 0; ii < len; ii++)
	    PUSHs(sv_2mortal(newSViv((long)*(I32*)(data+sizeof(I32)*ii))));

void
fetch_list_fixed(self, i)
	VirtArray self;
	long i;
    PREINIT:
/* nur für Arrays mit fixer Länge
 * gibt eine Liste von Integern zurück
 */
	long len;
	int ii;
    PPCODE:
	len  = self->reclen/sizeof(I32);
	EXTEND(sp, len);
	for(ii = 0; ii < len; ii++)
	    PUSHs(sv_2mortal(newSViv((long)*(I32*)(self->start_data+i*self->reclen+ii))));

void
set_default(self)
	VirtArray self;
    CODE:
/* set_default setzt das Objekt für fast_fetch fest */
	dflt_array = self;

BOOT:
newXS("VirtArray::fast_fetch", XS_VirtArray_fast_fetch, file);
newXS("VirtArray::fast_fetch_var", XS_VirtArray_fast_fetch_var, file);
newXS("VirtArray::fast_fetch_fixed", XS_VirtArray_fast_fetch_fixed, file);

