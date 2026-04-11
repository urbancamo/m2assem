;
;   arith.asm -- remaining arithmetic opcodes
;
;   Adds coverage for ADDD (ABCD), SUBD (SBCD), SUBC (SUBX), MUL
;   (MULS), MULU, DIV (DIVS), DIVU, NEG, NEGC (NEGX), NEGD (NBCD),
;   EXT, CHK, NOT, CLR and TEST (TST).
;

        OBJECT  1
        SYMBOL  1
        BASE    D'10

        ORG     1024

        LD.L    #100,.D0
        LD.L    #7,.D1
        LD.W    #200,.D2
        LD.W    #8,.D3

        ;  Multiplication (signed and unsigned) — 16x16 → 32
        MUL.W   .D3,.D2                 ; signed multiply
        MULU.W  .D3,.D2                 ; unsigned multiply

        ;  Division (signed and unsigned) — 32/16 → 16:16
        LD.L    #1000,.D4
        LD.W    #7,.D5
        DIV.W   .D5,.D4                 ; signed divide
        LD.L    #1000,.D4
        LD.W    #7,.D5
        DIVU.W  .D5,.D4                 ; unsigned divide

        ;  Decimal arithmetic (ABCD / SBCD)
        ADDD.B  .D1,.D0                 ; packed BCD add with X
        SUBD.B  .D1,.D0                 ; packed BCD subtract with X

        ;  Extended subtract with borrow (68000 SUBX)
        SUBC.L  .D1,.D0

        ;  Negation variants
        NEG.L   .D0                     ; two's complement negate
        NEGC.L  .D0                     ; negate with extend (NEGX)
        NEGD.B  .D0                     ; BCD negate (NBCD)

        ;  Sign extension.  The modifier is the SOURCE width in
        ;  m2assem, so EXT.B is 68000 EXT.W (byte→word) and EXT.W
        ;  is 68000 EXT.L (word→long).
        EXT.B   .D0
        EXT.W   .D0

        ;  Check against bounds (raises TRAP 6 if .D0 < 0 or > .D1)
        CHK.W   .D1,.D0

        ;  Bitwise NOT
        NOT.L   .D0

        ;  Clear register to zero
        CLR.L   .D0

        ;  Test (compare against zero)
        TEST.L  .D0

        BRK     #0

        END
