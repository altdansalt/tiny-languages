/* A multi-file program for the new aarch64 MesCC backend: it is compiled
   separately and linked against libc-aarch64.c (a small libc the backend also
   compiled). Demonstrates real separate compilation + a libc with puts / strcmp
   / putint — the shape every nontrivial bootstrap program takes. */
int puts(char *s);
int strcmp(char *a, char *b);
void putint(int n);
void putchar(int c);
void *malloc(int n);

int main()
{
	int i;
	int s;
	int *a;
	puts("libc-aarch64 online (separate compilation + linked libc):");

	if (strcmp("mescc", "mescc") == 0)
		puts("  strcmp equal     -> ok");
	if (strcmp("abc", "abd") < 0)
		puts("  strcmp ordering  -> ok");

	puts("  squares 1..6:");
	for (i = 1; i <= 6; i = i + 1) {
		putchar(32);
		putchar(32);
		putint(i * i);
	}
	putchar(10);

	/* dynamic memory: malloc an array, fill it, sum it */
	a = (int *) malloc(10 * 4);
	for (i = 0; i < 10; i = i + 1)
		a[i] = (i + 1) * (i + 1);
	s = 0;
	for (i = 0; i < 10; i = i + 1)
		s = s + a[i];
	puts("  malloc'd sum of squares 1..10:");
	putchar(32);
	putchar(32);
	putint(s);
	putchar(10);
	return 0;
}
