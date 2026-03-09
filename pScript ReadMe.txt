// pScript v0.7.0 by John Roland Penner ©2026
// Based on a Recursive Descent Parser based by Robert Purves (2008)
// Released March 9, 2026


--| pBasic HELP |----- 

> HELP

Keywords:
	VAR name : Type = value    (Int, Float, String, Bool)
	VAR arr[size] : Type       (1D Arrays)
	PRINT expr or expr;        (; suppresses newline)
	INPUT var or INPUT "prompt"; var
	CLS, TAB(n), LEN(), MID$(), String Concatenation with +

Flow Control: FOR, TO, STEP, NEXT, IF, THEN
	FOR var = start TO end [STEP n] ... NEXT var
	IF condition THEN statement
	WHILE (condition) { ... }
	END, EXIT (to shell)
	
Function Declaration: 
	func myFunc(param1, param2) {
		var local : Type = value
		return expression
	}
	Call: var result = myFunc(arg1, arg2)
	Recursive calls supported.

Timer: 
	TIMER 0.25 funcName  (declare interval in seconds + callback)
	TIMERON              (start or resume timer)
	TIMERSTOP            (suspend timer, remembers pending events)
	TIMEROFF             (invalidate timer; must redeclare to restart)
	Timer auto-stops on END, runtime error, or program completion.

Operators:
	Arithmetic: +, -, *, /, ^ (power)
	Comparison: ==, >, <, >=, <=, <> (not equal)
	Assignment: =
	Type declaration: :

Variable Types: 
	Int - Integer numbers
	Float - Floating point numbers
	String - Text (variable names ending in $)
	Bool - Boolean (0/1, true/false)
	Arrays - 1D arrays of any type: [size]
	REDIM(array)

Math Functions:
	SIN(x), COS(x), TAN(x), ATAN(x) / ATN(x)
	SQRT(x) - square root, SQR(x) - square (x²)
	EXP(x), LOG(x) / LN(x), LOG10(x)
	ABS(x) - absolute value
	INT(x) - floor function
	RND(x) - random number 0.0 to 1.0

Dynamic Constants: 
	PI / π - 3.14159...
	DATE - current date (MMM d yyyy)
	TIME - current time (HH:mm:ss)
	INKEY$ - single char String of current keyboard input

REPL Commands:
	CLS - Clear screen
	NEW - Clear program
	LOAD filename - Load from: ~/Documents/
	SAVE filename - Save to: ~/Documents/
	RUN - Execute program
	LIST - Show program (line nums for display only)
	DELETE linenum - Remove linenum
	DIR [path] - List directory (files in ~/Documents/)
	QUIT / EXIT - Exit pBasic


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
	
	
	NOTE: you will need to include pBasic in your $PATH
	i) copy pBasic executable into ~/bin
	ii) echo "path+=(~bin)" > .zshrc
	
	

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

