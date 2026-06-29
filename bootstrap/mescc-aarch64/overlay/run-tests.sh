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
# --- Milestone 4: pointers, memory, globals, bitwise, shifts ---
check 'int main(){int x;int *p;x=5;p=&x;*p=42;return x;}'              42
check 'int main(){int a[4];a[0]=10;a[1]=32;return a[0]+a[1];}'         42
check 'int main(){int x;x=12;return x&6;}'                            4
check 'int main(){int x;x=8;return x|2;}'                             10
check 'int main(){int x;x=15;return x^9;}'                            6
check 'int main(){int x;x=3;return x<<4;}'                            48
check 'int main(){int x;x=168;return x>>2;}'                          42
check 'int g;int main(){g=42;return g;}'                              42
check 'int gs[3];int main(){gs[1]=42;return gs[1];}'                  42
check 'char c;int main(){c=65;return c;}'                             65
# --- Milestone 5: division, modulo, for, logical, switch, increment ---
check 'int main(){return 84/2;}'                                       42
check 'int main(){return 85%43;}'                                      42
check 'int main(){int i;int s;s=0;for(i=0;i<=8;i=i+1){s=s+i;}return s;}' 36
check 'int main(){int x;x=5;return !x;}'                                0
check 'int main(){int x;x=0;return !x;}'                                1
check 'int main(){return (3<5)&&(2<4);}'                               1
check 'int main(){return (3>5)||(2<4);}'                               1
check 'int main(){int x;x=40;x+=2;return x;}'                          42
check 'int main(){int x;int y;x=5;y=x++;return x*10+y;}'               65
check 'int main(){int x;x=2;switch(x){case 1:return 1;case 2:return 42;}return 0;}' 42
check 'int main(){int x;x=3;do{x=x+10;}while(x<40);return x;}'         43
check 'char *s;int main(){s="*";return s[0];}'                         42
# --- Milestone 6: strings, byte loops, structs, function pointers ---
check 'int strlen(char*s){int n;n=0;while(s[n])n=n+1;return n;}int main(){return strlen("hello*world");}' 11
check 'int eq(char*a,char*b){while(*a){if(*a!=*b)return 0;a=a+1;b=b+1;}return *b==0;}int main(){return eq("abc","abc")+eq("abc","abd");}' 1
check 'struct P{int x;int y;};int main(){struct P p;struct P *q;q=&p;q->x=42;return p.x;}' 42
check 'int x=7;int main(){return x*6;}'                                 42
check 'int a[3]={10,20,12};int main(){return a[0]+a[1]+a[2];}'          42
check 'int add(int a,int b){return a+b;}int main(){int(*f)(int,int);f=add;return f(40,2);}' 42
check 'struct P{int a;int b;};struct P arr[3];int main(){arr[2].b=42;return arr[2].b;}' 42
check 'int main(){unsigned int a;a=4000000000;if(a>1000000000)return 42;return 0;}' 42
check 'int ack(int m,int n){if(m==0)return n+1;if(n==0)return ack(m-1,1);return ack(m-1,ack(m,n-1));}int main(){return ack(2,3);}' 9
# comparison as a non-leftmost subexpression -> result in x1 (regression: CSET_X1_*)
check 'int main(){int i;int c;c=0;for(i=1;i<=20;i=i+1)c=c+(i%3==0);return c;}' 6
check 'int main(){int x;int y;x=5;y=3;return 36+(x>y)+(x==y)*9+(y<x);}' 38
# --- Milestone 7: heavier C surface (typedef/enum/static/goto/struct sizes) ---
check 'typedef int myint;myint main(){myint x;x=42;return x;}'         42
check 'enum{A,B,C,D};int main(){return C*14;}'                         28
check 'int f(){static int c;c=c+1;return c;}int main(){f();f();return f()*14;}' 42
check 'int main(){int i;i=0;loop:i=i+1;if(i<42)goto loop;return i;}'    42
check 'struct P{int a;int b;int c;};int main(){return sizeof(struct P)+30;}' 42
check 'struct In{int v;};struct Out{struct In i;int w;};int main(){struct Out o;o.i.v=42;return o.i.v;}' 42
check 'int main(){int x;x=5;x=x>3?x<10?42:1:0;return x;}'              42
check 'int main(){int x;x=0x2a;return x;}'                             42
check 'int main(){int a;int b;a=5;b=3;a=a^b;b=a^b;a=a^b;return a*8+b+13;}' 42
echo "=== $([ $fail -eq 0 ] && echo 'ALL PASS' || echo 'SOME FAILED') ==="
[ $fail -eq 0 ]
