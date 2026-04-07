IMPLEMENTATION MODULE Interface;

(*
	MODULE:	Interface	Version 1.0	(c) 1990 Mark Wickens
	
	Created: 01-01-90
	
	This module provides the interface for the meta-assembler to the
	outside world.
*)

FROM Storage	IMPORT	ALLOCATE, DEALLOCATE, Available;
FROM Lib	IMPORT	ParamCount, ParamStr;
FROM MyStrings	IMPORT	EqualStrings, StringToArray, ArrayToString,
			LongestString, InitialiseAString, EndOfLine,
			MakeSubstring, ConcatStrings;
FROM Exceptions	IMPORT	Raise, ExceptionLevel, ExceptionType;
FROM Lib	IMPORT	Dos;
FROM SYSTEM	IMPORT	Registers;
IMPORT FIO;
IMPORT IO;

CONST
  (* Dubugging Switch *)
  IODebug               = TRUE;

  BufferSize		= 2;
  FileMissingError	= "File to be opened cannot be found";
  FileCreateError	= "File could not be created";
  FileOpenError		= "File could not be opened";
  FileCloseError	= "File could not be closed";
  OutOfMemoryError	= "File buffer could not be allocated";
  NotOpenError		= "File to be accessed is not open";
  ReadError		= "Attempt to read failed";
  WriteError		= "Attempt to write failed";

TYPE
  BufferPtr	= POINTER TO Buffer;
  Buffer	= ARRAY [0..(BufferSize * 512 + FIO.BufferOverhead)] OF BYTE;
  BufferList	= ARRAY [5..FIO.MaxOpenFiles] OF BufferPtr;

VAR
  UsedBuffers	: BufferList;
  CurrentBuffer	: CARDINAL;


PROCEDURE FileExists(FileName: String): BOOLEAN;
BEGIN
  RETURN FIO.Exists(FileName)
END FileExists;


PROCEDURE CreateAFile(F: String): FileHandle;

CONST
  FEE1          = "File ";
  FEE2          = " has been overwritten.";

VAR
  FHandle	: FileHandle;
  FileBuffer	: BufferPtr;
  FileExistsError: String;

BEGIN
  IF FIO.Exists(F) THEN
    InitialiseAString(FileExistsError);
    MakeSubstring(FEE1, 1, 10, FileExistsError);
    ConcatStrings(FileExistsError, F);
    ConcatStrings(FileExistsError, FEE2);
    Raise(Environment, Warning, FileExistsError);
  END;
  FHandle := FIO.Create(F);
  IF (FHandle = MAX(CARDINAL)) OR ((NOT IODebug AND (FIO.IOresult() <> 0))) THEN
    Raise(Environment, Error, FileCreateError);
    RETURN NULLFile
  ELSIF Available(SIZE(Buffer)) AND NOT ((FHandle = StdIn) OR
                                         (FHandle = StdOut) OR
                                         (FHandle = ErrOut) OR
                                         (FHandle = AuxDev) OR
                                         (FHandle = PrnDev)) THEN
    ALLOCATE(FileBuffer, SIZE(Buffer));
    FIO.AssignBuffer(FHandle, FileBuffer^);
    INC(CurrentBuffer);
    UsedBuffers[CurrentBuffer] := FileBuffer;
    RETURN FHandle
  ELSE
    Raise(Environment, Fatal, OutOfMemoryError);
    RETURN NULLFile
  END
END CreateAFile;


PROCEDURE OpenAFile(F: String): FileHandle;

VAR
  FHandle	: FileHandle;
  FileBuffer	: BufferPtr;

BEGIN
  IF NOT(FIO.Exists(F)) THEN
    Raise(Environment, Error, FileMissingError);
    RETURN NULLFile
  ELSE
    FHandle := FIO.Open(F);
    IF (FHandle = MAX(CARDINAL)) OR
                                 ((NOT IODebug AND (FIO.IOresult() <> 0))) THEN
      Raise(Environment, Error, FileOpenError);
      RETURN NULLFile
    ELSIF Available(SIZE(Buffer)) THEN
      ALLOCATE(FileBuffer, SIZE(Buffer));
      FIO.AssignBuffer(FHandle, FileBuffer^);
      INC(CurrentBuffer);
      UsedBuffers[CurrentBuffer] := FileBuffer;
      RETURN FHandle
    ELSE
      Raise(Environment, Fatal, OutOfMemoryError);
      RETURN NULLFile
    END
  END
END OpenAFile;


PROCEDURE CloseAFile(F: FileHandle);

BEGIN
  IF (F >= 5) AND (F <= FIO.MaxOpenFiles) THEN
    FIO.Close(F);
    IF (NOT IODebug) AND (FIO.IOresult() <> 0) THEN
      Raise(Environment, Error, FileCloseError)
    END
  END
END CloseAFile;


PROCEDURE DeleteAFile(Filename: String);

BEGIN
  IF FIO.Exists(Filename) THEN
    FIO.Erase(Filename)
  END
END DeleteAFile;


PROCEDURE EndOfFile(): BOOLEAN;

BEGIN
  RETURN FIO.EOF
END EndOfFile;


PROCEDURE ReadAString(F: FileHandle; VAR S: String);

BEGIN
  IF F <> NULLFile THEN
    IF F = FIO.StandardInput THEN
      IO.RdStr(S)
    ELSE
      FIO.RdStr(F, S)
    END;
    IF NOT FIO.OK THEN
      Raise(Environment, Fatal, ReadError)
    END
  ELSE
    Raise(Internal, Error, NotOpenError)
  END
END ReadAString;


PROCEDURE WriteAString(F: FileHandle; S: String);

BEGIN
  IF F <> NULLFile THEN
    IF F = FIO.StandardOutput THEN
      IO.WrStr(S)
    ELSE
      FIO.WrStr(F, S)
    END;
    IF NOT FIO.OK THEN
      Raise(Environment, Fatal, WriteError);
      InitialiseAString(S)
    END
  ELSE
    Raise(Internal, Error, NotOpenError)
  END
END WriteAString;


PROCEDURE ReadAChar(F: FileHandle): CHAR;

VAR
  C: CHAR;

BEGIN
  IF F <> NULLFile THEN
    IF F = FIO.StandardInput THEN
      C := IO.RdChar()
    ELSE
      C := FIO.RdChar(F)
    END;
    IF NOT FIO.OK THEN
      Raise(Environment, Fatal, ReadError);
      C := EndOfLine
    END
  ELSE
    Raise(Internal, Error, NotOpenError);
    C := EndOfLine
  END;
  RETURN C
END ReadAChar;


PROCEDURE WriteAChar(F: FileHandle; C: CHAR);

BEGIN
  IF F <> NULLFile THEN
    IF F = FIO.StandardOutput THEN
      IO.WrChar(C)
    ELSE
      FIO.WrChar(F, C)
    END;
    IF NOT FIO.OK THEN
      Raise(Environment, Fatal, WriteError);
      C := EndOfLine
    END
  ELSE
    Raise(Internal, Error, NotOpenError)
  END
END WriteAChar;


PROCEDURE NextPrinting(F: FileHandle): CHAR;

VAR
  C: CHAR;

BEGIN
  C := ReadAChar(F);
  WHILE (C = CHR(10)) OR (C = CHR(13)) DO
    C := ReadAChar(F)
  END;
  RETURN C
END NextPrinting;


PROCEDURE WriteALine(F: FileHandle);

BEGIN
  IF F <> NULLFile THEN
    IF F = FIO.StandardOutput THEN
      IO.WrLn
    ELSE
      FIO.WrLn(F)
    END;
    IF NOT FIO.OK THEN
      Raise(Environment, Fatal, WriteError);
    END
  ELSE
    Raise(Internal, Error, NotOpenError)
  END
END WriteALine;


PROCEDURE ReadACard(F: FileHandle): CARDINAL;

VAR
  C: CARDINAL;

BEGIN
  IF F <> NULLFile THEN
    IF F = FIO.StandardInput THEN
      C := IO.RdCard()
    ELSE
      C := FIO.RdCard(F)
    END;
    IF NOT FIO.OK THEN
      Raise(Environment, Fatal, ReadError);
      C := 0
    END
  ELSE
    Raise(Internal, Error, NotOpenError);
    C := 0
  END;
  RETURN C
END ReadACard;


PROCEDURE WriteACard(F: FileHandle; C: CARDINAL; Length: CARDINAL);

BEGIN
  IF F <> NULLFile THEN
    IF F = FIO.StandardOutput THEN
      IO.WrCard(C, Length)
    ELSE
      FIO.WrCard(F, C, Length)
    END;
    IF NOT FIO.OK THEN
      Raise(Environment, Fatal, WriteError);
    END
  ELSE
    Raise(Internal, Error, NotOpenError)
  END
END WriteACard;


PROCEDURE ReadALongInt(F: FileHandle): LONGINT;

VAR
  L: LONGINT;

BEGIN
  IF F <> NULLFile THEN
    IF F = FIO.StandardInput THEN
      L := IO.RdLngInt()
    ELSE
      L := FIO.RdLngInt(F)
    END;
    IF NOT FIO.OK THEN
      Raise(Environment, Fatal, ReadError);
      L := 0
    END
  ELSE
    Raise(Internal, Error, NotOpenError);
    L := 0
  END;
  RETURN L
END ReadALongInt;


PROCEDURE WriteALongInt(F: FileHandle; L: LONGINT; Length: CARDINAL);

BEGIN
  IF F <> NULLFile THEN
    IF F = FIO.StandardOutput THEN
      IO.WrLngInt(L, Length)
    ELSE
      FIO.WrLngInt(F, L, Length)
    END;
    IF NOT FIO.OK THEN
      Raise(Environment, Fatal, WriteError);
    END
  ELSE
    Raise(Internal, Error, NotOpenError)
  END
END WriteALongInt;


PROCEDURE ReadALongHex(F: FileHandle): LONGCARD;

VAR
  L: LONGINT;

BEGIN
  IF F <> NULLFile THEN
    IF F = FIO.StandardInput THEN
      L := IO.RdLngHex()
    ELSE
      L := FIO.RdLngHex(F)
    END;
    IF NOT FIO.OK THEN
      Raise(Environment, Fatal, ReadError);
      L := 0
    END
  ELSE
    Raise(Internal, Error, NotOpenError);
    L := 0
  END;
  RETURN L
END ReadALongHex;


PROCEDURE WriteALongHex(F: FileHandle; L: LONGCARD; Length: CARDINAL);

BEGIN
  IF F <> NULLFile THEN
    IF F = FIO.StandardOutput THEN
      IO.WrLngHex(L, Length)
    ELSE
      FIO.WrLngHex(F, L, Length)
    END;
    IF NOT FIO.OK THEN
      Raise(Environment, Fatal, WriteError);
    END
  ELSE
    Raise(Internal, Error, NotOpenError)
  END
END WriteALongHex;


PROCEDURE ReadArgument(Number: CARDINAL; VAR Parameter: String);

BEGIN
  ParamStr(Parameter, Number);
END ReadArgument;


PROCEDURE NumberOfArguments(): CARDINAL;

BEGIN
  RETURN ParamCount()
END NumberOfArguments;


PROCEDURE GetTime(VAR Hours, Minutes, Seconds: CARDINAL);

VAR
  r: Registers;

BEGIN
  r.AH := 2CH;
  Dos(r);
  Hours := CARDINAL(r.CH);
  Minutes := CARDINAL(r.CL);
  Seconds := CARDINAL(r.DH)
END GetTime;


PROCEDURE GetDate(VAR Year, Month, Day: CARDINAL);

VAR
  r: Registers;

BEGIN
  r.AH := 2AH;
  Dos(r);
  Year := r.CX;
  Month := CARDINAL(r.DH);
  Day := CARDINAL(r.DL)
END GetDate;


PROCEDURE InterfaceShutdown;

VAR
  Index	: CARDINAL;

BEGIN
  FOR Index := 5 TO CurrentBuffer DO
    DEALLOCATE(UsedBuffers[Index], SIZE(Buffer))
  END;
  CurrentBuffer := 4;
END InterfaceShutdown;


BEGIN
  IF IODebug THEN
    FIO.IOcheck := TRUE
  ELSE
    FIO.IOcheck := FALSE
  END;
  CurrentBuffer := 4;
END Interface.

