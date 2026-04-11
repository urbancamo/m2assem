;
;   branches.asm -- every Type 11 Bcc and BR (Type 25)
;
;   Adds coverage for BE, BNE, BC, BNC, BP, BN, BV, BNV, BGT, BLT,
;   BH, BNH.  (BGE and BLE are already covered by bubble.asm.)
;   BR is also exercised here with a bare-label operand, which the
;   port fixed by routing Type 25's Dir/Rel path through Type 11
;   (the same Bcc encoder the conditional variants use) — the 1990
;   code had it going to Type 15 (JMP) which required an Absolute
;   operand type, so "BR Label" was broken.
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

        BR      L01             ; unconditional (was broken in 1990)
L01:    BE      L02             ; ==
L02:    BNE     L03             ; !=
L03:    BC      L04             ; carry
L04:    BNC     L05             ; no carry
L05:    BP      L06             ; plus
L06:    BN      L07             ; minus
L07:    BV      L08             ; overflow
L08:    BNV     L09             ; no overflow
L09:    BGT     L10             ; >
L10:    BLT     L11             ; <
L11:    BH      L12             ; higher (unsigned >)
L12:    BNH     L13             ; not higher (unsigned <=)
L13:    BRK     #0

        END
