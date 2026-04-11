IMPLEMENTATION MODULE TableExt;

(*
	Module: TableExt	Version 1.0	(c) 1989 Mark Wickens
	
	Created: 24-12-89
	
	This module serves two purposes.
	
	(1).  It contains all the data specifics so that any changes to the
	record type stored within the table are contained in one module only.
	
	(2).  It extends the basic table operations to allow specific fields
	of a table record to be specified as parameters in an insert procedure,
	allowing the initial set-up of the table to be performed without
	reference to variables.
*)

FROM ADM	IMPORT	WORDLENGTH;
FROM Table	IMPORT	Insert, IsIn, IsRoom;
FROM Exceptions	IMPORT	ExceptionLevel, ExceptionType, Raise;
FROM MyStrings	IMPORT	EqualStrings, LengthOfString, CharInString, EndOfLine,
			InitialiseAString, LongestString, ArrayToString;
FROM Interface	IMPORT	ReadAString, WriteAString, ReadACard, WriteACard,
			WriteALine, ReadALongInt, WriteALongInt, StdIn, StdOut;
			
CONST
  TableFullError	= "Table size has exceeded memory availability";
  InsertError		= "Key has already been inserted in table";
  WordLengthError	= "Length of mask string is not WORDLENGTH";


(* Extended Operations. *)


PROCEDURE ConvertTo(Mask: String): Word;

VAR
  ConvInstruction	: Word;
  Length, CurrentPos	: CARDINAL;

BEGIN
  Length := LengthOfString(Mask);
  IF Length <> WORDLENGTH THEN
    Raise(Internal, Error, WordLengthError)
  ELSE
    FOR CurrentPos := 0 TO WORDLENGTH - 1 DO
      IF CharInString(Mask, CurrentPos + 1) = '1' THEN
        INCL(ConvInstruction, WORDLENGTH - CurrentPos);
      END
    END
  END;
  RETURN ConvInstruction
END ConvertTo;


PROCEDURE ConvertFrom(Mask: Word; VAR ConvString: String);

VAR
  CurrentPos	: CARDINAL;
  StringSoFar	: ARRAY [1..LongestString] OF CHAR;

BEGIN
  InitialiseAString(ConvString);
  CurrentPos := 0;
  WHILE CurrentPos <= WORDLENGTH - 1 DO
    IF CurrentPos IN Mask THEN
      StringSoFar[WORDLENGTH - CurrentPos] := '1'
    ELSE
      StringSoFar[WORDLENGTH - CurrentPos] := '0'
    END;
    INC(CurrentPos)
  END;
  StringSoFar[WORDLENGTH + 1] := EndOfLine;
  ArrayToString(StringSoFar, ConvString)
END ConvertFrom;


PROCEDURE InsertCommand(Key: String; Mask: Word; Type: CARDINAL);

VAR
  Temp: TableType;

BEGIN
  Temp.Key	:= Key;
  Temp.Kind	:= Command;
  Temp.Mask	:= Mask;
  Temp.Type	:= Type;
  IF IsRoom() THEN
    IF IsIn(Key) THEN
      Raise(User, Error, InsertError)
    ELSE
      Insert(Temp)
    END
  ELSE
    Raise(User, Error, TableFullError)
  END
END InsertCommand;


PROCEDURE InsertSymbol(Key: String; Value: LONGINT; Status: SymbolStatus);

VAR
  Temp: TableType;

BEGIN
  Temp.Key	:= Key;
  Temp.Kind	:= Symbol;
  Temp.Value	:= Value;
  Temp.Status	:= Status;
  IF IsRoom() THEN
    IF IsIn(Key) THEN
      Raise(User, Error, InsertError)
    ELSE
      Insert(Temp)
    END
  ELSE
    Raise(User, Error, TableFullError)
  END
END InsertSymbol;


(* I/O Operations. *)


PROCEDURE GetRec(Input: FileHandle; KeyToInput: String; VAR NewRec: TableType);

VAR
  What		: String;
  BitPattern	: String;
  InputValue	: LONGINT;
  Prompts	: BOOLEAN;

BEGIN
  InitialiseAString(What);
  InitialiseAString(BitPattern);
  IF Input = StdIn THEN
    Prompts := TRUE
  ELSE
    Prompts := FALSE
  END;
  WITH NewRec DO
    Key := KeyToInput;
    IF Prompts THEN
      WriteAString(StdOut, "Entry Type: ")
    END;
    ReadAString(Input, What);
    IF EqualStrings(What, "Command") THEN
      Kind := Command;
      IF Prompts THEN
        WriteAString(StdOut, "Bit Pattern: ")
      END;
      ReadAString(Input, BitPattern);
      Mask := ConvertTo(BitPattern);
      IF Prompts THEN
        WriteAString(StdOut, "Type: ")
      END;
      Type := ReadACard(Input)
    ELSIF EqualStrings(What, "Symbol") THEN
      Kind := Symbol;
      IF Prompts THEN
        WriteAString(StdOut, "Value: ")
      END;
      InputValue := ReadALongInt(Input);
      Value := InputValue;
      IF Prompts THEN
        WriteAString(StdOut, "Status: ")
      END;
      ReadAString(Input, What);
      IF    EqualStrings(What, "Absolute") THEN Status := Absolute
      ELSIF EqualStrings(What, "Relative") THEN Status := Relative
      ELSIF EqualStrings(What, "Register") THEN Status := Register
      ELSE
        Status := Absolute
      END
    END
  END
END GetRec;


PROCEDURE PutRec(Output: FileHandle; Record: TableType);

VAR
  Legends	: BOOLEAN;
  MaskString	: String;

BEGIN
  IF Output = StdOut THEN
    Legends := TRUE
  ELSE
    Legends := FALSE
  END;
  WITH Record DO
    IF Legends THEN
      WriteAString(StdOut, "Key: ")
    END;
    WriteAString(Output, Key);
    WriteALine(Output);
    IF Kind = Command THEN
      IF Legends THEN
        WriteAString(StdOut, "Kind: Command");
        WriteALine(StdOut);
        WriteAString(StdOut, "Bit Pattern: ");
      END;
      ConvertFrom(Mask, MaskString);
      WriteAString(Output, MaskString);
      WriteALine(Output);
      IF Legends THEN
        WriteAString(StdOut, "Type: ");
      END;
      WriteACard(StdOut, Type, 0);
      WriteALine(StdOut)
    ELSIF Kind = Symbol THEN
      IF Legends THEN
        WriteAString(StdOut, "Kind: Symbol");
        WriteALine(StdOut);
        WriteAString(StdOut, "Value: ")
      END;
      WriteALongInt(Output, Value, 0);
      WriteALine(Output);
      IF Legends THEN
        WriteAString(StdOut, "Status: ")
      END;
      CASE Status OF
        Absolute	: WriteAString(Output, "Absolute");
        		  WriteALine(Output)			 |
        Relative	: WriteAString(Output, "Relative");
        		  WriteALine(Output)			 |
        Register	: WriteAString(Output, "Regsiter");
        		  WriteALine(Output)
      END
    END
  END
END PutRec;


PROCEDURE TableExtShutdown;
END TableExtShutdown;


END TableExt.

