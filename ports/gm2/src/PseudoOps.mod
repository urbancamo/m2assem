IMPLEMENTATION MODULE PseudoOps;

(*
        MODULE: PseudoOps       Version 1.0     (c)1990 Mark Wickens

        Created: 03/03/90

        This module handles all valid operations not assembler specific,
        i.e., all the assembly language-independent pseudo operations.
*)

FROM TableExt           IMPORT  InsertCommand;
FROM ADM                IMPORT  MEMLOW, MEMHIGH, Word, Instruction,
                                LongIntToWord;
FROM Location           IMPORT  SetLocation, CurrentLocation;
FROM Exceptions         IMPORT  Raise, ExceptionLevel, ExceptionType;
FROM TableExt           IMPORT  SymbolStatus, InsertSymbol, TableType,
                                EntryType;
FROM Listing            IMPORT  SetPageLength, SetLineLength, INCPage,
                                SymbolTable, SetTitle;
FROM Expression         IMPORT  Evaluate, ChangeBase, BaseType;
FROM Table              IMPORT  Amend;
FROM MyStrings            IMPORT  MakeSubstring, LengthOfString;
FROM ObjectGenerator    IMPORT  ObjectOutput, AddCode;

PROCEDURE AssemblePseudoOp(DecInstr: DecodedLine; PassNo, Type: CARDINAL;
                           VAR Length: CARDINAL);
(*
        Performs the appropriate action on the peudo-op found.
*)

TYPE
  SwitchType = (SymbolSwitch, ObjectSwitch);

CONST
  OperandCountError = "Wrong number of operands";
  IndicesCountError = "Wrong number of indices";
  LocationRangeError = "Attempted to exceed location max/min limits";
  RelativeError = "Operand evaluated to a relative result";


  PROCEDURE DoORG;
  (*
        Relocates the origin of code produced from source line onwards.
  *)
  VAR
    Origin: LONGINT;
    OriginType: SymbolStatus;

  BEGIN
    Length := 0;
    IF DecInstr.NoOfOperands = 1 THEN
      IF DecInstr.Operand[1].NoOfIndices = 0 THEN
        Evaluate(DecInstr.Operand[1].Argument, Origin, OriginType);
        IF OriginType = Absolute THEN
          IF (Origin >= MEMLOW) AND (Origin <= MEMHIGH) THEN
            SetLocation(LONGCARD(Origin))
          ELSE
            Raise(Code, Error, LocationRangeError)
          END
        ELSE
          SetLocation(LONGCARD(Origin) - CurrentLocation());
          Raise(Code, Warning, RelativeError)
        END
      ELSE
        Raise(Code, Error, IndicesCountError)
      END
    ELSE
      Raise(Code, Error, OperandCountError)
    END
  END DoORG;


  PROCEDURE DoEQU;
  (*
        Equates an expression to a symbol.
  *)
  VAR
    Result: LONGINT;
    ResultType: SymbolStatus;
    AmendEntry: TableType;

  BEGIN
    Length := 0;
    IF PassNo = 1 THEN
      IF DecInstr.NoOfOperands = 1 THEN
        IF DecInstr.Operand[1].NoOfIndices = 0 THEN
          Evaluate(DecInstr.Operand[1].Argument, Result, ResultType);
          MakeSubstring(DecInstr.Label, 1, LengthOfString(DecInstr.Label),
                        AmendEntry.Key);
          AmendEntry.Kind := Symbol;
          AmendEntry.Value := Result;
          AmendEntry.Status := ResultType;
          Amend(AmendEntry)
        ELSE
          Raise(Code, Error, IndicesCountError)
        END
      ELSE
        Raise(Code, Error, OperandCountError)
      END
    END
  END DoEQU;


  PROCEDURE DoEND;
  END DoEND;


  PROCEDURE DoPAGE;
  (*
        If no arguments, advances by a page.
        If one argument, sets up page length.
        If two arguments, sets up page length and width.
  *)
  VAR
    Length, Width: LONGINT;
    LengthType, WidthType: SymbolStatus;

  BEGIN
    Length := 0;
    IF PassNo = 2 THEN
      IF (DecInstr.Operand[1].NoOfIndices = 0) AND
         (DecInstr.Operand[2].NoOfIndices = 0) THEN
        CASE DecInstr.NoOfOperands OF
          0: INCPage               |
          1: Evaluate(DecInstr.Operand[1].Argument, Length, LengthType);
             SetPageLength(VAL(CARDINAL, Length)) |
          2: Evaluate(DecInstr.Operand[1].Argument, Length, LengthType);
             SetPageLength(VAL(CARDINAL, Length));
             Evaluate(DecInstr.Operand[1].Argument, Width, WidthType);
             SetLineLength(VAL(CARDINAL, Width))
        END
      ELSE
        Raise(Code, Error, IndicesCountError)
      END
    END
  END DoPAGE;


  PROCEDURE DoTITLE;
  BEGIN
    SetTitle(DecInstr.Operand[1].Argument)
  END DoTITLE;


  PROCEDURE DoDATA;

  VAR
    DATA: LONGINT;
    DATAType: SymbolStatus;
    Data: Instruction;
    Counter: CARDINAL;

  BEGIN
    Length := 0;
    IF PassNo = 2 THEN
      IF DecInstr.NoOfOperands = 1 THEN
        IF DecInstr.Operand[1].NoOfIndices = 0 THEN
          IF PassNo = 2 THEN
            Evaluate(DecInstr.Operand[1].Argument, DATA, DATAType);
            FOR Counter := 1 TO 5 DO
              Data[Counter] := Word{}
            END
          END;
          CASE DecInstr.Modifier OF
            'B': Length := 1;
                 IF PassNo = 2 THEN
                   Data[1] := LongIntToWord(DATA);
                   AddCode(CurrentLocation(), Data, Length)
                 END
          |
            'W': Length := 2;
                 IF PassNo = 2 THEN
                   Data[1] := LongIntToWord(DATA);
                   AddCode(CurrentLocation(), Data, Length)
                 END
          |
            'L': Length := 4;
                 IF PassNo = 2 THEN
                   (*MSW Data[1] := Word(INTEGER(DATA >> 16));*)
                   Data[2] := LongIntToWord(DATA);
                   AddCode(CurrentLocation(), Data, Length)
                 END
          END
        ELSE
          Raise(Code, Error, IndicesCountError)
        END
      ELSE
        Raise(Code, Error, OperandCountError)
      END
    END
  END DoDATA;


  PROCEDURE DoRES;
  VAR
    RESSize: LONGINT;
    RESType: SymbolStatus;

  BEGIN
    Length := 0;
    IF DecInstr.NoOfOperands = 1 THEN
      IF DecInstr.Operand[1].NoOfIndices = 0 THEN
        Evaluate(DecInstr.Operand[1].Argument, RESSize, RESType);
        SetLocation(CurrentLocation() + VAL(LONGCARD, RESSize))
      ELSE
        Raise(Code, Error, IndicesCountError)
      END
    ELSE
      Raise(Code, Error, OperandCountError)
    END
  END DoRES;


  PROCEDURE DoBASE;
  CONST
    BaseError = "Invalid base (must be 2, 8, 10 or 16)";

  VAR
    Base: LONGINT;
    BaseType: SymbolStatus;

  BEGIN
    Length := 0;
    IF PassNo = 1 THEN
      IF DecInstr.NoOfOperands = 1 THEN
        IF DecInstr.Operand[1].NoOfIndices = 0 THEN
          Evaluate(DecInstr.Operand[1].Argument, Base, BaseType);
          IF BaseType = Absolute THEN
            CASE VAL(CARDINAL, Base) OF
              2:  ChangeBase(Bin)        |
              8:  ChangeBase(Oct)        |
              10: ChangeBase(Dec)        |
              16: ChangeBase(Hex)
            ELSE
              Raise(Code, Error, BaseError)
            END
          ELSE
            Raise(Code, Error, RelativeError)
          END
        ELSE
          Raise(Code, Error, IndicesCountError)
        END
      ELSE
        Raise(Code, Error, OperandCountError)
      END
    END
  END DoBASE;


  PROCEDURE DoSWITCH(Switch: SwitchType);
  VAR
    Result: LONGINT;
    ResultType: SymbolStatus;
    SwitchStatus: BOOLEAN;

  BEGIN
    Length := 0;
    IF DecInstr.NoOfOperands = 1 THEN
      IF DecInstr.Operand[1].NoOfIndices = 0 THEN
        Evaluate(DecInstr.Operand[1].Argument, Result, ResultType);
        IF ResultType = Absolute THEN
          IF Result = 1 THEN
            SwitchStatus := TRUE
          ELSE
            SwitchStatus := FALSE
          END;
          CASE Switch OF
            SymbolSwitch:   SymbolTable(SwitchStatus)       |
            ObjectSwitch:   ObjectOutput(SwitchStatus)
          END
        ELSE
          Raise(Code, Error, RelativeError)
        END
      ELSE
        Raise(Code, Error, IndicesCountError)
      END
    ELSE
      Raise(Code, Error, OperandCountError)
    END
  END DoSWITCH;


  PROCEDURE DoOBJ;
  END DoOBJ;


BEGIN
  CASE Type OF
    1000: DoORG                 |
    1001: DoEQU                 |
    1002: DoEND                 |
    1003: DoPAGE                |
    1004: DoTITLE               |
    1005: DoDATA                |
    1006: DoRES                 |
    1007: DoBASE                |
    1008: DoSWITCH(SymbolSwitch)|
    1009: DoSWITCH(ObjectSwitch)
  END

END AssemblePseudoOp;


PROCEDURE PseudoOpsShutdown;
END PseudoOpsShutdown;


BEGIN
(*
        Main program part inserts all the available pseudo-ops in the hash-
        table. All pseudo-ops in this module have a type number of greater
        than 1000, so there is plenty of room for op-codes (they could use
        greater than the last pseudo-op if necessary - unlikely!).
*)
  InsertCommand("ORG",    Word{}, 1000);
  InsertCommand("EQU",    Word{}, 1001);
  InsertCommand("END",    Word{}, 1002);
  InsertCommand("PAGE",   Word{}, 1003);
  InsertCommand("TITLE",  Word{}, 1004);
  InsertCommand("DATA",   Word{}, 1005);
  InsertCommand("RES",    Word{}, 1006);
  InsertCommand("BASE",   Word{}, 1007);
  InsertCommand("SYMBOL", Word{}, 1008);
  InsertCommand("OBJECT", Word{}, 1009);
END PseudoOps.

