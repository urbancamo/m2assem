MODULE TestLex;

(*
	MODULE: TestLex		Version 1.0	(c) 1989 Mark Wickens
	
	Created: 17-12-89
	
	This is the test module for the lexical scanner.
*)

FROM Lex	IMPORT	ScanLine, DecodedLine;
FROM MyStrings	IMPORT	String, InitialiseAString, EqualStrings;
FROM IO		IMPORT	RdStr, WrCard;
FROM ADM	IMPORT	MAXOPERANDS, MAXINDICES;
FROM Interface	IMPORT	StdInputName, StdOutputName, OpenAFile, CloseAFile,
			ReadAString, WriteAString, FileHandle, WriteALine,
			WriteAChar;
			
VAR
  UnLexed: String;
  Lexed: DecodedLine;
  Input, Output: FileHandle;

PROCEDURE WriteDecoded(VAR AI: DecodedLine);

VAR
  OperandIndex, IndicesIndex: CARDINAL;

BEGIN
  WITH AI DO
    WriteAString(Output, "Label: ");
    WriteAString(Output, Label);
    WriteALine(Output);

    WriteAString(Output, "Command: ");
    WriteAString(Output, Command);
    WriteALine(Output);

    WriteAString(Output, "Modifier: ");
    WriteAChar(Output, Modifier);
    WriteALine(Output);
    WriteALine(Output);

    FOR OperandIndex := 1 TO MAXOPERANDS DO
      WriteAString(Output, "Operand: "); WrCard(OperandIndex, 2);
      WriteALine(Output);
      WriteAString(Output, "  Prefix: ");
      WriteAChar(Output, Operand[OperandIndex].Prefix);
      WriteALine(Output);
      WriteAString(Output, "  Argument: ");
      WriteAString(Output, Operand[OperandIndex].Argument);
      WriteALine(Output);

      FOR IndicesIndex := 1 TO MAXINDICES DO
        WriteAString(Output, "  Index: ");
        WriteAString(Output, Operand[OperandIndex].Indices[IndicesIndex]);
        WriteALine(Output)
      END;
      WriteAString(Output, "  Postfix: ");
      WriteAChar(Output, Operand[OperandIndex].Postfix);
      WriteALine(Output);
      WriteALine(Output);
    END;

    WriteAString(Output, "Comment: ");
    WriteAString(Output, Comment);
    WriteALine(Output)
  END
END WriteDecoded;


BEGIN
  Input := OpenAFile(StdInputName);
  Output := OpenAFile(StdOutputName);

  InitialiseAString(UnLexed);
  ReadAString(Input, UnLexed);
  WHILE NOT EqualStrings(UnLexed, "quit") DO
    Lexed := ScanLine(UnLexed);
    WriteDecoded(Lexed);
    InitialiseAString(UnLexed);
    ReadAString(Input, UnLexed);
  END;

  CloseAFile(Input);
  CloseAFile(Output)
END TestLex.

