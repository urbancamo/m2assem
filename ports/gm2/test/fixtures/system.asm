;
;   system.asm -- Type 18 system-control and return instructions
;
;   Adds coverage for WAIT (STOP), BRKV (TRAPV), RESET, RET (RTS),
;   RETR (RTR) and RETE (RTE).  NOP is already covered by sample.asm.
;
;   These are all no-operand Type 18 opcodes.  The test just needs the
;   assembler to accept each mnemonic.
;

        OBJECT  1
        SYMBOL  1
        BASE    D'10

        ORG     1024

        WAIT                            ; STOP — halt / wait for interrupt
        BRKV                            ; TRAPV — trap if overflow
        RESET                           ; external reset
        RET                             ; RTS
        RETR                            ; RTR
        RETE                            ; RTE
        BRK     #0

        END
