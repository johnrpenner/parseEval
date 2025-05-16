// ParseEvaluate.fbas
// Robert Purves (2000)


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
to Pascal. Its error messages for structure errors (such as "BEGIN without END")
were perhaps more successful than those for invalid arithmetic expressions.

The remaining task of a parser is to emit executable code. The usual
technique, seen here, is to generate opcodes of an 'intermediate' language
that is interpreted at runtime (that is, during a call to FN Evaluate). The
detailed content of FN Evaluate thus describes the intermediate language.
FN ParseText has the job of taking the user's text and converting it into a
list of tokens of the intermediate language.

ParseText understands the following lexemes:

+ - * / ^ ( )
EXP, LOG or LN, LOG10, SIN, COS, TAN, ATN or ATAN, ABS, INT, SQR (square), SQRT (square root)
Three special variables with any names (most simply "x", "y" and "z")
¹ or PI
Numbers (such as 5, -3.1889, and 1e-10)

All of the above except numbers are recognised by way of the symbol table. The
symbol table is composed, somewhat inelegantly, of three global arrays:
dim gSymTable(_maxNumSymbols) as Str15
dim gSymType(_maxNumSymbols)  as short
dim gSymCode(_maxNumSymbols)  as short

FN InitSymbolTable enters the above lexemes into the symbol table. The parser
ignores white space or a comment anywhere except inside another lexeme.
A commentlooks like this:   `stuff between the comment-symbols`
Thus   sin(1) `comment`    and    sin`comment`(1)   are valid expressions.

Squares can be represented in three different ways:
expression^2    or   expression*expression   or   sqr(expression),
the last representation using a Pascal keyword. If you don't need or like this
feature, you can easily change things so that sqr means square root, as in BASIC.
*/


//--| INTERFACE |-----//

local mode
local fn BuildFuncDefWind( initString as CFStringRef )

window 1, @"Parse and Evaluate",  (0,0)-(380,340) ,_noGoAway + _docNoGrow
text ,12
edit field _errorEFNum, @"",      (5,190)-(375,205), _statFramed
call Moveto (5,300) : print "x:"
edit field _xValEFNum, @"1",      (35,290)-(135,305), _framedNoCR
call Moveto (240,300) : print "y:"
edit field _yValEFNum,   @"2.01", (275,290)-(375,305), _framedNoCR
edit field _resultEFNum, @"",     (5,315)-(375,330), _statFramed
button _parseBtn, _enable,  @"Parse",     (5,220)-(80,240)
button _evalu8Btn, _disable, @"Evaluate",  (5,250)-(80,270)
edit field _expressionEFNum, initString, (5,5)-(375,180)
SetSelect _maxInt, _maxint
end fn


// house-keeping: extract text from edit field and call FN ParseText
local mode
local fn ParseEditField( xVar as Str15, yVar as Str15 )

dim as Str255  expression

edit$( _errorEFNum ) = ""
edit field _expressionEFNum
expression = edit$( _expressionEFNum )
fn ParseText (xVar, yVar, @expression[1], expression[0] ) // do the actual parse
end fn


local fn DoEvaluate

dim as double  xVar, yVar, result
dim as short   err

xVar = val( edit$( _xValEFNum ) )
yVar = val( edit$( _yValEFNum ) )
result = fn Evaluate( gMyCodeArray(0), gParsedConstants(0), xVar, yVar, @err )
long if err
edit$( _resultEFNum ) = "Numeric error"
xelse
edit$( _resultEFNum ) = str$( result )
end if
end fn


local fn DoParse

fn ParseEditField( "x", "y" ) // x & y are special variables
long if ( gParseError )
button _evalu8Btn, _disable
xelse
button _evalu8Btn, _enable
edit$( _errorEFNum ) = " OKÉ"
end if
end fn


local mode
local fn HandleDialog

dim as long  evnt, id

evnt = dialog( 0 ) : id = dialog( evnt )
select case evnt
case _btnClick
select id
case _parseBtn : fn DoParse
case _evalu8Btn : fn DoEvaluate
end select
end select
end fn


local mode
local fn HandleEdit

dim as long  efID

efID = window( _efNum )
tekey$ = tekey$
long if ( efID == _expressionEFNum )
button 2, _disable: edit$( _errorEFNum ) = ""
edit$( _resultEFNum ) = ""
end if
end fn

// main program

dim as CFSTringRef  initialFuncStr

menu 1, 0, 1, @"File"
menu 1, 1, 1, @"Quit/Q"

edit menu 2

on dialog fn HandleDialog
on edit   fn HandleEdit

initialFuncStr = @"10*(x + y)/2.0 + sin( ¹*0.5 ) ` just a demoÉ `"
fn BuildFuncDefWind( initialFuncStr )
do
HandleEvents
until ( gFBQuit )


//--| ParseEvaluate.glbl |-----//

#if ndef _FBtoC
compile shutdown "Requires FB5/FBtoC"
#endif


begin enum 1
 _expressionEFNum
 _errorEFNum
 _xValEFNum
 _yValEFNum
 _resultEFNum
 _parseBtn
 _evalu8Btn
end enum

// Parse setup values
_maxNumConsts       = 20 // adjust to suit
_maxNumSymbols      = 100 // adjust to suit
_maxCodeLength      = 100 // adjust to suit
_maxEvalStackSize   = 10
_commentChar        = _"`"
_spaceChar          = _" "

// Output of a parse, and input to FN Evaluate
dim as double gParsedConstants(_maxNumConsts)
dim as short  gMyCodeArray(_maxCodeLength)

// Communication between Parse modules
dim as long    gNumConsts, gCharPos, gCode, gParseError, glenTxt
dim as pointer gTextPtr // pointer will hold test being parsed

// symbol table
dim as Str15 gSymTable(_maxNumSymbols)
dim as short gSymType(_maxNumSymbols)
dim as short gSymCode(_maxNumSymbols)
dim as long  gNumSyms

// Number search tables
dim as Str15  gNumStartString(11)
dim as Str15  gNumContentString(14)
dim as short gNumofNumStartStrings
dim as short gNumofNumContentStrings


// Parse lexeme types
begin enum 1
_plusMinusOpType
_timesDivideOpType
_powerOpType
_leftParenType
_rightParenType
_readVarType
_unaryOpType
_readConstType
end enum

// Evaluate opcodes
begin enum
_noOpCode
_plusOpCode
_minusOpCode
_timesOpCode
_divideOpCode
_powerOpCode
_xVarOpCode
_yVarOpCode
_unaryMinusCode
_EXPopCode
_LOGopCode
_LOG10opCode
_SQRopCode
_SQRTopCode
_SINopCode
_COSopCode
_TANopCode
_ATNopCode
_ABSOpCode
_INTopCode
_piOpCode
_readConstCode
end enum


//--| Parse.bas |-----//

local fn ClearParseError

edit$( _resultEFNum ) = ""
gParseError = _false
end fn


local fn ParseError( errMsg as Str255 )

if gParseError then exit fn // show once only (no showers of consequential errors)
gParseError = _zTrue
SetSelect gCharPos - 1, gCharPos - 1 // insertion pt at error position
edit$( _errorEFNum ) = errMsg
end fn


// table is sorted by length, longest first
local fn AddToSymTable( opStr as Str15, type as short, opcode as short )

dim as long  j, lenInsertStr, insertIndex, lenTableEntry

long if ( gNumSyms >= _maxNumSymbols )
stop "Symbol table full"
xelse
lenInsertStr = opStr[0]
long if ( lenInsertStr < 1 )
stop "Prog error: null string in AddToSymTable"
xelse
insertIndex = 1
lenTableEntry = len( gSymTable(insertIndex) )
while ( lenInsertStr <= lenTableEntry ) and ( insertIndex <= gNumSyms )
long if ( lenInsertStr == lenTableEntry ) // equal length strings; check for existing entry = error
long if ( ucase$( opStr ) == ucase$( gSymTable(insertIndex) ) )
stop "Symbol table entry duplicated"
end if
end if
inc( insertIndex )
lenTableEntry = len( gSymTable(insertIndex) )
wend

// make room for insertion
for j = gNumSyms to insertIndex step -1
gSymTable(j + 1) = gSymTable(j)
gSymType(j + 1)  = gSymType(j)
gSymCode(j + 1)  = gSymCode(j)
next j
// insert
gSymTable(insertIndex) = opStr
gSymType(insertIndex)  = type
gSymCode(insertIndex)  = opcode
inc( gNumSyms )
end if
end if
end fn


local fn InitSymbolTable

/* Insert the following:
+ - * /  ^ ( )
EXP, LOG or LN, LOG10, SIN, COS, TAN, ATN or ATAN, ABS, INT
SQR (square),  SQRT (square root)
¹ or PI
*/
gNumSyms = 0
fn AddToSymTable( "+",    _plusMinusOpType,   _plusOpCode )
fn AddToSymTable( "-",    _plusMinusOpType,   _minusOpCode )
fn AddToSymTable( "*",    _timesDivideOpType, _timesOpCode )
fn AddToSymTable( "/",    _timesDivideOpType, _divideOpCode )
fn AddToSymTable( "^",    _powerOpType,    _powerOpCode )
fn AddToSymTable( "EXP",  _unaryOpType,    _EXPopCode )
fn AddToSymTable( "LOG",  _unaryOpType,    _LOGopCode )
fn AddToSymTable( "LN",   _unaryOpType,    _LOGopCode ) // synonym
fn AddToSymTable( "LOG10",_unaryOpType,    _LOG10opCode )
fn AddToSymTable( "SIN",  _unaryOpType,    _SINopCode )
fn AddToSymTable( "COS",  _unaryOpType,    _COSopCode )
fn AddToSymTable( "TAN",  _unaryOpType,    _TANopCode )
fn AddToSymTable( "ATN",  _unaryOpType,    _ATNopCode )
fn AddToSymTable( "ATAN", _unaryOpType,    _ATNopCode ) // synonym
fn AddToSymTable( "SQR",  _unaryOpType,    _SQRopCode ) // square
fn AddToSymTable( "SQRT", _unaryOpType,    _SQRTopCode ) // square root
fn AddToSymTable( "ABS",  _unaryOpType,    _ABSOpCode )
fn AddToSymTable( "INT",  _unaryOpType,    _INTopCode )
fn AddToSymTable( "¹",    _readVarType,    _piOpCode )
fn AddToSymTable( "PI",   _readVarType,    _piOpCode ) // synonym
fn AddToSymTable( "(",    _leftParenType,  _noOpCode )
fn AddToSymTable( ")",    _rightParenType, _noOpCode )
end fn


// similar to INSTR. Looks for soughtStr in text. Case insensitive
local mode
local fn IsStringInText( lenTxt as long, txtPtr as ptr, startPos as long, soughtStr as Str15 )

dim as long   j, lenOfSought, tmp, found
//dim as long   j, lenOfSought
//var found : Bool
//var tmp : String

lenOfSought = soughtStr[0]
found = _false
long if lenOfSought
long if ( (lenTxt - startPos + 1) >= lenOfSought )
soughtStr = ucase$( soughtStr ) // convert for case insensitive
for j = 1 to lenOfSought
tmp = peek( txtPtr + j + startPos - 2 )
if ( tmp >= _"a" ) and ( tmp <= _"z" ) then tmp -= _spaceChar // upper case alphabetic
if ( tmp != peek( @soughtStr + j ) ) then exit fn
next j
found = _zTrue
end if
end if
end fn = found


// Put constant in gParsedConstants(); return index
local fn StoreParsedConst( value as double )

dim as long  j

long if ( gNumConsts > 0 )
for j = 1 to gNumConsts
if ( value == gParsedConstants(j) ) then exit fn // re-use stored value
next j
end if
long if ( gNumConsts < _maxNumConsts )
gNumConsts++
gParsedConstants(gNumConsts) = value // new entry
j = gNumConsts
xelse
fn ParseError( "Too many constants" )
j = 1
end if
end fn = j


local fn InitNumSearchStrings

dim as long  j

for j = 1 to 10
gNumStartString(j)   = mid$( str$( j - 1 ), 2 ) // 0-9
gNumContentString(j) = gNumStartString(j)
next j
gNumStartString(11)     = "."
gNumofNumStartStrings   = 11

gNumContentString(11)   = "."
gNumContentString(12)   = "E-"
gNumContentString(13)   = "E+"
gNumContentString(14)   = "E"
gNumofNumContentStrings = 14
end fn


local fn GetIndexOfNextNumContentBit

dim as long  j

for j = 1 to gNumofNumContentStrings
long if fn IsStringInText( glenTxt,gTextPtr,gCharPos,gNumContentString(j) )
exit fn // found a number-content
end if
next j
j = 0 // not found
end fn = j


// returns _zTrue if theString represents a number, else _false
local mode
local fn IsNumeric( theString as Str31 )

dim as long    digit, ch
dim as ptr     pntr, endPtr
dim as Boolean numeric

pntr = @theString + 1
endPtr = pntr + theString[0] - 1
numeric = _false
if ( pntr <= endPtr ) then ch = pntr.nil` : pntr++ else ch = -1
while ( ch == _spaceChar )
if ( pntr <= endPtr ) then ch = pntr.nil` : pntr++ else ch = -1
wend // ignore leading spaces
long if ( ch == _"+" ) or ( ch == _"-" )
if ( pntr <= endPtr ) then ch = pntr.nil`: pntr++ else ch = -1
end if
digit=_false
while ( ch >= _"0" ) and ( ch <= _"9" )// eat digits
digit=_zTrue
if ( pntr <= endPtr ) then ch = pntr.nil`: pntr++ else ch = -1
wend
long if digit
long if ( ch == _"." )
if ( pntr <= endPtr ) then ch = pntr.nil`: pntr++ else ch = -1
while ch>=_"0" and ch<=_"9"
if ( pntr <= endPtr ) then ch = pntr.nil` : pntr++ else ch = -1
wend // eat digits, don't care if none
end if
xelse
long if (ch == _".")
if ( pntr <= endPtr ) then ch = pntr.nil` : pntr++ else ch = -1
digit = _false
while ( ch >= _"0" ) and ( ch <= _"9" )// eat digits
digit = _zTrue
if ( pntr <= endPtr ) then ch = pntr.nil` : pntr++ else ch = -1
wend
if not digit then exit fn // no digits before or after point
xelse
exit fn
end if
end if

long if ( ch == _"E" ) or ( ch == _"e" ) // exponent
if ( pntr <= endPtr ) then ch = pntr.nil` : pntr++ else ch = -1
long if ( ch == _"+" ) or ( ch == _"-" )
if ( pntr <= endPtr ) then ch = pntr.nil` : pntr++ else ch = -1
end if
digit = _false
while ( ch >= _"0" ) and ( ch <= _"9" ) // eat digits
digit = _zTrue
if ( pntr <= endPtr ) then ch = pntr.nil` : pntr++ else ch = -1
wend
if not digit then exit fn // no digits after exp
end if
while ( ch == _spaceChar )
if ( pntr <= endPtr ) then ch = pntr.nil` : pntr++ else ch = -1
wend // eat spaces at end
numeric = (ch == -1) // non-numeric if extra non-space chars after digits
end fn = numeric



local fn ParseNumber as double // text known to have number starting at gCharPos

dim as long   j, lngth
dim as Str31  numString

numString[0] = 0
j = fn GetIndexOfNextNumContentBit
while ( j > 0 )
numString = numString + gNumContentString(j)
lngth     = len( gNumContentString(j) )
gCharPos += lngth
j         = fn GetIndexOfNextNumContentBit
wend
if not fn IsNumeric( numString ) then fn ParseError( "Bad number format" )
end fn = val( numString )


local fn SkipSillyChars

// skip leading spaces, controls, anything enclosed by comment chars
dim as long  theChar, endCommentSought, continue

continue         = _zTrue
endCommentSought = _false
while continue and ( gCharPos <= glenTxt )
theChar = peek( gTextPtr + gCharPos - 1 )
select theChar
case _commentChar
endCommentSought = not endCommentSought
case > _spaceChar
continue = endCommentSought
end select
if continue then gCharPos++
wend
if endCommentSought then fn ParseError( "Unterminated comment" )
end fn


local fn GetLexeme

dim as long     j, type
dim as double   value

type = _nil
if gParseError then exit fn
fn SkipSillyChars
for j = 1 to gNumSyms // look through sym table
long if fn IsStringInText( glenTxt, gTextPtr, gCharPos, gSymTable(j) )
type  = gSymType(j)
gCode = gSymCode(j)
gCharPos += len( gSymTable(j) )
exit fn
end if
next j

for j = 1 to gNumofNumStartStrings
long if fn IsStringInText( glenTxt, gTextPtr, gCharPos, gNumStartString(j) )
// found a number-start
value  = fn ParseNumber#
gCode  = fn StoreParsedConst( value )
type   = _readConstType
exit fn
end if
next j

type = _nil // error, not found
if ( gCharPos < glenTxt ) then fn ParseError( "Name or symbol not recognisable" )
end fn = type


local fn GetRightParenthesis( type as long )

if gParseError then exit fn
long if ( type != _rightParenType )
fn ParseError( "Expecting right parenthesis" )
xelse
type = fn GetLexeme
end if
end fn = type


local fn GetLeftParenthesis( type as long )

if gParseError then exit fn
long if (type != _leftParenType)
fn ParseError( "Expecting left parenthesis" )
xelse
type = fn GetLexeme
end if
end fn = type


local fn PlantCode( code as long )

dim as long  codeLength : codeLength = 0

if gParseError then exit fn
codeLength = gMyCodeArray(0)
long if ( codeLength < _maxCodeLength ) // check length (in gMyCodeArray(0))
inc( codeLength )
gMyCodeArray(0) = codeLength
gMyCodeArray(codeLength) = code // 1 word opcode
xelse
fn ParseError( "Expression too long" )
end if
end fn = codeLength // current index


def fn Expression( type as long ) // forward declaration prototype


local fn Factor( type as long )

dim as long  tempCode

if gParseError then exit fn
select case type
case _readConstType // read, double opcode
fn PlantCode( _readConstcode )
fn PlantCode( gCode )
type = fn GetLexeme
case _readVarType // read, single opcode
fn PlantCode( gCode )
type = fn GetLexeme
case _leftParenType
type = fn GetLexeme
type = fn Expression( type )
type = fn GetRightParenthesis( type )
case _plusMinusOpType // unary + or -
tempCode = gCode
type = fn GetLexeme
type = fn Factor( type )
if ( tempCode == _minusOpCode ) then fn PlantCode( _unaryMinusCode ) // postfix unary - ; unary + ignored
case _unaryOpType // SIN COS etc
tempCode = gCode
type = fn GetLexeme
type = fn GetLeftParenthesis( type )
type = fn Expression( type )
type = fn GetRightParenthesis( type )
fn PlantCode( tempcode ) // postfix operator
case else
fn ParseError( "Syntax error" )
end select
end fn = type


local fn PowerTerm( type as long )

dim as long  tempCode

if gParseError then exit fn
type = fn Factor( type )
while ( type == _powerOpType )
tempCode = gCode
type = fn GetLexeme
type = fn Factor( type )
fn PlantCode( tempCode ) // postfix operator
wend
end fn = type


local fn Term( type as long )

dim as long  tempCode

if gParseError then exit fn
type = fn PowerTerm( type )
while ( type == _timesDivideOpType )
tempCode = gCode
type = fn GetLexeme
type = fn PowerTerm( type )
fn PlantCode( tempCode ) // postfix operator
wend
end fn = type


local fn Expression( type as long )

dim as long  tempCode

if gParseError then exit fn
type = fn Term( type )
while ( type == _plusMinusOpType )
tempCode = gCode
type = fn GetLexeme
type = fn Term( type )
fn PlantCode( tempCode ) // postfix operator
wend
end fn = type


local fn ParseText( xVar as Str15, yVar as Str15, txtPtr as ptr, lenTxt as long )

dim as long  type

fn ClearParseError
// set up globals for communication between parsing FNs
glenTxt          = lenTxt
gTextPtr         = txtPtr
gCharPos         = 1
gNumConsts       = 0
gMyCodeArray(0)  = 0 // initialise zero length of code
fn InitSymbolTable
fn InitNumSearchStrings

if ( xVar != "" ) then fn AddToSymTable( xVar, _readVarType, _xVarOpCode )
if ( yVar != "" ) then fn AddToSymTable( yVar, _readVarType, _yVarOpCode )

type = fn GetLexeme
long if ( type == _nil )
fn ParseError( "Missing expression" )
xelse
type = fn Expression( type )
fn SkipSillyChars
long if ( gParseError == _false )
long if ( type != _nil )
fn ParseError( "Syntax error" )
xelse
long if ( gCharPos != glenTxt + 1 )
fn ParseError( "End of expression expected" )
end if
end if
end if
end if

end fn


//--| Evaluate.bas |-----//

// Interpret opcodes in codeArray()
// Literal constants in the function definition are passed in litConsts()
local fn Evaluate( codeArray(_maxCodeLength) as short, litConsts(_maxNumConsts) as double, xVar as double, yVar as double,  errReturnPtr as ptr ) as double

dim as long    index, codeLength, level
dim as long    evalErr
dim as double  stack(_maxEvalStackSize)

index      = 1 // counter through code
level      = 0 // stack
evalErr    = _noErr // we hope
codeLength = codeArray(0) // stored in 0th element of code array

while ( index <= codeLength and evalErr == _noErr )

select codeArray(index)
case _plusOpCode
level--
stack(level) = stack(level) + stack(level + 1)
case _minusOpCode
level--
stack(level) = stack(level) - stack(level + 1)
case _xVarOpCode
level++
stack(level) = xVar
case _yVarOpCode
level++
stack(level) = yVar
case _timesOpCode
level--
stack(level) = stack(level)*stack(level + 1)
case _divideOpCode
level--
stack(level) = stack(level)/stack(level + 1)
case _readConstCode
inc (index) // second word of opcode
level++
stack(level) = litConsts(codeArray(index))
case _unaryMinusCode
stack(level) = -stack(level)
case _EXPopCode
stack(level) = exp( stack(level) )
case _LOGopCode
stack(level) = log( stack(level) )
case _LOG10opCode
stack(level) = log10( stack(level) )
case _SQRopCode
stack(level) = stack(level)*stack(level)
case _SQRTopCode
stack(level) = sqr( stack(level) )
case _SINopCode
stack(level) = sin( stack(level) )
case _COSopCode
stack(level) = cos (stack(level) )
case _TANopCode
stack(level) = tan (stack(level) )
case _ATNopCode
stack(level) = atn (stack(level) )
case _powerOpCode
level--
stack(level) = stack(level)^stack(level + 1)
case _ABSOpCode
stack(level) = abs( stack(level) )
case _INTopCode
stack(level) = fix( stack(level) )
case _piOpCode
level++
stack(level) = pi
case else
stop "Programming error: undefined opcode"
end select
inc( index )
wend
errReturnPtr.nil% = evalErr // signal numeric error
end fn = stack(1)
