IMPLEMENTATION MODULE Exceptions;

(*
	MODULE: Exceptions	Version 1.0	(c) 1989 Mark Wickens
	
	Created: 28/11/89
	
	This module handles all exception processing for the meta-assembler.
*)

FROM MyStrings             IMPORT  StringsShutdown;
FROM Interface	         IMPORT  WriteAString, WriteALine, ErrOut, WriteACard,
                                 InterfaceShutdown;
FROM Table               IMPORT  TableShutdown;
FROM TableExt            IMPORT  TableExtShutdown;
FROM TableTrees          IMPORT  TableTreesShutdown;
FROM Listing             IMPORT  ListingShutdown, AddError, CurrentlyListing,
                                 CurrentSourceLine;
FROM Lex                 IMPORT  LexShutdown;
FROM Location            IMPORT  LocationShutdown;
FROM Expression          IMPORT  ExpressionShutdown;
FROM ObjectGenerator     IMPORT  ObjectGeneratorShutdown, StopObject;
FROM PseudoOps           IMPORT  PseudoOpsShutdown;

VAR
  ExceptionCount: CARDINAL;
  CurrentStatus: StatusType;


PROCEDURE CallShutdowns;
BEGIN
  InterfaceShutdown;
  TableShutdown;
  ListingShutdown;
  LexShutdown;
  LocationShutdown;
  ExpressionShutdown;
  ObjectGeneratorShutdown;
  PseudoOpsShutdown
END CallShutdowns;


PROCEDURE Raise(Type: ExceptionType; Level: ExceptionLevel; Message: String);

BEGIN
  INC(ExceptionCount);

  CASE Type OF
    Code:	IF CurrentlyListing() THEN
                  AddError(Message)
                END;
                WriteAString(ErrOut, "Source line ");
                WriteACard(ErrOut, CurrentSourceLine(), 1);
                WriteAString(ErrOut, " ") |
    User:	WriteAString(ErrOut, "User ") |
    Environment:WriteAString(ErrOut, "Environment ") |
    Internal:	WriteAString(ErrOut, "Internal ")
  END;

  CASE Level OF
    Warning:	WriteAString(ErrOut, "warning: ") |
    Error:	WriteAString(ErrOut, "error: ");
                StopObject;
                CurrentStatus := NoCode            |
    Fatal:	WriteAString(ErrOut, "fatal error: ");
                WriteAString(ErrOut, Message);
                WriteALine(ErrOut);
                CallShutdowns;
                HALT
  END;

  WriteAString(ErrOut, Message);
  WriteALine(ErrOut)
END Raise;


PROCEDURE ChangeStatus(NewStatus: StatusType);
BEGIN
  CurrentStatus := NewStatus
END ChangeStatus;


PROCEDURE ProgramStatus(): StatusType;
BEGIN
  RETURN CurrentStatus
END ProgramStatus;


PROCEDURE Number(): CARDINAL;
BEGIN
  RETURN ExceptionCount
END Number;


BEGIN
  ExceptionCount := 0;
  CurrentStatus := Normal
END Exceptions.
