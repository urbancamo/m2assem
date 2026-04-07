MODULE TestTable;

(*
	MODULE: TestTable	Version 1.0	(c) 1989 Mark Wickens
	
	Created: 24-12-89
	Updated: 04-01-90	Tests modules Lex and Expression also.

	This program is the driver program for a suite of programs which
	together manage storage of, and access to, data in a table.
*)

FROM MyStrings	IMPORT	String, InitialiseAString, EqualStrings;
FROM Table	IMPORT	InitialiseTable, IsRoom, IsIn, Insert, Retrieve,
			Delete, Amend, Greater, NextInOrder, SizeOfTable,
			ElementsAtLocation, TableType, EntryType, SymbolStatus;
FROM TableExt	IMPORT	TableType, EntryType, SymbolStatus, GetRec, PutRec,
			ConvertFrom;
FROM Interface	IMPORT	WriteAChar, WriteACard, WriteAString, WriteALine,
			ReadAChar, ReadAString, ReadACard, FileHandle, StdIn,
			StdOut, WriteALongInt, NextPrinting;
FROM ADM	IMPORT	MAXOPERANDS, MAXINDICES, Instruction, Word,
			MAXWORDSPERINSTRUCTION, InsertOpcodesInTable, Assemble;
FROM Lex	IMPORT	ScanLine, DecodedLine;
FROM Expression	IMPORT	Evaluate, ChangeBase, CurrentBase, BaseType;
FROM Listing	IMPORT	StartListing, StopListing, SetPageLength, SymbolTable,
			SetLineLength, AddLine, INCLine, INCPage, SetTitle;


VAR
  Selection	: CHAR;
  Name		: String;
  Entry		: TableType;
  Line		: String;
  AssemInstr	: DecodedLine;
  Result	: LONGINT;
  ResultType	: SymbolStatus;
  NewBase	: BaseType;
  ICoun, OCoun	: CARDINAL;
  Counter	: CARDINAL;
  MCInstr	: Instruction;
  MCString	: String;
  MCWord	: CARDINAL;
  Number	: CARDINAL;
  InstrLength	: CARDINAL;
  PassNo	: CARDINAL;

PROCEDURE WriteLine(Line: String);
BEGIN
  WriteAString(StdOut, Line);
  WriteALine(StdOut)
END WriteLine;


PROCEDURE Instruct;
BEGIN
  WriteLine('Meta-Assembler Module Tester.');
  WriteLine('Developed by M S Wickens  (c) 1990');
  WriteALine(StdOut);
  WriteLine('Type one of:');
  WriteLine('I    to add a new entry to the table');
  WriteLine('R    retrieve details of an entry');
  WriteLine('D    to delete an entry from the table');
  WriteLine("A    to assemble a line input with option 'S'");
  WriteLine('P    to display the contents of the table in order');
  WriteLine('N    to display the number of entries in each hash location');
  WriteLine('S    to input a line and perform a lexical scan');
  WriteLine('E    to input an expression and evaluate it.');
  WriteLine('C    change to the default base of constants in expressions.');
  WriteLine('L    test listing module.');
  WriteLine('?    to display this message');
  WriteLine('X    to leave the program')
END Instruct;


PROCEDURE Performance;
VAR
  PositionInTable: CARDINAL;
BEGIN
  WriteLine('Position     NoOfElements');
  FOR PositionInTable := 0 TO SizeOfTable() - 1 DO
    WriteACard(StdOut, PositionInTable, 8);
    WriteAString(StdOut, '     ');
    WriteACard(StdOut, ElementsAtLocation(PositionInTable), 8);
    WriteALine(StdOut)
  END
END Performance;


PROCEDURE WriteDecoded(VAR AI: DecodedLine);

VAR
  OperandIndex, IndicesIndex: CARDINAL;

BEGIN
  WITH AI DO
    WriteAString(StdOut, "Label: ");
    WriteAString(StdOut, Label);
    WriteALine(StdOut);

    WriteAString(StdOut, "Command: ");
    WriteAString(StdOut, Command);
    WriteALine(StdOut);

    WriteAString(StdOut, "Modifier: ");
    WriteAChar(StdOut, Modifier);
    WriteALine(StdOut);
    WriteALine(StdOut);

    FOR OperandIndex := 1 TO AI.NoOfOperands DO
      WriteAString(StdOut, "Operand: "); WriteACard(StdOut, OperandIndex, 2);
      WriteALine(StdOut);
      WriteAString(StdOut, "  Prefix: ");
      WriteAChar(StdOut, Operand[OperandIndex].Prefix);
      WriteALine(StdOut);
      WriteAString(StdOut, "  Argument: ");
      WriteAString(StdOut, Operand[OperandIndex].Argument);
      WriteALine(StdOut);

      FOR IndicesIndex := 1 TO AI.Operand[OperandIndex].NoOfIndices DO
        WriteAString(StdOut, "  Index: ");
        WriteAString(StdOut, Operand[OperandIndex].Indices[IndicesIndex]);
        WriteALine(StdOut)
      END;
      WriteAString(StdOut, "  Postfix: ");
      WriteAChar(StdOut, Operand[OperandIndex].Postfix);
      WriteALine(StdOut);
      WriteALine(StdOut);
    END;

    WriteAString(StdOut, "Comment: ");
    WriteAString(StdOut, Comment);
    WriteALine(StdOut)
  END
END WriteDecoded;


BEGIN
  InitialiseTable;
  InsertOpcodesInTable;
  Instruct;
  WriteAString(StdOut, '>> ');
  Selection := CAP(NextPrinting(StdIn));
  WHILE Selection <> 'X' DO
    CASE Selection OF
      'I': IF IsRoom() THEN
             WriteAString(StdOut, "Enter Key: ");
             ReadAString(StdIn, Name);
	     IF IsIn(Name) THEN
	       WriteAString(StdOut, Name);
	       WriteLine(' is already in the table');
	     ELSE
	       GetRec(StdIn, Name, Entry);
	       Insert(Entry);
	       WriteAString(StdOut, Name);
	       WriteLine(' has been inserted in the table')
	     END
	   ELSE
	     WriteLine('Table is already full')
	   END
    |
      'R': WriteAString(StdOut, "Enter Key: ");
           ReadAString(StdIn, Name);
           IF IsIn(Name) THEN
	     Entry := Retrieve(Name);
	     WriteLine('Details are:');
	     PutRec(StdOut, Entry)
	   ELSE
	     WriteAString(StdOut, Name);
	     WriteLine(' is not in the table')
	   END
    |
      'D': WriteAString(StdOut, "Enter Key: ");
           ReadAString(StdIn, Name);
           IF IsIn(Name) THEN
	     Delete(Name);
	     WriteAString(StdOut, Name);
	     WriteLine(' has been deleted from the table')
	   ELSE
	     WriteAString(StdOut, Name);
	     WriteLine(' is not in the table')
	   END
    |
      'A': WriteAString(StdOut, "Enter Pass Number: ");
      	   PassNo := ReadACard(StdIn);
           Assemble(AssemInstr, PassNo, MCInstr, InstrLength);
           WriteAString(StdOut, "Instruction Length: ");
           WriteACard(StdOut, InstrLength, 1);
           WriteALine(StdOut);
           IF PassNo = 2 THEN
             FOR Counter := 1 TO InstrLength DO
               WriteAString(StdOut, "MC: ");
               InitialiseAString(MCString);
               ConvertFrom(MCInstr[Counter], MCString);
               WriteAString(StdOut, MCString);
               WriteAString(StdOut, " == ");
               WriteALongInt(StdOut, LONGINT(INTEGER(MCInstr[Counter])), 1);
               WriteALine(StdOut)
             END
           END
    |
      'P': InitialiseAString(Name);
           WHILE Greater(Name) DO
	     NextInOrder(Name, Entry);
	     PutRec(StdOut, Entry);
	     WriteALine(StdOut);
	     Name := Entry.Key
	   END;
	   WriteLine('End of list of table entries')
    |
      'N': Performance()
    |
      'S': InitialiseAString(Line);
      	   WriteLine("Enter ASSEM line: ");
      	   ReadAString(StdIn, Line);
      	   AssemInstr := ScanLine(Line);
      	   WriteDecoded(AssemInstr);
      	   WriteALine(StdOut);
    |
      'E': InitialiseAString(Line);
           WriteLine("Enter an expression: ");
           ReadAString(StdIn, Line);
           Evaluate(Line, Result, ResultType);
           WriteAString(StdOut, "Result: ");
           WriteALongInt(StdOut, Result, 0);
           WriteALine(StdOut);
           WriteAString(StdOut, "Result Type: ");
           CASE ResultType OF
             Absolute:	WriteLine("Absolute") |
             Relative:	WriteLine("Relative")
           END;

    |
      'C': WriteAString(StdOut, "Current Default: ");
      	   CASE CurrentBase() OF
      	     Bin: WriteLine("Binary")	|
      	     Oct: WriteLine("Octal")	|
      	     Dec: WriteLine("Decimal")	|
      	     Hex: WriteLine("Hexadecimal")
      	   END;
      	   WriteAString(StdOut, "New Default: ");
      	   InitialiseAString(Line);
      	   ReadAString(StdIn, Line);
      	   IF EqualStrings(Line, "Binary") THEN
      	     ChangeBase(Bin)
      	   ELSIF EqualStrings(Line, "Octal") THEN
      	     ChangeBase(Oct)
      	   ELSIF EqualStrings(Line, "Decimal") THEN
      	     ChangeBase(Dec)
      	   ELSIF EqualStrings(Line, "Hexadecimal") THEN
      	     ChangeBase(Hex)
      	   ELSE
      	     WriteLine("Base not recognised.")
      	   END
    |
      'L': InitialiseAString(Line);
      	   WriteLine("Enter line to list: ");
           ReadAString(StdIn, Line);
           FOR Counter := 1 TO MAXWORDSPERINSTRUCTION DO
	     WriteAString(StdOut, "Enter MC for Word: ");
	     MCWord := ReadACard(StdIn);
	     MCInstr[Counter] := Word(MCWord);
	   END;
	   WriteAString(StdOut, "Enter number of lines: ");
	   Number := ReadACard(StdIn);
	
	   SetTitle("This is the title.");
	   StartListing("LIST.LST");
	   SetLineLength(132);
	   SymbolTable(TRUE);
	   FOR Counter := 1 TO (Number * 3) BY 3 DO
	     AddLine(LONGCARD(Counter), MCInstr, 3, Line)
	   END;
	   StopListing
    |
      '?': Instruct

    ELSE   WriteLine('Illegal instruction.  Type "?" for help')
    END;
    WriteAString(StdOut, '>> ');
    Selection := CAP(NextPrinting(StdIn));
  END;
END TestTable.


