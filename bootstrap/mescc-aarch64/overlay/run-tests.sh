#!/bin/sh
# Compile a set of C programs with the new aarch64 MesCC backend, link each
# through the M2libc aarch64 stack, run it, and assert its exit code. The build
# gates on this (any mismatch -> nonzero exit), so it doubles as a regression test
# of what the backend can compile.
set -u
cd /b/mes
fail=0
check() {
  prog="$1"; expect="$2"
  rm -f /b/main.elf
  printf '%s\n' "$prog" > /b/main.c
  guile -L module -L /opt/nyacc/module -L . /b/drive.scm --arch=aarch64 -S /b/main.c -o /b/main.s >/b/c.log 2>&1 \
    && M1 --architecture aarch64 --little-endian -f /b/defs.M1 -f /b/crt1.M1 -f /b/main.s -o /b/code.hex2 >>/b/c.log 2>&1 \
    && hex2 --architecture aarch64 --little-endian --base-address 0x00400000 \
         -f /b/header.hex2 -f /b/code.hex2 -f /b/footer.hex2 -o /b/main.elf >>/b/c.log 2>&1
  if [ ! -x /b/main.elf ] || ! head -c4 /b/main.elf | grep -qa ELF; then
    printf '  %-34s build-FAIL\n' "$prog"; fail=1; tail -2 /b/c.log | sed 's/^/      /'; rm -f /b/main.elf; return
  fi
  /b/main.elf; rc=$?
  if [ "$rc" -eq "$expect" ]; then printf '  %-34s -> %-3s  ok\n' "$prog" "$rc"
  else printf '  %-34s -> %-3s  MISMATCH (want %s)\n' "$prog" "$rc" "$expect"; fail=1; fi
}
echo "=== MesCC-aarch64: compile + run C programs natively on aarch64 ==="
check 'int main(){return 42;}'            42
check 'int main(){return 2+3*4;}'         14
check 'int main(){return (10-4)*2;}'      12
check 'int main(){return 7*6;}'           42
check 'int main(){return 1+2+3+4+5;}'     15
check 'int main(){return 100-58;}'        42
check 'int main(){return 2*3*7;}'         42
# --- Milestone 2b: comparisons, conditional branches, loops ---
check 'int main(){int i;i=0;while(i<10){i=i+1;}return i;}'              10
check 'int main(){int s;int i;s=0;i=1;while(i<=5){s=s+i;i=i+1;}return s;}' 15
check 'int main(){int i;i=0;if(i<3){i=7;}return i;}'                    7
check 'int main(){int i;i=9;if(i<3){i=7;}return i;}'                    9
check 'int main(){int n;int f;n=5;f=1;while(n>1){f=f*n;n=n-1;}return f;}' 120
# --- Milestone 3: functions, arguments, recursion ---
check 'int f(int a,int b){return a+b;} int main(){return f(40,2);}'      42
check 'int sq(int x){return x*x;} int main(){return sq(7);}'            49
check 'int add3(int a,int b,int c){return a+b+c;} int main(){return add3(10,20,12);}' 42
check 'int fact(int n){if(n<2){return 1;}return n*fact(n-1);}int main(){return fact(5);}' 120
check 'int fib(int n){if(n<2){return n;}return fib(n-1)+fib(n-2);}int main(){return fib(10);}' 55
echo "=== $([ $fail -eq 0 ] && echo 'ALL PASS' || echo 'SOME FAILED') ==="
[ $fail -eq 0 ]
