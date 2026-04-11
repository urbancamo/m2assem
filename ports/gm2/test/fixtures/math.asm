;
;   math.asm -- arithmetic / logical / shift / DBR-loop coverage
;
;   Exercises a broader slice of the IEEE-draft 68000 opcode set than
;   bubble.asm: AND, OR, XOR, SHL.L, SHRA.L, DBR, and DATA.L (the last
;   of which was broken in the original 1990 code — this fixture is
;   also the regression test for that fix).
;
;   The program writes eight 32-bit result words to RESLOC:
;
;     [0]  sum   of ARRAY[0..N-1]
;     [1]  AND   of ARRAY[0..N-1]
;     [2]  OR    of ARRAY[0..N-1]
;     [3]  XOR   of ARRAY[0..N-1]   (running parity)
;     [4]  X + Y                    (scalar)
;     [5]  X - Y
;     [6]  X << 2                   (SHL.L  #2,Dn)
;     [7]  X >> 2 arithmetic        (SHRA.L #2,Dn)
;

        OBJECT  1
        SYMBOL  1
        BASE    D'10

N       EQU     6                       ; number of array elements
ARRLOC  EQU     4096                    ; array at absolute 4096
RESLOC  EQU     8192                    ; results at absolute 8192

        ORG     1024                    ; code at 1024

;
;   --- scalar ops on X = 100, Y = 37 ---
;
Main:   LD.L    #100,.D1                ; X
        LD.L    #37,.D2                 ; Y
        LD.L    #RESLOC,.A0             ; .A0 -> results

        MOV.L   .D1,.D0
        ADD.L   .D2,.D0                 ;   X + Y     = 137
        MOV.L   .D0,@.A0(16)            ; -> results[4]

        MOV.L   .D1,.D0
        SUB.L   .D2,.D0                 ;   X - Y     = 63
        MOV.L   .D0,@.A0(20)            ; -> results[5]

        MOV.L   .D1,.D0
        SHL.L   #2,.D0                  ;   X << 2    = 400
        MOV.L   .D0,@.A0(24)            ; -> results[6]

        MOV.L   .D1,.D0
        SHRA.L  #2,.D0                  ;   X >>s 2   = 25   (arith right)
        MOV.L   .D0,@.A0(28)            ; -> results[7]

;
;   --- array loop: sum / AND / OR / XOR accumulators ---
;
        LD.L    #ARRLOC,.A1             ; .A1 -> array

        MOV.L   @.A1,.D0                ; sum <- a[0]
        MOV.L   @.A1,.D3                ; AND <- a[0]
        MOV.L   @.A1,.D4                ; OR  <- a[0]
        MOV.L   @.A1,.D5                ; XOR <- a[0]
        ADD.L   #4,.A1                  ; advance past a[0]
        LD.W    #N-2,.D7                ; DBR counter: N-1 more elements

Loop:   MOV.L   @.A1,.D6                ; .D6 = a[j]
        ADD.L   .D6,.D0                 ; sum += a[j]
        AND.L   .D6,.D3                 ; AND
        OR.L    .D6,.D4                 ; OR
        XOR.L   .D6,.D5                 ; XOR (parity)
        ADD.L   #4,.A1                  ; advance
        DBR     .D7,Loop                ; decrement and branch

        MOV.L   .D0,@.A0                ; -> results[0] = sum
        MOV.L   .D3,@.A0(4)             ; -> results[1] = AND
        MOV.L   .D4,@.A0(8)             ; -> results[2] = OR
        MOV.L   .D5,@.A0(12)            ; -> results[3] = XOR

        BRK     #0                      ; halt

        ORG     ARRLOC                  ; data lives at 4096

        DATA.L  10
        DATA.L  20
        DATA.L  30
        DATA.L  40
        DATA.L  50
        DATA.L  60

        END
