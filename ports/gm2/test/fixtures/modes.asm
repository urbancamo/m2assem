;
;   modes.asm -- addressing mode coverage sweep
;
;   Exercises every IEEE addressing mode listed in ADM.def's
;   ValidAddressingModes enum that isn't already covered by the
;   existing fixtures and that is actually implemented by the Type
;   dispatchers in ADM.mod.
;
;   Modes already covered elsewhere:
;
;     Dir         (.Dn / .An)        — everywhere
;     Imm         (#expr)            — everywhere
;     Ind         (@.An)             — bubble, math, call
;     Abs         (/xxx)             — call
;     IndPostIdx  (@.An(d16))        — bubble, math
;
;   This fixture adds:
;
;     AutoPostInc (.An+)             — 68000 (An)+
;     AutoPreDec  (-.An)             — 68000 -(An)
;     Index       (@.An(.Xn,d8))     — 68000 d8(An,Xn.W)
;     Rel         ($label)           — 68000 immediate that accepts
;                                      a Relative-typed operand
;
;   The remaining four modes in ValidAddressingModes are either
;   unreachable or buggy in the 1990 code and therefore NOT covered:
;
;     BPage       (!xxx)             — never appears in any AMS
;                                      set, so no instruction accepts
;                                      it.  Dead mnemonic.
;     AutoPreInc  (+.An)             — Type 1 has no dispatch for it;
;                                      Pass 1 returns an uninitialised
;                                      length and the location counter
;                                      blows past MEMHIGH on the first
;                                      use.
;     AutoPostDec (.An-)             — same as AutoPreInc.
;     PC-indexed  (@*(.Xn,d8))       — CalcEA's IndPostIndex branch
;                                      calls RegisterType on a Register
;                                      string that was never populated
;                                      when the argument is "*", so it
;                                      raises "Badly formed register"
;                                      before ever reaching the PC case.
;
;   These limitations are documented in TEST.md under the "Historical
;   discoveries" section.
;

        OBJECT  1
        SYMBOL  1
        BASE    D'10

ARRLOC  EQU     4096

        ORG     1024

Main:
        LD.L    /ARRLOC,.A0             ; set A0 (Abs — already tested)

        ;  AutoPostInc — .An+   ->  68000 (An)+
        MOV.L   .A0+,.D0

        ;  AutoPreDec  — -.An   ->  68000 -(An)
        MOV.L   -.A0,.D1

        ;  Index       — @.An(.Xn,d8)  ->  68000 d8(An,Xn.W)
        ;  IEEE order is (index_reg,disp) — register first, then displacement.
        MOV.L   @.A0(.D6,4),.D2

        ;  Rel         — $label  ->  #imm with a Relative-typed value
        ;  (The 1990 code lets you use a label's address as an
        ;  immediate without tripping the "Argument must be absolute"
        ;  check.)
        MOV.L   $ARRLOC,.D3

        BRK     #0

        END
