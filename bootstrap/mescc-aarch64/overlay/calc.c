/* A recursive-descent arithmetic evaluator — a genuine mini-compiler — built by
   the new aarch64 MesCC backend and run natively on this host. It parses and
   evaluates integer expressions with +, -, *, / and parentheses, honoring
   precedence, via mutual recursion (expr -> term -> factor -> expr) over a global
   cursor. Exercises about everything the backend can do at once: mutual recursion,
   global pointer state, char classification, multi-digit parsing, and I/O. */
int write(int fd, char *buf, int n);

char *p;                       /* the parse cursor */
int expr(void);

int number(void)
{
	int n;
	n = 0;
	while (*p >= 48 && *p <= 57) {   /* '0'..'9' */
		n = n * 10 + (*p - 48);
		p = p + 1;
	}
	return n;
}

int factor(void)
{
	int n;
	if (*p == 40) {                  /* '(' */
		p = p + 1;
		n = expr();
		p = p + 1;               /* ')' */
		return n;
	}
	return number();
}

int term(void)
{
	int n;
	n = factor();
	while (*p == 42 || *p == 47) {   /* '*' '/' */
		if (*p == 42) { p = p + 1; n = n * factor(); }
		else          { p = p + 1; n = n / factor(); }
	}
	return n;
}

int expr(void)
{
	int n;
	n = term();
	while (*p == 43 || *p == 45) {   /* '+' '-' */
		if (*p == 43) { p = p + 1; n = n + term(); }
		else          { p = p + 1; n = n - term(); }
	}
	return n;
}

void print_int(int n)
{
	char buf[16];
	int i;
	i = 16;
	if (n == 0) { i = i - 1; buf[i] = 48; }
	else { while (n > 0) { i = i - 1; buf[i] = 48 + n % 10; n = n / 10; } }
	write(1, &buf[i], 16 - i);
}

int eval(char *s)
{
	p = s;
	return expr();
}

int main(void)
{
	print_int(eval("2+3*(4+10)-2"));   /* 42 */
	write(1, "\n", 1);
	print_int(eval("10*10-58"));       /* 42 */
	write(1, "\n", 1);
	print_int(eval("(1+2)*(3+4)"));    /* 21 */
	write(1, "\n", 1);
	return 0;
}
