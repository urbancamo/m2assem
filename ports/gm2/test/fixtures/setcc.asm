;
;   setcc.asm -- every Type 10 Scc instruction
;
;   Adds coverage for SET (always), SETE, SETNE, SETC, SETNC, SETP,
;   SETN, SETV, SETNV, SETGT, SETGE, SETLT, SETLE, SETH, SETNH.
;
;   The 68000 Scc family sets a byte to $FF if the condition holds
;   and $00 otherwise.  Each line below sets a single data register.
;

        OBJECT  1
        SYMBOL  1
        BASE    D'10

        ORG     1024

        LD.W    #1,.D0
        LD.W    #1,.D1
        CMP.W   .D1,.D0                 ; flags for the Scc below

        SET     .D2                     ; always true
        SETE    .D2                     ; equal
        SETNE   .D2                     ; not equal
        SETC    .D2                     ; carry
        SETNC   .D2                     ; no carry
        SETP    .D2                     ; plus
        SETN    .D2                     ; minus / negative
        SETV    .D2                     ; overflow
        SETNV   .D2                     ; no overflow
        SETGT   .D2                     ; signed >
        SETGE   .D2                     ; signed >=
        SETLT   .D2                     ; signed <
        SETLE   .D2                     ; signed <=
        SETH    .D2                     ; unsigned > (higher)
        SETNH   .D2                     ; unsigned <= (not higher)

        BRK     #0

        END
