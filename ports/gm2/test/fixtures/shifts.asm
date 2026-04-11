;
;   shifts.asm -- remaining Type 21 shift / rotate instructions
;
;   Adds coverage for SHR, SHLA, ROR, ROL, RORC, ROLC.
;   (SHL and SHRA are already covered by sample.asm and math.asm.)
;
;   Each instruction shifts/rotates a register by an immediate count
;   and writes the result to a results buffer.
;

        OBJECT  1
        SYMBOL  1
        BASE    D'10

RESLOC  EQU     8192

        ORG     1024

        LD.L    #RESLOC,.A0

        LD.L    #255,.D0                ; 0x000000FF
        SHR.L   #2,.D0                  ; LSR: logical shift right
        MOV.L   .D0,@.A0

        LD.L    #255,.D0
        SHLA.L  #2,.D0                  ; ASL: arith shift left
        MOV.L   .D0,@.A0(4)

        LD.L    #255,.D0
        ROR.L   #4,.D0                  ; rotate right
        MOV.L   .D0,@.A0(8)

        LD.L    #255,.D0
        ROL.L   #4,.D0                  ; rotate left
        MOV.L   .D0,@.A0(12)

        LD.L    #255,.D0
        RORC.L  #4,.D0                  ; ROXR: rotate right through carry
        MOV.L   .D0,@.A0(16)

        LD.L    #255,.D0
        ROLC.L  #4,.D0                  ; ROXL: rotate left through carry
        MOV.L   .D0,@.A0(20)

        BRK     #0

        END
