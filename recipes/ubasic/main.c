/* Minimal file-running driver for adamdunkels/ubasic (which ships only a
   library + a hardcoded-program demo). Reads a .bas file and runs it. */
#include <stdio.h>
#include <stdlib.h>
#include "ubasic.h"

int main(int argc, char *argv[]) {
  if (argc < 2) {
    fprintf(stderr, "usage: %s <program.bas>\n", argv[0]);
    return 1;
  }
  FILE *f = fopen(argv[1], "rb");
  if (!f) { perror("fopen"); return 1; }
  static char prog[16384];
  size_t n = fread(prog, 1, sizeof(prog) - 1, f);
  prog[n] = '\0';
  fclose(f);

  ubasic_init(prog);
  do {
    ubasic_run();
  } while (!ubasic_finished());
  return 0;
}
