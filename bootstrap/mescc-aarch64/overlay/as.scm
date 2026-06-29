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

;; --- stack (spill) ops ------------------------------------------------------
;; The 2-register model (registers = x0,x1) means MesCC spills deeper sub-
;; expressions to the x18 stack; these are how it does it.
(define (aarch64:push-r0 info)
  `((,(aarch64:push (get-r0 info)))))
(define (aarch64:pop-r0 info)
  `((,(aarch64:pop (get-r0 info)))))
(define (aarch64:push-register info r)
  `((,(aarch64:push r))))
(define (aarch64:pop-register info r)
  `((,(aarch64:pop r))))

;; --- integer arithmetic -----------------------------------------------------
;; In the 2-register model r0=x0, r1=x1 always, so these map straight onto
;; M2libc's fixed-register macros. (add/mul commute; sub is x0 = x0 - x1.)
(define (aarch64:r0+r1 info) `(("ADD_X0_X1_X0")))   ; x0 = x1 + x0
(define (aarch64:r0-r1 info) `(("SUB_X0_X0_X1")))   ; x0 = x0 - x1
(define (aarch64:r0*r1 info) `(("MUL_X0_X1_X0")))   ; x0 = x1 * x0

;; swap x0 <-> x1 via the x16 scratch (SET_X0_FROM_X1 is in extra.M1)
(define (aarch64:swap-r0-r1 info)
  `(("SET_X16_FROM_X0")
    ("SET_X0_FROM_X1")
    ("SET_X1_FROM_X16")))

;; r = r + immediate.  Load |v| (positive) into x16, then add or subtract by sign
;; — using only verified-correct M2libc macros (its ADD_X0_X16_X0 is buggy, so we
;; use ADD_X0_X16_X0_OK from extra.M1 for that one case).
(define (aarch64:add-imm r v)            ; r = "X0" or "X1"
  (let ((add (if (string=? r "X0") "ADD_X0_X16_X0_OK" (string-append "ADD_" r "_X16_" r)))
        (sub (string-append "SUB_" r "_" r "_X16")))
    `(("LOAD_W16_AHEAD")
      ("SKIP_32_DATA")
      (,(string-append "%" (number->string (abs v))))
      (,(if (>= v 0) add sub)))))
(define (aarch64:r+value info v)  (aarch64:add-imm (string-upcase (get-r info)) v))
(define (aarch64:r0+value info v) (aarch64:add-imm (string-upcase (get-r0 info)) v))

;; --- local variables (BP-relative; M2libc's BP is x17) ----------------------
;; load the byte offset |off| into x16 (offsets here are small multiples of 8)
(define (load-x16 off)
  `(("LOAD_W16_AHEAD") ("SKIP_32_DATA") (,(string-append "%" (number->string off)))))
(define (first-r info)
  (car (if (pair? (.allocated info)) (.allocated info) (.registers info))))

;; r = local#n  (value at [BP - 8n]).  The address is built in the x13 scratch so
;; the other working register (the live operand of a binary op) is never touched.
(define (aarch64:local->r info n)
  (let ((r (string-upcase (first-r info))))
    `(("SET_X13_FROM_BP")
      ,@(load-x16 (* 8 n))
      ("SUB_X13_X13_X16")              ; x13 = BP - 8n  (address)
      (,(string-append "SET_" r "_FROM_X13"))
      (,(string-append "DEREF_" r)))))  ; r = [address]

;; local#n = r  (store r at [BP - 8n]); address via x13, value straight from r.
(define (aarch64:r->local info n)
  (let ((r (string-upcase (get-r info))))
    `(("SET_X13_FROM_BP")
      ,@(load-x16 (* 8 n))
      ("SUB_X13_X13_X16")              ; x13 = address
      (,(string-append "STR_" r "_[X13]")))))

;; register moves between the working pair
(define (aarch64:r1->r0 info) `(("SET_X0_FROM_X1")))   ; x0 = x1
(define (aarch64:r0->r1 info) `(("SET_X1_FROM_X0")))   ; x1 = x0
;; r2->r0: in the 2-register model there is no 3rd register, so MesCC's fallback
;; is to peek the spilled top-of-stack (pop then push it back).
(define (aarch64:r2->r0 info)
  `((,(aarch64:pop (get-r0 info)))
    (,(aarch64:push (get-r0 info)))))

;; sign-extend a 32-bit (int) value in r to the full 64-bit register
(define (aarch64:long-signed-r info)
  (let ((r (string-upcase (get-r info))))
    `((,(string-append "SXTW_" r "_" r)))))

;; --- comparisons & control flow (Milestone 2b) ------------------------------
;; Condition pair: x14 = condx, x15 = condy.  The compare-setup op loads the two
;; operands; the jump/materialize op consumes them.  This mirrors the riscv64
;; backend's condregx/condregy, realised with aarch64 SUBS+B.cond / CSET.
(define (label->s label)
  (cond ((string? label) label)
        ((symbol? label) (symbol->string label))
        (else (format #f "~a" label))))

;; the 4-instruction absolute jump M2libc-style: load &label into x16, BR x16
(define (jump-to label)
  `(("LOAD_W16_AHEAD") ("SKIP_32_DATA")
    (,(string-append "&" (label->s label)))
    ("BR_X16")))

(define (aarch64:jump info label)
  (jump-to label))

;; set up the condition pair for a test against zero:  condx = r, condy = 0
(define (aarch64:test-r info)
  (let ((r (string-upcase (get-r info))))
    `((,(string-append "SET_X14_FROM_" r)) ("SET_X15_TO_0"))))
(define (aarch64:r-zero? info)
  (let ((r (string-upcase (first-r info))))
    `((,(string-append "SET_X14_FROM_" r)) ("SET_X15_TO_0"))))

;; set up the condition pair from the working registers: condx = r0, condy = r1
(define (aarch64:r0-cmp-r1 info)
  `(("SET_X14_FROM_X0") ("SET_X15_FROM_X1")))

;; branch if condx == condy  (jump-z) / condx != condy  (jump-nz)
(define (aarch64:jump-z info label)
  `(("CMP_X14_X15") ("BNE_SKIP_JUMP") ,@(jump-to label)))
(define (aarch64:jump-nz info label)
  `(("CMP_X14_X15") ("BEQ_SKIP_JUMP") ,@(jump-to label)))

;; materialize a signed comparison of (condx ? condy) as 0/1 into r
(define (aarch64:cmp->r info cond)
  (let ((r (string-upcase (get-r info))))
    `(("CMP_X14_X15") (,(string-append "CSET_" r "_" cond)))))
(define (aarch64:l?->r info)  (aarch64:cmp->r info "LT"))  ; condx <  condy
(define (aarch64:g?->r info)  (aarch64:cmp->r info "GT"))  ; condx >  condy
(define (aarch64:le?->r info) (aarch64:cmp->r info "LE"))  ; condx <= condy
(define (aarch64:ge?->r info) (aarch64:cmp->r info "GE"))  ; condx >= condy
(define (aarch64:eq?->r info) (aarch64:cmp->r info "EQ"))  ; condx == condy
(define (aarch64:ne?->r info) (aarch64:cmp->r info "NE"))  ; condx != condy

(define aarch64:instructions
  `((function-preamble . ,aarch64:function-preamble)
    (function-locals . ,aarch64:function-locals)
    (value->r . ,aarch64:value->r)
    (value->r0 . ,aarch64:value->r0)
    (return->r . ,aarch64:return->r)
    (ret . ,aarch64:ret)
    (nop . ,aarch64:nop)
    (push-r0 . ,aarch64:push-r0)
    (pop-r0 . ,aarch64:pop-r0)
    (push-register . ,aarch64:push-register)
    (pop-register . ,aarch64:pop-register)
    (r0+r1 . ,aarch64:r0+r1)
    (r0-r1 . ,aarch64:r0-r1)
    (r0*r1 . ,aarch64:r0*r1)
    (swap-r0-r1 . ,aarch64:swap-r0-r1)
    (r1->r0 . ,aarch64:r1->r0)
    (r0->r1 . ,aarch64:r0->r1)
    (r2->r0 . ,aarch64:r2->r0)
    (r+value . ,aarch64:r+value)
    (r0+value . ,aarch64:r0+value)
    (local->r . ,aarch64:local->r)
    (r->local . ,aarch64:r->local)
    (long-signed-r . ,aarch64:long-signed-r)
    (jump . ,aarch64:jump)
    (jump-z . ,aarch64:jump-z)
    (jump-nz . ,aarch64:jump-nz)
    (test-r . ,aarch64:test-r)
    (r-zero? . ,aarch64:r-zero?)
    (r0-cmp-r1 . ,aarch64:r0-cmp-r1)
    (g?->r . ,aarch64:g?->r)
    (ge?->r . ,aarch64:ge?->r)
    (l?->r . ,aarch64:l?->r)
    (le?->r . ,aarch64:le?->r)
    (eq?->r . ,aarch64:eq?->r)
    (ne?->r . ,aarch64:ne?->r)))
