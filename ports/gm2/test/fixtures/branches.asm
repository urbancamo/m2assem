;
;   branches.asm -- every Type 11 Bcc
;
;   Adds coverage for BE, BNE, BC, BNC, BP, BN, BV, BNV, BGT, BLT,
;   BH, BNH.  (BGE and BLE are already covered by bubble.asm.)
;   BR and CALL (Type 25) are covered separately in call.asm because
;   their addressing-mode routing is quite different.
;
;   Each branch targets the next label, producing a tiny chain of
;   branches each 2 bytes apart.  We don't care whether each condition
;   is actually taken at runtime — the test is that the assembler
;   accepts every mnemonic with a bare-label (Direct) operand.
;

        OBJECT  1
        SYMBOL  1
        BASE    D'10

        ORG     1024

        LD.W    #10,.D0
        LD.W    #5,.D1
        CMP.W   .D1,.D0         ; set flags

        BE      L01             ; ==
L01:    BNE     L02             ; !=
L02:    BC      L03             ; carry
L03:    BNC     L04             ; no carry
L04:    BP      L05             ; plus
L05:    BN      L06             ; minus
L06:    BV      L07             ; overflow
L07:    BNV     L08             ; no overflow
L08:    BGT     L09             ; >
L09:    BLT     L10             ; <
L10:    BH      L11             ; higher (unsigned >)
L11:    BNH     L12             ; not higher (unsigned <=)
L12:    BRK     #0

        END
