IMPLEMENTATION MODULE Lex;

(*
	MODULE: Lex		Version 1.0	(c) 1989 Mark Wickens
	
	Created: 03-12-89
	Updated: 17-12-89       Works satisfactorily.
        Updated: 30-12-89	Modified so that arguments of operands can
        			be expressions containing postfix characters
        			e.g., + and -.

	This module converts the free format source code into a fixed format
	assembler instruction, the layout of which conforms to the IEEE
	proposed assembler language format.
*)

FROM MyStrings		IMPORT	CharInString, InitialiseAString, EmptyString,
				LengthOfString, MakeSubstring, EndOfLine,
				CapitaliseString, String;
FROM Exceptions		IMPORT	ExceptionLevel, ExceptionType, Raise;
FROM ADM		IMPORT	MAXINDICES, MAXOPERANDS, ValidAddressingModes,
				DecodedLine, OperandElement;

TYPE
  CharSet	= SET OF CHAR;

CONST
  (* Characters *)
  SP	= ' ';
  HT	= CHR(9);

  (* Character Sets *)
  AlphabetSet	= CharSet{'A'..'Z', 'a'..'z'};
  DigitSet	= CharSet{'0'..'9'};
  AlphaNumSet	= CharSet{'A'..'Z', 'a'..'z', '0'..'9', "'"};
  WhiteSpaceSet	= CharSet{SP, HT};
  CommentSet	= CharSet{';'};
  PreIndexSet	= CharSet{'('};
  PostIndexSet	= CharSet{')'};
  OperandSet	= CharSet{','};
  LabelSet	= CharSet{':'};
  SeperatorSet	= CharSet{'.'};
  ModifierSet	= CharSet{'B', 'H', 'L', 'D', 'F', '1', '4', 'M', 'W'};
  EOLSet	= CharSet{EndOfLine};
  PrefixSet	= CharSet{'/', '!', '@', '$', '#', '+', '-'};
  PostfixSet	= CharSet{'+', '-'};

  (* Exception Messages *)
  LabelError	= "Label starts with non-alphabetic character";
  ModifierError	= "Illegal Modifier";
  CommandError	= "Command contains non-alphabetic characters";
  ArgumentError	= "Badly formed argument";
  CommentError	= "Badly formed comment";
  OperandError	= "Badly formed operand";
  IndexError	= "Badly formed index";
  EOLError	= "Unexpected end of line";
  TooManyOperandsError	= "Number of operands exceeds maximum permitted";
  TooManyIndicesError	= "Number of indices exceeds maximum permitted";
  AddrModeError	= "Invalid addressing mode";

PROCEDURE InitialiseDecoded(VAR AI: DecodedLine);

(*
	This procedure creates a completely blank structure which will be
	filled with the decoded line.  The structure is defined at compile
	time by constants defined in the definition module ADM.
*)

VAR
  OperandIndex, IndicesIndex: CARDINAL;

BEGIN
  WITH AI DO
    InitialiseAString(Label);
    InitialiseAString(Command);
    Modifier := 'W';
    NoOfOperands := 0;
    FOR OperandIndex := 1 TO MAXOPERANDS DO
      Operand[OperandIndex].Prefix := ' ';
      InitialiseAString(Operand[OperandIndex].Argument);
      Operand[OperandIndex].NoOfIndices := 0;
      FOR IndicesIndex := 1 TO MAXINDICES DO
        InitialiseAString(Operand[OperandIndex].Indices[IndicesIndex])
      END;
      Operand[OperandIndex].Postfix := ' '
    END
  END
END InitialiseDecoded;


PROCEDURE ScanLine(Line: String; VAR Decoded: DecodedLine);

(*
	This is the only procedure exported and it converts Line into a
	structure containing all the elements of the input line.
*)

VAR
  CurrentPos		: CARDINAL;
  CurrentChar		: CHAR;


  PROCEDURE SkipBlanks(Input: String; VAR Skipped: CARDINAL);

  (*
  	Skips over any blanks in the string Line, starting at skipped.
  	On exit skipped will contain the position of the first non space or
  	tab character (or LengthOfString(Input) if an EndOfLine character is
  	encountered.
  *)

  BEGIN
    CurrentChar := CharInString(Input, Skipped);
    WHILE (CurrentChar IN WhiteSpaceSet) AND NOT(CurrentChar IN EOLSet) DO
      INC(Skipped);
      CurrentChar := CharInString(Input, Skipped)
    END
  END SkipBlanks;


  PROCEDURE ExtractLabel;

  (*
  	ExtractLabel operates on the global (to procedure ScanLine) variables
  	CurrentPos and CurrentChar.  It enters the Label field of Decoded
  	with any label found.
  *)

  BEGIN
    CurrentChar := CharInString(Line, CurrentPos);
    IF CurrentChar IN AlphabetSet THEN
      REPEAT
        INC(CurrentPos);
        CurrentChar := CharInString(Line, CurrentPos)
      UNTIL CurrentChar IN WhiteSpaceSet + LabelSet + EOLSet;
      MakeSubstring(Line, 1, CurrentPos - 1, Decoded.Label);
      INC(CurrentPos)
    ELSIF NOT(CurrentChar IN WhiteSpaceSet + CommentSet + EOLSet) THEN
      Raise(Code, Error, LabelError)
    END
  END ExtractLabel;


  PROCEDURE ExtractOperands;

  (*
  	Upto MAXOPERANDS operands are extracted from the current input line.
  *)

  VAR
    MoreOperands: BOOLEAN;
    OperandCount, StartArgPos	: CARDINAL;


    PROCEDURE ReadIndices;

    (*
    	Upto MAXINDICES indices are extracted from the current input line.
    *)

    VAR
      IndexCount, StartIndexPos	: CARDINAL;
      MoreIndices		: BOOLEAN;

    BEGIN
      CurrentChar := CharInString(Line, CurrentPos);
      IF CurrentChar IN PreIndexSet THEN
        IndexCount := 1;
        MoreIndices := TRUE;
        INC(CurrentPos);
        WHILE MoreIndices DO
          StartIndexPos := CurrentPos;
          CurrentChar := CharInString(Line, CurrentPos);
          WHILE NOT(CurrentChar IN WhiteSpaceSet + OperandSet + PostIndexSet +
          							EOLSet) DO
            INC(CurrentPos);
            CurrentChar := CharInString(Line, CurrentPos)
          END;
          IF CurrentChar IN OperandSet + PostIndexSet THEN
            IF IndexCount <= MAXINDICES THEN
              MakeSubstring(Line, StartIndexPos, CurrentPos - StartIndexPos,
              		    Decoded.Operand[OperandCount].Indices[IndexCount]);
              IF CurrentChar IN OperandSet THEN
                INC(IndexCount)
              ELSE
                MoreIndices := FALSE
              END;
              INC(CurrentPos)
            ELSE
              Raise(Code, Error, TooManyIndicesError);
              MoreIndices := FALSE
            END
          ELSE
            Raise(Code, Error, IndexError);
            MoreIndices := FALSE
          END
        END;
        Decoded.Operand[OperandCount].NoOfIndices := IndexCount
      END
    END ReadIndices;


  BEGIN
    SkipBlanks(Line, CurrentPos);
    CurrentChar := CharInString(Line, CurrentPos);
    IF NOT(CurrentChar IN CommentSet + EOLSet) THEN
      OperandCount := 1;
      MoreOperands := TRUE;
      WHILE MoreOperands DO
        CurrentChar := CharInString(Line, CurrentPos);
        IF NOT(CurrentChar IN EOLSet) THEN
          IF CurrentChar IN PrefixSet THEN
            Decoded.Operand[OperandCount].Prefix := CurrentChar;
            INC(CurrentPos);
            CurrentChar := CharInString(Line, CurrentPos)
          END;
          StartArgPos := CurrentPos;
          WHILE NOT(CurrentChar IN WhiteSpaceSet + PreIndexSet +
            						OperandSet + EOLSet) DO
            INC(CurrentPos);
            CurrentChar := CharInString(Line, CurrentPos)
          END;
          IF OperandCount <= MAXOPERANDS THEN
	    IF CharInString(Line, CurrentPos - 1) IN PostfixSet THEN
	      DEC(CurrentPos)
	    END;
	    MakeSubstring(Line, StartArgPos, CurrentPos - StartArgPos,
	    			  Decoded.Operand[OperandCount].Argument)
	  ELSE
	    Raise(Code, Error, TooManyOperandsError);
	    MoreOperands := FALSE
	  END;
	
          ReadIndices;

          CurrentChar := CharInString(Line, CurrentPos);
          IF CurrentChar IN PostfixSet THEN
            Decoded.Operand[OperandCount].Postfix := CurrentChar;
            INC(CurrentPos);
            CurrentChar := CharInString(Line, CurrentPos)
          END;
          IF NOT(CurrentChar IN OperandSet) THEN
            MoreOperands := FALSE;
            IF NOT(CurrentChar IN WhiteSpaceSet + EOLSet) THEN
              Raise(Code, Error, OperandError)
            END
          ELSE
            INC(CurrentPos);
            INC(OperandCount)
          END
        ELSE
          MoreOperands := FALSE
        END
      END;
      Decoded.NoOfOperands := OperandCount
    END
  END ExtractOperands;


  PROCEDURE ExtractCommand;

  (*
  	From the current position blanks are skipped.  A string of alphabetic
  	characters is then read until either whitespace, a modifier character
  	(in which case a modifier is read) or the end of line is encountered.
  	If this is not the case, an error is produced.  The alphabetic string
  	read is stored in the command field of decoded.  If a command was
  	successfully read, ExtractOperands is called.
  *)

  VAR
    StartPos	: CARDINAL;

  BEGIN
    SkipBlanks(Line, CurrentPos);
    CurrentChar := CharInString(Line, CurrentPos);
    IF NOT(CurrentChar IN EOLSet + CommentSet) THEN
      StartPos := CurrentPos;
      (* A command name must start with a letter but may then contain
         letters or digits — the 1990 code accepted only letters, which
         left the TEST1 mnemonic unreachable because the lexer bailed
         on the digit before ever looking up the opcode table. *)
      IF CurrentChar IN AlphabetSet THEN
        INC(CurrentPos);
        CurrentChar := CharInString(Line, CurrentPos);
        WHILE CurrentChar IN AlphabetSet + DigitSet DO
          INC(CurrentPos);
          CurrentChar := CharInString(Line, CurrentPos);
        END
      END;
      IF CurrentChar IN SeperatorSet THEN
  	INC(CurrentPos);
	CurrentChar := CAP(CharInString(Line, CurrentPos));
        IF CurrentChar IN ModifierSet THEN
	  Decoded.Modifier := CurrentChar
	ELSE
	  Raise(Code, Warning, ModifierError)
	END;
	MakeSubstring(Line, StartPos, CurrentPos - StartPos - 1,
							Decoded.Command);
	INC(CurrentPos)
      ELSIF CurrentChar IN EOLSet + WhiteSpaceSet THEN
        MakeSubstring(Line, StartPos, CurrentPos - StartPos,
        						Decoded.Command);
        INC(CurrentPos)
      ELSE
        Raise(Code, Error, CommandError)
      END;
      CapitaliseString(Decoded.Command);
      ExtractOperands
    END
  END ExtractCommand;


  PROCEDURE ExtractComment;

  (*
  	Extract comment skips any blanks from the current position.  If the
  	next character is a comment field of Decoded.  Otherwise, an error
  	is produced.
  *)

  BEGIN
    SkipBlanks(Line, CurrentPos);
    CurrentChar := CharInString(Line, CurrentPos);
    IF NOT(CurrentChar IN EOLSet) THEN
      IF CurrentChar IN CommentSet THEN
        INC(CurrentPos);
        MakeSubstring(Line, CurrentPos, LengthOfString(Line) - CurrentPos + 1,
        						Decoded.Comment)
      ELSE
        Raise(Code, Error, CommentError)
      END
    END
  END ExtractComment;

BEGIN
  InitialiseDecoded(Decoded);
  CurrentPos := 1;

  ExtractLabel;
  ExtractCommand;
  ExtractComment;
END ScanLine;


PROCEDURE ScanOperand(	OperandToScan: OperandElement;
			VAR AddressingMode: ValidAddressingModes);
(*
	Possible combinations:
	
	PREFIX	POSTFIX		AddressingMode
	------	-------		--------------
	
				Direct
	/			Absolute
	!			Base Page
	@			Indirect
	$			Relative
	#			Immediate
	.			Register
	+			Auto-pre-increment
		+		Auto-post-increment
	-			Auto-pre-decrement
		-		Auto-post-decrement
		@		Indirect-pre-indexed
	@			Indirect-post-indexed
	
	With indices appearing in brackets where appropriate.
*)

BEGIN
  WITH OperandToScan DO
    CASE Prefix OF
      '/': AddressingMode := Abs		|
      '!': AddressingMode := BPage		|
      '@': IF NoOfIndices = 0 THEN
             AddressingMode := Ind
           ELSE
             AddressingMode := IndPostIndex
           END					|
       '$': AddressingMode := Rel		|
       '#': AddressingMode := Imm		|
       '+': AddressingMode := AutoPreInc	|
       '-': AddressingMode := AutoPreDec
    ELSE
      CASE Postfix OF
        '@': IF NoOfIndices > 0 THEN
    	       AddressingMode := IndPreIndex
             ELSE
               Raise(Code, Error, AddrModeError)
             END				|
        '+': AddressingMode := AutoPostInc	|
        '-': AddressingMode := AutoPostDec	|
        ' ': AddressingMode := Dir
      ELSE
        Raise(Code, Error, AddrModeError)
      END
    END;
    IF (Prefix <> ' ') AND (Postfix <> ' ') THEN
      Raise(Code, Error, AddrModeError)
    END
  END
END ScanOperand;


PROCEDURE LexShutdown;
END LexShutdown;


END Lex.
