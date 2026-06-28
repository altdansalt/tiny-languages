;;; GNU Mes --- aarch64 MesCC backend code generator (NEW).
;;;
;;; Each function emits a list of M1 lines.  A single-string entry is a raw M1
;;; source line (a macro name from M2libc's aarch64_defs.M1, or %imm data).
;;; Immediates use M2libc's load-ahead idiom:
;;;     LOAD_W<n>_AHEAD / SKIP_32_DATA / %value   -> load a 32-bit literal into x<n>
;;;
;;; Bring-up strategy: the instruction table below lists only what is implemented;
;;; anything MesCC needs but we haven't written yet surfaces as a clear
;;; "no such instruction <key>" at compile time, which drives the next function.

(define-module (mescc aarch64 as)
  #:use-module (mes guile)
  #:use-module (mescc as)
  #:use-module (mescc info)
  #:export (aarch64:instructions))

(define %retreg "x0")

;; "x13" -> "13"  (register name -> numeric suffix for the W<n> macros)
(define (reg-n r) (substring r 1))

;; push/pop a named register via the per-register PUSH_/POP_ macros
(define (aarch64:push r) (string-append "PUSH_" (string-upcase r)))
(define (aarch64:pop r)  (string-append "POP_"  (string-upcase r)))

;; load a 32-bit immediate into register r
(define (aarch64:li r v)
  `((,(string-append "LOAD_W" (reg-n r) "_AHEAD"))
    ("SKIP_32_DATA")
    (,(string-append "%" (number->string v)))))

(define (aarch64:function-preamble info . rest)
  `(("PUSH_LR")
    ("PUSH_BP")
    ("SET_BP_FROM_SP")))

(define (aarch64:function-locals . rest)
  ;; reserve 8*1024 scratch buffer + 20 locals, like the other backends
  (let ((n (+ (* 8 1025) (* 20 8))))
    `(("LOAD_W16_AHEAD")
      ("SKIP_32_DATA")
      (,(string-append "%" (number->string n)))
      ("SUB_SP_SP_X16"))))

(define (aarch64:value->r info v)
  (let ((r (get-r info)))
    (aarch64:li r v)))

(define (aarch64:value->r0 info v)
  (let ((r0 (get-r0 info)))
    (aarch64:li r0 v)))

(define (aarch64:ret . rest)
  `(("SET_SP_FROM_BP")
    (,(aarch64:pop "BP"))
    (,(aarch64:pop "LR"))
    ("RETURN")))

;; move the just-returned value (in the ABI return reg x0) into r, if needed
(define (aarch64:return->r info)
  (let ((r (car (.allocated info))))
    (if (equal? r %retreg) '()
        `((,(string-append "SET_" (string-upcase r) "_FROM_X0"))))))

(define (aarch64:nop info . rest) '(("; nop")))

(define aarch64:instructions
  `((function-preamble . ,aarch64:function-preamble)
    (function-locals . ,aarch64:function-locals)
    (value->r . ,aarch64:value->r)
    (value->r0 . ,aarch64:value->r0)
    (return->r . ,aarch64:return->r)
    (ret . ,aarch64:ret)
    (nop . ,aarch64:nop)))
