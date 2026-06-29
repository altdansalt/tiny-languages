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

;; address of local#n into x13:  x13 = BP - 8n.  Locals have n>0 (below BP);
;; function parameters come through with n<0 (above BP).  LOAD_W16 zero-extends,
;; so load |offset| and pick SUB (below) or ADD (above) by sign — never clobbering
;; the working pair x0/x1 (the other operand of a binary op may be live there).
(define (addr-x13 n)
  (let ((off (* 8 n)))
    `(("SET_X13_FROM_BP")
      ,@(load-x16 (abs off))
      (,(if (>= off 0) "SUB_X13_X13_X16" "ADD_X13_X13_X16")))))

;; r = local#n  (value at [BP - 8n])
(define (aarch64:local->r info n)
  (let ((r (string-upcase (first-r info))))
    `(,@(addr-x13 n)
      (,(string-append "SET_" r "_FROM_X13"))
      (,(string-append "DEREF_" r)))))  ; r = [address]

;; local#n = r  (store r at [BP - 8n])
(define (aarch64:r->local info n)
  (let ((r (string-upcase (get-r info))))
    `(,@(addr-x13 n)
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

;; --- bitwise & shifts (Milestone 4) -----------------------------------------
;; 2-register model: r0=x0, r1=x1, so r0 OP r1 maps to a fixed-register macro.
(define (aarch64:r0-and-r1 info) `(("AND_X0_X0_X1")))
(define (aarch64:r0-or-r1 info)  `(("OR_X0_X0_X1")))
(define (aarch64:r0-xor-r1 info) `(("EOR_X0_X0_X1")))
(define (aarch64:r0<<r1 info)    `(("LSLV_X0_X0_X1")))
(define (aarch64:r0>>r1 info)    `(("LSRV_X0_X0_X1")))
(define (aarch64:r0>>r1-signed info) `(("ASRV_X0_X0_X1")))
;; r <<= immediate n  (shift amount loaded into x16)
(define (aarch64:shl-r info n)
  (let ((r (string-upcase (get-r info))))
    `(,@(load-x16 n) (,(string-append "LSLV_" r "_" r "_X16")))))

;; --- sign/zero extension in place -------------------------------------------
(define (aarch64:ext r kind) `((,(string-append kind "_" r "_" r))))
(define (aarch64:byte-r info)        (aarch64:ext (string-upcase (get-r info)) "UXTB"))
(define (aarch64:byte-signed-r info) (aarch64:ext (string-upcase (get-r info)) "SXTB"))
(define (aarch64:word-r info)        (aarch64:ext (string-upcase (get-r info)) "UXTH"))
(define (aarch64:word-signed-r info) (aarch64:ext (string-upcase (get-r info)) "SXTH"))

;; --- pointer / memory access ------------------------------------------------
;; r = [r]  (the address is already in r); sub-word loads zero-extend
(define (aarch64:mem->r info)      (let ((r (string-upcase (get-r info)))) `((,(string-append "DEREF_" r)))))
(define (aarch64:long-mem->r info) (let ((r (string-upcase (get-r info)))) `((,(string-append "DEREF_" r "_W")))))
(define (aarch64:word-mem->r info) (let ((r (string-upcase (get-r info)))) `((,(string-append "DEREF_" r "_H")))))
(define (aarch64:byte-mem->r info) (let ((r (string-upcase (get-r info)))) `((,(string-append "DEREF_" r "_BYTE")))))
;; [r1] = r0  (store the value in x0 at the address in x1), by width
(define (aarch64:r0->r1-mem info)      `(("STR_X0_[X1]")))
(define (aarch64:long-r0->r1-mem info) `(("STR_W0_[X1]")))
(define (aarch64:word-r0->r1-mem info) `(("STRH_W0_[X1]")))
(define (aarch64:byte-r0->r1-mem info) `(("STR_BYTE_W0_[X1]")))

;; address of local#n into r (no dereference)
(define (aarch64:local-ptr->r info n)
  (let ((r (string-upcase (get-r info))))
    `(,@(addr-x13 n) (,(string-append "SET_" r "_FROM_X13")))))

;; --- globals (label-addressed storage) --------------------------------------
;; address of a label into r (32-bit address space, so a word load suffices)
(define (aarch64:label->r info label)
  (let ((r (get-r info)))
    `((,(string-append "LOAD_W" (reg-n r) "_AHEAD"))
      ,(skip+addr label))))
;; value at a label into r (address then dereference, by width)
(define (aarch64:label-mem->r info label)
  (let ((ru (string-upcase (get-r info))))
    `(,@(aarch64:label->r info label) (,(string-append "DEREF_" ru)))))
;; store r at a label.  Load &label into x16, then store r there by width.
(define (label-store r-suffix label)
  `(("LOAD_W16_AHEAD") ,(skip+addr label)
    (,(string-append r-suffix "_[X16]"))))
(define (aarch64:r->label info label)
  (label-store (string-append "STR_" (string-upcase (get-r info))) label))
(define (aarch64:r->long-label info label)
  (label-store (string-append "STR_W" (reg-n (get-r info))) label))
(define (aarch64:r->word-label info label)
  (label-store (string-append "STRH_W" (reg-n (get-r info))) label))
(define (aarch64:r->byte-label info label)
  (label-store (string-append "STR_BYTE_W" (reg-n (get-r info))) label))

;; --- comparisons & control flow (Milestone 2b) ------------------------------
;; Condition pair: x14 = condx, x15 = condy.  The compare-setup op loads the two
;; operands; the jump/materialize op consumes them.  This mirrors the riscv64
;; backend's condregx/condregy, realised with aarch64 SUBS+B.cond / CSET.
;; The SKIP_32_DATA macro plus the 4-byte &label it skips over, as one M1 line.
;; The structured (#:address ,label) token lets M1.scm render every label kind
;; MesCC passes — plain strings (jump targets), <global>/<function> records, and
;; nested (#:address ...) forms — via global->string/function->string.  It must
;; share a line with a leading string token (here "SKIP_32_DATA"), since
;; line->M1 requires the first or last token to be a string/symbol.
(define (skip+addr label) `("SKIP_32_DATA" (#:address ,label)))

;; the absolute jump M2libc-style: load &label into x16, BR x16
(define (jump-to label)
  `(("LOAD_W16_AHEAD")
    ,(skip+addr label)
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

;; --- function calls (Milestone 3) -------------------------------------------
;; Calling convention (matches MesCC's other backends): the caller PUSHes each
;; argument onto the x18 stack, then calls; after return the caller pops the n
;; argument words (x18 += 8n).  The callee reads its parameters as locals at
;; positive BP offsets (above the saved LR/BP that function-preamble pushes).
(define (aarch64:r->arg info i)
  `((,(aarch64:push (get-r info)))))

(define (aarch64:label->arg info label i)
  `(("LOAD_W16_AHEAD")
    ,(skip+addr label)
    ("PUSH_X16")))

;; pop n argument words off the x18 stack after a call (x18 += 8n).  Uses the
;; corrected add — M2libc's ADD_SP_X16_SP is mis-encoded (see extra.M1).
(define (args-cleanup n)
  (if (> n 0) `(,@(load-x16 (* 8 n)) ("ADD_SP_SP_X16_OK")) '()))

(define (aarch64:call-label info label n)
  `(("LOAD_W16_AHEAD")
    ,(skip+addr label)
    ("BLR_X16")
    ,@(args-cleanup n)))

(define (aarch64:call-r info n)
  (let ((r (string-upcase (get-r info))))
    `((,(string-append "SET_X16_FROM_" r))
      ("BLR_X16")
      ,@(args-cleanup n))))

;; swap a working register with the top word of the x18 stack (used to reorder
;; operands spilled across a call, e.g. fib(n-1)+fib(n-2)).  x13 is a free scratch.
(define (swap-with-stack r)
  `(("LDR_X13_[SP]")                          ; tmp = [x18]
    (,(string-append "STR_" r "_[SP]"))       ; [x18] = r
    (,(string-append "SET_" r "_FROM_X13")))) ; r = tmp
(define (aarch64:swap-r-stack info)  (swap-with-stack (string-upcase (get-r info))))
(define (aarch64:swap-r1-stack info) (swap-with-stack (string-upcase (get-r0 info))))

(define aarch64:instructions
  `((function-preamble . ,aarch64:function-preamble)
    (r->arg . ,aarch64:r->arg)
    (swap-r-stack . ,aarch64:swap-r-stack)
    (swap-r1-stack . ,aarch64:swap-r1-stack)
    (label->arg . ,aarch64:label->arg)
    (call-label . ,aarch64:call-label)
    (call-r . ,aarch64:call-r)
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
    (ne?->r . ,aarch64:ne?->r)
    (r0-and-r1 . ,aarch64:r0-and-r1)
    (r0-or-r1 . ,aarch64:r0-or-r1)
    (r0-xor-r1 . ,aarch64:r0-xor-r1)
    (r0<<r1 . ,aarch64:r0<<r1)
    (r0>>r1 . ,aarch64:r0>>r1)
    (r0>>r1-signed . ,aarch64:r0>>r1-signed)
    (shl-r . ,aarch64:shl-r)
    (byte-r . ,aarch64:byte-r)
    (byte-signed-r . ,aarch64:byte-signed-r)
    (word-r . ,aarch64:word-r)
    (word-signed-r . ,aarch64:word-signed-r)
    (mem->r . ,aarch64:mem->r)
    (long-mem->r . ,aarch64:long-mem->r)
    (word-mem->r . ,aarch64:word-mem->r)
    (byte-mem->r . ,aarch64:byte-mem->r)
    (r0->r1-mem . ,aarch64:r0->r1-mem)
    (long-r0->r1-mem . ,aarch64:long-r0->r1-mem)
    (word-r0->r1-mem . ,aarch64:word-r0->r1-mem)
    (byte-r0->r1-mem . ,aarch64:byte-r0->r1-mem)
    (local-ptr->r . ,aarch64:local-ptr->r)
    (label->r . ,aarch64:label->r)
    (label-mem->r . ,aarch64:label-mem->r)
    (r->label . ,aarch64:r->label)
    (r->long-label . ,aarch64:r->long-label)
    (r->word-label . ,aarch64:r->word-label)
    (r->byte-label . ,aarch64:r->byte-label)))
