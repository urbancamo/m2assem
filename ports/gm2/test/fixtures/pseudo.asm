;
;   pseudo.asm -- remaining pseudo-ops
;
;   Adds coverage for DATA.B, RES, TITLE and PAGE.
;

        OBJECT  1
        SYMBOL  1
        BASE    D'10

        TITLE   Demo

        ORG     1024

        NOP

        PAGE                            ; page break in listing

        NOP

        BRK     #0

        ORG     2048

        DATA.B  1
        DATA.B  2
        DATA.B  3
        DATA.B  4

        RES     16                      ; reserve 16 words

        DATA.B  9

        END
