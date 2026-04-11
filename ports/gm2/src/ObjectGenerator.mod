IMPLEMENTATION MODULE ObjectGenerator;

(*
	MODULE: ObjectGenerator	Version 1.0	(c) 1989 Mark Wickens
	
	Created: 28-11-89
	Updated: 22-01-90	Added implementation module.
	
	Produces the object file in a format determined by calling module.
*)

FROM MyStrings		IMPORT	String, InitialiseAString, MakeSubstring,
                                ConcatStrings, LengthOfString;
FROM Interface		IMPORT	CreateAFile, CloseAFile, WriteALongHex,
				WriteAString, WriteAChar, FileHandle,
				WriteALine;
FROM Exceptions		IMPORT	Raise, ExceptionType, ExceptionLevel;
FROM ADM                IMPORT  MAXWORDSPERINSTRUCTION, WORDLENGTH;

CONST
  FormatError	= "Cannot change object code format while assembling";
  HexConversionError	= "Illegal Number to Hex Converter";

VAR
  ObjectFile: FileHandle;
  GenerateObject: BOOLEAN;
  CurrentFormat: ObjectFormat;

(* Constructors. *)
PROCEDURE StartObject(Filename: String);

VAR
  ObjectFName: String;

BEGIN
  IF GenerateObject THEN
    InitialiseAString(ObjectFName);
    MakeSubstring(Filename, 1, LengthOfString(Filename), ObjectFName);
    ConcatStrings(ObjectFName, ".OBJ");
    ObjectFile := CreateAFile(ObjectFName);
  END
END StartObject;


PROCEDURE StopObject;
BEGIN
  IF GenerateObject THEN
    CloseAFile(ObjectFile);
    GenerateObject := FALSE
  END
END StopObject;


PROCEDURE SetFormat(NewType: ObjectFormat);
BEGIN
  CurrentFormat := NewType
END SetFormat;


PROCEDURE WriteObject(MCode: Instruction; MCLength: CARDINAL);


  PROCEDURE Pow2(Number: CARDINAL): CARDINAL;

  VAR Sum, Counter: CARDINAL;

  BEGIN
    Sum := 1;
    IF Number > 0 THEN
      FOR Counter := 1 TO Number DO
        Sum := Sum * 2
      END;
    END;
    RETURN Sum
  END Pow2;


  PROCEDURE ConvertToHex(input: CARDINAL): CHAR;
  BEGIN
    CASE input OF
      0..9:	RETURN (CHR(ORD('0') + input)) |
      10..15:	RETURN (CHR(ORD('A') + input - 10))
    ELSE
      Raise(Internal, Error, HexConversionError)
    END
  END ConvertToHex;


VAR
  NoNeeded, CurrentWord, CurrentNybble, CurrentBit,
  NybbleSum, Sum					: INTEGER;
  HexDigit						: CHAR;

BEGIN
  IF (MCLength > 0) AND (MCLength <= MAXWORDSPERINSTRUCTION) THEN
    CurrentWord := 1;
    NybbleSum := 0;
    WHILE CurrentWord <= INTEGER(MCLength) DO
      CurrentNybble := (WORDLENGTH DIV 4) - 1;
      WHILE CurrentNybble >= 0 DO
        Sum := 0;
        CurrentBit := 0;
        WHILE CurrentBit <= 3 DO
          IF CARDINAL((CurrentNybble * 4) + CurrentBit)
          					 IN MCode[CurrentWord] THEN
            Sum := Sum + INTEGER(Pow2(CurrentBit))
          END;
          INC(CurrentBit)
        END;
        HexDigit := ConvertToHex(Sum);
        WriteAChar(ObjectFile, HexDigit);
        DEC(CurrentNybble);
        INC(NybbleSum)
      END;
      INC(CurrentWord);
    END
  END
END WriteObject;


PROCEDURE AddCode(Address: LONGCARD; MCCode: Instruction; MCLength: CARDINAL);
BEGIN
  IF GenerateObject AND (MCLength > 0) THEN
    IF CurrentFormat = Generic THEN
      WriteALongHex(ObjectFile, Address, 8);
      WriteAChar(ObjectFile, ' ');
      WriteObject(MCCode, MCLength);
      WriteALine(ObjectFile)
    END
  END
END AddCode;


PROCEDURE ObjectOutput(Switch: BOOLEAN);
BEGIN
  GenerateObject := Switch
END ObjectOutput;


PROCEDURE ObjectGeneratorShutdown;
BEGIN
  IF GenerateObject THEN
    CloseAFile(ObjectFile);
    GenerateObject := FALSE
  END
END ObjectGeneratorShutdown;


BEGIN
  GenerateObject := TRUE
END ObjectGenerator.

