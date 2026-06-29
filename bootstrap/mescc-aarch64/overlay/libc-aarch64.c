/* A small libc for the new aarch64 MesCC backend — written in C and compiled by
   the backend itself, in the same style as GNU Mes's own libc (per-arch syscall
   stubs using asm() with raw assembler tokens, everything else portable C).
   This is the layer a full Mes-libc aarch64 port rides on; here it carries just
   enough (raw syscalls + a few string/IO routines) to compile real multi-function
   programs against. The asm() macros come from libc-aarch64.M1. */

/* --- syscall layer: marshal args into x8/x0..x5 and SVC -------------------- */
long __sys_call(long n)
{
	asm("LDR_X8_[BP_16]");
	asm("SYSCALL");
}
long __sys_call1(long n, long a)
{
	asm("LDR_X8_[BP_16]");
	asm("LDR_X0_[BP_24]");
	asm("SYSCALL");
}
long __sys_call2(long n, long a, long b)
{
	asm("LDR_X8_[BP_16]");
	asm("LDR_X0_[BP_24]");
	asm("LDR_X1_[BP_32]");
	asm("SYSCALL");
}
long __sys_call3(long n, long a, long b, long c)
{
	asm("LDR_X8_[BP_16]");
	asm("LDR_X0_[BP_24]");
	asm("LDR_X1_[BP_32]");
	asm("LDR_X2_[BP_40]");
	asm("SYSCALL");
}

/* --- Linux aarch64 syscall numbers we use --------------------------------- */
/* read=63 write=64 exit=93 */

int write(int fd, char *buf, int n)
{
	return __sys_call3(64, fd, buf, n);
}

int read(int fd, char *buf, int n)
{
	return __sys_call3(63, fd, buf, n);
}

void exit(int code)
{
	__sys_call1(93, code);
}

/* --- a bump allocator over brk(2) (syscall 214) --------------------------- */
char *g_brk;

char *sbrk(int n)
{
	char *p;
	if (g_brk == 0)
		g_brk = (char *) __sys_call1(214, 0);   /* current break */
	p = g_brk;
	g_brk = g_brk + n;
	__sys_call1(214, (long) g_brk);                 /* extend the break */
	return p;
}

void *malloc(int n)
{
	return sbrk(n);
}

/* --- portable C on top of the syscalls ------------------------------------ */
int strlen(char *s)
{
	int n;
	n = 0;
	while (s[n])
		n = n + 1;
	return n;
}

int strcmp(char *a, char *b)
{
	while (*a && *a == *b) {
		a = a + 1;
		b = b + 1;
	}
	return *a - *b;
}

char *strcpy(char *dst, char *src)
{
	int i;
	i = 0;
	while (src[i]) {
		dst[i] = src[i];
		i = i + 1;
	}
	dst[i] = 0;
	return dst;
}

void putchar(int c)
{
	char b;
	b = c;
	write(1, &b, 1);
}

int puts(char *s)
{
	write(1, s, strlen(s));
	write(1, "\n", 1);
	return 0;
}

/* print a signed integer in decimal (no newline) */
void putint(int n)
{
	char buf[16];
	int i;
	int neg;
	neg = 0;
	if (n < 0) {
		neg = 1;
		n = 0 - n;
	}
	i = 16;
	if (n == 0) {
		i = i - 1;
		buf[i] = 48;
	} else {
		while (n > 0) {
			i = i - 1;
			buf[i] = 48 + n % 10;
			n = n / 10;
		}
	}
	if (neg) {
		i = i - 1;
		buf[i] = 45;        /* '-' */
	}
	write(1, &buf[i], 16 - i);
}
