IMPLEMENTATION MODULE ADM;

(*
	Module: ADM		Version 1.0	(c)1990	Mark Wickens
	
	Created: 22/01/90
	
	This is the module in the meta-assembler that performs the assembler
	specific operations.  This module defines assembler operation for the
	Motorola MC680x0 series of processors (specifically including
	instructions for the MC68000).  The instructions are as defined in
	the proposed IEEE Assembly Language Standard Draft of 1979.
*)

FROM Exceptions		IMPORT	Raise, ExceptionLevel, ExceptionType;
FROM TableExt		IMPORT	InsertCommand, InsertSymbol, SymbolStatus;
FROM Table		IMPORT	IsIn, Retrieve;
FROM TableExt		IMPORT	TableType;
FROM Location		IMPORT	CurrentLocation;
FROM MyStrings		IMPORT	EmptyString, InitialiseAString, CharInString,
				EqualStrings;
FROM Expression		IMPORT	Evaluate, CheckRegister;
FROM Lex		IMPORT	ScanOperand;
FROM PseudoOps          IMPORT  AssemblePseudoOp;

TYPE
  RegType		= (Data, Address);
  AddressingModeSet	= SET OF ValidAddressingModes;

CONST
  AMS1	= AddressingModeSet{Dir,Abs,Rel,Ind,Imm,Index,Reg,AutoPreInc,
		AutoPostInc,AutoPreDec,AutoPostDec,IndPreIndex,IndPostIndex};
  AMS2	= AddressingModeSet{Ind,AutoPreDec,IndPreIndex,Abs};
  AMS3	= AddressingModeSet{Ind,AutoPostInc,IndPreIndex,Abs};
  AMS4	= AddressingModeSet{Dir,Ind,AutoPostInc,AutoPreDec,IndPreIndex,Abs};
  AMS5  = AddressingModeSet{Ind,AutoPreDec,AutoPostInc,IndPreIndex,Abs};

  LabelError		= "Label already defined - first value holds";
  CommandError		= "Command not defined";
  ModifierError		= "Wrong modifier";
  WrongRegisterError	= "Wrong register type";
  OperandNoError	= "Wrong number of operands or indices";
  BadRegisterError	= "Badly formed register";
  AbsoluteError		= "Argument must be absolute";
  AddrModeError		= "Wrong addressing mode";
  Type16ErrorA		= "Vector must be between 0 and 15";
  RegisterError		= "Argument must be a register";
  TooLargeError		= "Argument too large for modifier specified";
  AddressRegError	= "Register must be an address register";
  OutOfRangeError	= "Operand out of range";
  RelativeError		= "Argument must be relative";

PROCEDURE LongIntToWord(L: LONGINT): Word;
VAR
  Result: Word;
  I: CARDINAL;
  V: CARDINAL;
BEGIN
  (* Wrap L into the positive 0..65535 range via Euclidean-style mod, so
     negative values end up as their two's-complement low WORDLENGTH bits. *)
  V := VAL(CARDINAL, ((L MOD 65536) + 65536) MOD 65536);
  Result := Word{};
  FOR I := 0 TO WORDLENGTH - 1 DO
    IF ODD(V) THEN
      INCL(Result, I)
    END;
    V := V DIV 2
  END;
  RETURN Result
END LongIntToWord;


PROCEDURE RegisterType(Register: String): RegType;
VAR
  Indicator: CHAR;

BEGIN
  Indicator := CharInString(Register, 1);
  IF Indicator = "D" THEN
    RETURN Data
  ELSIF Indicator = "A" THEN
    RETURN Address
  ELSIF EqualStrings("SP", Register) THEN
    RETURN Address
  ELSE
    Raise(Code, Error, BadRegisterError);
    RETURN Data
  END
END RegisterType;


PROCEDURE AddBinary(VAR AI: Word; BinaryToAdd: Word; Position, Len: CARDINAL);
VAR
  BitCounter: CARDINAL;

BEGIN
  FOR BitCounter := Position TO Position + Len - 1 DO
    IF BitCounter - Position IN BinaryToAdd THEN
      INCL(AI, BitCounter)
    END
  END
END AddBinary;


PROCEDURE AddRegister(VAR AI: Word; RegisterToAdd: String; Position: CARDINAL);

VAR
  RegisterNumber: CHAR;
  RegisterValue: CARDINAL;

BEGIN
  RegisterNumber := CharInString(RegisterToAdd, 2);
  RegisterValue := ORD(RegisterNumber) - ORD('0');
  IF EqualStrings("SP", RegisterToAdd) THEN
    RegisterValue := 7
  END;
  (* Non-constant set constructors like Word{Position + 1, Position} crash
     gm2 15.2 with "internal compiler error: expecting ConstVar symbol", so
     we use INCL on the individual bit indices instead. *)
  CASE RegisterValue OF
    1:	INCL(AI, Position)                                                  |
    2:	INCL(AI, Position + 1)                                              |
    3:	INCL(AI, Position + 1); INCL(AI, Position)                          |
    4:	INCL(AI, Position + 2)                                              |
    5:	INCL(AI, Position + 2); INCL(AI, Position)                          |
    6:	INCL(AI, Position + 2); INCL(AI, Position + 1)                      |
    7:	INCL(AI, Position + 2); INCL(AI, Position + 1); INCL(AI, Position)
  END
END AddRegister;


PROCEDURE Assemble(DecInstr: DecodedLine; PassNo: CARDINAL;
		   VAR AI: Instruction; VAR Length: CARDINAL);

(*
	The comments for all TypeXX commands provide information of the type
	of instruction being assembled.  The key to the word shown is;
	
	O - Opcode.
	R - Register.
	S - Size.
	8 - 8 Bit Constant.
	1 - Count.
	E - Effective Address.
	D - Data.
	C - Condition.
	P - Displacement.
	V - Vector
*)

VAR
  CommandEntry	: TableType;
  ClearIdx	: CARDINAL;


  PROCEDURE CalcEA	(
  			Operand		: OperandElement;
  			ValidModes	: AddressingModeSet;
  			Modifier	: CHAR;
  			Position	: CARDINAL;
  			VAR AI		: Instruction
  		        ): CARDINAL;
  (*
  	This procedure determines the address type of the operand and
  	using that creates the appropriate bit pattern in the instruction AI
  	(on PassNo 2 only).  The resulting effective address is placed in
  	word 1 of the AI and then returns the length of the instruction
  	relative to the modifier used.
  *)

  VAR
    AddrMode	: ValidAddressingModes;
    Result      : LONGINT;
    ResultType	: SymbolStatus;
    Register	: String;


  PROCEDURE ARIWISecondWord(VAR SecondWord: Word;
  				IndexRegString, DisplacementString: String);
  VAR
    IndexRegister: String;
    Displacement: LONGINT;
    DisplacementType: SymbolStatus;

  BEGIN
    SecondWord := Word{};
    InitialiseAString(IndexRegister);
    IF CheckRegister(IndexRegString, IndexRegister) THEN
      IF RegisterType(IndexRegister) = Address THEN
        INCL(SecondWord, 15)
      END;
      AddRegister(SecondWord, IndexRegister, 12);
      INCL(SecondWord, 11);
      Evaluate(DisplacementString, Displacement, DisplacementType);
      IF (DisplacementType = Absolute) THEN
        IF (Displacement >= -128) AND (Displacement <= 127) THEN
          AddBinary(SecondWord, LongIntToWord(Displacement), 0 , 8)
        ELSE
          Raise(Code, Error, OutOfRangeError)
        END
      ELSE
        Raise(Code, Error, AbsoluteError)
      END
    ELSE
      Raise(Code, Error, RegisterError)
    END
  END ARIWISecondWord;


  BEGIN
    ScanOperand(Operand, AddrMode);
    InitialiseAString(Register);
    IF AddrMode IN ValidModes THEN
      CASE AddrMode OF
        Dir:
          IF PassNo = 1 THEN
            RETURN 1
          ELSE
            IF CheckRegister(Operand.Argument, Register) THEN
              IF RegisterType(Register) = Address THEN
                INCL(AI[1], Position + 3)		(* Set Mode *)
              END;
              AddRegister(AI[1], Register, Position)(* Set Register *)
	    ELSE
              Raise(Code, Error, RegisterError)
            END;
            RETURN 1
          END
        |
        Ind:
          IF PassNo = 1 THEN
            RETURN 1
          ELSE
            IF CheckRegister(Operand.Argument, Register) THEN
              IF RegisterType(Register) = Address THEN
                INCL(AI[1], Position + 4);
                AddRegister(AI[1], Register, Position);
              ELSE
                Raise(Code, Error, AddressRegError);
              END;
            ELSE
              Raise(Code, Error, RegisterError);
            END;
            RETURN 1
          END
        |
        AutoPostInc:
          IF PassNo = 1 THEN
       	    RETURN 1
       	  ELSE
       	    IF CheckRegister(Operand.Argument, Register) THEN
              IF RegisterType(Register) = Address THEN
                INCL(AI[1], Position + 3);
                INCL(AI[1], Position + 4);
                AddRegister(AI[1], Register, Position)
       	      ELSE
       	        Raise(Code, Error, AddressRegError)
       	      END
       	    ELSE
       	      Raise(Code, Error, RegisterError)
       	    END;
       	    RETURN 1
       	  END
       	|
       	AutoPreDec:
       	  IF PassNo = 1 THEN
            RETURN 1
       	  ELSE
            IF CheckRegister(Operand.Argument, Register) THEN
              IF RegisterType(Register) = Address THEN
                INCL(AI[1], Position + 5);
                AddRegister(AI[1], Register, Position)
              ELSE
                Raise(Code, Error, AddressRegError)
              END
      	    ELSE
       	      Raise(Code, Error, RegisterError)
       	    END;
       	    RETURN 1
       	  END
       	|
       	IndPostIndex:
       	  IF PassNo = 1 THEN
       	    RETURN 2
       	  ELSE
       	    IF CheckRegister(Operand.Argument, Register) OR
			    (CharInString(Operand.Argument, 1) = '*') THEN
       	      IF RegisterType(Register) = Address THEN
       	        IF (Operand.NoOfIndices = 1) AND
       	           (CharInString(Operand.Argument, 1) <> '*') THEN
(*
	Motorola Addressing mode:
	Address Register Indirect with Displacement
*)
		  INCL(AI[1], Position + 3);
		  INCL(AI[1], Position + 5);
		  AddRegister(AI[1], Register, Position);
		ELSIF (Operand.NoOfIndices = 1) AND
       	              (CharInString(Operand.Argument, 1) = '*') THEN
(*
	Motorola Addressing mode:
	Program Counter with Displacement
*)
		  INCL(AI[1], Position + 3);
		  INCL(AI[1], Position + 4);
		  INCL(AI[1], Position + 5);
		  INCL(AI[1], Position + 1)
		END;
		IF (Operand.NoOfIndices = 1) THEN
		  Evaluate(Operand.Indices[1], Result, ResultType);
		  IF ResultType = Absolute THEN
		    IF (Result >= -32768) AND (Result <= 32767) THEN
		      AI[2] := LongIntToWord(Result)
		    ELSE
		      Raise(Code, Error, OutOfRangeError)
		    END
	          ELSE
		    Raise(Code, Error, AbsoluteError)
	          END
	        ELSIF (Operand.NoOfIndices = 2) AND
       		      (CharInString(Operand.Argument, 1) <> "*") THEN
(*
	Motorola Addressing mode:
	Address Register Indirect with Index
*)
		  INCL(AI[1], Position + 5);
		  INCL(AI[1], Position + 4);
		  AddRegister(AI[1], Register, Position);
		  ARIWISecondWord(AI[2], Operand.Indices[1], Operand.Indices[2])
	        ELSIF (Operand.NoOfIndices = 2) AND
       		      (CharInString(Operand.Argument, 1) = "*") THEN
(*
	Motorola Addressing mode:
	Program Counter with Index
*)
		  INCL(AI[1], Position + 3);
		  INCL(AI[1], Position + 4);
		  INCL(AI[1], Position + 5);
		  INCL(AI[1], Position);
		  INCL(AI[1], Position + 1);
	        ELSIF (Operand.NoOfIndices = 2) THEN
		  Evaluate(Operand.Indices[1], Result, ResultType);
	          IF ResultType = Absolute THEN
	            IF (Result >= -128) AND (Result <= 127) THEN
	              AI[2] := LongIntToWord(Result);
	              IF CheckRegister(Operand.Indices[1], Register) THEN
		        AddRegister(AI[2], Register, 12);
		        IF RegisterType(Register) = Address THEN
			  INCL(AI[2], 15)
		        END;
		        INCL(AI[2], 11)
		      ELSE
		        Raise(Code, Error, RegisterError)
		      END
		    ELSE
		      Raise(Code, Error, OutOfRangeError)
		    END
		  ELSE
		    Raise(Code, Error, AbsoluteError)
		  END
	        END
	      ELSE
	        Raise(Code, Error, AbsoluteError)
	      END
	    ELSE
	      Raise(Code, Error, RegisterError)
	    END;
	    RETURN 2
	  END
        |
        Abs:
(*
	Motorola Addressing mode:
	Absolute Long Address
*)
          IF PassNo = 1 THEN
            RETURN 3
          ELSE
            Evaluate(Operand.Argument, Result, ResultType);
            IF ResultType = Absolute THEN
              INCL(AI[1], Position + 3);
              INCL(AI[1], Position + 4);
              INCL(AI[1], Position + 5);
              INCL(AI[1], Position);
              AddBinary(AI[3], LongIntToWord(Result), 0, 16);
              AddBinary(AI[2], LongIntToWord(Result DIV 65536), 0, 16)
            ELSE
              Raise(Code, Error, AbsoluteError)
            END;
            RETURN 3
          END
        |
        Imm:
          IF PassNo = 1 THEN
            IF (Modifier = 'B') OR (Modifier = 'W') THEN
              RETURN 2
            ELSE
              RETURN 3
            END
          ELSE
            Evaluate(Operand.Argument, Result, ResultType);
            IF ResultType = Absolute THEN
              INCL(AI[1], Position + 3);
              INCL(AI[1], Position + 4);
              INCL(AI[1], Position + 5);
	      INCL(AI[1], Position + 2);
	      IF (Result >= -128) AND (Result <= 127) AND
	         (Modifier = 'B') THEN
	        AI[2] := LongIntToWord(Result);
	        RETURN 2
	      ELSIF (Result >= -32768) AND (Result <= 32767) AND
		    (Modifier = 'W') THEN
		AI[2] := LongIntToWord(Result);
		RETURN 2
	      ELSIF Modifier = 'L' THEN
		AI[2] := LongIntToWord(Result DIV 32768);
		AI[3] := LongIntToWord(Result);
		RETURN 3
	      ELSE
		Raise(Code, Error, OutOfRangeError)
	      END
	    ELSE
	      Raise(Code, Error, AbsoluteError)
	    END;
	    RETURN 3
	  END
	|
	Rel:
          IF PassNo = 1 THEN
            IF (Modifier = 'B') OR (Modifier = 'W') THEN
              RETURN 2
            ELSE
              RETURN 3
            END
          ELSE
            Evaluate(Operand.Argument, Result, ResultType);
            IF ResultType = Absolute THEN
              INCL(AI[1], Position + 3);
              INCL(AI[1], Position + 4);
              INCL(AI[1], Position + 5);
	      INCL(AI[1], Position + 2);
	      IF (Result >= -128) AND (Result <= 127) AND
	         (Modifier = 'B') THEN
	        AI[2] := LongIntToWord(Result);
	        RETURN 2
	      ELSIF (Result >= -32768) AND (Result <= 32767) AND
		    (Modifier = 'W') THEN
		AI[2] := LongIntToWord(Result);
		RETURN 2
	      ELSIF Modifier = 'L' THEN
		AI[2] := LongIntToWord(Result DIV 32768);
		AI[3] := LongIntToWord(Result);
		RETURN 3
	      ELSE
		Raise(Code, Error, OutOfRangeError)
	      END
	    ELSE
	      Raise(Code, Error, AbsoluteError)
	    END;
	    RETURN 3
	  END
      END
    ELSE
      Raise(Code, Error, AddrModeError);
      RETURN 0
    END
  END CalcEA;


  PROCEDURE Type1(): CARDINAL;
  (*
  	Format: OOSSEEEEEEEEEEEE
  	Assembles: LD, ST & MV (equivalent to the Motorola MOVE instruction).
  	           These are selected with the type23 procedure to ensure
  	           that each mode has the right type of operands.
  *)

  VAR
    Length, Counter     : CARDINAL;
    FirstWordCopy       : Word;

  BEGIN
    Length := CalcEA(DecInstr.Operand[2], AMS1, DecInstr.Modifier, 6, AI);
    (* Swap Register and Mode positions in output word. *)
    FirstWordCopy := AI[1];
    FOR Counter := 6 TO 8 DO
      IF Counter IN FirstWordCopy THEN
        INCL(AI[1], Counter + 3)
      ELSE
        EXCL(AI[1], Counter + 3)
      END
    END;
    FOR Counter := 9 TO 11 DO
      IF Counter IN FirstWordCopy THEN
        INCL(AI[1], Counter - 3)
      ELSE
        EXCL(AI[1], Counter - 3)
      END
    END;
    AI[4] := AI[2];
    AI[5] := AI[3];
    Length := Length + CalcEA(DecInstr.Operand[1], AMS1, DecInstr.Modifier,
              0, AI) - 1;
    IF PassNo = 2 THEN
      CASE DecInstr.Modifier OF
      'B':
        AI[1] := AI[1] + Word{12}
      |
      'W':
        AI[1] := AI[1] + Word{12, 13}
      |
      'L':
        AI[1] := AI[1] + Word{13}
      ELSE
        Raise(Code, Error, ModifierError)
      END;
    END;
    RETURN Length
  END Type1;


  PROCEDURE Type2(): CARDINAL;
  (*
  	Format: OOOORRRMMMEEEEEE
  	Assembles: ADD, SUB, variant of CMP, variant of AND
  	           (Motorola: ADD, SUB, CMP, AND).
  *)

  VAR
   Length          : CARDINAL;
   Register        : String;
   LeftToRight     : BOOLEAN;

  BEGIN
    InitialiseAString(Register);
    IF CheckRegister(DecInstr.Operand[1].Argument, Register) THEN
      IF (DecInstr.NoOfOperands = 2) AND
         (DecInstr.Operand[1].NoOfIndices = 0) THEN
        LeftToRight := TRUE;
        Length := CalcEA(DecInstr.Operand[2], AMS1, DecInstr.Modifier, 0, AI);
      ELSE
        Raise(Code, Error, OperandNoError)
      END
    ELSIF CheckRegister(DecInstr.Operand[2].Argument, Register) THEN
      IF (DecInstr.NoOfOperands = 2) AND
         (DecInstr.Operand[2].NoOfIndices = 0) THEN
        LeftToRight := FALSE;
        Length := CalcEA(DecInstr.Operand[1], AMS1,
                         DecInstr.Modifier, 0, AI);
      ELSE
        Raise(Code, Error, OperandNoError)
      END
    ELSE
      Raise(Code, Error, RegisterError)
    END;
    IF PassNo = 2 THEN
      AddRegister(AI[1], Register, 9);
      IF RegisterType(Register) = Data THEN
        CASE DecInstr.Modifier OF
        'B':
          IF LeftToRight THEN
            AI[1] := AI[1] + Word{8}
          END
        |
        'W':
          IF LeftToRight THEN
            AI[1] := AI[1] + Word{8}
          END;
          AI[1] := AI[1] + Word{6}
        |
        'L':
          IF LeftToRight THEN
            AI[1] := AI[1] + Word{8}
          END;
          AI[1] := AI[1] + Word{7}
        ELSE
          Raise(Code, Error, ModifierError)
        END
      ELSE
        AI[1] := AI[1] + Word{6,7};
        CASE DecInstr.Modifier OF
        'L':
          AI[1] := AI[1] + Word{8}
        |
        'W':;
        ELSE
          Raise(Code, Error, ModifierError)
        END
      END
    END;
    RETURN Length
  END Type2;


  PROCEDURE Type3(): CARDINAL;
  (*
  	Format: OOOORRROOOEEEEEE
  	Assembles: MULU, MUL, DIVU, DIV, CHK (Motorola - MULU, MULS, DIVU,
  	           DIVS, CHK).
  *)

  VAR
    Length      : CARDINAL;
    Register    : String;

  BEGIN
    Length := CalcEA(DecInstr.Operand[1], AMS1, DecInstr.Modifier, 0, AI);
    IF PassNo = 2 THEN
      IF DecInstr.Modifier <> 'W' THEN
        Raise(Code, Error, ModifierError)
      ELSE
        IF DecInstr.Operand[2].NoOfIndices = 0 THEN
          InitialiseAString(Register);
          IF CheckRegister(DecInstr.Operand[2].Argument, Register) THEN
            IF RegisterType(Register) = Data THEN
              AddRegister(AI[1], Register, 9)
            ELSE
              Raise(Code, Error, WrongRegisterError)
            END
          ELSE
            Raise(Code, Error, RegisterError)
          END
        ELSE
          Raise(Code, Error, OperandNoError)
        END
      END
    END;
    RETURN Length
  END Type3;


  PROCEDURE Type4(): CARDINAL;
  (*
  	Format: OOOORRRMMMOOORRR
  *)

  BEGIN
    RETURN 0
  END Type4;


  PROCEDURE Type5(): CARDINAL;
  (*
  	Format: OOOORRROSSOOORRR
  	Assembles: ADDC, SUBC instructions (Motorola - ADDX, SUBX)
  *)

  VAR Register1, Register2: String;

  BEGIN
    IF PassNo = 2 THEN
      IF DecInstr.Modifier = 'L' THEN
        AI[1] := AI[1] + Word{7}
      ELSIF DecInstr.Modifier = 'W' THEN
        AI[1] := AI[1] + Word{6}
      ELSIF DecInstr.Modifier <> 'B' THEN
        Raise(Code, Error, ModifierError)
      END;
      IF (DecInstr.NoOfOperands = 2) AND (DecInstr.Operand[1].NoOfIndices = 0)
         AND (DecInstr.Operand[2].NoOfIndices = 0) THEN
        InitialiseAString(Register1);
        IF CheckRegister(DecInstr.Operand[1].Argument, Register1) THEN
          IF RegisterType(Register1) = Data THEN
            InitialiseAString(Register2);
            IF CheckRegister(DecInstr.Operand[2].Argument, Register2) THEN
              IF RegisterType(Register2) = Data THEN
                AddRegister(AI[1], Register1, 0);
                AddRegister(AI[1], Register2, 9)
              ELSE
                Raise(Code, Error, WrongRegisterError)
              END
            ELSE
              Raise(Code, Error, RegisterError)
            END
          ELSE
            Raise(Code, Error, WrongRegisterError)
          END
        ELSE
          Raise(Code, Error, RegisterError)
        END
      ELSE
        Raise(Code, Error, OperandNoError)
      END
    END;
    RETURN 1
  END Type5;


  PROCEDURE Type6(): CARDINAL;
  (*
  	Format: OOOORRROOOOOORRR
  	Assembles: SUBD, ADDD instructions (Motorola - SBCD, ABCD)
  	           Current implementation allows only Data Register to
  	           Data register operation.
  *)

  VAR Register1, Register2: String;

  BEGIN
    IF PassNo = 2 THEN
      IF DecInstr.Modifier = 'B' THEN
        IF (DecInstr.NoOfOperands = 2) AND (DecInstr.Operand[1].NoOfIndices = 0)
           AND (DecInstr.Operand[2].NoOfIndices = 0) THEN
          InitialiseAString(Register1);
          IF CheckRegister(DecInstr.Operand[1].Argument, Register1) THEN
            IF RegisterType(Register1) = Data THEN
              InitialiseAString(Register2);
              IF CheckRegister(DecInstr.Operand[2].Argument, Register2) THEN
                IF RegisterType(Register2) = Data THEN
                  AddRegister(AI[1], Register1, 0);
                  AddRegister(AI[1], Register2, 9)
                ELSE
                  Raise(Code, Error, WrongRegisterError)
                END
              ELSE
                Raise(Code, Error, RegisterError)
              END
            ELSE
              Raise(Code, Error, WrongRegisterError)
            END
          ELSE
            Raise(Code, Error, RegisterError)
          END
        ELSE
          Raise(Code, Error, OperandNoError)
        END
      ELSE
        Raise(Code, Error, ModifierError)
      END
    END;
    RETURN 1
  END Type6;


  PROCEDURE Type7(): CARDINAL;
  (*
  	Format: OOOORRRO88888888
  *)

  BEGIN
    RETURN 0
  END Type7;


  PROCEDURE Type8(): CARDINAL;
  (*
  	Format: OOOO111OSSOOORRR
  *)

  BEGIN
    RETURN 0
  END Type8;


  PROCEDURE Type9(): CARDINAL;
  (*
  	Format: OOOODDDOSSEEEEEE
  *)

  BEGIN
    RETURN 0
  END Type9;


  PROCEDURE Type10(): CARDINAL;
  (*
  	Format: OOOOCCCCOOEEEEEE
  	Assembles: Scc Instructions (Condition code field is implied in the
  	opcode mask.
  *)

  BEGIN
    RETURN CalcEA(DecInstr.Operand[1], AMS4, DecInstr.Modifier, 0, AI)
  END Type10;


  PROCEDURE Type11(): CARDINAL;
  (*
  	Format: OOOOCCCCPPPPPPPP
  	Assembles: Bcc Instructions (Condition code field is implied in the
  	opcode mask).
  *)

  VAR
    AddrMode	: ValidAddressingModes;
    Displacement: LONGINT;
    Dest	: LONGINT;
    DestType	: SymbolStatus;

  BEGIN
    IF PassNo = 1 THEN
      IF DecInstr.Modifier = 'B' THEN
        RETURN 1
      ELSIF DecInstr.Modifier = 'W' THEN
        RETURN 2
      ELSE
        RETURN 1
      END
    ELSE
      ScanOperand(DecInstr.Operand[1], AddrMode);
      IF (AddrMode = Rel) OR (AddrMode = Dir) THEN
        Evaluate(DecInstr.Operand[1].Argument, Dest, DestType);
        IF (DestType = Relative) OR (AddrMode = Rel) THEN
          Displacement := Dest - LONGINT(CurrentLocation()) - 2;
          IF DecInstr.Modifier = 'B' THEN
            IF (Displacement >= -128) AND (Displacement <= 127) THEN
              AddBinary(AI[1], LongIntToWord(Displacement), 0, 8);
              RETURN 1
            ELSE
              Raise(Code, Error, OutOfRangeError)
            END
          ELSIF DecInstr.Modifier = 'W' THEN
            IF (Displacement >= -32768) AND (Displacement <= 32767) THEN
              AI[2] := LongIntToWord(Displacement);
              RETURN 2
            ELSE
              Raise(Code, Error, OutOfRangeError)
            END
	  ELSE
	    Raise(Code, Error, ModifierError)
	  END
        ELSE
          Raise(Code, Error, RelativeError)
        END
      ELSE
        Raise(Code, Error, AddrModeError)
      END;
      RETURN 1
    END
  END Type11;


  PROCEDURE Type12(): CARDINAL;
  (*
  	Format: OOOOCCCCOOOOORRR
  	Assembles: DBcc Instructions (Condition code field is implied in the
  	opcode mask).
  *)

  VAR
    Register	: String;
    Length	: CARDINAL;
    AddrMode	: ValidAddressingModes;
    Dest	: LONGINT;
    Displacement: LONGINT;
    DestType	: SymbolStatus;

  BEGIN
    IF PassNo = 2 THEN
      IF DecInstr.Modifier = 'W' THEN
        InitialiseAString(Register);
        IF CheckRegister(DecInstr.Operand[1].Argument, Register) THEN
          ScanOperand(DecInstr.Operand[1], AddrMode);
          IF AddrMode = Dir THEN
            IF RegisterType(Register) = Data THEN
              AddRegister(AI[1], Register, 0);
              ScanOperand(DecInstr.Operand[2], AddrMode);
              IF (AddrMode = Rel) OR (AddrMode = Dir) THEN
                Evaluate(DecInstr.Operand[2].Argument, Dest, DestType);
                IF (DestType = Relative) OR (AddrMode = Rel) THEN
                  Displacement := Dest - LONGINT(CurrentLocation()) - 2;
                  IF (Displacement >= -32768) AND (Displacement <= 32767) THEN
                    AI[2] := LongIntToWord(Displacement)
                  ELSE
                    Raise(Code, Error, OutOfRangeError)
                  END
                ELSE
                  Raise(Code, Error, RelativeError)
                END
              ELSE
                Raise(Code, Error, AddrModeError)
              END
            ELSE
              Raise(Code, Error, WrongRegisterError)
            END
          ELSE
            Raise(Code, Error, AddrModeError)
          END
        ELSE
          Raise(Code, Error, AddrModeError)
        END
      ELSE
        Raise(Code, Error, ModifierError)
      END
    END;
    RETURN 2
  END Type12;


  PROCEDURE Type13(): CARDINAL;
  (*
  	Format: OOOOOOOOSSEEEEEE
  	Assembles: NEG, NEGC, NOT, TEST, CLR, immediate ADD, immediate SUB
  	(Motorola - NEG, NEGX, NOT, TST, CLR, ADDI, SUBI).
  *)
  VAR
    Length: CARDINAL;
    SaveWord: Word;

  BEGIN
    IF DecInstr.Modifier = 'W' THEN
      INCL(AI[1], 6)
    ELSIF DecInstr.Modifier = 'L' THEN
      INCL(AI[1], 7)
    ELSIF DecInstr.Modifier <> 'B' THEN
      Raise(Code, Error, ModifierError)
    END;
    IF EqualStrings("ADD", DecInstr.Command) OR
       EqualStrings("SUB", DecInstr.Command) THEN
      Length := CalcEA(DecInstr.Operand[2], AMS4, DecInstr.Modifier, 0, AI);
      AI[4] := AI[2];
      AI[5] := AI[3];
      SaveWord := AI[1];
      Length := Length + CalcEA(DecInstr.Operand[1], AddressingModeSet{Imm},
                DecInstr.Modifier, 0, AI) - 1;
      AI[1] := SaveWord;
      RETURN Length
    ELSE
      RETURN CalcEA(DecInstr.Operand[1], AMS1, DecInstr.Modifier, 0, AI)
    END
  END Type13;


  PROCEDURE Type14(): CARDINAL;
  (*
  	Format: OOOOOOOOOSEEEEEE
	Assembles: LDM, STM (Motorola - MOVEM)
  *)

  VAR
    Length	: CARDINAL;
    AddrMode	: ValidAddressingModes;
    RegMask	: LONGINT;
    RegMaskType	: SymbolStatus;
    VAMS	: AddressingModeSet;

  BEGIN
    IF PassNo = 2 THEN
      IF DecInstr.Modifier = 'L' THEN
        INCL(AI[1], 6)
      ELSIF DecInstr.Modifier = 'B' THEN
        Raise(Code, Error, ModifierError)
      END
    END;
    IF EqualStrings("STM", DecInstr.Command) THEN
      VAMS := AMS2
    ELSE
      VAMS := AMS3
    END;
    ScanOperand(DecInstr.Operand[2], AddrMode);
    Length := CalcEA(DecInstr.Operand[2], VAMS, DecInstr.Modifier, 0, AI);
    IF PassNo = 1 THEN
      RETURN Length + 1
    END;
    ScanOperand(DecInstr.Operand[1], AddrMode);
    IF AddrMode = Imm THEN
      Evaluate(DecInstr.Operand[1].Argument, RegMask, RegMaskType)
    ELSE
      Raise(Code, Error, AddrModeError);
      RegMask := 0;
      RegMaskType := Absolute
    END;
    IF Length >= 3 THEN
      AI[4] := AI[3];
      IF Length >= 2 THEN
        AI[3] := AI[2];
      END
    END;
    IF RegMaskType = Absolute THEN
      IF (RegMask >= 0) AND (RegMask <= 65536) THEN
        AI[2] := LongIntToWord(RegMask)
      ELSE
        Raise(Code, Error, OutOfRangeError)
      END
    ELSE
      Raise(Code, Error, AbsoluteError)
    END;
    RETURN Length + 1
  END Type14;


  PROCEDURE Type15(): CARDINAL;
  (*
  	Format: OOOOOOOOOOEEEEEE
  	Assembles: NBCD, (Motorola - JMP, JSR, PEA)
  *)

  BEGIN
    RETURN CalcEA(DecInstr.Operand[1], AMS1, DecInstr.Modifier, 0, AI)
  END Type15;


  PROCEDURE Type16(): CARDINAL;
  (*
  	Format: OOOOOOOOOOOOVVVV
  	Assembles: TRAP
  *)

  VAR
    AddrMode: ValidAddressingModes;
    Vector: LONGINT;
    RType: SymbolStatus;

  BEGIN
    IF PassNo = 1 THEN
      RETURN 1
    ELSE
      ScanOperand(DecInstr.Operand[1], AddrMode);
      IF AddrMode = Imm THEN
        IF (DecInstr.NoOfOperands = 1) AND
           (DecInstr.Operand[1].NoOfIndices = 0) THEN
          Evaluate(DecInstr.Operand[1].Argument, Vector, RType);
          IF RType = Absolute THEN
            IF (Vector >= 0) AND (Vector <= 15) THEN
              AddBinary(AI[1], LongIntToWord(Vector), 0, 4);
              RETURN 1
            ELSE
              Raise(Code, Error, Type16ErrorA)
            END
          ELSE
            Raise(Code, Error, AbsoluteError)
          END
        ELSE
          Raise(Code, Error, OperandNoError)
        END
      ELSE
        Raise(Code, Error, AddrModeError)
      END;
      RETURN 1
    END
  END Type16;


  PROCEDURE Type17(): CARDINAL;
  (*
  	Format: OOOOOOOOOOOOORRR
  	Assembles: EXT
  *)
  VAR Register: String;

  BEGIN
    IF PassNo = 1 THEN
      RETURN 1
    ELSE
      AI[1] := CommandEntry.Mask;
      InitialiseAString(Register);
      IF CheckRegister(DecInstr.Operand[1].Argument, Register) THEN
        IF (DecInstr.NoOfOperands = 1) AND
           (DecInstr.Operand[1].NoOfIndices = 0) THEN
          IF RegisterType(Register) = Data THEN
            AddRegister(AI[1], Register, 0);
            IF DecInstr.Modifier = 'B' THEN
              AI[1] := AI[1] + Word{7}
            ELSIF DecInstr.Modifier = 'W' THEN
              AI[1] := AI[1] + Word{6,7}
            ELSE
              Raise(Code, Error, ModifierError);
            END
          ELSE
            Raise(Code, Error, WrongRegisterError)
          END
        ELSE
          Raise(Code, Error, OperandNoError)
        END
      ELSE
        Raise(Code, Error, RegisterError);
      END;
      RETURN 1
    END
  END Type17;


  PROCEDURE Type18(): CARDINAL;
  (*
  	Format: OOOOOOOOOOOOOOOO
  *)

  BEGIN
    IF PassNo = 1 THEN
      RETURN 1
    ELSE
      AI[1] := CommandEntry.Mask;
      RETURN 1
    END
  END Type18;


  PROCEDURE Type19(): CARDINAL;

  (*
        Format: VARIABLE
        Assembles: Takes the standard mnemonic of ADD or SUB
                   and converts into Motorola format ADD/SUB or ADDA/SUBA or
                   or ADDI/SUBI (ADDQ/SUBQ is not supported).  The appropriate
                   type is the called from this.
  *)

  VAR
    Op1AddrMode, Op2AddrMode    : ValidAddressingModes;
    Register1, Register2        : String;

  BEGIN
    InitialiseAString(Register1);
    InitialiseAString(Register2);
    ScanOperand(DecInstr.Operand[1], Op1AddrMode);
    ScanOperand(DecInstr.Operand[2], Op2AddrMode);

    IF CheckRegister(DecInstr.Operand[2].Argument, Register2) THEN
      IF (DecInstr.NoOfOperands = 2) AND
         (DecInstr.Operand[2].NoOfIndices = 0) THEN
         RETURN Type2()
      ELSE
        Raise(Code, Error, OperandNoError)
      END
    ELSIF CheckRegister(DecInstr.Operand[1].Argument, Register1) THEN
      IF RegisterType(Register1) = Data THEN
        IF (DecInstr.NoOfOperands = 2) AND
           (DecInstr.Operand[2].NoOfIndices = 0) THEN
           RETURN Type2()
        ELSE
          Raise(Code, Error, OperandNoError)
        END
      ELSE
        Raise(Code, Error, WrongRegisterError)
      END
    ELSIF Op1AddrMode = Imm THEN
      IF (DecInstr.NoOfOperands = 2) AND
         (DecInstr.Operand[2].NoOfIndices = 0) THEN
        RETURN Type13()
      ELSE
        Raise(Code, Error, OperandNoError)
      END
    ELSE
      Raise(Code, Error, AddrModeError)
    END
  END Type19;


  PROCEDURE Type20(): CARDINAL;
  BEGIN
    RETURN 0
  END Type20;


  PROCEDURE Type21(): CARDINAL;
  (*
        Format: VARIABLE
        Assembles: All Shift Instructions.
  *)

  VAR
    Register1, Register2: String;
    Shift: LONGINT;
    ShiftType: SymbolStatus;
    AddrMode: ValidAddressingModes;

  BEGIN
    InitialiseAString(Register1);
    InitialiseAString(Register2);
    IF DecInstr.NoOfOperands = 1 THEN
      IF PassNo = 2 THEN
        AI[1] := AI[1] + Word{9, 7, 6}
      END;
      RETURN CalcEA(DecInstr.Operand[1], AMS5, DecInstr.Modifier, 0, AI)
    ELSE
      IF PassNo = 1 THEN
        RETURN 1
      END;
      IF CheckRegister(DecInstr.Operand[2].Argument, Register2) THEN
        IF RegisterType(Register2) = Data THEN
          CASE DecInstr.Modifier OF
          'B':;
          |
          'W':
            AI[1] := AI[1] + Word{6}
          |
          'L':
            AI[1] := AI[1] + Word{7}
          ELSE
            Raise(Code, Error, ModifierError)
          END;
          IF DecInstr.Operand[2].NoOfIndices = 0 THEN
            AddRegister(AI[1], Register2, 0);
            IF CheckRegister(DecInstr.Operand[1].Argument, Register1) THEN
              IF RegisterType(Register1) = Data THEN
                IF DecInstr.Operand[1].NoOfIndices = 0 THEN
                  AddRegister(AI[1], Register1, 9);
                  AI[1] := AI[1] + Word{5};
                ELSE
                  Raise(Code, Error, OperandNoError)
                END
              ELSE
                Raise(Code, Error, WrongRegisterError)
              END
            ELSE
              ScanOperand(DecInstr.Operand[1], AddrMode);
              IF AddrMode = Imm THEN
                Evaluate(DecInstr.Operand[1].Argument, Shift, ShiftType);
                IF ShiftType = Absolute THEN
                  IF (Shift >= 1) AND (Shift <= 8) THEN
                    IF Shift <> 8 THEN
                      AddBinary(AI[1], LongIntToWord(Shift), 9, 3);
                    END
                  ELSE
                    Raise(Code, Error, OutOfRangeError)
                  END
                ELSE
                  Raise(Code, Error, AbsoluteError)
                END
              ELSE
                Raise(Code, Error, AddrModeError)
              END
            END
          ELSE
            Raise(Code, Error, AddrModeError)
          END
        ELSE
          Raise(Code, Error, WrongRegisterError)
        END
      ELSE
        Raise(Code, Error, RegisterError)
      END
    END;
    RETURN 1
  END Type21;


  PROCEDURE Type22(): CARDINAL;
  (*
        Format: VARIABLE
        Selects: between two types of format possible with instructions
                 TEST1, TESTSET, TESTCLR, TESTNOT.
  *)

  VAR
    Register: String;
    AddrMode: ValidAddressingModes;
    Result: LONGINT;
    ResultType: SymbolStatus;
    Length: CARDINAL;

  BEGIN
    InitialiseAString(Register);
    IF CheckRegister(DecInstr.Operand[1].Argument, Register) THEN
      IF RegisterType(Register) = Data THEN
        RETURN Type3()
      ELSE
        Raise(Code, Error, WrongRegisterError);
        RETURN 0
      END
    ELSE
      ScanOperand(DecInstr.Operand[1], AddrMode);
      IF AddrMode = Imm THEN
        Length := Type15();
        Evaluate(DecInstr.Operand[2].Argument, Result, ResultType);
        IF (Result > 0) AND (Result <= 256) AND (ResultType = Absolute) THEN
          AI[2] := LongIntToWord(Result);
          RETURN 2
        ELSE
          Raise(Code, Error, OutOfRangeError);
          RETURN 0
        END
      ELSE
        Raise(Code, Error, AddrModeError);
        RETURN 0
      END
    END
  END Type22;


  PROCEDURE Type23(): CARDINAL;
  (*
        Format: OOSSEEEEEEEEEEEE
        Selects: between LD, ST and MOV instructions.
                 (Motorola - MOVE, MOVEA)

        Load instructions operands are swapped because they are the
        opposite way around to the Motorola standard.
  *)
  VAR
    Register: String;
    TempOp1, TempOp2: OperandElement;

  BEGIN
    IF CheckRegister(DecInstr.Operand[1].Argument, Register) THEN
      IF NOT CheckRegister(DecInstr.Operand[2].Argument, Register) THEN
        (* Must be either LD or ST instruction. *)
        IF EqualStrings(DecInstr.Command, "LD") THEN
          (* LD instruction so swap operands. *)
          TempOp1 := DecInstr.Operand[1];
          TempOp2 := DecInstr.Operand[2];
          DecInstr.Operand[1] := TempOp2;
          DecInstr.Operand[2] := TempOp1;
          RETURN Type1()
        ELSIF EqualStrings(DecInstr.Command, "ST") THEN
          (* ST instruction - no swap necessary. *)
          RETURN Type1()
        ELSE
          IF PassNo = 2 THEN
            Raise(Code, Error, AddrModeError);
          END;
          RETURN 0
        END
      ELSE
        (* Must be a register to register MV instruction. *)
        RETURN Type1()
      END
    ELSE
      (*
         First operand is not a register. Must be a memory to memory
         MV instruction.
      *)
      RETURN Type1()
    END
  END Type23;


  PROCEDURE Type24(): CARDINAL;
  (*
        Format: VARIABLE
        Assembles: XCH by selecting between Motorola equivalents of EXG
                   and SWAP.
  *)
  VAR
    Register1, Register2: String;

  BEGIN
    IF DecInstr.NoOfOperands = 1 THEN
      RETURN Type17()
    ELSE
      InitialiseAString(Register1);
      InitialiseAString(Register2);
      IF CheckRegister(DecInstr.Operand[1].Argument, Register1) AND
         CheckRegister(DecInstr.Operand[2].Argument, Register2) THEN
        IF RegisterType(Register1) = Data THEN
          IF RegisterType(Register2) = Data THEN
            AI[1] := AI[1] + Word{6}
          ELSE
            AI[1] := AI[1] + Word{3, 7}
          END
        ELSE
          IF RegisterType(Register2) = Data THEN
            Raise(Code, Error, WrongRegisterError)
          ELSE
            AI[1] := AI[1] + Word{3, 6}
          END
        END;
        RETURN Type6()
      ELSE
        Raise(Code, Error, RegisterError);
        RETURN 0
      END
    END
  END Type24;


  PROCEDURE Type25(): CARDINAL;
  (*
        Format: VARIABLE
        Assembles: CALL by selecting between motorola equivalents of
                   BSR and JSR.
  *)

  VAR
    AddrMode: ValidAddressingModes;

  BEGIN
    IF DecInstr.NoOfOperands = 1 THEN
      ScanOperand(DecInstr.Operand[1], AddrMode);
      IF AddrMode = Imm THEN
        (* Must be a BSR instruction. *)
        RETURN Type11()
      ELSE
        RETURN Type15()
      END
    ELSE
      Raise(Code, Error, OperandNoError)
    END
  END Type25;


  PROCEDURE Type26(): CARDINAL;
  BEGIN
    RETURN 0
  END Type26;


BEGIN
  (* Always reset Length and AI at entry — the original 1990 code left
     them uninitialised when the line carried no command (blank line or
     label-only), which caused the caller's copy to retain values from
     the previous call and thereby re-emit the previous instruction's
     bytes on every blank line. gm2 surfaces this via its "attempting
     to access Length before it has been initialised" warning. *)
  Length := 0;
  FOR ClearIdx := 1 TO MAXWORDSPERINSTRUCTION DO
    AI[ClearIdx] := Word{}
  END;
  IF PassNo = 1 THEN
    IF NOT EmptyString(DecInstr.Label) THEN
      IF NOT(IsIn(DecInstr.Label)) THEN
        InsertSymbol(DecInstr.Label, CurrentLocation(), Relative)
      ELSE
        Raise(Code, Warning, LabelError)
      END
    END
  END;
  IF NOT(EmptyString(DecInstr.Command)) THEN
    IF IsIn(DecInstr.Command) THEN
      CommandEntry := Retrieve(DecInstr.Command);
      AI[1] := CommandEntry.Mask;
      CASE CommandEntry.Type OF
        1:	Length :=  Type1()	|
        2:	Length :=  Type2()	|
        3:	Length :=  Type3()	|
        4:	Length :=  Type4()	|
        5:	Length :=  Type5()	|
        6:	Length :=  Type6()	|
        7:	Length :=  Type7()	|
        8:	Length :=  Type8()	|
        9:	Length :=  Type9()	|
        10:	Length :=  Type10()	|
        11:	Length :=  Type11()	|
        12:	Length :=  Type12()	|
        13:	Length :=  Type13()	|
        14:	Length :=  Type14()	|
        15:	Length :=  Type15()	|
        16:	Length :=  Type16()	|
        17:	Length :=  Type17()	|
        18:	Length :=  Type18()	|
        19:	Length :=  Type19()	|
        20:	Length :=  Type20()	|
        21:	Length :=  Type21()	|
        22:	Length :=  Type22()	|
        23:	Length :=  Type23()	|
        24:	Length :=  Type24()	|
        25:	Length :=  Type25()	|
        26:	Length :=  Type26()
      ELSE
        AssemblePseudoOp(DecInstr, PassNo, CommandEntry.Type, AI, Length)
      END
    ELSE
      Raise(Code, Error, CommandError)
    END
  END
END Assemble;


PROCEDURE InsertOpcodesInTable;
BEGIN
  InsertCommand("ADD",		Word{12,14,15},			19);
  InsertCommand("ADDD",		Word{8,14,15}, 			6);
  InsertCommand("ADDC",		Word{8,12,14,15},		5);
  InsertCommand("SUB",		Word{12,15}, 			19);
  InsertCommand("SUBD",		Word{8,15}, 			6);
  InsertCommand("SUBC",		Word{8,12,15}, 			5);
  InsertCommand("MULU",		Word{6,7,14,15}, 		3);
  InsertCommand("MUL",		Word{6,7,8,14,15}, 		3);
  InsertCommand("DIVU",		Word{6,7,15}, 			3);
  InsertCommand("DIV",		Word{6,7,8,15}, 		3);
  InsertCommand("CMP",		Word{12,13,15}, 		19);
  InsertCommand("NEG",		Word{10,14}, 			13);
  InsertCommand("NEGC",		Word{14}, 			13);
  InsertCommand("NEGD",		Word{11,14}, 			15);
  InsertCommand("EXT",		Word{11,14}, 			17);
  InsertCommand("DBR",		Word{3,6,7,12,14}, 		12);
  InsertCommand("DBE",		Word{3,6,7,8,9,10,12,14},	12);
  InsertCommand("DBNE",		Word{3,6,7,9,10,12,14}, 	12);
  InsertCommand("DBC",		Word{3,6,7,8,10,12,14}, 	12);
  InsertCommand("DBNC",		Word{3,6,7,10,12,14}, 		12);
  InsertCommand("DBP",		Word{3,6,7,9,11,12,14}, 	12);
  InsertCommand("DBN",		Word{3,6,7,8,9,11,12,14}, 	12);
  InsertCommand("DBV",		Word{3,6,7,8,11,12,14}, 	12);
  InsertCommand("DBNV",		Word{3,6,7,11,12,14}, 		12);
  InsertCommand("DBGT",		Word{3,6,7,9,10,11,12,14}, 	12);
  InsertCommand("DBGE",		Word{3,6,7,10,11,12,14}, 	12);
  InsertCommand("DBLT",		Word{3,6,7,8,10,11,12,14}, 	12);
  InsertCommand("DBLE",		Word{3,6,7,8,9,10,11,12,14}, 	12);
  InsertCommand("DBH",		Word{3,6,7,9,12,14}, 		12);
  InsertCommand("DBNH",		Word{3,6,7,8,12,14}, 		12);
  InsertCommand("AND",		Word{14,15}, 			19);
  InsertCommand("OR",		Word{15}, 			19);
  InsertCommand("XOR",		Word{12,13,15}, 		19);
  InsertCommand("NOT",		Word{9,10,14}, 			13);
  InsertCommand("SHR",		Word{3,13,14,15}, 		21);
  InsertCommand("SHL",		Word{3,8,13,14,15}, 		21);
  InsertCommand("SHRA",		Word{13,14,15}, 		21);
  InsertCommand("SHLA",		Word{8,13,14,15}, 		21);
  InsertCommand("ROR",		Word{3,4,13,14,15}, 		21);
  InsertCommand("ROL",		Word{3,4,8,13,14,15}, 		21);
  InsertCommand("RORC",		Word{4,13,14,15}, 		21);
  InsertCommand("ROLC",		Word{4,8,13,14,15}, 		21);
  InsertCommand("TEST",		Word{9,11,14}, 			13);
  InsertCommand("TEST1",	Word{8}, 			22);
  InsertCommand("TESTSET",	Word{6,7,8}, 			22);
  InsertCommand("TESTCLR",	Word{7,8}, 			22);
  InsertCommand("TESTNOT",	Word{6,8}, 			22);
  InsertCommand("CHK",		Word{7,8,14},  			3);
  InsertCommand("LD",		Word{}, 			23);
  InsertCommand("LDM",		Word{7,10,11,14}, 		14);
  InsertCommand("ST",		Word{}, 			23);
  InsertCommand("STM",		Word{7,11,14}, 			14);
  InsertCommand("MOV",		Word{}, 			23);
  InsertCommand("XCH",		Word{8,14,15}, 			24);
  InsertCommand("CLR",		Word{9,14}, 			13);
  InsertCommand("SET",		Word{6,7,12,14}, 		10);
  InsertCommand("SETE",		Word{6,7,8,9,10,12,14}, 	10);
  InsertCommand("SETNE",	Word{6,7,9,10,12,14}, 		10);
  InsertCommand("SETC",		Word{6,7,8,10,12,14}, 		10);
  InsertCommand("SETNC",	Word{6,7,10,12,14}, 		10);
  InsertCommand("SETP",		Word{6,7,9,11,12,14}, 		10);
  InsertCommand("SETN",		Word{6,7,8,9,11,12,14}, 	10);
  InsertCommand("SETV",		Word{6,7,8,11,12,14}, 		10);
  InsertCommand("SETNV",	Word{6,7,11,12,14}, 		10);
  InsertCommand("SETGT",	Word{6,7,9,10,11,12,14}, 	10);
  InsertCommand("SETGE",	Word{6,7,10,11,12,14}, 		10);
  InsertCommand("SETLT",	Word{6,7,8,10,11,12,14}, 	10);
  InsertCommand("SETLE",	Word{6,7,8,9,10,11,12,14}, 	10);
  InsertCommand("SETH",		Word{6,7,9,12,14}, 		10);
  InsertCommand("SETNH",	Word{6,7,8,9,12,14}, 		10);
  InsertCommand("BR",		Word{13,14}, 			25);
  InsertCommand("BE",		Word{8,9,10,13,14}, 		11);
  InsertCommand("BNE",		Word{9,10,13,14}, 		11);
  InsertCommand("BC",		Word{8,10,13,14}, 		11);
  InsertCommand("BNC",		Word{10,13,14}, 		11);
  InsertCommand("BP",		Word{9,11,13,14}, 		11);
  InsertCommand("BN",		Word{8,9,11,13,14}, 		11);
  InsertCommand("BV",		Word{8,11,13,14}, 		11);
  InsertCommand("BNV",		Word{11,13,14}, 		11);
  InsertCommand("BGT",		Word{9,10,11,13,14}, 		11);
  InsertCommand("BGE",		Word{10,11,13,14}, 		11);
  InsertCommand("BLT",		Word{8,10,11,13,14}, 		11);
  InsertCommand("BLE",		Word{8,9,10,11,13,14}, 		11);
  InsertCommand("BH",		Word{9,13,14}, 			11);
  InsertCommand("BNH",		Word{8,9,13,14}, 		11);
  InsertCommand("CALL",		Word{8,13,14}, 			25);
  InsertCommand("RET",		Word{0,2,4,5,6,9,10,11,14}, 	18);
  InsertCommand("RETR",		Word{0,1,2,4,5,6,9,10,11,14},	18);
  InsertCommand("RETE",		Word{0,1,4,5,6,9,10,11,14}, 	18);
  InsertCommand("NOP",		Word{0,4,5,6,9,10,11,14}, 	18);
  InsertCommand("PUSH",		Word{6,11,14}, 			26);
  InsertCommand("POP",		Word{6,7,8,14}, (* ** *)	26);
  InsertCommand("WAIT",		Word{1,4,5,6,9,10,11,14}, 	18);
  InsertCommand("BRK",		Word{6,9,10,11,14}, 		16);
  InsertCommand("BRKV",		Word{1,2,4,5,6,9,10,11,14}, 	18);
  InsertCommand("RESET",	Word{4,5,6,9,10,11,14},		18)
END InsertOpcodesInTable;


PROCEDURE ADMShutdown;
END ADMShutdown;


BEGIN
  ValidRegisters[1] := "D0";
  ValidRegisters[2] := "D1";
  ValidRegisters[3] := "D2";
  ValidRegisters[4] := "D3";
  ValidRegisters[5] := "D4";
  ValidRegisters[6] := "D5";
  ValidRegisters[7] := "D6";
  ValidRegisters[8] := "D7";
  ValidRegisters[9] := "A0";
  ValidRegisters[10] := "A1";
  ValidRegisters[11] := "A2";
  ValidRegisters[12] := "A3";
  ValidRegisters[13] := "A4";
  ValidRegisters[14] := "A5";
  ValidRegisters[15] := "A6";
  ValidRegisters[16] := "A7";
  ValidRegisters[17] := "SP";
END ADM.

