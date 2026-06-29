;;; GNU Mes --- aarch64 MesCC backend (NEW — tiny-languages bootstrap project)
;;; Initialize MesCC as an aarch64 compiler.
;;;
;;; This is the missing piece that lets the native-arm64 bootstrap continue past
;;; M2-Planet: a MesCC code-generator backend for aarch64.  It mirrors the riscv64
;;; backend (the other fixed-width 64-bit RISC target) but emits the *whole-
;;; instruction* M1 macros already defined and tested in M2libc's aarch64_defs.M1,
;;; rather than RISC-V-style field macros.

(define-module (mescc aarch64 info)
  #:use-module (mescc info)
  #:use-module (mescc aarch64 as)
  #:export (aarch64-info
            aarch64:registers))

(define (aarch64-info)
  (make <info> #:types aarch64:type-alist #:registers aarch64:registers #:instructions aarch64:instructions))

;; 2-register model: r0=x0, r1=x1 — the working pair M2libc's fixed-register
;; macros are built around (ADD_X0_X1_X0, SUB_X0_X0_X1, MUL_X0_X1_X0, …). MesCC
;; spills deeper subexpressions to the x18 stack (PUSH_X0/POP_X1), so two
;; registers suffice and every ALU op maps to an existing, tested macro.
(define aarch64:registers '("x0" "x1"))

(define aarch64:type-alist
  `(("char" . ,(make-type 'signed 1 #f))
    ("short" . ,(make-type 'signed 2 #f))
    ("int" . ,(make-type 'signed 4 #f))
    ("long" . ,(make-type 'signed 8 #f))
    ("default" . ,(make-type 'signed 4 #f))
    ("*" . ,(make-type 'unsigned 8 #f))
    ("long long" . ,(make-type 'signed 8 #f))
    ("long long int" . ,(make-type 'signed 8 #f))

    ("void" . ,(make-type 'void 1 #f))
    ("signed char" . ,(make-type 'signed 1 #f))
    ("unsigned char" . ,(make-type 'unsigned 1 #f))
    ("unsigned short" . ,(make-type 'unsigned 2 #f))
    ("unsigned" . ,(make-type 'unsigned 4 #f))
    ("unsigned int" . ,(make-type 'unsigned 4 #f))
    ("unsigned long" . ,(make-type 'unsigned 8 #f))
    ("unsigned long long" . ,(make-type 'unsigned 8 #f))
    ("unsigned long long int" . ,(make-type 'unsigned 8 #f))

    ("float" . ,(make-type 'float 4 #f))
    ("double" . ,(make-type 'float 8 #f))
    ("long double" . ,(make-type 'float 8 #f))

    ("short int" . ,(make-type 'signed 2 #f))
    ("unsigned short int" . ,(make-type 'unsigned 2 #f))
    ("long int" . ,(make-type 'signed 8 #f))
    ("unsigned long int" . ,(make-type 'unsigned 8 #f))))
