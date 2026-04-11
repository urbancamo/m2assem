;
;   call.asm -- CALL/RET, STM/LDM, XCH, ST, PUSH/POP, BR
;
;   Adds coverage for CALL (via absolute JSR), STM (MOVEM src,ea),
;   LDM (MOVEM ea,dst), XCH (EXG/SWAP), ST, PUSH and POP.  BR is also
;   exercised here since it shares Type 25 routing with CALL.
;
;   Subroutine addresses are declared via EQU so they land in the
;   "Absolute" status class and can be referenced through the `/addr`
;   effective-address form.  Labels placed with "Rel" status can't be
;   used as CALL/BR targets because Type 25 routes non-immediate
;   operands to Type 15 (JMP/JSR), whose CalcEA requires an Absolute
;   type.
;

        OBJECT  1
        SYMBOL  1
        BASE    D'10

SUBLOC  EQU     2048                    ; absolute entry of subroutine
BUFLOC  EQU     4096                    ; save-area base
RMASK   EQU     15                      ; mask D0-D3

        ORG     1024

Main:
        BR      /SUBLOC                 ; BRA / JMP absolute
        CALL    /SUBLOC                 ; BSR / JSR absolute

        ;  XCH — EXG (data-reg form) and SWAP (single-operand Type 17).
        ;  Type 24 (XCH) falls through to Type 6, which only accepts
        ;  .B as a modifier, so we have to write XCH.B even though
        ;  the 68000 EXG is actually long-word.
        XCH.B   .D0,.D1                 ; EXG
        XCH.W   .D2                     ; SWAP (single op -> Type 17)

        ;  ST with register source and memory destination.
        LD.L    #BUFLOC,.A0
        ST.L    .D3,@.A0

        ;  STM / LDM with a register mask and indirect EA.
        STM.L   #RMASK,@.A0             ; MOVEM.L D0-D3,(A0)
        LDM.L   #RMASK,@.A0             ; MOVEM.L (A0),D0-D3

        ;  PUSH / POP — Type 26 is a stub in the 1990 code (returns 0
        ;  with no encoding logic), so these just verify that the
        ;  mnemonic is recognised.  No bytes are emitted.
        PUSH    .D0
        POP     .D0

        BRK     #0

        ORG     SUBLOC
        RET                             ; RTS
        RETR                            ; RTR  (covered here too)
        RETE                            ; RTE
        END
