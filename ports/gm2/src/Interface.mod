IMPLEMENTATION MODULE Interface;

(*
	MODULE:	Interface	Version 1.0	(c) 1990 Mark Wickens

	Created: 01-01-90
	Ported to GNU Modula-2: 2026

	This module provides the interface for the meta-assembler to the
	outside world.  Rewritten for GNU Modula-2 — the original targeted
	TopSpeed Modula-2 on MS-DOS and used Lib.Dos / SYSTEM.Registers
	for time/date and TopSpeed's FIO and IO modules.  This version
	uses gm2's PIM FIO, NumberIO, Args and FileSysOp libraries plus
	the ISO SysClock for time/date, and drops the manual buffer pool
	because gm2's FIO manages its own I/O buffers.
*)

FROM MyStrings	IMPORT	String, LongestString, StringToArray, ArrayToString,
			InitialiseAString, EndOfLine;
FROM Exceptions	IMPORT	Raise, ExceptionLevel, ExceptionType;
IMPORT FIO;
IMPORT NumberIO;
IMPORT Args;
IMPORT FileSysOp;
IMPORT SysClock;

CONST
  FileMissingError	= "File to be opened cannot be found";
  FileCreateError	= "File could not be created";
  FileOpenError		= "File could not be opened";
  FileCloseError	= "File could not be closed";
  NotOpenError		= "File to be accessed is not open";
  ReadError		= "Attempt to read failed";
  WriteError		= "Attempt to write failed";

VAR
  LastReadFile	: FileHandle;


PROCEDURE ToCString(S: String; VAR A: ARRAY OF CHAR);
(* Convert a MyStrings.String (1-based, NUL-terminated at EndOfLine) into a
   gm2 open ARRAY OF CHAR (0-based, NUL-terminated). *)
BEGIN
  StringToArray(S, A)
END ToCString;


PROCEDURE FileExists(FileName: String): BOOLEAN;
VAR
  Name: ARRAY [0..LongestFileName] OF CHAR;
BEGIN
  ToCString(FileName, Name);
  RETURN FIO.Exists(Name)
END FileExists;


PROCEDURE CreateAFile(FileName: String): FileHandle;
CONST
  FEE1		= "File ";
  FEE2		= " has been overwritten.";
VAR
  FHandle	: FileHandle;
  Name		: ARRAY [0..LongestFileName] OF CHAR;
BEGIN
  ToCString(FileName, Name);
  FHandle := FIO.OpenToWrite(Name);
  IF NOT FIO.IsNoError(FHandle) THEN
    Raise(Environment, Error, FileCreateError);
    RETURN NULLFile
  END;
  RETURN FHandle
END CreateAFile;


PROCEDURE OpenAFile(FileName: String): FileHandle;
VAR
  FHandle	: FileHandle;
  Name		: ARRAY [0..LongestFileName] OF CHAR;
BEGIN
  ToCString(FileName, Name);
  IF NOT FIO.Exists(Name) THEN
    Raise(Environment, Error, FileMissingError);
    RETURN NULLFile
  END;
  FHandle := FIO.OpenToRead(Name);
  IF NOT FIO.IsNoError(FHandle) THEN
    Raise(Environment, Error, FileOpenError);
    RETURN NULLFile
  END;
  LastReadFile := FHandle;
  RETURN FHandle
END OpenAFile;


PROCEDURE CloseAFile(F: FileHandle);
BEGIN
  IF (F <> NULLFile) AND FIO.IsActive(F) THEN
    FIO.Close(F);
    IF NOT FIO.IsNoError(F) THEN
      Raise(Environment, Error, FileCloseError)
    END
  END
END CloseAFile;


PROCEDURE DeleteAFile(Filename: String);
VAR
  Name	: ARRAY [0..LongestFileName] OF CHAR;
  ok	: BOOLEAN;
BEGIN
  ToCString(Filename, Name);
  IF FIO.Exists(Name) THEN
    ok := FileSysOp.Unlink(Name)
  END
END DeleteAFile;


PROCEDURE EndOfFile(): BOOLEAN;
BEGIN
  RETURN FIO.EOF(LastReadFile)
END EndOfFile;


PROCEDURE ReadAString(F: FileHandle; VAR S: String);
VAR
  Buf	: ARRAY [0..LongestString] OF CHAR;
BEGIN
  IF F = NULLFile THEN
    Raise(Internal, Error, NotOpenError);
    RETURN
  END;
  LastReadFile := F;
  FIO.ReadString(F, Buf);
  IF NOT FIO.IsNoError(F) THEN
    Raise(Environment, Fatal, ReadError)
  END;
  ArrayToString(Buf, S)
END ReadAString;


PROCEDURE WriteAString(F: FileHandle; S: ARRAY OF CHAR);
BEGIN
  IF F = NULLFile THEN
    Raise(Internal, Error, NotOpenError);
    RETURN
  END;
  FIO.WriteString(F, S);
  IF NOT FIO.IsNoError(F) THEN
    Raise(Environment, Fatal, WriteError)
  END
END WriteAString;


PROCEDURE ReadAChar(F: FileHandle): CHAR;
VAR
  C: CHAR;
BEGIN
  IF F = NULLFile THEN
    Raise(Internal, Error, NotOpenError);
    RETURN EndOfLine
  END;
  LastReadFile := F;
  C := FIO.ReadChar(F);
  IF NOT FIO.IsNoError(F) THEN
    Raise(Environment, Fatal, ReadError);
    C := EndOfLine
  END;
  RETURN C
END ReadAChar;


PROCEDURE WriteAChar(F: FileHandle; C: CHAR);
BEGIN
  IF F = NULLFile THEN
    Raise(Internal, Error, NotOpenError);
    RETURN
  END;
  FIO.WriteChar(F, C);
  IF NOT FIO.IsNoError(F) THEN
    Raise(Environment, Fatal, WriteError)
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
  IF F = NULLFile THEN
    Raise(Internal, Error, NotOpenError);
    RETURN
  END;
  FIO.WriteLine(F);
  IF NOT FIO.IsNoError(F) THEN
    Raise(Environment, Fatal, WriteError)
  END
END WriteALine;


PROCEDURE ReadACard(F: FileHandle): CARDINAL;
VAR
  C: CARDINAL;
BEGIN
  IF F = NULLFile THEN
    Raise(Internal, Error, NotOpenError);
    RETURN 0
  END;
  LastReadFile := F;
  C := FIO.ReadCardinal(F);
  IF NOT FIO.IsNoError(F) THEN
    Raise(Environment, Fatal, ReadError);
    C := 0
  END;
  RETURN C
END ReadACard;


PROCEDURE WriteACard(F: FileHandle; C: CARDINAL; Length: CARDINAL);
VAR
  Buf	: ARRAY [0..31] OF CHAR;
BEGIN
  IF F = NULLFile THEN
    Raise(Internal, Error, NotOpenError);
    RETURN
  END;
  NumberIO.CardToStr(C, Length, Buf);
  FIO.WriteString(F, Buf);
  IF NOT FIO.IsNoError(F) THEN
    Raise(Environment, Fatal, WriteError)
  END
END WriteACard;


PROCEDURE ReadALongInt(F: FileHandle): LONGINT;
VAR
  C	: CARDINAL;
BEGIN
  IF F = NULLFile THEN
    Raise(Internal, Error, NotOpenError);
    RETURN 0
  END;
  LastReadFile := F;
  C := FIO.ReadCardinal(F);
  IF NOT FIO.IsNoError(F) THEN
    Raise(Environment, Fatal, ReadError);
    RETURN 0
  END;
  RETURN VAL(LONGINT, C)
END ReadALongInt;


PROCEDURE WriteALongInt(F: FileHandle; L: LONGINT; Length: CARDINAL);
VAR
  Buf	: ARRAY [0..31] OF CHAR;
BEGIN
  IF F = NULLFile THEN
    Raise(Internal, Error, NotOpenError);
    RETURN
  END;
  NumberIO.IntToStr(VAL(INTEGER, L), Length, Buf);
  FIO.WriteString(F, Buf);
  IF NOT FIO.IsNoError(F) THEN
    Raise(Environment, Fatal, WriteError)
  END
END WriteALongInt;


PROCEDURE ReadALongHex(F: FileHandle): LONGCARD;
VAR
  C	: CARDINAL;
BEGIN
  IF F = NULLFile THEN
    Raise(Internal, Error, NotOpenError);
    RETURN 0
  END;
  LastReadFile := F;
  C := FIO.ReadCardinal(F);
  IF NOT FIO.IsNoError(F) THEN
    Raise(Environment, Fatal, ReadError);
    RETURN 0
  END;
  RETURN VAL(LONGCARD, C)
END ReadALongHex;


PROCEDURE WriteALongHex(F: FileHandle; L: LONGCARD; Length: CARDINAL);
VAR
  Buf	: ARRAY [0..31] OF CHAR;
BEGIN
  IF F = NULLFile THEN
    Raise(Internal, Error, NotOpenError);
    RETURN
  END;
  NumberIO.HexToStr(VAL(CARDINAL, L), Length, Buf);
  FIO.WriteString(F, Buf);
  IF NOT FIO.IsNoError(F) THEN
    Raise(Environment, Fatal, WriteError)
  END
END WriteALongHex;


PROCEDURE ReadArgument(Number: CARDINAL; VAR Parameter: String);
VAR
  Buf	: ARRAY [0..LongestFileName] OF CHAR;
  ok	: BOOLEAN;
BEGIN
  InitialiseAString(Parameter);
  ok := Args.GetArg(Buf, Number);
  IF ok THEN
    ArrayToString(Buf, Parameter)
  END
END ReadArgument;


PROCEDURE NumberOfArguments(): CARDINAL;
BEGIN
  (* Args.Narg includes argv[0] (the program name); the rest of the code
     counts only user arguments, so we subtract one. *)
  IF Args.Narg() = 0 THEN
    RETURN 0
  END;
  RETURN Args.Narg() - 1
END NumberOfArguments;


PROCEDURE GetTime(VAR Hours, Minutes, Seconds: CARDINAL);
VAR
  dt: SysClock.DateTime;
BEGIN
  SysClock.GetClock(dt);
  Hours := dt.hour;
  Minutes := dt.minute;
  Seconds := dt.second
END GetTime;


PROCEDURE GetDate(VAR Year, Month, Day: CARDINAL);
VAR
  dt: SysClock.DateTime;
BEGIN
  SysClock.GetClock(dt);
  Year := CARDINAL(dt.year);
  Month := dt.month;
  Day := dt.day
END GetDate;


PROCEDURE InterfaceShutdown;
BEGIN
  (* Nothing to release — gm2 FIO owns its buffers and closes its own
     files at program termination. *)
END InterfaceShutdown;


BEGIN
  StdIn  := FIO.StdIn;
  StdOut := FIO.StdOut;
  ErrOut := FIO.StdErr;
  LastReadFile := FIO.StdIn;
END Interface.
