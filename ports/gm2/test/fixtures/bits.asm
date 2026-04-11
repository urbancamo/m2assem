;
;   bits.asm -- Type 22 bit-manipulation instructions
;
;   Adds coverage for TESTSET (BSET), TESTCLR (BCLR) and TESTNOT
;   (BCHG).
;
;   TEST1 (BTST) is NOT covered here because the 1990 Lex module only
;   reads alphabetic characters for command names (ExtractCommand
;   loops while CurrentChar IN AlphabetSet), so any mnemonic with a
;   digit — TEST1 is the only one in the opcode table — can't be
;   parsed at all.  The opcode is registered in InsertOpcodesInTable
;   but unreachable from a source file; this is a latent bug in the
;   1990 lexer.
;

        OBJECT  1
        SYMBOL  1
        BASE    D'10

        ORG     1024

        LD.L    #5,.D0                  ; bit number
        LD.L    #0,.D1                  ; target word

        TESTSET .D0,.D1                 ; BSET — test and set
        TESTCLR .D0,.D1                 ; BCLR — test and clear
        TESTNOT .D0,.D1                 ; BCHG — test and change

        BRK     #0

        END
