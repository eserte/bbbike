/* --------------------------------- sqrt.c --------------------------------- */

/* This is a collection of sqrt(ulong) programs off the net (see later for the
 * original notes). I added my own version, eyal(), which uses the standard
 * iterative approach. eyal0() is the simple one while eyal() uses a table
 * lookup for the initial guess.
 *
 * Some functions were adjusted so that all truncate in the same way.
 *
 * Eyal Lebedinsky	(eyal@ise.canberra.edu.au)
 *
 * Found on: http://samba.anu.edu.au/eyal/samples.html
 *           ftp://samba.anu.edu.au/pub/eyal/samples/sqrt.c
 *
 */

#include "sqrt.h"

#if 0

 These are the results for running the program on a 486DX50 on
msdos(quickC), msdos(C7.00) and Linux(gcc2.2.2). Note that the ftime on
Linux gives 10ms resolution. The table shows time in 1ms units. All
compiles were done with maximum optimization (best speed options).

 The summary line shows what the compiler can contribute (compare qc and c7)
and what the machine capability can do (gcc test done in 32-bit mode).


calling sqrt() 100000 times:

function    gcc     c7      qc     check
                                             
null         60     84     120         0 
null         60     84     120         0 (acid)
rodent      350  2,818   3,165  21032170 
rodent      350  2,921   3,275  74047927 (acid)
grupe       690  3,364   3,681  21032170 
grupe       700  3,516   3,826  74047927 (acid)
dj          980  4,389  19,681  21032170 
dj        1,050  4,582  20,239  74047927 (acid)
thyssen   1,100  4,462  20,282  21032170 
thyssen   1,160  4,643  20,671  74047927 (acid)
kskelm    3,030 14,878  14,625  21032170 
eyal0       700  2,099   2,464  21032170 
eyal0       830  2,696   3,134  74047927 (acid)
eyal        320    555     802  21032170 
eyal        350    625   1,405  74047927 (acid)
         ====== ====== =======
         11,730 51,716 117,490


Original posting:
=================
         
$From comp.sys.ibm.pc.programmer Tue Oct  8 09:16:35 1991
$Newsgroup: comp.sys.ibm.pc.programmer/3360
$Subject: Summary: SQRT(int) algorithm (with profiling)
$From: warwick@cs.uq.oz.au (Warwick Allison)
$Sender: news@cs.uq.oz.au
$Date: 7 Oct 91 01:20:38 GMT
$Message-Id: <4193@uqcspe.cs.uq.oz.au>
$Path: csc.canberra.edu.au!manuel!munnari.oz.au!bunyip.cc.uq.oz.au!uqcspe!cs.uq.oz.au!warwick
$Reply-To: warwick@cs.uq.oz.au
$Followup-To: comp.sys.amiga.programmer
$Lines: 177


Thanks to all those who responded.

Profiles:

 %time  cumsecs  #call  ms/call  name
  52.4     3.16  99999     0.03  _kskelm
  12.1     3.89  99999     0.01  _thyssen
  10.8     4.54  99999     0.01  _grupe
  10.6     5.18  99999     0.01  _dj
   5.3     5.98  99999     0.00  _rodent

All gave the same accuracy except for grupe, which also rounded rather
than truncating.

(I added this to rodent() at slight cost)

Thanks again all,
Warwick
--
  _-_|\       warwick@cs.uq.oz.au
 /     *  <-- Computer Science Department,
 \_.-._/      University of Queensland,
      v       Brisbane, AUSTRALIA.

---------------- code below -----------------
#endif

#if 0
#include <stdio.h>
#include <stdlib.h>

#if 1
/* This is for msdos
*/
#include "tick.h"
#define GET_TIME	(GetLowTickCount()/10L)
#endif

#if 0
/* This is for unix
*/
#include <time.h>
#include <sys/timeb.h>

#define GET_TIME	timer_milli()

static unsigned long
timer_milli (void)
{
	struct timeb	tm;

	ftime (&tm);
	return (tm.time*1000L + tm.millitm);
}
#endif
#endif

#if 0
/*
    This integer sqrt function is about *15* times faster than
    the standard double-precision math function under lattice.
    It was the result of a thread on comp.graphics a while ago.
    I've tested the precise accuracy of it's results up to 600000.
*/

static unsigned long rodent(v)
unsigned long v;
{
    register long t = 1L<<30, r = 0, s;

#define STEP(k) s = t + r; r >>= 1; if (s <= v) { v -= s; r |= t;}

    STEP(15);   t >>= 2;
    STEP(14);   t >>= 2;
    STEP(13);   t >>= 2;
    STEP(12);   t >>= 2;
    STEP(11);   t >>= 2;
    STEP(10);   t >>= 2;
    STEP(9);    t >>= 2;
    STEP(8);    t >>= 2;
    STEP(7);    t >>= 2;
    STEP(6);    t >>= 2;
    STEP(5);    t >>= 2;
    STEP(4);    t >>= 2;
    STEP(3);    t >>= 2;
    STEP(2);    t >>= 2;
    STEP(1);    t >>= 2;
    STEP(0);

/*  if (r<v) return r+1;	add for rounding */

    return r;
}


static unsigned long grupe(x)
unsigned long x;
{
        register unsigned long xr;      /** result register **/
        register unsigned long q2;      /** scan-bit register **/
        register int f;                 /** flag (one bit) **/

        xr = 0;                         /** clear result **/
        q2 = 0x40000000L;               /** higest possible result bit **/
        do
        {
          if((xr + q2) <= x)
          {
            x -= xr + q2;
            f = 1;                      /** set flag **/
          }
          else f = 0;                   /** clear flag **/
          xr >>= 1;
          if(f) xr += q2;               /** test flag **/
        } while(q2 >>= 2);              /** shift twice **/
/*      if(xr < x) return xr +1;         add for rounding */
        return xr;
}


static unsigned long kskelm(val)
unsigned long val;
{
        register unsigned long rt = 0;
        register unsigned long odd = 1;

        while (val >= odd) {
         val -= odd;
         odd += 2;
         rt += 1;
        }
        /* sqrt now contains the square root */
        /* val now contains the remainder */
	return rt;
}

static unsigned long dj(val)
unsigned long val;
{
  unsigned long result = 0;
  unsigned long side = 0;
  unsigned long left = 0;
  int digit = 0;
  int i;
  for (i=0; i<16; i++)
  {
    left = (left << 2) + (val >> 30);
    val <<= 2;
    if (left >= (side<<1) + 1)
    {
      left -= (side<<1)+1;
      side = (side+1)<<1;
      result <<= 1;
      result |= 1;
    }
    else
    {
      side += side;
      result <<= 1;
    }
  }
  return result;
}

static unsigned long thyssen(val)
unsigned long val;
{
  register unsigned long result = 0;
  register unsigned long side = 0;
  register unsigned long left = 0;
  int i;

  for (i=0; i<sizeof(unsigned long)*4; i++) /* once for every other bit */
  {
    left = (left << 2) + (val >> 30);
    val <<= 2;
    if (left >= side*2 + 1)
    {
      left -= side*2+1;
      side = (side+1)*2;
      result <<= 1;
      result |= 1;
    }
    else
    {
      side *= 2;
      result <<= 1;
    }
  }
  return result;
}

#endif

static unsigned long eyal0(x)		/* used for initialization only */
unsigned long x;
{
	register unsigned long	r, t;
	register long		e;

	if (x & 0xffff0000L)
		r = 662 + x / 17916;
	else if (x & 0x0000ff00L)
		r = 3 + x / 70;
	else
		r = 2 + x / 11;

	do {
		t = x / r;
		e = (long)(r - t) / 2;
		r = (r + t) >> 1;
	} while (e);
	return (r);
}

static unsigned int	sqrtab[256+1] = {0};

void
set_eyal ()
{
	int	i;

	for (i = 0; i < 256; ++i)
		sqrtab[i] = eyal0 (i*256L*256L*256L);
	sqrtab[256] = 0xffffU;
}

unsigned long eyal(x)
unsigned long x;
{
	register unsigned int	r, t;
	register int		e;

/* Select the intial guess. Ensure that it is ABOVE the qsrt so that the
 * long/short divide will fit into a short (or else we get a divide
 * overflow).
*/
	if (x >= 0x00010000UL)
		if (x >= 0x01000000UL)
			if (x >= 0xfffe0001UL)
				return (0xffffU);
			else
				r = sqrtab[(x>>24)+1];
		else
			r = sqrtab[(x>>16)+1] >> 4;
	else if ((unsigned int)x >= 0x0100U)
		r = sqrtab[((unsigned int)x>>8)+1] >> 8;
	else
		return (sqrtab[x] >> 12);

/* Iterate until error is zero.
 * It was measured that on randomly large numbers (acid test) we go round
 * the loop on average 2.2 times.
*/
	do {
		t = (unsigned int)(x / r);
		e = (int)(r - t) >> 1;
		r -= e;
	} while (e);

	return (t);
}

#if 0
static unsigned long null(x)
unsigned long x;
{
	return (x);
}

static void
test (func, name, n, acid)
unsigned long (*func) ();
char		*name;
unsigned long	n;
int		acid;
{
	unsigned long	i, x, xx, t, a;

	a = 0L;
	x = acid ? 0xffffffffUL/n : 1L;
	t = GET_TIME;
	for (xx = x, i = 0L; i < n; i++, xx += x)
		a += (*func) (xx);
	t = GET_TIME - t;
	printf ("%-10s %7ld %10ld %s\n", name, t, a, acid ? "(acid)" : "");
	fflush (stdout);
}

#define TEST(f,n,acid) \
	test (f, n, loops, 0);	\
	if (acid) test (f, n, loops, 1)

int
main (argc, argv)
int	argc;
char	*argv[];
{
	long	i, a, t, loops;

	if (argc) {
		loops = atol (argv[1]);
		if (loops <= 0) {
			printf ("bad count\n");
			exit (1);
		}
	} else
		loops = 10000L;

	printf ("calling sqrt() %ld times:\n", loops);

	printf ("\n%-10s %7s %10s\n\n", "function",  "time", "check");

	TEST(null,"null",1);
	TEST(rodent,"rodent",1);
	TEST(grupe,"grupe",1);
	TEST(dj,"dj",1);
	TEST(thyssen,"thyssen",1);
	TEST(kskelm,"kskelm",0);	/* too slow for acid test */
	TEST(eyal0, "eyal0",1);
	set_eyal ();
	TEST(eyal,"eyal",1);

	exit (0);
}
#endif
