/* A multi-file program for the new aarch64 MesCC backend: it is compiled
   separately and linked against libc-aarch64.c (a small libc the backend also
   compiled). Demonstrates real separate compilation + a libc with puts / strcmp
   / putint — the shape every nontrivial bootstrap program takes. */
int puts(char *s);
int strcmp(char *a, char *b);
void putint(int n);
void putchar(int c);

int main()
{
	int i;
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
	return 0;
}
