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

;; r0=x0, r1=x1 (the working pair the M2libc macros are built around); x13..x15
;; are the spare temp pool (PUSH_X13.., SET_X0_FROM_X13.., ADD_X0_X14_X0.. exist).
(define aarch64:registers '("x0" "x1" "x13" "x14" "x15"))

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
