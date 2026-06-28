#!/bin/sh
# What can cproc compile? An EXPECTATION- encoded capability matrix.
#
# Each test records the documented expected result; the probe fails (nonzero exit)
# if cproc's actual behavior deviates — so this doubles as a regression gate on the
# claims in BOOTSTRAP.md. PASS = cproc compiles it AND the program runs (exit 0).
# FAIL = cproc or its qbe backend rejects it. The interesting content is the set of
# FAILs: they are exactly cproc+QBE's current limits.
set -u
mism=0
report() {  # name  got  expect  [reason]
  if [ "$2" = "$3" ]; then s=ok; else s=MISMATCH; mism=$((mism + 1)); fi
  printf '  %-36s %-4s (want %-4s) [%s] %s\n' "$1" "$2" "$3" "$s" "${4:-}"
}
run() {     # name  expect ; C source on stdin
  name="$1"; expect="$2"; cat > /tmp/s.c
  if cproc -o /tmp/s /tmp/s.c -lm >/tmp/e 2>&1 && /tmp/s >/tmp/o 2>&1; then
    got=PASS; r=""
  else
    got=FAIL; r=$(head -1 /tmp/e | cut -c1-52)
  fi
  report "$name" "$got" "$expect" "$r"
}

echo "=== Standard C / C11 (expected to work) ==="
run "printf / stdio" PASS <<'EOF'
#include <stdio.h>
int main(){ printf("hi\n"); return 0; }
EOF
run "_Generic" PASS <<'EOF'
#include <stdio.h>
#define T(x) _Generic((x), int:"i", double:"d", char*:"s", default:"?")
int main(){ printf("%s%s%s\n", T(1), T(1.0), T("x")); return 0; }
EOF
run "_Static_assert" PASS <<'EOF'
_Static_assert(sizeof(long) >= 4, "long too small");
int main(){ return 0; }
EOF
run "compound literal + designated init" PASS <<'EOF'
struct P{int x,y;};
int main(){ struct P p=(struct P){.y=2,.x=1}; int a[5]={[3]=9}; return p.x+a[3]-10; }
EOF
run "varargs (stdarg)" PASS <<'EOF'
#include <stdarg.h>
int sum(int n,...){int s=0;va_list a;va_start(a,n);while(n--)s+=va_arg(a,int);va_end(a);return s;}
int main(){ return sum(3,10,20,12)-42; }
EOF
run "VLA (variable-length array)" PASS <<'EOF'
int f(int n){ int v[n]; for(int i=0;i<n;i++) v[i]=i; return v[n-1]; }
int main(){ return f(5)-4; }
EOF
run "bitfields" PASS <<'EOF'
struct F{unsigned a:3,b:5,c:8;};
int main(){ struct F f={.a=5,.b=17,.c=200}; return (f.a+f.b+f.c)-222; }
EOF
run "long long / 64-bit arithmetic" PASS <<'EOF'
#include <stdint.h>
int main(){ uint64_t x=0xdeadbeefULL*0x1000+7; return (int)(x & 0xff)-7; }
EOF
run "double arithmetic + printf %f" PASS <<'EOF'
#include <stdio.h>
int main(){ double d=0.1+0.2; printf("%.3f\n", d); return (d>0.29&&d<0.31)?0:1; }
EOF
run "libm via own prototype (sqrt)" PASS <<'EOF'
extern double sqrt(double);
int main(){ return sqrt(4.0)==2.0 ? 0 : 1; }
EOF
run "setjmp / longjmp" PASS <<'EOF'
#include <setjmp.h>
jmp_buf b; int main(){ if(setjmp(b)) return 0; longjmp(b,1); return 2; }
EOF

echo
echo "=== Current limits (expected to FAIL) ==="
run "long double (QBE has no long double)" FAIL <<'EOF'
int main(){ long double x=1.0L/3.0L; return (x>0.33L)?0:1; }
EOF
run "#include <math.h> (musl forces ldbl)" FAIL <<'EOF'
#include <math.h>
int main(){ return 0; }
EOF
run "isnan() macro (pulls in long double)" FAIL <<'EOF'
#include <math.h>
int main(){ double d=1.0; return isnan(d)?1:0; }
EOF
run "_Atomic / <stdatomic.h>" FAIL <<'EOF'
#include <stdatomic.h>
int main(){ atomic_int x=0; atomic_fetch_add(&x,5); return atomic_load(&x)-5; }
EOF
run "GNU inline asm" FAIL <<'EOF'
int main(){ int x=42,r; __asm__("mov %1,%0":"=r"(r):"r"(x)); return r-42; }
EOF
run "computed goto (GNU ext)" FAIL <<'EOF'
int main(){ void *t[]={&&a,&&b}; goto *t[1]; a: return 1; b: return 0; }
EOF
run "statement expression (GNU ext)" FAIL <<'EOF'
int main(){ int n=({int z=20; z+22;}); return n-42; }
EOF

echo
echo "=== Real programs (clone + compile with cproc) ==="
rp_skip() { printf '  %-36s %-4s [skip] %s\n' "$1" "----" "$2"; }

if git clone --depth 1 -q https://github.com/rxi/fe /tmp/fe 2>/dev/null; then
  cproc -I/tmp/fe/src -c /tmp/fe/src/fe.c -o /tmp/fe.o >/tmp/e 2>&1 && g=PASS || g=FAIL
  report "fe (rxi) — single-file Lisp" "$g" PASS "$([ "$g" = FAIL ] && head -1 /tmp/e|cut -c1-40)"
else rp_skip "fe (rxi)" "clone failed"; fi

if git clone --depth 1 -q https://github.com/adamdunkels/ubasic /tmp/ub 2>/dev/null; then
  cproc -c /tmp/ub/ubasic.c -o /tmp/u1.o >/tmp/e 2>&1 \
    && cproc -c /tmp/ub/tokenizer.c -o /tmp/u2.o >/tmp/e2 2>&1 && g=PASS || g=FAIL
  report "ubasic — tiny BASIC" "$g" PASS "$([ "$g" = FAIL ] && head -1 /tmp/e|cut -c1-40)"
else rp_skip "ubasic" "clone failed"; fi

if git clone --depth 1 -q https://github.com/lua/lua /tmp/lua 2>/dev/null; then
  g=PASS; why=""
  for f in /tmp/lua/*.c; do
    case "$(basename "$f")" in lua.c|luac.c) continue ;; esac
    cproc -c -DLUA_USE_POSIX "$f" -o /tmp/l.o >/tmp/e 2>&1 \
      || { g=FAIL; why="$(basename "$f"): $(head -1 /tmp/e|cut -c1-34)"; break; }
  done
  report "lua — full interpreter" "$g" FAIL "$why"
else rp_skip "lua" "clone failed"; fi

echo
echo "Legend: cproc is a near-complete C11 front end (QBE backend -> arm64/amd64/"
echo "riscv64). It self-hosts and builds clean standard-C codebases (fe, ubasic, qbe,"
echo "itself). It does NOT yet do long double — so on musl, including <math.h> alone"
echo "fails, which is why lua doesn't build — nor GNU extensions (inline asm, computed"
echo "goto, statement expressions) or <stdatomic.h>."
echo
echo "=== $mism mismatch(es) vs documented expectations ==="
[ "$mism" -eq 0 ]
