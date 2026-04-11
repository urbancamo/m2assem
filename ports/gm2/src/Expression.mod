IMPLEMENTATION MODULE Expression;

(*
	MODULE: Expression	Version 1.0	(c) 1990 Mark Wickens
	
        Created: 03-01-90
	Updated: 05-01-90	Added error messages.
	
	Evaluates an expression according to the symbols in the symbol table
	and constants defined.
*)

FROM MyStrings		IMPORT	CharInString, LengthOfString, MakeSubstring,
				InitialiseAString, EndOfLine, EqualStrings,
				ArrayToString;
FROM TableExt		IMPORT	TableType, EntryType;
FROM Exceptions		IMPORT	Raise, ExceptionType, ExceptionLevel;
FROM Table		IMPORT	IsIn, Retrieve;
FROM Location		IMPORT	CurrentLocation;
FROM ADM		IMPORT	ValidRegisters, NOOFREGISTERS;

TYPE
  CharSet	= SET OF CHAR;

CONST
(* Character Sets. *)
  BaseSet	= CharSet{'B', 'Q', 'D', 'H'};
  BaseSepSet	= CharSet{"'"};
  BinSet	= CharSet{'0', '1'};
  OctSet 	= CharSet{'0'..'7'};
  DecSet	= CharSet{'0'..'9'};
  HexSet	= CharSet{'0'..'9', 'a'..'f', 'A'..'F'};
  OperatorSet	= CharSet{'.', '+', '-', '*', '/'};
  RegisterSet	= CharSet{'.'};
  EOLSet	= CharSet{EndOfLine};

(* Errors. *)
  UnknownBaseError	= "Base of constant is illegal";
  StatusError		= "Expression cannot be evaluated";
  AddError		= "Addition would cause overflow";
  SubError		= "Subraction would cause underflow";
  MultError		= "Multiplication would cause overflow";
  DivError		= "Cannot divide by zero";
  WrongTypeError	= "Symbol in expression is not addressable";
  OperandError		= "Unknown operand in expression";
  OperatorError		= "Invalid operator in expression";
  ExpError		= "Cannot raise to power less than 0";
  RegisterError		= "Unknown register";

VAR
  DefaultBase: BaseType;


PROCEDURE Evaluate(Input: String; VAR Result: LONGINT;
						VAR ResultType: SymbolStatus);

TYPE
  OpType = (Add, Sub, Mult, DivSig, DivUn, And, Or, Xor, Not, Shl, Shr, Mod,
  	    Exp, Bit);

VAR
  Op1, Op2 				: LONGINT;
  Op1Status, Op2Status	 		: SymbolStatus; 	
  CurrentPos				: CARDINAL;
  CurrentChar				: CHAR;
  Operator				: OpType;


  PROCEDURE GetOperand(VAR OperandValue: LONGINT;
		    		VAR OperandStatus: SymbolStatus): BOOLEAN;

  VAR
    Base: BaseType;

    PROCEDURE GetBase(VAR Base: BaseType): BOOLEAN;

    VAR
      CurrentBase	: CHAR;

    BEGIN
      CurrentChar := CAP(CharInString(Input, CurrentPos));
      IF CurrentChar IN BaseSet THEN
        CurrentBase := CurrentChar;
        INC(CurrentPos);
        CurrentChar := CharInString(Input, CurrentPos);
        IF CurrentChar IN BaseSepSet THEN
          CASE CurrentBase OF
            'B': Base := Bin |
            'Q': Base := Oct |
            'D': Base := Dec |
            'H': Base := Hex
          ELSE
            Raise(Code, Error, UnknownBaseError);
            DEC(CurrentPos);
            RETURN FALSE
          END;
          INC(CurrentPos);
          RETURN TRUE
        ELSE
          DEC(CurrentPos);
          RETURN FALSE
        END
      ELSE
        RETURN FALSE
      END
    END GetBase;


    PROCEDURE GetConstant(VAR OperandValue: LONGINT;
      				VAR OperandStatus: SymbolStatus): BOOLEAN;

    VAR
      ValidSet		: CharSet;
      ConstantStart	: CARDINAL;
      Length		: INTEGER;
      ConstantString	: String;
      Negative		: BOOLEAN;


      PROCEDURE ConvertBase(In: String; Base: BaseType): LONGINT;
	
      VAR
	CurrentValue	: LONGINT;
	Index		: INTEGER;
	BaseValue	: CARDINAL;

	
 	PROCEDURE Power(Value: LONGINT; Position: INTEGER; Base: CARDINAL)
 	  							: LONGINT;
 	
	VAR
	  Sum		: LONGINT;
	  Counter	: INTEGER;
	
	BEGIN
	  Sum := 1;
	  FOR Counter := 0 TO Position DO
	    Sum := Sum * VAL(LONGINT, Base)
	  END;
	  RETURN Sum * Value
	END Power;

	
	PROCEDURE ValueOfChar(In: CHAR): LONGINT;
	BEGIN
	  CASE In OF
	    '0'..'9': RETURN VAL(LONGINT, ORD(In) - ORD('0'))      |
	    'a'..'f': RETURN VAL(LONGINT, ORD(In) - ORD('a')) + 10 |
	    'A'..'F': RETURN VAL(LONGINT, ORD(In) - ORD('A')) + 10
	  ELSE
	    Raise(Code, Error, OperandError);
	    RETURN 0
	  END
	END ValueOfChar;
	

      BEGIN
        CASE Base OF
	  Bin: BaseValue := 2  |
	  Oct: BaseValue := 8  |
	  Dec: BaseValue := 10 |
	  Hex: BaseValue := 16
	END;
	CurrentValue := 0;
	Length := INTEGER(LengthOfString(In));
	FOR Index := 1 TO Length DO
	  CurrentValue := CurrentValue +
	    		    Power(ValueOfChar(CharInString(In, Index)),
	    		    	  Length - Index - 1, BaseValue)
	END;
	RETURN CurrentValue
      END ConvertBase;
	

    BEGIN
      CASE Base OF
        Bin: ValidSet := BinSet |
        Oct: ValidSet := OctSet |
        Dec: ValidSet := DecSet |
        Hex: ValidSet := HexSet
      END;
      ConstantStart := CurrentPos;
      CurrentChar := CharInString(Input, CurrentPos);
      IF CurrentChar = '-' THEN
        Negative := TRUE;
        INC(CurrentPos);
        INC(ConstantStart);
        CurrentChar := CharInString(Input, CurrentPos)
      ELSE
        Negative := FALSE
      END;
      WHILE CurrentChar IN ValidSet DO
        INC(CurrentPos);
        CurrentChar := CharInString(Input, CurrentPos)
      END;
      IF CurrentPos = ConstantStart THEN
        OperandValue := 0;
        OperandStatus := Absolute;
        RETURN FALSE
      ELSE
        InitialiseAString(ConstantString);
        MakeSubstring(Input, ConstantStart, CurrentPos - ConstantStart,
       							ConstantString);
        IF Negative THEN
          OperandValue := -ConvertBase(ConstantString, Base);
        ELSE
          OperandValue := ConvertBase(ConstantString, Base);
     	END;
        OperandStatus := Absolute;
        RETURN TRUE
      END
    END GetConstant;


    PROCEDURE GetSymbol(VAR OperandValue: LONGINT;
      			  VAR OperandStatus: SymbolStatus): BOOLEAN;

    VAR
      SymbolStart	: CARDINAL;
      Key		: String;
      Entry		: TableType;
      Negative		: BOOLEAN;

    BEGIN
      SymbolStart := CurrentPos;
      CurrentChar := CharInString(Input, CurrentPos);
      IF CurrentChar = '-' THEN
        Negative := TRUE;
        INC(CurrentPos);
        INC(SymbolStart);
        CurrentChar := CharInString(Input, CurrentPos)
      ELSE
        Negative := FALSE
      END;
      IF CurrentChar = '*' THEN
        IF Negative THEN
         OperandValue := -LONGINT(CurrentLocation());
        ELSE
         OperandValue := LONGINT(CurrentLocation())
        END;
        OperandStatus := Relative;
        INC(CurrentPos);
        CurrentChar := CharInString(Input, CurrentPos);
        RETURN TRUE
      ELSE
        WHILE NOT(CurrentChar IN OperatorSet + EOLSet) DO
          INC(CurrentPos);
          CurrentChar := CharInString(Input, CurrentPos)
        END;
        InitialiseAString(Key);
        MakeSubstring(Input, SymbolStart, CurrentPos - SymbolStart, Key);
        IF IsIn(Key) THEN
  	  Entry := Retrieve(Key);
	  IF Entry.Kind = Symbol THEN
	    IF Negative THEN
	      OperandValue := -Entry.Value
	    ELSE
	      OperandValue := Entry.Value
	    END;
	    OperandStatus := Entry.Status;
	    RETURN TRUE
	  ELSE
	    Raise(Code, Error, WrongTypeError);
	    OperandValue := 0;
	    OperandStatus := Absolute;
	    RETURN FALSE
	  END
        ELSE
          IF Negative THEN
            CurrentPos := SymbolStart - 1
          ELSE
  	    CurrentPos := SymbolStart
	  END;
	  RETURN FALSE
        END
      END
    END GetSymbol;


  BEGIN
    IF GetBase(Base) THEN
      IF NOT GetConstant(OperandValue, OperandStatus) THEN
        Raise(Code, Error, OperandError);
        RETURN FALSE
      END;
    ELSIF NOT(GetSymbol(OperandValue, OperandStatus)) THEN
      Base := DefaultBase;
      IF NOT GetConstant(OperandValue, OperandStatus) THEN
        RETURN FALSE
      END
    END;
    RETURN TRUE
  END GetOperand;


  PROCEDURE GetOperator(VAR Operator: OpType): BOOLEAN;

  VAR
    OperatorStart	: CARDINAL;
    OperatorString	: String;

  BEGIN
    OperatorStart := CurrentPos;
    CurrentChar := CharInString(Input, CurrentPos);
    INC(CurrentPos);
    CASE CurrentChar OF
      '+':	Operator := Add;
      		RETURN TRUE		|
      '-':	Operator := Sub;
      		RETURN TRUE		|
      '*':	IF CharInString(Input, CurrentPos) = '*' THEN
        	  INC(CurrentPos);
        	  Operator := Exp
        	ELSE
        	  Operator := Mult
          	END;
          	RETURN TRUE		|
      '/':	IF CharInString(Input, CurrentPos) = '/' THEN
                  INC(CurrentPos);
                  Operator := DivUn
                ELSE
                  Operator := DivSig
                END;
                RETURN TRUE		|
      '.':	CurrentChar := CharInString(Input, CurrentPos);
        	WHILE NOT(CurrentChar IN OperatorSet + EOLSet) DO
        	  INC(CurrentPos);
        	  CurrentChar := CharInString(Input, CurrentPos)
        	END;
        	InitialiseAString(OperatorString);
        	MakeSubstring(Input, OperatorStart,
        			CurrentPos - OperatorStart + 1, OperatorString);
		IF CurrentChar IN OperatorSet THEN
		  INC(CurrentPos);
		  IF EqualStrings(OperatorString, ".AND.") THEN
		    Operator := And;
		    RETURN TRUE
		  ELSIF EqualStrings(OperatorString, ".OR.") THEN
		    Operator := Or;
		    RETURN TRUE
		  ELSIF EqualStrings(OperatorString, ".XOR.") THEN
		    Operator := Xor;
		    RETURN TRUE
		  ELSIF EqualStrings(OperatorString, ".NOT.") THEN
		    Operator := Not;
		    RETURN TRUE
		  ELSIF EqualStrings(OperatorString, ".SHL.") THEN
		    Operator := Shl;
		    RETURN TRUE
		  ELSIF EqualStrings(OperatorString, ".SHR.") THEN
		    Operator := Shr;
		    RETURN TRUE
		  ELSIF EqualStrings(OperatorString, ".MOD.") THEN
		    Operator := Mod;
		    RETURN TRUE
		  ELSE
		    Raise(Code, Error, OperatorError);
		    RETURN FALSE
		  END
		ELSE
		  RETURN FALSE
		END			|
    EndOfLine:	RETURN FALSE
    ELSE
      Raise(Code,Error, OperatorError);
      RETURN FALSE
    END
  END GetOperator;


  PROCEDURE Eval(Operand1: LONGINT; Operand1Status: SymbolStatus;
  		 Operator: OpType;
  		 Operand2: LONGINT; Operand2Status: SymbolStatus;
  		 VAR Result: LONGINT; VAR ResultStatus: SymbolStatus);


    		
    PROCEDURE Valid(Op1Status, Op2Status: SymbolStatus; Operator: OpType;
    			VAR ResultType: SymbolStatus): BOOLEAN;

    BEGIN
      IF (Op1Status = Absolute) AND (Op2Status = Absolute) THEN
        ResultType := Absolute;
        RETURN TRUE
      ELSIF (Operator = Add) AND
      		(((Op1Status = Absolute) AND (Op2Status = Relative)) OR
      		 ((Op1Status = Relative) AND (Op2Status = Absolute))) THEN
        ResultType := Relative;
        RETURN TRUE
      ELSIF (Operator = Sub) AND
      		((Op1Status = Relative) AND (Op2Status = Absolute)) THEN
      	ResultType := Relative;
      	RETURN TRUE
      ELSIF (Operator = Sub) AND
      		((Op1Status = Relative) AND (Op2Status = Relative)) THEN
      	ResultType := Relative;
      	RETURN TRUE
      ELSE
        Raise(Code, Error, StatusError);
        RETURN FALSE
      END
    END Valid;


    PROCEDURE DoAdd(Op1, Op2: LONGINT): LONGINT;
    BEGIN
      IF (MAX(LONGINT) - ABS(Op1)) < ABS(Op2) THEN
        Raise(Code, Error, AddError);
        RETURN 0
      ELSE
        RETURN Op1 + Op2
      END
    END DoAdd;


    PROCEDURE DoSub(Op1, Op2: LONGINT): LONGINT;
    BEGIN
      IF (MAX(LONGINT) - ABS(Op1)) < ABS(Op2) THEN
        Raise(Code, Error, SubError);
        RETURN 0
      ELSE
        RETURN Op1 - Op2
      END
    END DoSub;


    PROCEDURE DoMult(Op1, Op2: LONGINT): LONGINT;
    BEGIN
      IF ABS(MAX(LONGINT) DIV Op1) < ABS(Op2) THEN
        Raise(Code, Error, MultError);
        RETURN 0
      ELSE
        RETURN Op1 * Op2
      END
    END DoMult;


    PROCEDURE DoDivSig(Op1, Op2: LONGINT): LONGINT;
    BEGIN
      IF Op2 = 0 THEN
        Raise(Code, Error, DivError);
        RETURN 0
      ELSE
        RETURN Op1 DIV Op2
      END
    END DoDivSig;


    PROCEDURE DoDivUn(Op1, Op2: LONGINT): LONGINT;
    BEGIN
      IF Op2 = 0 THEN
        Raise(Code, Error, DivError);
        RETURN 0
      ELSE
        RETURN ABS(Op1) DIV ABS(Op2)
      END
    END DoDivUn;


    (* DoShl and DoShr were originally mutually recursive via a FORWARD
       declaration (TopSpeed / PIM-2 style).  Rewritten to inline the
       opposite direction so gm2 doesn't need the FORWARD. *)

    PROCEDURE DoShl(Op1, Op2: LONGINT): LONGINT;
    VAR
      Counter, Op1ABS: LONGINT;

    BEGIN
      Op1ABS := ABS(Op1);
      IF Op2 >= 0 THEN
        FOR Counter := 0 TO Op2 - 1 DO
          Op1ABS := DoMult(Op1ABS, 2)
        END
      ELSE
        FOR Counter := 0 TO ABS(Op2) - 1 DO
          Op1ABS := Op1ABS DIV 2
        END
      END;
      RETURN Op1ABS
    END DoShl;


    PROCEDURE DoShr(Op1, Op2: LONGINT): LONGINT;
    VAR
      Counter, Op1ABS: LONGINT;

    BEGIN
      Op1ABS := ABS(Op1);
      IF Op2 >= 0 THEN
        FOR Counter := 0 TO Op2 - 1 DO
          Op1ABS := Op1ABS DIV 2
        END
      ELSE
        FOR Counter := 0 TO ABS(Op2) - 1 DO
          Op1ABS := DoMult(Op1ABS, 2)
        END
      END;
      RETURN Op1ABS
    END DoShr;


    PROCEDURE DoAnd(Op1, Op2: LONGINT): LONGINT;
    TYPE
      Bits	= SET OF [0..63];

    VAR
      Op1Bits, Op2Bits, Result	: Bits;

    BEGIN
      Op1Bits := Bits(Op1);
      Op2Bits := Bits(Op2);
      Result := Op1Bits * Op2Bits;
      RETURN LONGINT(Result)
    END DoAnd;


    PROCEDURE DoOr(Op1, Op2: LONGINT): LONGINT;
    TYPE
      Bits	= SET OF [0..63];

    VAR
      Op1Bits, Op2Bits, Result	: Bits;

    BEGIN
      Op1Bits := Bits(Op1);
      Op2Bits := Bits(Op2);
      Result := Op1Bits + Op2Bits;
      RETURN LONGINT(Result)
    END DoOr;


    PROCEDURE DoXor(Op1, Op2: LONGINT): LONGINT;
    TYPE
      Bits	= SET OF [0..63];

    VAR
      Op1Bits, Op2Bits, Result	: Bits;

    BEGIN
      Op1Bits := Bits(Op1);
      Op2Bits := Bits(Op2);
      Result := Op1Bits / Op2Bits;
      RETURN LONGINT(Result)
    END DoXor;


    PROCEDURE DoNot(Op1: LONGINT): LONGINT;
    TYPE
      Bits	= SET OF [0..63];

    VAR
      Op1Bits, Result	: Bits;

    BEGIN
      Op1Bits := Bits(Op1);
      Result := Bits{0..31} - Op1Bits;
      RETURN LONGINT(Result)
    END DoNot;


    PROCEDURE DoMod(Op1, Op2: LONGINT): LONGINT;
    BEGIN
      IF Op2 = 0 THEN
        Raise(Code, Error, DivError);
        RETURN 0
      ELSE
        RETURN Op1 MOD Op2
      END
    END DoMod;


    PROCEDURE DoExp(Op1, Op2: LONGINT): LONGINT;
    VAR
      Sum, Counter: LONGINT;

    BEGIN
      IF Op2 < 0 THEN
        Raise(Code, Error, ExpError);
        RETURN 0
      ELSE
        Sum := 1;
        FOR Counter := 0 TO Op2 - 1 DO
          Sum := DoMult(Sum, Op1)
        END
      END;
      RETURN Sum
    END DoExp;


  BEGIN
    IF Valid(Operand1Status, Operand2Status, Operator, ResultType) THEN
      CASE Operator OF
        Add:	Result := DoAdd(Operand1, Operand2)	|
        Sub:	Result := DoSub(Operand1, Operand2)	|
        Mult:	Result := DoMult(Operand1, Operand2)	|
        DivSig:	Result := DoDivSig(Operand1, Operand2)	|
        DivUn:	Result := DoDivUn(Operand1, Operand2)	|
        Shl:	Result := DoShl(Operand1, Operand2)	|
        Shr:	Result := DoShr(Operand1, Operand2)	|
        And:	Result := DoAnd(Operand1, Operand2)	|
        Or:	Result := DoOr(Operand1, Operand2)	|
        Xor:	Result := DoXor(Operand1, Operand2)	|
        Not:	Result := DoNot(Operand1)		|
        Mod:	Result := DoMod(Operand1, Operand2)	|
        Exp:	Result := DoExp(Operand1, Operand2)
      END
    END
  END Eval;

BEGIN
  CurrentPos := 1;
  IF GetOperand(Op1, Op1Status) THEN
    IF GetOperator(Operator) THEN
      IF NOT(Operator = Not) THEN
        IF GetOperand(Op2, Op2Status) THEN
          CurrentChar := CharInString(Input, CurrentPos);
          IF CurrentChar <> EndOfLine THEN
            Raise(Code, Error, OperandError)
          END
        ELSE
          Raise(Code, Error, OperandError)
        END
      END;
      Eval(Op1, Op1Status, Operator, Op2, Op2Status, Result, ResultType)
    ELSE
      Result := Op1;
      ResultType := Op1Status
    END
  ELSE
    Raise(Code, Error, OperandError);
    Result := 0;
    ResultType := Absolute
  END
END Evaluate;


PROCEDURE CheckRegister(Operand: String; VAR Register: String): BOOLEAN;

VAR
  CurrentPos, RegisterCount: CARDINAL;
  CurrentChar: CHAR;
  TempReg: ARRAY [1..133] OF CHAR;

BEGIN
  CurrentPos := 1;
  CurrentChar := CharInString(Operand, CurrentPos);
  IF CurrentChar IN RegisterSet THEN
    INC(CurrentPos);
    CurrentChar := CharInString(Operand, CurrentPos);
    WHILE NOT(CurrentChar IN EOLSet) DO
      TempReg[CurrentPos-1] := CAP(CurrentChar);
      INC(CurrentPos);
      CurrentChar := CharInString(Operand, CurrentPos)
    END;
    TempReg[CurrentPos-1] := EndOfLine;
    ArrayToString(TempReg, Register);
    FOR RegisterCount := 1 TO NOOFREGISTERS DO
      IF EqualStrings(Register, ValidRegisters[RegisterCount]) THEN
        RETURN TRUE
      END
    END;
    Raise(Code, Error, RegisterError);
    RETURN FALSE
  ELSE
    InitialiseAString(Register);
    RETURN FALSE
  END
END CheckRegister;


PROCEDURE CurrentBase(): BaseType;

BEGIN
  RETURN DefaultBase
END CurrentBase;


PROCEDURE ChangeBase(NewBase: BaseType);

BEGIN
  DefaultBase := NewBase
END ChangeBase;


PROCEDURE ExpressionShutdown;
END ExpressionShutdown;


BEGIN
  DefaultBase := Dec
END Expression.

