MODULE M2Assem;

(*
	MODULE: M2Assem		Version 1.0	(c)1990 Mark Wickens
	
	Created: 22/01/90
	
	This is the main driver program for the Meta-Assembler.
*)

FROM ADM                IMPORT InsertOpcodesInTable, Assemble, Instruction;
FROM MyStrings            IMPORT String, InitialiseAString, EqualStrings,
                               ConcatStrings, MakeSubstring, LengthOfString;
FROM Listing            IMPORT StartListing, StopListing, AddLine, PurgeError,
                               SymbolTable, CurrentSourceLine, MCAssemblyRate;
FROM ObjectGenerator    IMPORT StartObject, StopObject, SetFormat, ObjectFormat,
                               AddCode;
FROM Exceptions         IMPORT Raise, ExceptionLevel, ExceptionType, Number,
                               ProgramStatus, StatusType;
FROM Interface          IMPORT File, NumberOfArguments, ReadArgument, OpenAFile,
                               WriteAString, WriteALine, StdOut, ReadAString,
                               EndOfFile, CloseAFile, FileExists, WriteALongInt,
                               WriteACard, NULLFile, WriteAChar;
FROM Lex                IMPORT DecodedLine, ScanLine;
FROM Location           IMPORT ResetLocation, CurrentLocation, INCLocation;

CONST
  ArgumentError = "Bad or missing filename";
  FileMissingError = "Input file could not be found";
  Message1 = "Modula-2 Meta-Assembler Version 1.0 (c)1990 Mark Wickens";
  Message2 = "Usage : M2Assem <filename>";
  Message3 = "where <filename> is name of source file without extension.";
  Message4 = "Extensions used: Source = .ASM, Listing = .LST, Object = .OBJ";
  Pass1Message = "Assembling: Pass 1";
  Pass2Message = "Assembling: Pass 2";
  CR           = 15C;

VAR
  PassNo	           : CARDINAL;
  Filename, InputFile      : String;
  InputHandle              : File;
  InputLine                : String;
  Decoded                  : DecodedLine;
  CurrentMC                : Instruction;
  MCLength                 : CARDINAL;
  LineNo                   : CARDINAL;


PROCEDURE ShowUsage;
BEGIN
  WriteAString(StdOut, Message2); WriteALine(StdOut);
  WriteAString(StdOut, Message3); WriteALine(StdOut);
  WriteAString(StdOut, Message4); WriteALine(StdOut);
END ShowUsage;


PROCEDURE OpenInputFile;
  PROCEDURE GetFilename(VAR Filename: String);

  BEGIN
    InitialiseAString(Filename);
    IF NumberOfArguments() = 1 THEN
      ReadArgument(1, Filename);
      IF EqualStrings(Filename, "?") THEN
        ShowUsage;
(*      Raise(User, Fatal, ArgumentError)*)
        HALT
      END
    ELSE
      ShowUsage;
      Raise(User, Fatal, ArgumentError)
    END
  END GetFilename;

BEGIN
  GetFilename(Filename);
  InitialiseAString(InputFile);
  MakeSubstring(Filename, 1, LengthOfString(Filename), InputFile);
  ConcatStrings(InputFile, ".ASM")
END OpenInputFile;


PROCEDURE OpenOutputFiles;
BEGIN
  IF FileExists(InputFile) THEN
    SetFormat(Generic);
    StartObject(Filename);
    StartListing(Filename)
  ELSE
    ShowUsage;
    Raise(Environment, Fatal, FileMissingError)
  END
END OpenOutputFiles;


PROCEDURE CloseFiles;

BEGIN
  StopListing;
  StopObject
END CloseFiles;


PROCEDURE WriteStats;

BEGIN
  WriteAString(StdOut, "Assembled ");
  WriteACard(StdOut, CurrentSourceLine()-1, 1);
  WriteAString(StdOut, " lines at a rate of ");
  WriteALongInt(StdOut, MCAssemblyRate(), 1);
  WriteAString(StdOut, " lines per minute.");
  WriteALine(StdOut);
  WriteAString(StdOut, "There were ");
  WriteACard(StdOut, Number(), 1);
  WriteAString(StdOut, " exception(s) raised during assembly.");
  WriteALine(StdOut);
  IF ProgramStatus() = Normal THEN
    WriteAString(StdOut, "A valid object code file was written.")
  ELSE
    WriteAString(StdOut, "Exceptions caused Object Code output to be halted.")
  END;
  WriteALine(StdOut);
  WriteALine(StdOut)
END WriteStats;


PROCEDURE Pass1;
BEGIN
  PassNo := 1;
  LineNo := 1;
  WriteAString(StdOut, Pass1Message); WriteALine(StdOut);
  InputHandle := OpenAFile(InputFile);
  IF InputHandle <> NULLFile THEN
    InsertOpcodesInTable;
    ResetLocation;
    ReadAString(InputHandle, InputLine);
    WHILE NOT EndOfFile() DO
      ScanLine(InputLine, Decoded);
(*      WriteAString(StdOut, "Assembling line: ");
      WriteACard(StdOut, LineNo, 6);
      WriteAChar(StdOut, CR);*)
      Assemble(Decoded, PassNo, CurrentMC, MCLength);
      INCLocation(MCLength);
      INC(LineNo);
      ReadAString(InputHandle, InputLine);
    END;
    CloseAFile(InputHandle);
    PurgeError
  END
END Pass1;


PROCEDURE Pass2;
BEGIN
  PassNo := 2;
  LineNo := 1;
  WriteAString(StdOut, Pass2Message); WriteALine(StdOut);
  InputHandle := OpenAFile(InputFile);
  IF InputHandle <> NULLFile THEN
    ResetLocation;
    ReadAString(InputHandle, InputLine);
    WHILE NOT EndOfFile() DO
      ScanLine(InputLine, Decoded);
(*      WriteAString(StdOut, "Assembling line: ");
      WriteACard(StdOut, LineNo, 6);
      WriteAChar(StdOut, CR);*)
      Assemble(Decoded, PassNo, CurrentMC, MCLength);
      AddLine(CurrentLocation(), CurrentMC, MCLength, InputLine);
      AddCode(CurrentLocation(), CurrentMC, MCLength);
      INCLocation(MCLength);
      INC(LineNo);
      ReadAString(InputHandle, InputLine);
    END;
    CloseAFile(InputHandle)
  END
END Pass2;

BEGIN
  WriteAString(StdOut, Message1);
  WriteALine(StdOut);
  OpenInputFile;
  Pass1;
  OpenOutputFiles;
  Pass2;
  CloseFiles;
  WriteStats
END M2Assem.
