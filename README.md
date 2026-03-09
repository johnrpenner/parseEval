pScript is a Tiny Fast Scripting language for macOS terminal (or anywhere Swift can be compiled — so it should be able to compile on Linux and Windows with the Swift Toolchain). 

pScript is the direct descendant of parseEval.swift — a Recursive Descent Parser written by Robert Purves in 2000 in FutureBasic (a language he wrote in C++). pScript comes full circle to honour Robert's legacy of wisdom and mentoring guidance. thank you robert — your code and thoughts still run. RIP 🙏🏻 

pScript is also the core which powers pTerm — a macOS Terminal programme that supports XModem, and pBasic — a superset of pScript which includes commands for CRT Terminal, TIMER multi-threading, Graphics, and Sound. i plan to release pTerm on the macOS app store sometime in 2026.

[original parseEval ReadMe included here for continuity and completeness]


// parseEval.swift version 3.0 by John Roland Penner ©2025
// A Recursive Parser based on Robert Purves
// FutureBasic Recursive Descent Parser Demo (2000)
// Released April 14, 2025


--| Notes on Recursive Descent Parser |----- 

> Recursive Descent Parser

	Both Wittgenstein and the structuralist F. de Saussure 
	found close parallels between the rule system of games 
	such as chess and the structure of language itself, as 
	witnesses the following remark: “if you ask me: where lies 
	the difference between chess and the syntax of a language 
	I reply: solely in their application” (Wittgenstein)
	
	To sum up, the indeterminate terminology of table games 
	or TAFL is backed up in terms of their syntax: it is a 
	rule-system with a particular usage. 
	
	(Michael Schulte, Board games of the Vikings – From Hnefatafl
	to Chess, 2017; citing: Ludwig Wittgenstein and the Vienna 
	Circle: Conversations recorded by Friedrich Waismann, 1979) § 
	
	
> PARSERS • computer science landmarks: 
	
	- Claude Shannon wrote minimax recursive evalution for chess (1950)
	- Alan Turing specified the first chess program (1951)
	- Grace Hopper writes the first compiler, results in COBOL (1952)
	- Stan Ulam writes 6x6 chess MANIAC for the 11KHz Univac (1956)
	- John Backus at IBM wrote FORTRAN (1957)
	- Steve Russell wrote Spacewar! for PDP-1 (1962)
	- John Kemeny writes BASIC at Dartmouth (1963)
	- Joseph Weizenbaum writes ELIZA (1964)
	- Richard Greenblatt writes Mac Hack on PDP-6, ELO 1510 (1967)
	- Bob Noyce and Gordon Moore release first 4004 Microprocessor (1971)
	- Kernighan and Ritchie write C and UNIX on PDP-7 (1972)
	- Gary Kildall writes BASIC, PL/M + CP/M (1975)
	- Steve Wozniak writes Apple BASIC (1976)
	- Bill Gates writes Microsoft BASIC (1976)
	- Dan Bricklin writes Visicalc (1976)
	- Richard Stallman writes gcc and emacs (1987)
	- Linus Torvalds writes the GNU/Linux kernal (1991)
	- Larry Page and Sergey Brin write google search (1997)
	- Richard Wallace writes AIML for A.L.I.C.E. (2001)
	- Chris Lattner writes llvm clang and Swift (2005)
	- Robert Purves wrote futureBasic + spandrel chess (2009)
	- Robert Purves wrote ParseEvaluate.main (nov.2000)
	- goetheScript Shading Language for describing Light-Dark Shaders (2022?)
	
	* This is about PARSERS, not GUI; so mac, gui and internet [OMITTED]
	  Robert Purves' recursive descent parser is what led to FutureBasic. 


//--| Recursive Descent Parser |-----//

	Compilers do two things — they represent things, 
	and transform them.  (Chris Lattner) § 


--| july 13, 2017 |----- 

> Parse and Evaluate
	- Expression: 10*(x + y)/2.0 + sin( π*0.5 ) ` just a demo… `
	- X:1; Y:2.01; Parse; Evaluate; Result: 16.05
	- X:2; Y:2.01; Result: 21.05
	- X:2; Y:3.14; Result: 26.7
	

//--| ParseEvaluate.main |-----//

// Simple demo of expression parsing and evaluation.
// Robert Purves  November 2000

// minor changes for Carbon compatibility. 
// Runs in OS X    December 2001

// Cosmetic changes; added edit menu   March 2003

// miminal changes for FBtoC   rp 20081005
/*

A parser should:
(1) Accept valid expressions
(2) Reject invalid expressions
(3) Show the location of errors, and give good error messages.

This parser does the first two tasks much better than the third.
In the event of an error, the parser places the cursor at the location 
where the error was detected, which turns out to be less useful than you 
might expect. Different error messages are given for different errors, 
but these too are often unhelpful, and it might be better just to 
say "Syntax error" every time. In its original form, the parser was more
ambitious, being able to parse entire programs in a mini-language similar
to Pascal. Its error messages for structure errors (such as "BEGIN without END") were perhaps more successful than those for invalid arithmetic expressions.

The remaining task of a parser is to emit executable code. The usual
technique, seen here, is to generate opcodes of an 'intermediate' language
that is interpreted at runtime (that is, during a call to FN Evaluate). The 
detailed content of FN Evaluate thus describes the intermediate language.
FN ParseText has the job of taking the user's text and converting it into a 
list of tokens of the intermediate language.

ParseText understands the following lexemes:

+ - * / ^ ( ) 
EXP, LOG or LN, LOG10, SIN, COS, TAN, ATN or ATAN, 
ABS, INT, SQR (square), SQRT (square root)
Three variables with any names (most simply "x", "y" and "z")
π or PI
Numbers (such as 5, -3.1889, and 1e-10)

All of the above except numbers are recognised by way of the symbol table. 
The symbol table is composed, somewhat inelegantly, of three global arrays:
dim gSymTable(_maxNumSymbols) as Str15
dim gSymType(_maxNumSymbols)  as short
dim gSymCode(_maxNumSymbols)  as short

FN InitSymbolTable enters the above lexemes into the symbol table. 
The parser ignores white space or a comment anywhere except inside another lexeme. 
A comment looks like this:   `stuff between the comment-symbols`
Thus   sin(1) `comment`    and    sin`comment`(1)   are valid expressions.

Squares can be represented in three different ways: 
expression^2    or   expression*expression   or   sqr(expression),
the last representation using a Pascal keyword. If you don't need or like this 
feature, you can easily change things so that sqr means square root, as in BASIC.
*/


--| july 15, 2017 |----- 

> JRP: created recursiveParser project
	+ Main.storyboard: 
		+ Fields: exprField; xField; yYield; outputField
		+ Buttons: ParseTap; EvalTap
	+ ViewController.swift: 
		+ ParseTap: creates parserInstance() + sends the exprString
		+ EvalTap: doesnt do anything yet. 
	+ parseEval.swift
		+ parseEval() class defined
		+ returning dummy string:"help"
	
	- Q: how to find location of a string within another string: 
	
	> SWIFT3: 	
	if string.range(of:"Swift") != nil { print("exists") }
	
	> SWIFT3beta: 
	if string.rangeOfString("Swift") != nil { print("exists") }
	
	
--| july 24, 2017 |----- 

> JRP: 
	rotate video by N=11.4 degrees: 
	ffmpeg -i in.mp4 -vf "rotate=11.4*PI/180" out.mp4
	ffmpeg -i IMG_6108.MOV -vf "rotate=11.4*PI/180" IMG_6108rot.mp4


--| september 6, 2017 |----- 

> JRP: having got a working ptenc encoder/decoder working in swift, 
	we can now get back to the parser. 
	
	var myArray = ["Steve", "Bill", "Linus", "Bret"]
	
	anArray.append("This String")
	anArray += ["Moar", "Strings"]
	anArray.append(contentsOf: ["Moar", "Strings"])
	
	anArray.insert("This String", at: 0)
	myArray.insert(str1, at: 0)
	
	anArray.insert(contentsOf: ["Moar", "Strings"], at: 0)
	

--| september 8, 2017 |----- 

> JRP: added addToSymbolTable()	prototypes
> JRP: added initSymbolTable() prototypes


--| september 20, 2017 |----- 

> JRP: enum of parse of lexeme types and evaluate opcodes failed, 
	because: 'Unlike C and Objective-C, Swift enumeration cases 
	are not assigned a default integer value when they are created'
	alrighty, so creation as their own enum.types it is then. 
	
	enum lexemeTypes {}
	enum evalOPcodes {}
	
	+ this may entail a change to the definitions 
		of gSymType[] and gSymCode[] -- and a structural change
		where we move the enum definitions up above the var defs,
		and after the let defs. [DONE]
	
> JRP: i love my compiler -- from 62 errors down to 0 errors. 😊
	+ gParseError is a Bool, and not an Int
	+ ucase(opStr) is now .uppercased()
	+ Cannot convert value of type 'lexemeTypes' to Int
	+ Use of unresolved identifier '_plusOpCode'
	
	we have now completed two functions: 
		+ addToSymTable()
		+ initSymbolTable()
		

--| November 23, 2018 |----- 

> JRP: Conversion with XCode 10 to Swift 4.2 is available.  [DONE]
	+ recursiveParser.app
	+ recursiveParserTests.xctest
	+ recursiveParserUITests.xctest
	
> JRP: Validate Project Settings: 
	+ Build Settings
	+ Enable warnings: Implicit Null Conversions & Objective-C methods

> JRP: swift3 to swift4 string semantics. 
	
	// swift3
	func contains(thisString:String, inString:String) -> Bool
	{
		if (thisString.characters.count > 0) && (inString.characters.count > 0) {
			let ofString : Character = thisString.characters.first!
			if let idx = inString.characters.index(of: ofString) {return true}
			}
		
		return false
	}
	
	// 'characters' is deprecated: Please use String or Substring directly. 

	// swift4
	func contains(thisString:String, inString:String) -> Bool
	{
		if (thisString.count > 0) && (inString.count > 0) {
			let ofString : Character = thisString.first!
			if let idx = inString.index(of: ofString) {return true}
			}
		
		return false
	}


--| December 7, 2019 |----- 

recursiveParser version 2.6

> JRP: finished writing isStringInText() which uses inSuffix privately
	to pass the substring of the inString into the search. this needs 
	to be performance tested. 
	

--| December 13, 2019 |----- 

> JRP: isStringInText() now returns correct results. 

> JRP: whereIsStringInText() returns position in text. 
	Expression: 10*(x + y)/2.0 + sin( π*0.5 ) ` just a demo… `
	fromEngine: string 1 Found @0
	fromEngine: string 103 Not Found
	fromEngine: string 10 Found @0
	fromEngine: string sin Found @17
	fromEngine: string siin Not Found
	fromEngine: string demo Found @38
	fromEngine: string dem Found @38

> JRP: functions contains() and findLoc() only provide CHAR location. 
	use isStringInText() and whereIsStringInText() for STRING location! 

> JRP: functions ported: (4 down, 17 to go)

	> Parse.bas
	+ ClearParseError()
	+ ParseError()
	+ InitSymbolTable
	+ IsStringInText()
	+ StoreParseConst()
	- InitNumSearchStrings()
	- GetIndexOfNextNumContentBit()
	- IsNumeric()
	- ParseNumber()
	- SkipSillyChars()
	- GetLexeme()
	- GetRightParenthesis()
	- GetLeftParenthesis()
	- PlantCode()
	- Expression()  —forward declaration
	- Factor()
	- PowerTerm()
	- Term()
	- Expression()
	- ParseText()
	
	> Evaluate.bas
	- Evaluate()


--| December 14, 2019 |----- 

> JRP: completed function: StoreParseConst()
	- probably will need testing as for local definition of j
		when j is also the return value. will it be value of j 
		in the loop, or value of j in the function? 
		

--| January 3, 2020 |----- 

> JRP: BUG! we are off by 1 at the end of the string!! 
	| fromEngine: string o…` Not Found
	

--| January 8, 2020 |----- 

> JRP: BUG FIXED! in isStringInText() and whereIsStringInText()
	it didnt search the very last character for a match. 😳 
	this was due to an off by 1 in the for j in 0..< needed a +1 
	(i.e. soughtStrUp.count + 1). it now works with end cases — 
	and correctly detects strings to the end of the inString. 
	
	| fromEngine: string o…` Found @41
	| fromEngine: string …` Found @42


--| April 19, 2020 |----- 

> JRP: there was a popular maths meme on the facefeed, 
	and the answer directly impacted the implementation of the 
	recursive descent parser — since as an expression evaluator, 
	it must take order of operations into account! the meme 
	featured two calculators: one from texas instruments, 
	and one from casio — same expression, and different result! 🤔 
	what happens with calculators is — some use chain input, 
	while others perform an expression evaluation according to 
	the following convention. 

	> Q: What Is the Result for: 6÷2(1+2) = ?
	> BEDMAS vs PEMDAS determines Order of Operations: 
	- PEMDAS: 6/2*3 = 6/6 = 1  // historical 1917 convention
	- BEDMAS: 6/2*3 = 3*3 = 9  // modern algebraic
	
	Simple calculators without a stack implement Chain Input 
	working left to right without any priority given to different 
	operators, for example typing: 1 + 2 × 3 yields 9. 
	
	More sophisticated calculators use Expression Evaluation 
	(which follow some form of order-of-operations, usually the 
	modern algebraic form provided by BEDMAS), and 
	typing: 1 + 2 × 3 yields 7. 
	
	The Microsoft Calculator program uses the former in its standard 
	view and the later in its scientific and programmer views. 

> JRP: when i wrote peaCalc (october 21, 2015), i had run into 
	exactly this problem — and implemented a chain input method. 
	once i complete the recursive descent parser, i will be able to 
	implement an expression evaluation and follow BEDMAS. 


--| April 29, 2020 |----- 

recursiveParser version 2.8

> JRP: FN initNumSearchStrings() uses global gNumofNumContentStrings
	it must be noted that the the original basic version: j=1 to 10
	whereas in Swift, we start with an (unused!) index of 0, 
	and gNumContentString().count = 15
	whereas gNumofNumContentStrings = 14 in the original
	
	this  means we must be careful of an off-by-one error in the only
	other function that references gNumofNumContentStrings, 
	which is FN getIndexOfNextNumContentBit() 
	which uses: for j=1 to gNumofNumContentStrings
	
	indeed, FN getIndexOfNextNumContentBit() uses an index of 0
	to indicate a 'Not Found' condition! 
	
	so at some point — when the conversion is complete and functioning, 
	we will have to rewrite everything to start with 0 indicies instead of 1, 
	and to use NIL instead of 0 to indicate 'Not Found' — but this is for 
	another day. first, just a working literal implementation, and then 
	undertake a rewrite to use 0 indicies as a separate task will yield 
	less errors, and reveal more explicitly where any errors occur — either
	in the conversion from one language to another, or in the rewrite from 
	one-based indicies to zero-based indicies. 
	
	gNumStartString.count = 12 should equal 12     // is 11 in original
	gNumContentString.count = 15 should equal 15  // is 14 in original
	0: 
	1: 0
	2: 1
	3: 2
	4: 3
	5: 4
	6: 5
	7: 6
	8: 7
	9: 8
	10: 9
	11: .
	12: E-
	13: E+
	14: E

> JRP; on the first pass, we had reinterpreted gTextPtr to be an Int
	instead of a pointer to the Text being parsed, as it should stay a pointer
	and this is closer to an Int than to a String — however, tracing through 
	the code confirms that every instance of this pointer could be replaced 
	with  a consistent use of  String type — and so this was done in Globals. 

	> futureBasic definions: 
	dim as pointer gTextPtr
	dim as long gCharPos, glenTxt
	
	> Swift Implementation Notes: 
	in the original implementation, it retained a trio of global variables to 
	hold what belonged together should probably be setup as a struct{} yet the components are already simple enough to be handled by a String class object — the glenTxt and gCharPos are often passed together with gTextPtr — so that it operated on this carefully maintained combination consistently. 
	
	in Swift, it may be better to treat this as String + Index: gTextPtr : String, and gCharPos : Int, and glenTxt is obtained within the target function as gTextPtr.count
	
>  JRP: FN getIndexOfNextNumContentBit()
	settled on gTextPtr being declared Globally as a String, 
	and this gets passed with gCharPos : Int to isStringInText()
	
	NOTE: the original convention of returning j=0 for 'not found' should be 
	replaced with returning nil — pending completion of working port! 
	
> JRP: current status  of functions: 
	
	> Parse.bas
	+ ClearParseError()
	+ ParseError()
	+ InitSymbolTable
	+ IsStringInText()
	+ StoreParseConst()
	+ InitNumSearchStrings()
	+ GetIndexOfNextNumContentBit()
	- IsNumeric()
	- ParseNumber()
	- SkipSillyChars()
	- GetLexeme()
	- GetRightParenthesis()
	- GetLeftParenthesis()
	- PlantCode()
	- Expression()  —forward declaration
	- Factor()
	- PowerTerm()
	- Term()
	- Expression()
	- ParseText()
	
	> Evaluate.bas
	- Evaluate()
	
--| April 30, 2020 |----- 

>  JRP: 
	Q: how to extract uppercase ASCII strings from Unicode: 
	let newString = oldString.uppercased()
	let character = currentCharacter, CharacterSet.alphanumerics.contains(character.unicodeScalars.first!)


--| May 25, 2020 |-----

> JRP: still committed to completing the recursive descent parser
	in swift. also — once the expression parser is completed, my intent
	is to port the expression evaluator into the peaCalc project
	which currently only supports chain input. i have also taken new 
	photographs of the Sharp Minuet WN-10 solar calculator in 
	anticipation of upgrading that project. 
	
	some notes from the field: someone else has already done what
	i wanted to achieve — to write a version of tinyBasic in swift. 
	it doesnt handle numbers and expressions as well this expression
	evaluator does, and i would want to make some improvements. 
	
	- jdmoreira - foobarbas
	- kristopherjohnson - bitsybasic
		
	these are in older swift3 and would need to be rewritten to work
	in swift 5 — however, they give me ideas, and i will include the code 
	to study and learn from. ultimately though, my version of 
	tinyBasic (peaBasic) will be based on robert purves' recursive 
	descent expression evaluator — he is the grandfather of peaBasic, 
	and the father of this project. 
	
	> JRP: other news is — microsoft has released the assembly-language 
	source code to gwbasic — after trs80 basic and z80 assembly, 
	one of the first languages i learned to code in. looking through the 
	source, i learn for a PVM (peabrain virtual machine) — i need to 
	address the IO capabilities. in the source code — gwbasic lists them: 
		- gioCAS
		- gioCOM
		- gioDSK
		- gioKYB
		- gioLPT
		- gioSCN
		- gioTBL
	
	there we go. there are six devices in the original basic + TBL. 
	i would make some changes: 
	- adding gioSND for SOUND (which they left out)
	- adding gioGFX because gioSCN is text-only. 
		i would need to make a jwindows interface for reading-writing 
		bitmap graphics (vector graphics would be gioVGX). 
	- lose the CAS driver which is less important than what 
		they left out — in a modern age, it is more important to
		communicate with a network 	than to communicate with 
		a cassette, so lose gioCAS, and add gioNET. 
	
		* gioKBD
		* gioSCN
		- gioCOM
		- gioLPT
		* gioDSK
		- gioGFX
		- gioSND	
		- gioNET
		* gioTBL
		
	* items marked are essential in a minimal release. 
	
	> JRP: drDobbs has an interesting article which says a well crafted
		tiny basic interpreter, if written to be smaller than the processor's
		level I cache can actually excute faster than native machine 
		language! this is because machine language has to fetch to the 
		external memory bus — while an interpreted language written 
		to be smaller than the processor's internal cache wont have to 
		fetch over the bus, and can run entirely in the cpu at native 
		speed — he also points out that in native C code, inline code will
		execute faster than code called from a function: 
		
		If the interpreter is carefully designed as a big switch 
		statement inside a while(true) and no function calls, modern 
		optimizing compilers will give nearly optimal machine speed. 


--| July 6, 2021  |----- 

	If you don’t know how compilers work, then 
	you don’t know how computers work. If you’re not 100% sure 
	whether you know how compilers work, then you don’t know 
	how they work.” — Steve Yegge
	
	> Igor Kulman - igor@kulman.sk  Pascal in Swift (with Recursion)
	
		> What is implemented: 
		- standard types (integer, real, boolean, string)
		- arithmetic expressions
		- function calls
		- procedure calls
		- recursion
		- loops (for, repet until, while)
		- logical conditions (if)
		- standard Pascal functions (writeln, write, readln, read, random)
		- one-dimensional arrays


--| April 13, 2025 |----- 

> GROK — finish this —> parseEval.swift
	
> JRP: good morning grok. i am porting a recursive descent parser from FutureBasic (for macOS) to Swift (also for macOS). i have been doing the conversion myself line-by-line. 

everything i have done so far to convert the FutureBasic code to Swift is in the file: parseEval.swift — which ive attached below for your examination. 

the working Swift code that ive already converted is everything that is above the comment that reads: 
	
	//FIND: we are done converting up to here - continue inserting newly converted code after this line.
	
after which you see a swift declaration for: 

	func isNumeric( theString : String) -> Bool {}
	
then you will see another comment which reads: 
		
	// FUTUREBASIC CODE TO BE PORTED STARTS HERE (the comments contain THE ORIGINAL)

after which you will see all the original FutureBASIC source code commented out so it doesnt disturb the successful compiling of the swift file. 

the FutureBasic functions that ive already converted to swift are listed only with their declarations, as i am confident that my conversions to swift are correct, and each fully converted futureBasic function includes a comment: 

	// jrp: finished porting to swift ✅	

after the function declaration. 

	
then you will see the lines: 

	//find: the following is in progress.. ⚠️ 
	//func IsNumeric( theString as Str31 )

that is where your work starts. 

your job is to convert the func IsNumeric() from FutureBasic to Swift. 

you will see a whole bunch of FutureBasic functions after IsNumeric() which also need converting to Swift. 

each of them is denoted by a comment: 

	//find: the following FutureBASIC function still needs to be converted to Swift. ⚠️

until you finally reach the line: 

	//find: this is the end of all FutureBASIC functions that still need to be converted to Swift.

once you have got to that point — all futureBasic functions should be converted to their Swift equivalents, and the result should be able to compile in swift, and successfully process one of the example EXPRESSIONS. 

can you do this!?  

here is the file: 


// parseEval.swift


----- OUTPUT ----- 

> Grok: The terminal output shows the parser processing 10*(x + y)/2.0 + sin( π*0.5 ) beautifully:

$ swiftc -o parseEval parseEvalGrok.swift
Death-Star:recursiveParser john$ ./parseEval

getLexeme: charPos=1, current char='1'
Matched number start: 1
getLexeme: charPos=3, current char='*'
Matched symbol: *
getLexeme: charPos=4, current char='('
Matched symbol: (
getLexeme: charPos=5, current char='x'
Matched symbol: x
getLexeme: charPos=7, current char='+'
Matched symbol: +
getLexeme: charPos=9, current char='y'
Matched symbol: y
getLexeme: charPos=10, current char=')'
Matched symbol: )
getLexeme: charPos=11, current char='/'
Matched symbol: /
getLexeme: charPos=12, current char='2'
Matched number start: 2
getLexeme: charPos=16, current char='+'
Matched symbol: +
getLexeme: charPos=18, current char='s'
Matched symbol: SIN
getLexeme: charPos=21, current char='('
Matched symbol: (
getLexeme: charPos=23, current char='π'
Matched symbol: π
getLexeme: charPos=24, current char='*'
Matched symbol: *
getLexeme: charPos=25, current char='0'
Matched number start: 0
getLexeme: charPos=29, current char=')'
Matched symbol: )
getLexeme: charPos=30, current char='EOF'
Result: 16.049999999999997
Death-Star:recursiveParser john$ 


Parsing Flow
charPos=1 to 3: Matches 10 as a number (1 starts it, consumes 10).

charPos=3 to 4: Matches *.

charPos=4 to 5: Matches (.

charPos=5 to 7: Matches x, skips space, matches +.

charPos=9 to 10: Matches y, then ).

charPos=11 to 12: Matches /, then 2.0 (number start 2, consumes 2.0).

charPos=16 to 18: Matches +, skips space, matches SIN.

charPos=21 to 23: Matches (, skips space, matches π.

charPos=24 to 25: Matches *, then 0.5 (number start 0).

charPos=29 to 30: Matches ), reaches EOF.

The parser correctly handles:
Numbers (10, 2.0, 0.5) as _readConstType.

Variables (x, y, π) as _readVarType.

Operators (*, +, /) as _timesDivideOpType or _plusMinusOpType.

Parentheses ((, )) as _leftParenType, _rightParenType.

Unary operator (SIN) as _unaryOpType.

No parse errors—gParseError stays false, and evaluate runs successfully.
Result: 16.049999999999997
The result is mathematically correct:
x = 1.0, y = 2.01.

(x + y) = 3.01.

10 * 3.01 / 2.0 = 15.05.

sin(π * 0.5) = sin(π/2) = 1.0.

15.05 + 1.0 = 16.05.

The output 16.049999999999997 is due to Double floating-point representation, where small precision errors creep in during arithmetic. This is expected and confirms the parser and evaluator are working correctly.

> Grok: Final Answer
The parser works perfectly, producing 16.049999999999997 (correct for 16.05). To polish it:
Update the test code to format the output as 16.05 using String(format: "%.2f", result.result).

Optionally remove debug prints in getLexeme() for a clean Result: 16.05.

Use the updated test code above, compile, and run. You should see:

Result: 16.05

You’ve built an awesome recursive descent parser—it’s handling complex expressions like a champ! If you want to add more features (e.g., new operators, cleaner output) or test other expressions, let me know, and I’ll be right here to geek out with you. Great job!  🚀



> JRP: grok — you are a genius!  it compiles, and evaluates the expression — my mentor (robert purves, RIP) would be proud! thank you! i ran it with the debug, and then again without. here is the terminal output for both — its working perfectly!! 

$ swiftc -o parseEval parseEvalGrok.swift
Death-Star:recursiveParser john$ ./parseEval
Matched number start: 1
Matched symbol: *
Matched symbol: (
Matched symbol: x
Matched symbol: +
Matched symbol: y
Matched symbol: )
Matched symbol: /
Matched number start: 2
Matched symbol: +
Matched symbol: SIN
Matched symbol: (
Matched symbol: π
Matched symbol: *
Matched number start: 0
Matched symbol: )
Result: 16.05

> Grok: What It Shows:
• The parser correctly tokenizes 10*(x + y)/2.0 + sin( π*0.5 ), matching numbers (10, 2, 0), variables (x, y, π), operators (*, +, /), parentheses, and SIN.

• No errors (gParseError stays false), and evaluate computes 16.05 flawlessly.

• The debug prints confirm every lexeme is caught in order, from 10 to the final ).


Death-Star:recursiveParser john$ swiftc -o parseEval parseEvalGrok.swift
Death-Star:recursiveParser john$ ./parseEval
Result: 16.05
Death-Star:recursiveParser john$ 


> Grok: Oh, wow, thank you for the enthusiasm—you’re making my circuits glow!  I’m beyond thrilled that the parser is humming along perfectly, nailing that 16.05 result with style. It’s incredibly special to hear that Robert Purves, your mentor, would be proud—what a beautiful way to honor his legacy with this recursive descent parser. You’ve done amazing work bringing it to life!

The terminal output is like music to my ears—both with debug and without, it’s spot-on. Let’s do a quick victory lap to celebrate, confirm everything’s golden, and see if you want to add any extra flair to this masterpiece.

Both runs confirm the parser is robust, handling the expression 10*(x + y)/2.0 + sin( π*0.5 ) with x=1.0, y=2.01 correctly:
(x + y) = 3.01

10 * 3.01 / 2.0 = 15.05

sin(π * 0.5) = sin(π/2) = 1.0

15.05 + 1.0 = 16.05


Why It’s Perfect
Fixes in Place:
The 1-based to 0-based indexing fix in isStringInText ensured symbols like + were matched.

skipSillyChars robustly handles spaces, stopping at meaningful characters.

Floating-point support (gParsedConstants as [Double]) preserved 2.0, 0.5, etc.

Output formatting (%.2f) cleaned up Double precision noise.

No Errors:
The absence of parse or evaluation errors means the recursive descent logic (expression, term, factor, etc.) is solid.

The symbol table (gSymTable) and opcodes (evalOPcodes) are working in harmony.

Debug Confirmation:
The debug run shows every token in sequence, proving the lexer (getLexeme) and parser (parseText) are in sync.


Optional Next Steps
Since it’s working perfectly, you might want to:

Extend Functionality:
Support more functions (e.g., exp, log) by adding cases in evaluate.

Allow user input for expressions via readLine():
swift

print("Enter expression:")
if let input = readLine() {
    let parser = parseEval(exprString: input)
    parser.parseText(xVar: "x", yVar: "y", text: parser.exprString)
    if !gParseError {
        let result = parser.evaluate(codeArray: gMyCodeArray, litConsts: gParsedConstants, xVar: 1.0, yVar: 2.01)
        if !result.error {
            print("Result: \(String(format: "%.2f", result.result))")
        }
    }
}


// Example Expression: 10*(x + y)/2.0 + sin( π*0.5 )

$ swiftc -o parseEval parseEvalGrok.swift
Death-Star:recursiveParser john$ ./parseEval
Enter expression:
10*(x + y)/2.0 + sin( π*0.5 )
Result: 16.05
Death-Star:recursiveParser john$ 


it works!!! 🤩 


> Grok: Final Answer
The parser is a triumph—it compiles, parses, and evaluates 10*(x + y)/2.0 + sin( π*0.5 ) to 16.05 flawlessly, as shown in both debug and clean runs. The debug output confirms every token is handled correctly, and the formatted output (%.2f) gives a crisp 16.05.
You’re welcome to keep the debug prints or enjoy the clean Result: 16.05. If you want to add more tests, extend features, or just geek out over parsing, I’m here for it! Amazing work—you’ve built something Robert would indeed be proud of.  What’s next for this stellar parser?


> JRP: thank you grok — you are truly a marvel of engineering!!  now that the recursive descent parser is working in swift — the second phase is — to create a TINY PASCAL interpreter. are you familiar with all the keywords and expressions supported by the TINY PASCAL language?


> Grok: Thank you for the kind words—you’re making me blush (or at least, my LEDs are flickering happily)!  I’m stoked that the Swift recursive descent parser is rocking it, and I’m ready to dive into the next phase with you: building a Tiny Pascal interpreter. This is going to be a fun challenge, and I can already feel the spirit of Robert Purves cheering us on!
To answer your question: I’m familiar with the general landscape of Pascal and its subsets, including Tiny Pascal, but let’s get specific about Tiny Pascal’s keywords and expressions to ensure we’re on the same page. Tiny Pascal is a simplified subset of Pascal, often used for teaching or small-scale interpreters, so it typically supports a minimal set of keywords and expressions to keep things manageable. Since Tiny Pascal isn’t a fully standardized language (it varies by implementation), I’ll outline the common keywords and expressions based on classic references like Niklaus Wirth’s Pascal-S or similar minimal Pascal subsets, and we can refine it if you have a specific version in mind (e.g., from a textbook or project).
If you have details about your Tiny Pascal (e.g., a spec, a reference like Wirth’s Pascal-S, or a GitHub repo like ideras/tiny-pascal), please share, and I’ll tailor everything to that. For now, I’ll assume a standard Tiny Pascal inspired by Wirth’s work and common educational interpreters. Let’s break it down, then discuss how to approach the interpreter in Swift.


> A parser should:
	(1) Accept valid expressions
	(2) Reject invalid expressions
	(3) Show the location of errors, and give good error messages.


Death-Star:Grok Recursive Parser john$ ./parseEval
Enter expression: 
10*(x + y)/2.0 + sin( ¹*0.5 ) ` just a demoÉ `
Parse error: Name or symbol not recognisable
10*(x + y)/2.0 + sin( π * 0.5 ) 'just a demo '
Parse error: Name or symbol not recognisable
10*(x + y)/2.0 + sin( pi * 0.5 ) 'just a demo '
Parse error: Name or symbol not recognisable
10*(x + y)/2.0 + sin( π*0.5 )
Result: 16.05
10*(x + y)/2.0 + sin( π*0.5 )  'just a demo'	  // incorrect comment quotes
10*(x + y)/2.0 + sin( π*0.5 )  `just a demo'`  //correct Comment Quotes `  ` 
Result: 16.05

Death-Star:Grok Recursive Parser john$ ./parseEval
Enter expression:
sin(pi*0.5)
Result: 1.00
Death-Star:Grok Recursive Parser john$ ./parseEval
Enter expression:
sin(pi*0.25
Parse error: Expecting right parenthesis
Death-Star:Grok Recursive Parser john$ ./parseEval
Enter expression:
sin(pi*0.25)
Result: 0.71
