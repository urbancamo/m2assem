MODULE TestStrings;

(*
	Module: TestStrings	Version 1.0	(c) 1989 Mark Wickens
	
	Created: 24-12-89
	
	This is a test module for the Strings Abstract Data Type.
*)
	
FROM Interface	IMPORT	WriteAString, WriteALine, ReadACard, WriteAChar,
			StdOut, NextPrinting, ReadAString, WriteACard, StdIn;
FROM MyStrings	IMPORT  String, InitialiseAString,
			CharInString, LengthOfString, MakeSubstring,
			EmptyString, ReverseString, AlphabeticallyLess,
			EqualStrings, ConcatStrings, CapitaliseString;
		
VAR
  S1, S2			: String;
  Start, Length, Position	: CARDINAL;
  Command			: CHAR;
	
BEGIN
  InitialiseAString(S1);
  InitialiseAString(S2);
	
  WriteAString(StdOut, 'This program exercises string processing operations');
  WriteALine(StdOut);
	
  REPEAT
    WriteALine(StdOut);
    WriteAString(StdOut, 'Type in the first string: ');
    WriteALine(StdOut);
    ReadAString(StdIn, S1);
    WriteAString(StdOut, 'Type in the second string: ');
    WriteALine(StdOut);
    ReadAString(StdIn, S2);
    WriteALine(StdOut);
	
    WriteAString(StdOut, S1);
    WriteAString(StdOut, ' was the first string typed in');
    WriteALine(StdOut);
    WriteAString(StdOut, S2);
    WriteAString(StdOut, ' was the second string typed in');
    WriteALine(StdOut);
    WriteALine(StdOut);

    ConcatStrings(S1, S2);
    WriteAString(StdOut, S1);
    WriteAString(StdOut, ' is first and second string concatanated.');
    WriteALine(StdOut);

    CapitaliseString(S1);
    WriteAString(StdOut, S1);
    WriteAString(StdOut, ' is the first string capitalised.');
    WriteALine(StdOut);
    WriteALine(StdOut);

    WriteAString(StdOut, 'What substring of the first string do you wish');
    WriteALine(StdOut);
    WriteAString(StdOut, 'to assign to the second string?');
    WriteALine(StdOut);
    WriteAString(StdOut, 'Enter the start position of the substring: ');
    Start := ReadACard(StdIn);
    WriteALine(StdOut);
    WriteAString(StdOut, 'Enter the length of the substring: ');
    Length := ReadACard(StdIn);
    WriteALine(StdOut);	
    MakeSubstring(S1, Start, Length, S2);

    IF EmptyString(S2) THEN
      WriteAString(StdOut, 'The second string is now empty');
    ELSE
      WriteAString(StdOut, S2);
      WriteAString(StdOut, ' is now the second string');
    END;
    WriteALine(StdOut);
    WriteALine(StdOut);
	
    IF AlphabeticallyLess(S1, S2) THEN
      WriteAString(StdOut, 'The first string is alphabetically less ');
      WriteAString(StdOut, 'than the second string');
    ELSIF EqualStrings(S1, S2) THEN
      WriteAString(StdOut, 'The two strings are identical')
    ELSE
      WriteAString(StdOut, 'The second string is alphabetically less ');
      WriteAString(StdOut, 'than the first string')
    END;
    WriteALine(StdOut);
    WriteALine(StdOut);
	
    WriteAString(StdOut, 'The length of the first string is: ');
    WriteACard(StdOut, LengthOfString(S1), 4);
    WriteALine(StdOut);
    WriteAString(StdOut, 'The length of the second string is: ');
    WriteACard(StdOut, LengthOfString(S2), 4);
    WriteALine(StdOut);
	
    WriteAString(StdOut, 'Which character of the first string do you wish ');
    WriteAString(StdOut, 'to retrieve?');
    WriteALine(StdOut);
    WriteAString(StdOut, 'Enter the position of the character: ');
    Position := ReadACard(StdIn);
    WriteALine(StdOut);
    WriteAString(StdOut, 'The character in this position is: ');
    WriteAChar(StdOut, CharInString(S1, Position));
    WriteALine(StdOut);
    WriteALine(StdOut);

    ReverseString(S1);
    WriteAString(StdOut, S1);
    WriteAString(StdOut, ' is now the first string, which has been reversed');
    WriteALine(StdOut);
    WriteALine(StdOut);

    WriteAString(StdOut, 'Type "c" to continue, "e" to exit the program: ');
    Command := NextPrinting(StdIn)
  UNTIL  Command = 'e';

END TestStrings.
	

