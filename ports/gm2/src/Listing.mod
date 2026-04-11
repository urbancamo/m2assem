IMPLEMENTATION MODULE Listing;

(*
	MODULE: Listing		Version 1.0	(c) 1989 Mark Wickens
	
	Created: 28-11-89
	
	Creates the listing file.
*)

FROM Interface	IMPORT	FileHandle, CreateAFile, WriteAString, WriteACard,
			WriteALine, LongestFileName, WriteAChar, CloseAFile,
			WriteALongHex, WriteALongInt, GetDate, GetTime;
FROM MyStrings	IMPORT	LengthOfString, MakeSubstring, InitialiseAString,
                        ConcatStrings, ArrayToString;
FROM Exceptions	IMPORT	Raise, ExceptionLevel, ExceptionType;
FROM Table	IMPORT	NextInOrder, Greater;
FROM TableExt	IMPORT	TableType, SymbolStatus, EntryType;
FROM ADM	IMPORT	WORDLENGTH, MAXWORDSPERINSTRUCTION;

CONST
  FF			= CHR(12);
  EXTRAPAGE		= 3;
  EXTRALINE		= 43;
  SYMBOLCONST		= 15;
  BLANK			= "  ";
  ADDRESSBLANK		= "        ";
  MCBLANK		= "                    ";
  MAXMCLISTLENGTH	= 20;
  SystemMessage		= "MetaASSEM  (c) 1990 M S Wickens  Version 1.0";

  PageLengthError	= "Illegal page length";
  LineLengthError	= "Illegal line length";
  HexConversionError	= "Illegal Number to Hex Converter";
  MCLengthError         = "Length of machine code greater than max permitted";

VAR
  PageNo, LineNo, SourceNo, PageLength, LineLength, TitleLength	: CARDINAL;
  AddressSwitch, MCSwitch, ListingSwitch, SymbolTableSwitch	: BOOLEAN;
  ListingFile							: FileHandle;
  StartHours, StartMinutes, StartSeconds, StartYear, StartMonth,
  StartDay, EndHours, EndMinutes, EndSeconds, EndYear, EndMonth,
  EndDay							: CARDINAL;
  StartTime, EndTime, AssemblyTime				: LONGCARD;
  TimeString, TitleString, ErrorString				: String;
  ErrorPending                                                  : BOOLEAN;
  AssemblyRate				                        : LONGINT;

(* Internal. *)
PROCEDURE WriteHeader;

VAR
  Count: CARDINAL;

BEGIN
  WriteAString(ListingFile, "Page: ");
  WriteACard(ListingFile, PageNo, 4);
  WriteAString(ListingFile, "    ");
  WriteAString(ListingFile, SystemMessage);
  WriteAString(ListingFile, BLANK);

  WriteACard(ListingFile, StartDay, 2);
  WriteAString(ListingFile, "/");
  WriteACard(ListingFile, StartMonth, 2);
  WriteAString(ListingFile, "/");
  WriteACard(ListingFile, StartYear, 4);
  WriteAString(ListingFile, BLANK);

  WriteACard(ListingFile, StartHours, 2);
  WriteAString(ListingFile, ":");
  WriteACard(ListingFile, StartMinutes, 2);
  WriteAString(ListingFile, ":");
  WriteACard(ListingFile, StartSeconds, 2);
  WriteALine(ListingFile);

  WriteAString(ListingFile, TitleString);
  WriteALine(ListingFile);
  WriteALine(ListingFile)
END WriteHeader;


PROCEDURE DumpSymbolTable;

VAR
  Entry		: TableType;
  CurrentKey	: String;
  EntryLength	: CARDINAL;

BEGIN
  WriteALine(ListingFile);
  WriteALine(ListingFile);
  WriteAString(ListingFile, "Symbol Table Dump: ");
  WriteALine(ListingFile);
  WriteALine(ListingFile);
  InitialiseAString(CurrentKey);

  WHILE Greater(CurrentKey) DO
    NextInOrder(CurrentKey, Entry);
    EntryLength := LengthOfString(Entry.Key);
    MakeSubstring(Entry.Key, 1, EntryLength, CurrentKey);

    IF Entry.Kind = Symbol THEN
      WriteALongInt(ListingFile, Entry.Value, 8);
      WriteAString(ListingFile, BLANK);

      CASE Entry.Status OF
        Absolute: WriteAString(ListingFile, "Abs") |
        Relative: WriteAString(ListingFile, "Rel") |
      END;
      WriteAString(ListingFile, BLANK);

      IF EntryLength > (LineLength - SYMBOLCONST) THEN
        MakeSubstring(Entry.Key, 1, LineLength - SYMBOLCONST, CurrentKey);
        WriteAString(ListingFile, CurrentKey);
      ELSE
        WriteAString(ListingFile, CurrentKey);
        WriteAString(ListingFile, BLANK);
      END;
      WriteALine(ListingFile);
    END
  END
END DumpSymbolTable;


PROCEDURE DumpStatistics;

VAR
  EndHours, EndMinutes, EndSeconds	: CARDINAL;

BEGIN
  GetTime(EndHours, EndMinutes, EndSeconds);
  EndTime :=	((VAL(LONGCARD, EndHours) * 3600) +
  		(VAL(LONGCARD, EndMinutes) * 60) +
  		(VAL(LONGCARD, EndSeconds)));
  IF EndHours < StartHours THEN
    EndTime := EndTime + 3600
  END;
  AssemblyTime := EndTime - StartTime;
  AssemblyRate := AssemblyTime;
  WriteALine(ListingFile);
  WriteAString(ListingFile, "Assembly Statistics: ");
  WriteALine(ListingFile);
  WriteAString(ListingFile, "Assembly Time: ");

  EndHours := VAL(CARDINAL, AssemblyTime DIV 3600);
  AssemblyTime := AssemblyTime MOD 3600;
  WriteACard(ListingFile, EndHours, 2);
  WriteAChar(ListingFile, ":");

  EndMinutes := VAL(CARDINAL, AssemblyTime DIV 60);
  AssemblyTime := AssemblyTime MOD 60;
  WriteACard(ListingFile, EndMinutes, 2);
  WriteAChar(ListingFile, ":");

  EndSeconds := VAL(CARDINAL, AssemblyTime);
  WriteACard(ListingFile, EndSeconds, 2);
  WriteALine(ListingFile);
  WriteAString(ListingFile, "Assembly Rate: ");
  AssemblyRate := (VAL(LONGINT, SourceNo) * 60) DIV AssemblyRate;
  WriteALongInt(ListingFile, AssemblyRate, 8);
  WriteAString(ListingFile, " lines per minute");
  WriteALine(ListingFile)
END DumpStatistics;


PROCEDURE WriteMC(MCode: Instruction; MCLength: CARDINAL);


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
  NybbleSum, Sum, CharCount, CharCounter       		: INTEGER;
  HexDigit						: CHAR;

BEGIN
  IF MCLength > 0 THEN
    IF MCLength <= MAXWORDSPERINSTRUCTION THEN
      CurrentWord := 1;
      NybbleSum := 0;
      CharCount := 0;
      WHILE (CurrentWord <= INTEGER(MCLength)) AND
      				(NybbleSum <= MAXMCLISTLENGTH) DO
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
          WriteAChar(ListingFile, HexDigit);
          INC(CharCount);
          DEC(CurrentNybble);
          INC(NybbleSum)
        END;
        INC(CurrentWord);
        WriteAChar(ListingFile, " ");
        INC(CharCount)
      END;
      FOR CharCounter := CharCount TO 25 DO
        WriteAChar(ListingFile, " ")
      END
    ELSE
      Raise(Internal, Error, MCLengthError)
    END
  ELSE
    WriteAChar(ListingFile, " ");
    FOR CurrentWord := 1 TO MAXWORDSPERINSTRUCTION DO
      WriteAString(ListingFile, "     ")
    END
  END
END WriteMC;


(* Constructors. *)
PROCEDURE AddLine(Address: LONGCARD; MCode: Instruction; MCLength: CARDINAL;
						SourceLine: String);

VAR
  SourceLength		: CARDINAL;
  ShortLine		: String;
  SaveAddress, SaveMC	: BOOLEAN;

BEGIN
  IF ListingSwitch THEN
    IF LineNo = 1 THEN
      WriteHeader;
    END;
    SourceLength := LengthOfString(SourceLine);
    IF SourceLength > (LineLength - EXTRALINE) THEN
      MakeSubstring(SourceLine, 1, (LineLength - EXTRALINE), SourceLine);
    END;
    (* Source Line Number *)
    WriteACard(ListingFile, SourceNo, 4);
    WriteAString(ListingFile, BLANK);

    (* Address *)
    IF AddressSwitch THEN
      WriteALongHex(ListingFile, Address, 8);
      INC(SourceNo)
    ELSE
      WriteAString(ListingFile, ADDRESSBLANK)
    END;
    WriteAString(ListingFile, BLANK);

    (* Machine Code *)
    IF MCSwitch THEN
      WriteMC(MCode, MCLength)
    ELSE
      WriteAString(ListingFile, MCBLANK)
    END;

    (* Source Line *)
    WriteAString(ListingFile, SourceLine);
    WriteALine(ListingFile);
    INCLine;

    (* Error if Pending. *)
    IF ErrorPending THEN
      WriteAString(ListingFile, "Error: ");
      WriteAString(ListingFile, ErrorString);
      WriteALine(ListingFile);
      INCLine;
      ErrorPending := FALSE
    END;
  END
END AddLine;


PROCEDURE AddError(ErrorMessage: ARRAY OF CHAR);
BEGIN
  ErrorPending := TRUE;
  ArrayToString(ErrorMessage, ErrorString)
END AddError;


PROCEDURE StartListing(Filename: String);

VAR
  ListingFName: String;

BEGIN
  InitialiseAString(ListingFName);
  GetTime(StartHours, StartMinutes, StartSeconds);
  GetDate(StartYear, StartMonth, StartDay);
  StartTime :=	(VAL(LONGCARD, StartHours) * 3600) +
  		(VAL(LONGCARD, StartMinutes) * 60) +
  		(VAL(LONGCARD, StartSeconds));
  MakeSubstring(Filename, 1, LengthOfString(Filename), ListingFName);
  ConcatStrings(ListingFName, ".LST");
  ListingFile := CreateAFile(ListingFName);
  ListingSwitch := TRUE;
  SourceNo := 1;
  LineNo := 1;
  PageNo := 1;
  AddressSwitch := TRUE;
  MCSwitch := TRUE;
  SymbolTableSwitch := FALSE;
  PageLength := DEFAULTPAGELENGTH;
  LineLength := DEFAULTLINELENGTH;
  TitleLength := 0;
  ErrorPending := FALSE
END StartListing;


PROCEDURE StopListing;

BEGIN
  IF SymbolTableSwitch THEN
    DumpSymbolTable
  END;
  DumpStatistics;
  WriteAChar(ListingFile, FF);
  CloseAFile(ListingFile);
  ListingSwitch := FALSE
END StopListing;


PROCEDURE SetPageLength(NewLength: CARDINAL);

BEGIN
  IF (NewLength < MINPAGELENGTH) OR (NewLength > MAXPAGELENGTH) THEN
    Raise(Code, Warning, PageLengthError);
    PageLength := DEFAULTPAGELENGTH
  ELSE
    PageLength := NewLength
  END
END SetPageLength;


PROCEDURE SetLineLength(NewLength: CARDINAL);

BEGIN
  IF (NewLength < MINLINELENGTH) OR (NewLength > MAXLINELENGTH) THEN
    Raise(Code, Warning, LineLengthError);
    LineLength := DEFAULTLINELENGTH
  ELSE
    LineLength := NewLength
  END
END SetLineLength;


PROCEDURE INCPage;

BEGIN
  INC(PageNo);
  WriteAChar(ListingFile, FF);
  LineNo := 1
END INCPage;


PROCEDURE INCLine;

BEGIN
  IF LineNo = PageLength - EXTRAPAGE THEN
    INCPage
  ELSE
    INC(LineNo)
  END
END INCLine;


PROCEDURE SetTitle(NewTitle: String);

BEGIN
  TitleLength := LengthOfString(NewTitle);
  IF TitleLength > MAXTITLELENGTH THEN
    TitleLength := MAXTITLELENGTH
  END;
  MakeSubstring(NewTitle, 1, TitleLength, TitleString)
END SetTitle;


PROCEDURE PurgeError;
BEGIN
  ErrorPending := FALSE
END PurgeError;


PROCEDURE Address(Include: BOOLEAN);

BEGIN
  AddressSwitch := Include
END Address;


PROCEDURE MachineCode(Include: BOOLEAN);

BEGIN
  AddressSwitch := Include
END MachineCode;


PROCEDURE SymbolTable(Include: BOOLEAN);

BEGIN
  SymbolTableSwitch := Include
END SymbolTable;


(* Predicates. *)
PROCEDURE CurrentlyListing(): BOOLEAN;

BEGIN
  RETURN ListingSwitch
END CurrentlyListing;


PROCEDURE CurrentSourceLine(): CARDINAL;

BEGIN
  RETURN SourceNo
END CurrentSourceLine;


PROCEDURE CurrentLine(): CARDINAL;

BEGIN
  RETURN LineNo
END CurrentLine;


PROCEDURE CurrentPage(): CARDINAL;

BEGIN
  RETURN PageNo
END CurrentPage;


PROCEDURE CurrentPageLength(): CARDINAL;

BEGIN
  RETURN PageNo
END CurrentPageLength;


PROCEDURE CurrentLineLength(): CARDINAL;

BEGIN
  RETURN LineNo
END CurrentLineLength;


PROCEDURE MCAssemblyRate(): LONGINT;

BEGIN
  RETURN AssemblyRate
END MCAssemblyRate;


PROCEDURE ListingShutdown;

BEGIN
  CloseAFile(ListingFile)
END ListingShutdown;


END Listing.

