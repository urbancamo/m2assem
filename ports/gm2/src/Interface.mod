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
    FIO.Close(F)
    (* Don't probe IsNoError after Close — the file is gone, the state
       lookup raises a runtime error in gm2's FIO. *)
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
  Len	: CARDINAL;
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
  (* gm2 FIO.ReadString consumes the trailing LF but leaves a trailing CR
     in place when reading DOS-style CRLF source files (such as the
     historical sample.asm).  Strip it so the lex/parse pipeline sees
     clean lines. *)
  Len := 0;
  WHILE (Len <= HIGH(Buf)) AND (Buf[Len] <> EndOfLine) DO
    INC(Len)
  END;
  IF (Len > 0) AND (Buf[Len - 1] = CHR(13)) THEN
    Buf[Len - 1] := EndOfLine
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
  i	: CARDINAL;
BEGIN
  IF F = NULLFile THEN
    Raise(Internal, Error, NotOpenError);
    RETURN
  END;
  NumberIO.HexToStr(VAL(CARDINAL, L), Length, Buf);
  (* gm2's NumberIO.HexToStr zero-pads to width.  TopSpeed's WrLngHex
     space-padded; preserve historical behaviour by replacing leading
     zeros with spaces, but always keep at least one digit. *)
  i := 0;
  WHILE (i + 1 < Length) AND (Buf[i] = '0') DO
    Buf[i] := ' ';
    INC(i)
  END;
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


(* Time/date support is currently stubbed out — see GM2-BUGS.md bug 3.
   gm2's SysClock.GetClock returns all zeros on macOS, and the alternative
   wraptime library crashes immediately because its Init* functions use
   malloc gated on HAVE_MALLOC_H, which is undefined on macOS (libc malloc
   lives in <stdlib.h> there).  Until either is fixed upstream the
   listing's date/time stamp will read all zeros. *)

PROCEDURE GetTime(VAR Hours, Minutes, Seconds: CARDINAL);
BEGIN
  Hours := 0;
  Minutes := 0;
  Seconds := 0
END GetTime;


PROCEDURE GetDate(VAR Year, Month, Day: CARDINAL);
BEGIN
  Year := 0;
  Month := 0;
  Day := 0
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
