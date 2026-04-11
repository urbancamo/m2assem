;
;   bits.asm -- Type 22 bit-manipulation instructions
;
;   Covers the full Type 22 opcode set: TEST1 (BTST), TESTSET (BSET),
;   TESTCLR (BCLR) and TESTNOT (BCHG).
;
;   TEST1 is the only mnemonic in the entire opcode table that contains
;   a digit.  The original 1990 Lex.ExtractCommand read only alphabetic
;   characters for a command name, so TEST1 couldn't be parsed at all
;   — it sat in the opcode table unreachable for 35 years.  The lexer
;   was extended during the gm2 port to also accept trailing digits
;   (letters first, then letters-or-digits), which matches the usual
;   identifier rule and unblocks TEST1 without opening up anything
;   unintended.  Any fixture built from this file is therefore a
;   regression test for that lexer fix too.
;

        OBJECT  1
        SYMBOL  1
        BASE    D'10

        ORG     1024

        LD.L    #5,.D0                  ; bit number
        LD.L    #0,.D1                  ; target word

        TEST1   .D0,.D1                 ; BTST — test bit
        TESTSET .D0,.D1                 ; BSET — test and set
        TESTCLR .D0,.D1                 ; BCLR — test and clear
        TESTNOT .D0,.D1                 ; BCHG — test and change

        BRK     #0

        END
