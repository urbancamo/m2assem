;
;   dbcc.asm -- every Type 12 DBcc
;
;   Adds coverage for DBE, DBNE, DBC, DBNC, DBP, DBN, DBV, DBNV, DBGT,
;   DBGE, DBLT, DBLE, DBH, DBNH.  (DBR is already covered by math.asm.)
;
;   Each DBcc is a single iteration loop — the operand pattern is
;   (counter-register, target-label).  The semantic effect isn't
;   interesting for this test; we just want every mnemonic to parse
;   and encode.
;

        OBJECT  1
        SYMBOL  1
        BASE    D'10

        ORG     1024

        LD.W    #1,.D0
        LD.W    #1,.D1
        CMP.W   .D1,.D0         ; set flags

T01:    DBE     .D0,T01
T02:    DBNE    .D0,T02
T03:    DBC     .D0,T03
T04:    DBNC    .D0,T04
T05:    DBP     .D0,T05
T06:    DBN     .D0,T06
T07:    DBV     .D0,T07
T08:    DBNV    .D0,T08
T09:    DBGT    .D0,T09
T10:    DBGE    .D0,T10
T11:    DBLT    .D0,T11
T12:    DBLE    .D0,T12
T13:    DBH    .D0,T13
T14:    DBNH    .D0,T14

        BRK     #0

        END
