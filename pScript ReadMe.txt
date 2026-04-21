// pScript 0.8.40 • Copyright 2026 by John Roland Penner
// Based on a Recursive Descent Parser based by Robert Purves (2008)
// Released April 19, 2026

	Look, a computer needs Instructions. 
	Put things in its memory, 
	tell it where to get something, 
	tell it to get something else, 
	tell it what to do with them, 
	tell it to place the answer somewhere... OK? Bye! 
	
	(Vincent Grant McDonell, PhD)


HISTORY OF BASIC

pBasic is a modern BASIC, which gets rid of the retro PEEK and POKE, and punched-card era statements like GOTO -- replacing them with SOUND, SPRITE, and FUNCTIONS. 

Although GOTO started as a keyword in COBOL, and has a precursor in machine language with the JMP command — Grace Hopper created COBOL to get away from the tedium of arcane machine commands, and invented the first computer LANGUAGE (vs an Instruction Set) -- a move greatly resisted by the old brigade, which insisted an interpreter could never be as performant as hand-coded Machine Language (which turned out to be false). 

GOTO as a language statement (a LEXEME) has the significance -- that the abstraction of Language brought device independence from specific machine architectures. instead of referring to a specific address in memory -- it referred to a Line Number as a LABEL / Proxy for an address in memory determined by the Compiler during execution. instead of being tied to a particular memory address, the language provided the SEMANTICS to execute the same logic on differing machine CPU architectures. what makes this semantic abstraction possible is the fact that both the machine language and the semantic adaptation are TURING COMPLETE. 

in the era of Mainframes, Punched-cards, and Teletype based Text editors which used Sequence Numbering to keep the cards in order -- GOTO used this sequence numbering as the LABEL (a Function Name in modern Basic) to reference a sequence of out of order instructions -- Grace Hopper's original itch -- to be able to reuse portions of code. 


SIXTIES COMPUTING (MAINFRAMES)

the earliest BASIC had: DEF FN, GOTO, GOSUB, READ, DATA (on Punched Cards!). 

FIND: IMAGE > IBM/360 Mainframe Printout with both FN and GOTO. 


since Kemeny & Kurtz had patterned their first Mainframe BASIC on FORTRAN — it included support for mathematical concepts such as: Trigonometric Functions (SIN COS TAN) and user-defined Functions (DEF FN), Algebraic concepts like Variables, and structured elements like FOR-NEXT which could represent Integrals ∫ . here are the original 15 keywords supported in Kemeny & Kurtz' original Mainframe BASIC: 
	
	DEF FN		Declares a user-defined Function. 
	LET			Declares a user-defined Variable. 
	INPUT		Allows user input to a Variable during execution. 
	PRINT		Displays output on a Teletype or Screen. 
	
	IF-THEN		Conditional branching. 
	FOR			Start a Loop (a mathematical Integral ∫ ). 
	NEXT		End a Loop. 
	
	GOTO		Unconditional Jump to Label/Line number. 
	GOSUB		Jumps to a Subroutine. 
	RETURN		Returns from a Subroutine. 
	
	REM			Remark; adds comments. 
	
	READ		Reads data from a DATA statement. 
	DATA		Supplies Data within a program. 
	RESTORE		Resets the data pointer to the start of DATA. 
	
	END			Ends the program. 
	

SEVENTIES COMPUTING

the next generation of 8bit BASIC was written by Microsoft which ran on the Altair, Apple II, TRS-80, and Commodore PET computers. Microsoft BASIC grew in popularity, because Bill Gates was the first to realize a universal software which ran on multiple 8bit hardware platforms was more important than building the actual hardware. what Microsoft crucially supplied, was the tricky bit of supporting Floating Point arithmetic libraries -- and this created a lingua franca of early Eighties Retro computing era (check out band 🎶 Simple Minds • I Travel 🎶 for authentic period avant music) 👾 

at this point —— if you want a real Retro experience, you will go take a walk to the corner store, buy a copy of BYTE magazine, and start typing in your BASIC code listings. this was DOWNLOAD 1.0. save what you typed to cassette tape (squelching machine noise at 1500 baud). your sister complains that this is not duran duran! 

this first Microsort BASIC depended on line numbers for text editing, as arrow keys on the 8bit keyboards were not yet universal (the Apple II only had left and right arrow keys, the TRS-80 put up-down on the opposite side of the keyboard form left-right) -- so line numbers were needed to refer to specific sections of code using GOTO and GOSUB. 

	It is practically impossible to teach good programming 
	to students that have had a prior exposure to BASIC; 
	as potential programmers they are mentally mutilated 
	beyond hope of regeneration. 
	
	(Edsger Dijkstra, Computer scientist, 1975)

microsoft's BASIC dominance -- and its use of line numbers led to the creation of unstructured and unmanageable code 🍝  the Spagetti code that resulted, made programming more difficult. Users were required to turn to machine language POKE and PEEK to get sound and graphics. there was no coherent design. 


EIGHTIES COMPUTING

the arrival of the IBM PC catalyzed the capabilities of the early machines, and MS-DOS came with with a line-based text editor called EDLIN (which used: 5,10L to list lines 5-10) and GW-BASIC (which already supported Functions, but still used line numbers, and came with a popular RENUM command which allowed renumbering many lines of code without breaking the order of execution). 

as arrow keys became more universalized -- Bill Gates shipped his QuickBasic 1.0 in 1985, which restored the original support of Functions with the keywords: SUB and END SUB —— and hastened the separation of Text Editing from the Parsing of descriptive LABELS instead of Line Numbers. The release of QuickBasic 2.0 in 1986 was the nail in the coffin —— and included a built-in Text Editor which fully utilitized arrow keys, and writing code with named Labels and Functions instead of Line Numbers —— which were increasingly discouraged in all forms of BASIC after 1985. 


VARIABLES
	
	VAR A = 3
	VAR B = 5
	VAR C$ = "Hello World  "
	PRINT A + B
	PRINT C$
	
	Result: 
	8
	Hello World  
	
	
FOR - NEXT
	
	FOR N = 1 to 3
	PRINT "Hello World  ";
	NEXT N

	Result: 
	Hello World  Hello World  Hello World  


FUNCTIONS

Functions allow you to SEND something (a$) and RETURN something: 

	FUNC peace(a$) 
	  { RETURN a$ + "✌🏻" }

in this case, the function called 'peace' recieves a string called: a$

and all the stuff between the { and } brackets gets executed. 

in this case, what gets executed is: return a$ + "✌🏻"

so if we do something like: 
	
	print peace("hello ")
	print peace("im a modern basic ")

the result is: 
	
	hello ✌🏻 
	im a modern basic ✌🏻 
	
you can see how it puts the strings a$ and "✌🏻" together. 

thats it really -- in the same way you can use a variable once youve defined it —— you can use a function with FUNC myFunc() to have it do THAT anywhere in your code -- without having to retype it. 


TURING COMPLETENESS

Grace Hopper's semantic abstraction is possible due to the fact that both the machine language of the CPU, and the semantic adaptation (language) are TURING COMPLETE -- and it would be worth understanding for any programmer to know what a TURING Finite State Machine is -- for on this rests the generalizability of computing and lexical abstraction. 

Alan Turing defined a computer mathematically in 1936 as a 'Finite State Machine' with four elements (FIND: turing machine image): 

	i) a TAPE (an infinite Memory index of cells). 
	ii) the HEAD (hovers over the tape, moving back and forth between cells, which it can READ WRITE or ERASE a Symbol to a cell). 
	iii) the STATE (a Register which contains the state of what the machine is currently doing: e.g. Start, Scan, Halt). 
	iv) Instruction Set (Rules which tell the machine what to do next given the curent STATE, and the symbol being read by the HEAD). 

To be Turing complete, a system generally must support: 
	• Memory READ + WRITE
	• Conditional BRANCHING (JNZ or IF statements)
	• LOOPING. 

A BASIC Language Interpreter or Compiler breaks down one set of instructions into LEXEMES, and then performs the logic necessary to transform them into OPCODES which are executed as the output. In the case of pBASIC, this transforms the BASIC language syntax into OPCODES executable in macOS as machine instructions. 




--| pBasic HELP |----- 

REPL Commands:
	NEW, DIR, LOAD, SAVE, LIST, EDIT, RUN, CLS, CLR, EXIT
	⬆️  Use Up-Arrow for REPL Command History
	10 FOR N = 1 to 10  Prefix w Line Numbers to Enter Code
	DIR [path]  (e.g., DIR, DIR pBasic, DIR ~/Pictures)
	LOAD file.bas, SAVE file.bas  (files in ~/Documents/)
	LIST [range]  Lists range of Lines (line nums for display only)
	EDIT  Opens the current file in Text Editor (EDITOR$) 
	DELETE linenum  (remove program line[s])

Keywords:
	VAR name : Type = value    (Types: Int, Float, String, Bool)
	VAR myArray[200,3] : Float
		Multi-Dimensional Arrays are Supported. 
		e.g. myArray[37,2] = 3.7
		e.g. var names[3] : String
	CLS, CLR, BUFFER, TAB(n), LEN(), MID$(), LOCATE(row,col)
	PRINT expression or expression; 
		Suffix with ; to suppresses newline. 
		Concatenate Multiple Strings with + 
		e.g. PRINT "Hello " + a$ + ". How are you? "
	INPUT var or INPUT "prompt"; var
		Supports Piped Input from Terminal. 
		e.g. echo "John" | pscript yourname.bas

Flow Control: FOR, TO, STEP, NEXT, IF, THEN
	FOR var = start TO end [STEP n] ... NEXT var
	IF condition THEN statement
	IF (condition) { one Statement per Line }
	WHILE (condition) { ... }
	END, EXIT (to shell)
	
Function Declaration: 
	FUNC myFunc(param1, param2) {
		var local : Type = value
		return expression
	}
	
	Call with: myFunc()
	Return Values: var myVal : Float = 0.0
	    myVal = myFunc(arg1, arg2)
	Recursive calls supported. 

File Handling: 
	Text files are read as an Array of Strings: 
	var fileLines[255] : String
	var a$ : String = "inFile.txt"
	var b$ : String = "outFile.txt"
	fileLines[] = LOAD(a$)
	SAVE b$, fileLines[]

Timer: 
	TIMER 0.25 funcName  (declare interval in seconds + callback)
	TIMERON              (start or resume timer)
	TIMERSTOP            (suspend timer, remembers pending events)
	TIMEROFF             (invalidate timer; must redeclare to restart)
	Timer auto-stops on END, runtime error, or program completion.
	
	NOTE: FUNC() in Timer Calls can NOT pass variables; use Globals. 

Sprites and Sound: 
	SPRITE(id, x, y, rotation, scale, hidden, alpha, imageURL)
		Create or update Sprites. Comma syntax — any argument 
		except id may be omitted. Emoji textures: imageURL = "@🛸"
	Declare Sprite: 
	    SPRITE(1, 630.0, 500.0, 0, 2.5, 1, 1.0, "@😎")
	    SPRITE(1, 630.0, 500.0, 0, 2.5, 1, 1.0, "viper.png")
	Move Sprite: SPRITE(1, shipX, shipY, shipRot, , , , )
	Hide Sprite: SPRITE(1, , , , , 0, , )
	
	PLAY(ID, volume, soundURL)
		PLAY(1, 1.0, "pBasic/Laser.wav")	(load Sound)
		PLAY(1)								(play Sound)
	
	SOUND(MIDI, duration, volume)	// Midi Note, Seconds, Volume
		SOUND(69, 0.5, 1.0)			// A4, half second, full volume
		SOUND(60, 0.25, 0.8)		// Middle C, quarter second, 80%

Operators:
	Variable Assignment: var myVar : Type = value
	Arithmetic: +, -, *, /, ^ (power), % (mod)
	Comparison: ==, >, <, >=, <=, <> (not equal)
	Boolean: && || ^^ !  (Logical Comparison: AND OR XOR NOT)

Variable Types: 
	Int - Integer numbers
	Float - Floating point numbers
	String - Text (variable names ending in $)
	Bool - Boolean (0/1, true/false)
	Arrays - Multi-Dimensional arrays of any type: [size]
	REDIM(array)

Math Functions:
	SIN(x), COS(x), TAN(x), ATAN(x) / ATN(x)
	SQRT(x) - Square Root
	SQR(x) - Square (x²)
	DIST(x1,y1,x2,y2) - Hypotenuse between two points
	EXP(x), LOG(x) / LN(x), LOG10(x)
	ABS(x) - absolute value
	INT(x) - floor function
	RND(x) - random number 0.0 to 1.0

Dynamic Constants: 
	PI / π - 3.14159...
	DATE - current date (MMM d yyyy)
	TIME - current time (HH:mm:ss)
	INKEY$ - single char String of current keyboard input
		Arrow Keys: ^U ^D ^L ^R  "RET"  "DEL"  " "  "ESC"


--| pScript Usage Modes |----- 

	pscript Usage:
	• Run file: ./pscript filename.bas
	• STDIN: echo "John Penner" | pscript ~/reverse.bas")
	• Interactive: ./pscript | then type statements at > prompt
	• Program: linenum statement  (e.g., 10 PRINT "Hello")

i) Redirection of STDIN and STDOUT to INPUT and PRINT commands. 
	if stdin is a pipe, "INPUT" will suppress the default "?", 
	and the INPUT command will accept the pipe to the INPUT statement. 
	for example: 
		
	john@miniMe % swiftc -o pBasic parseEval.swift
	john@miniMe % cat ~/Documents/pBasic/yourname.bas
	
	var a$ = ""
	input "what is your name? "; a$
	print "hello ";
	print a$
	exit
	
	// Interactive Mode (shows prompt)
	john@miniMe % pBasic ~/Documents/pBasic/yourname.bas
	what is your name? John     
	hello John
	
	// Piped Mode from STDIN (suppresses prompt)
	john@miniMe % echo "John Penner" | pBasic ~/Documents/pBasic/yourname.bas
	hello John Penner
	john@miniMe %  
	
	
	// Interactive MID$() with REVERSE
	
	john@miniMe pBasic % pBasic
	pBasic v0.6.4 • Copyright 2026 John Roland Penner
	Type HELP for Commands and Expressions.
	
	Ready
	> load pBasic/reverse.bas
	Loaded 9 lines from pBasic/reverse.bas
	> list
	10 var a$ = ""
	20 input a$
	30 var b$ = ""
	40 print "hello ";
	50 for n = len(a$) - 1 to 0 step -1
	60 b$ = b$ + mid$(a$, n, 1)
	70 next n
	80 print b$
	90 exit
	> run
	? John Penner
	hello renneP nhoJ
	
	Prefix code with linenumbers to add to program in memory. 
	linenum statement  (e.g., 10 PRINT "Hello")
	Line numbers are not saved — they are used ONLY as 
	an editor reference in LIST and DELETE commands. 
	
	
	// Commandline MID$() with REVERSE
	
	john@miniMe pBasic % 
	john@miniMe pBasic % echo "John Penner" | pBasic pBasic/reverse.bas
	hello renneP nhoJ
	john@miniMe pBasic % 
	
	
	NOTE: you will need to include pSasic in your $PATH
	i) copy pscript executable into ~/bin
	ii) echo "path+=(~bin)" > .zshrc
	

//--| pBasic — Language Reference |--------------------------// 

• Variables & Declarations •

	var x : Int = 0
	var f : Float = 0.0
	var s$ : String = ""
	var b : Bool = 0

var arr[1000] : Float		// 1D array
var grid[200, 3] : Float	// 2D array — access: grid[row, col]

All numbers are Double internally. 
Int and Float are the same backing type — no overflow behaviour difference. 
Bool is 0/1. No constants (CONST) — use VAR. 


• Arithmetic & Operators •

+ - * /  ^					// power: 2^8 = 256

&& || ^^ !          		// logical AND OR XOR NOT
								(also bitwise on integers)

== <> > < >= <=				// comparison


• Control Flow • 

IF — Single line only, no multi-line IF {} blocks! 
	
	if x > 0 then y = 1
	if x > 0 && y > 0 then doSomething()
	if a$ == "ESC" then end

Limitation: No ELSE. 
No multi-line IF { } (Milestone 32 pending). 
Workaround: use sentinel variables and multiple IF checks. 

FOR / NEXT
	
	for i = 0 to 100
	    x = x + i
	next i

	for f = 0.0 to 1.0 step 0.01
	    // float step supported
	next f
	
WHILE
	
	while (condition) {
	    // body
	}

Condition must be in parentheses. 
Opening { on same line as while. 
No BREAK yet (Milestone pending) — use sentinel variable to exit. 


• Functions • 
	
	func mandelbrot(cr, ci) {
	    var zr : Float = 0.0
	    var zi : Float = 0.0
	    var iter : Int = 0
	    var maxIter : Int = 64
	    while (iter < maxIter) {
	        var zr2 : Float = zr * zr - zi * zi + cr
	        var zi2 : Float = 2.0 * zr * zi + ci
	        zr = zr2
	        zi = zi2
	        if zr * zr + zi * zi > 4.0 then iter = maxIter
	        iter = iter + 1
	    }
	    return iter
	}


	Call with: 
		myFunc()
	
	Return Values: 
		var myVal : Float = 0.0
	    myVal = myFunc(arg1, arg2)

- Recursive calls supported
- Parameters are untyped — all Float internally
- Local var declarations are truly local (scoped to function)
- Single return value only
- Limitation: cannot return early from middle of function with a value and continue — 'return' in an if-then exits the function. 

NOTE: FUNC() in Timer Calls can NOT pass variables; use Globals. 


• PRINT • 

	print "hello"           // with newline
	print x                 // numeric
	print s$                // string
	print "val: ";          // semicolon at end suppresses newline
	print "hello " + a$		// Concatenate Multiple Strings with + 
		
	PRINT "x = " + STR$(x)
	PRINT "The Value is: " + STR$(x) + " precisely " + a$


• String Functions • 
	
	LEN(s$)                 // length
	MID$(s$, start, len)    // substring, 0-based start
	VAL("3.14")             // string to Float
	STR$(n)                 // number to String
	CHR$(65)                // ASCII/Unicode scalar to String  → "A"
	ASC("A")                // first char to Unicode scalar    → 65
	VERSION$                // built-in string constant
	TIME                    // current time as String "HH:mm:ss"
	DATE                    // current date as String


• Math Functions • 

	SIN(x)  COS(x)  TAN(x)  ATAN(x)
	SQRT(x)  SQR(x)          // SQR = square (x²), SQRT = square root
	ABS(x)  INT(x)           // floor
	EXP(x)  LOG(x)  LOG10(x)
	RND(0)                   // random Float 0.0–<1.0
	PI                       // 3.14159...
	π                        // 3.14159...


• pBASIC GRAPHICS • 

	CLR                       // clear canvas
	PEN 2.0                   // set line/point width
	
	POINT(x, y, r, g, b, a)               // plot pixel — r,g,b,a in 0.0–1.0
	LINE(x1, y1, x2, y2, r, g, b, a)      // draw line
	SAMPLE(x, y, channel, size)           // read pixel: ch 0=R 1=G 2=B 3=A
	FILL(r, g, b, a)					  // Background Colour for TEXT default (0,0,0,0)
	TEXT(r, g, b, a)					  // Foreground Colour for TEXT default (0,0,0,0)

Canvas: 1260 × 1000 pixels, origin top-left, Y increases downward.
Draws are async to main thread — SAMPLE sync-waits so ordering is correct.


• Double Buffering • 

	BUFFER:1        // draw to back buffer, display front
	BUFFER          // swap buffers (show what you drew)
	
Draw to buffer 1 while buffer 0 displays. 
Swap when frame is complete — no flicker. 


• Timer • 

	TIMER 0.25 tickFunc     // declare: interval in seconds + callback name
	TIMERON                 // start timer
	TIMERSTOP               // pause (resumable)
	TIMEROFF                // stop and invalidate
	
	func tickFunc() {
	    var k$ : String = INKEY$
	    if k$ == "ESC" then end
	    if k$ == "^U" then scrollUp()
	    if k$ == "^D" then scrollDown()
	    if k$ == "^L" then scrollLeft()
	    if k$ == "^R" then scrollRight()
	    if k$ == " " then redraw = 1
	    if k$ == "z" then zoomIn()
	    if k$ == "x" then zoomOut()
	    return 0
	}

Timer fires on a serial background queue. 
Timer function has access to all global variables. 
Cannot call `END` directly from timer — set a flag and check it. 


• Sprites •

	SPRITE(id, x, y, rotation, scale, hidden, alpha, imageURL)
		Create or update Sprites. Comma syntax — any argument 
		except id may be omitted. Emoji textures: imageURL = "@🛸"
	Declare Sprite: 
	    SPRITE(1, 630.0, 500.0, 0, 2.5, 1, 1.0, "@😎")
	    SPRITE(1, 630.0, 500.0, 0, 2.5, 1, 1.0, "viper.png")
	Move Sprite: SPRITE(1, shipX, shipY, shipRot, , , , )
	Hide Sprite: SPRITE(1, , , , , 0, , )

• Audio •
	
	BEEP                    // system bell
	SAY "hello"             // text-to-speech, non-blocking, queues utterances
	SAY STOP                // halt speech immediately
	
	PLAY(ID, volume, soundURL)
		PLAY(1, 1.0, "pBasic/Laser.wav")	(load Sound)
		PLAY(1)								(play Sound)
	
	SOUND(MIDI, duration, volume)	// Midi Note, Seconds, Volume
		SOUND(69, 0.5, 1.0)			// A4, half second, full volume
		SOUND(60, 0.25, 0.8)		// Middle C, quarter second, 80%


• File I/O • 
	
	var lines[5000] : String
	lines[] = LOAD("data.csv")       // load text file into string array
	SAVE "output.txt", lines[]       // write string array to text file


• System •

	CLS                     // clear text screen
	LOCATE row, col         // move cursor (1-based)
	TAB(n)                  // print n spaces
	END                     // stop programme
	INKEY$                  // non-blocking key read
	
	• INKEY$ Tokens • 
	
	"^U"    Up arrow
	"^D"    Down arrow  
	"^L"    Left arrow
	"^R"    Right arrow
	"RET"   Return
	"ESC"   Escape
	"DEL"   Delete/Backspace
	" "     Space
	"z"     Z key (lowercase)
	"x"     X key (lowercase)
			Single printable characters arrive 
			as their literal character string. 


--| Known Workarounds for Language Limitations |----- 

Need		Workaround

No ELSE		Two if statements with complementary conditions

No BREAK in WHILE
			Instead of 'BREAK', set result variable, 
			and use sentinel to skip remaining iterations. 
			e.g. IF exitCond then loopRun = 0  //sentinel


//--| Recursive Descent Parser |-----//

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
	
	
	Compilers do two things — they represent things, 
	and transform them.  (Chris Lattner) § 


	//--| ParseEvaluate.main |-----//
	
	> Parse and Evaluate
	- Expression: 10*(x + y)/2.0 + sin( π*0.5 ) ` just a demo… `
	- X:1; Y:2.01; Parse; Evaluate; Result: 16.05
	- X:2; Y:2.01; Result: 21.05
	- X:2; Y:3.14; Result: 26.7

	// Simple demo of expression parsing and evaluation.
	// Robert Purves  November 2000
	
	A parser should:
	(1) Accept valid expressions
	(2) Reject invalid expressions
	(3) Show the location of errors, and give good error messages.
	
	ParseText understands the following lexemes:

	+ - * / ^ ( ) 
	EXP, LOG or LN, LOG10, SIN, COS, TAN, ATN or ATAN, 
	ABS, INT, SQR (square), SQRT (square root)
	
	Three variables with any names 
	(most simply "x", "y" and "z")
	π or PI
	Numbers (such as 5, -3.1889, and 1e-10)


$ swiftc -o parseEval parseEvalGrok.swift
Death-Star:recursiveParser john$ ./parseEval
Enter expression:
10*(x + y)/2.0 + sin( π*0.5 )
Result: 16.05
Death-Star:recursiveParser john$ 

it works!!! 🤩 

all the rest was derived from this. 
thank you RP 🙏🏻 


//--| is pBASIC real basic? |-----------------------------------// 

pBASIC is a modern basic, not a retro basic
pBASIC makes BASIC USEFUL AGAIN!!  😎 

some retro users — pining for their PEEKS and POKES and GOTO, have made the claim that pBASIC is 'not a REAL basic' — for example: 'when does BASIC stop being BASIC? statement blocks { } are C style instead of trad BASIC, and the equality operator is == instead of BASIC = which is again C style'. where are all the traditional keywords in UPPERCASE ONLY!? 🤷🏼‍♂️  

pBASIC is a language that has learned over time — all the simplicity of A$ = MID$() and FOR-NEXT without the pain that is PEEK and POKE just to get sound. pBasic is not trad BASIC — a language that doesnt evolve and learn over time is to be stuck in retro Orthodoxy, and not a useful modern language. 
	
	user: wtf!? {} not allowed — you're not REAL basic!
	
	programmer: millenial basic aint for you bro. 
	
	orthodox goto fundamentalists need not apply
	bible thumper by-the-line-number.. 
	poke and peek your way through anything. 
	but use { and } instead of while.. WEND [gasps!] [horrorrrs!] 
	
	👻 
	
	ascii sprite ghostie will fly in your hair!! 
	the ghosts of BASIC are all in there: 
	
	historical BASIC keywords: 
	INPUT A$, PRINT "HELLO "; MID$() FOR-TO-NEXT, IF-THEN,
	VAR DIM and FUNC funcName(), WHILE WEND with { }
	TIMER, SPRITE, and recursive BASIC Expression Evalution. 
	
	brother — BASIC evolves over time.. pBASIC is 2026 basic, not retro basic. 
	
	a$ can equal an emoji = "✌🏻"
	and it can handle unicode characters. 
	
	we use // instead of ' 
	
	and we use WHILE { and } instead of WHILE and WEND
	
	you say tomato — i saay potatoo 
	
	hope you enjoy — ive made the language easy to adopt claassic BASIC demos — while at the same time adopting some modern IDIOMS that young basic programmers will encounter once they 'get out there in the real world' — and leave baby basic for Javascript, Swift, and Python — languages that they will be able to USE (as is pBasic a superset of a Terminal scripting lanuage that can be used in macOS, Windows, and LINUX teminals instead of Python or Java — with pBasic — you will still be able to script with the familiar A$ = MID$() paradigm.. but with modern integrations. im building a language you can USE — not just feel retro NOSTALGIA for because there arent enough POKES and PEEKS and GOTO in it. 🙄
	
	have your retro BASIC blast in an emulator — there are lots of good Commodore 64 and Apple ][ emulators out there which will let you POKE and PEEK in Retro obscurity. pBASIC is not for you — but if you want a great retro like enviroment with the modern syntax (like what you, as a carpenter, after decades of learning would have done different, after having been broken on bad implementations, UPPER-CASE ONLY WITHOUT SOLDERING IN RAM BIT 7, and USE the language innovations BASIC has gone through decades ago — with ZBASIC and FutureBASIC as the foundation — pBASIC has a solid BASIC legacy going back — but its the future we're aiming for, not your past. 🚀 
		
	yes — pBASIC is REAL BASIC — but it is a modern, not a retro basic. 
	
	pBasic is a modern basic. we got rid of line numbers like it was 1985 (like Microsoft QuickBasic) — we've adopted some modern idioms, like WHILE with { } instead of WHILE WEND —
	
	for the next generation — it will be more useful to know how to handle a WHILE command with { and } than to figure out what POKE and PEEKs you need to use to get Sound out of the machine.. BASIC has evolved over the course of 50 years — these are the right modern design choices. 💯
	
	unlike Retro BASICS that require an 8bit machine or emulator — pBasic is useful in a modern macOS or LINUX Terminal — instead of Java or Python — i can run pBASIC code right in Terminal, and do useful things with it — not just putter around on retro systems. if you want retro basic — you're better off downloading a C64 or Apple ][ emulator. then you will still have all the POKEs and PEEKS and line numbers of a 'Real' Basic. 🤣 
	
	pBasic accepts Terminal input so you can use BASIC with FOR-NEXT and MID$() instead of being stuck using Python or Javascript in your Terminal — pBASIC makes BASIC USEFUL AGAIN!!  😎 	


> pBasic is modern, not retro
	strings can be >255 characters, and handle unicode characters. 
	a$ can equal an emoji = "✌🏻" 
	
	// notRetro.bas
	
	func peace(a$) {
		return a$ + "✌🏻"
	}
	
	var b$ = "pBASIC is a modern basic, not a retro basic. "
	for n = 1 to 7
		tab(n)
		print peace(b$)
	next n


