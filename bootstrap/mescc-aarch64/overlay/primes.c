/* A non-trivial program for the new aarch64 MesCC backend: print every prime
   below 40, space-separated. Exercises void functions, char arrays, digit
   arithmetic (48 + n%10), division/modulo, nested calls, address-of an array
   element (&buf[i]), and pointer arguments — all compiled to native aarch64. */
int write(int fd, char *buf, int n);

void print_int(int n)
{
	char buf[16];
	int i;
	i = 16;
	if (n == 0) {
		i = i - 1;
		buf[i] = 48;            /* '0' */
	} else {
		while (n > 0) {
			i = i - 1;
			buf[i] = 48 + n % 10;
			n = n / 10;
		}
	}
	write(1, &buf[i], 16 - i);
}

int is_prime(int n)
{
	int d;
	if (n < 2)
		return 0;
	d = 2;
	while (d * d <= n) {
		if (n % d == 0)
			return 0;
		d = d + 1;
	}
	return 1;
}

int main()
{
	int i;
	for (i = 2; i < 40; i = i + 1) {
		if (is_prime(i)) {
			print_int(i);
			write(1, " ", 1);
		}
	}
	write(1, "\n", 1);
	return 0;
}
