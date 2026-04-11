;
;   bubble.asm -- bubble sort of 5 16-bit words
;
;   Exercises: immediate, register direct, indirect, indirect with
;   displacement, label expressions, EQU, BASE, forward and backward
;   branches, DATA and BRK.
;
;   This is the IEEE Proposed Assembly Language Standard draft (1979)
;   form of 68000 assembly — see the PDF reports under doc/pdf/ for the
;   IEEE-to-Motorola mapping.
;
;   Labels are "Relative" symbols in m2assem and can't be used as
;   immediate operands (the assembler's Evaluate rejects any operand
;   whose type isn't Absolute for #imm forms).  So the array base
;   address is declared as an absolute EQU and the data is placed
;   there via a second ORG.
;

        OBJECT  1
        SYMBOL  1
        BASE    D'10                    ; decimal throughout

        ORG     1000                    ; code lives at 1000

N       EQU     5                       ; array length
ARRLOC  EQU     2000                    ; array sits at absolute 2000

Start:  LD.L    #ARRLOC,.A0             ; .A0 <- array base
        LD.W    #N-1,.D7                ; .D7 =  outer counter

Outer:  MOV.L   .A0,.A1                 ; .A1 <- reset inner pointer
        MOV.W   .D7,.D6                 ; .D6 =  inner counter

Inner:  MOV.W   @.A1,.D0                ; .D0 <- a[j]
        MOV.W   @.A1(2),.D1             ; .D1 <- a[j+1]
        CMP.W   .D1,.D0                 ; compare a[j] vs a[j+1]
        BLE     NoSwap                  ; skip if already ordered
        MOV.W   .D1,@.A1                ; swap: a[j]   <- a[j+1]
        MOV.W   .D0,@.A1(2)             ;       a[j+1] <- saved a[j]

NoSwap: ADD.L   #2,.A1                  ; advance one word
        SUB.W   #1,.D6                  ; inner--
        BGE     Inner                   ; loop while >= 0

        SUB.W   #1,.D7                  ; outer--
        BGE     Outer                   ; loop while >= 0

        BRK     #0                      ; halt

        ORG     ARRLOC                  ; data lives at 2000

        DATA.W  5
        DATA.W  3
        DATA.W  8
        DATA.W  1
        DATA.W  9

        END
