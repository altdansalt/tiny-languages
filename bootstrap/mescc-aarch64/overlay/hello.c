/* Hello world for the new aarch64 MesCC backend.
   Compiled to native aarch64 by MesCC, linked through the M2libc aarch64 stack
   plus the tiny `write` shim (libc-tiny.M1), and run on this arm64 host. */
int write(int fd, char *buf, int n);

int main()
{
	write(1, "hello, aarch64! (compiled by a brand-new MesCC backend)\n", 56);
	return 0;
}
