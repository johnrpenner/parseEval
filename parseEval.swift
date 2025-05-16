// parseEval.swift version 3.0
// A Recursive Parser based on Robert Purves
// FutureBasic Recursive Descent Parser Demo (2000)
// 
// Created by John Penner on 07-15-17.
// Updated: April 29, 2020 by johnrpenner
// Updated: April 13, 2025 by Grok3 
// Copyright © 2025 John Roland Penner. All rights reserved.


//--| ParseEvaluate.main |-----//

// ParseEvaluate.fbas
// Robert Purves (2000)
// 
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



import Foundation

//---| GLOBALS |-------

// Parse setup values
let _maxNumConsts: Int = 20 // adjust to suit
let _maxNumSymbols: Int = 100 // adjust to suit
let _maxCodeLength: Int = 100 // adjust to suit
let _maxEvalStackSize: Int = 10
let _commentChar: String = "`"
let _spaceChar: String = " "

// Output of a parse, and input to FN Evaluate
var gParsedConstants = [Double](repeating: 0.0, count: _maxNumConsts)
var gMyCodeArray = [Int](repeating: 0, count: _maxCodeLength + 1) // +1 for length storage

// Communication between Parse modules
var gNumConsts: Int = 0
var gCode: Int = 0
var gParseError: Bool = false
var gTextPtr: String = "" // Holds the Full Expression String Under Evaluation
var gCharPos: Int = 0 // Index to Location in Text

// Parse lexeme types
enum lexemeTypes {
    case _plusMinusOpType
    case _timesDivideOpType
    case _powerOpType
    case _leftParenType
    case _rightParenType
    case _readVarType
    case _unaryOpType
    case _readConstType
}

// Evaluate opcodes
enum evalOPcodes: Int {
    case _noOpCode
    case _plusOpCode
    case _minusOpCode
    case _timesOpCode
    case _divideOpCode
    case _powerOpCode
    case _xVarOpCode
    case _yVarOpCode
    case _unaryMinusCode
    case _EXPopCode
    case _LOGopCode
    case _LOG10opCode
    case _SQRopCode
    case _SQRTopCode
    case _SINopCode
    case _COSopCode
    case _TANopCode
    case _ATNopCode
    case _ABSOpCode
    case _INTopCode
    case _piOpCode
    case _readConstCode
}

// Symbol Table
var gSymTable = [String](repeating: "", count: _maxNumSymbols)
var gSymType = [lexemeTypes](repeating: ._plusMinusOpType, count: _maxNumSymbols)
var gSymCode = [evalOPcodes](repeating: ._noOpCode, count: _maxNumSymbols)
var gNumSyms: Int = 0

// Number search tables
var gNumStartString = [String](repeating: "", count: 12)
var gNumContentString = [String](repeating: "", count: 15)
var gNumofNumStartStrings: Int = 0
var gNumofNumContentStrings: Int = 0

class parseEval: NSObject {
    //--| PROPERTIES |-----
    
    var exprString: String
    
    init(exprString: String) {
        self.exprString = exprString
    }
    
    //--| METHODS |-----------------------------------------------------------
    
    func getWords(inString: String) -> [String] {
        return inString.components(separatedBy: " ")
    }
    
    func getChar(theString: String, charIndex: Int) -> String {
        if charIndex >= 0 && charIndex < theString.count {
            return String(theString[theString.index(theString.startIndex, offsetBy: charIndex)])
        }
        return ""
    }
    
    func midString(theString: String, charIndex: Int, range: Int) -> String {
        let start = theString.index(theString.startIndex, offsetBy: charIndex)
        let end = theString.index(theString.startIndex, offsetBy: min(charIndex + range, theString.count))
        let span = start..<end
        return String(theString[span])
    }
    
    func string2char(theString: String) -> Character {
        let defChar: Character = " "
        if !theString.isEmpty {
            return theString.first!
        }
        return defChar
    }
    
    func contains(thisString: String, inString: String) -> Bool {
        if !thisString.isEmpty && !inString.isEmpty {
            let ofString = thisString.first!
            return inString.firstIndex(of: ofString) != nil
        }
        return false
    }
    
    func findLoc(ofString: String, inString: String) -> Int {
        if !ofString.isEmpty && inString.count > ofString.count {
            let offString = ofString.first!
            if let idx = inString.firstIndex(of: offString) {
                let pos = inString.distance(from: inString.startIndex, to: idx)
                print("findLoc(): Found \(offString) at position \(pos)")
                return pos
            } else {
                print("findLoc(): Not found")
                return -1
            }
        } else {
            print("findLoc(): zeroLength")
            return -1
        }
    }
    
    //--| PARSE |-------------------------------------------------------------
    
    func clearParseError() {
        gParseError = false
    }
    
    func parseError(errMsg: String) {
        if gParseError { return }
        gParseError = true
        print("Parse error: \(errMsg)")
    }
    
    func addToSymTable(opStr: String, type: lexemeTypes, opcode: evalOPcodes) {
        if gNumSyms >= _maxNumSymbols {
            print("Symbol table full")
            return
        }
        
        let lenInsertStr = opStr.count
        
        if lenInsertStr < 1 {
            print("Program error: null string in AddToSymTable")
            return
        }
        
        var insertIndex = 1
        while insertIndex <= gNumSyms && lenInsertStr <= gSymTable[insertIndex].count {
            if lenInsertStr == gSymTable[insertIndex].count && opStr.uppercased() == gSymTable[insertIndex].uppercased() {
                print("Symbol table entry duplicated")
                return
            }
            insertIndex += 1
        }
        
        gSymTable.insert(opStr, at: insertIndex)
        gSymType.insert(type, at: insertIndex)
        gSymCode.insert(opcode, at: insertIndex)
        gNumSyms += 1
    }
    
    func initSymbolTable() {
        gNumSyms = 0
        addToSymTable(opStr: "(", type: ._leftParenType, opcode: ._noOpCode)
        addToSymTable(opStr: ")", type: ._rightParenType, opcode: ._noOpCode)
        addToSymTable(opStr: "+", type: ._plusMinusOpType, opcode: ._plusOpCode)
        addToSymTable(opStr: "-", type: ._plusMinusOpType, opcode: ._minusOpCode)
        addToSymTable(opStr: "*", type: ._timesDivideOpType, opcode: ._timesOpCode)
        addToSymTable(opStr: "/", type: ._timesDivideOpType, opcode: ._divideOpCode)
        addToSymTable(opStr: "^", type: ._powerOpType, opcode: ._powerOpCode)
        addToSymTable(opStr: "π", type: ._readVarType, opcode: ._piOpCode)
        addToSymTable(opStr: "EXP", type: ._unaryOpType, opcode: ._EXPopCode)
        addToSymTable(opStr: "LOG", type: ._unaryOpType, opcode: ._LOGopCode)
        addToSymTable(opStr: "LN", type: ._unaryOpType, opcode: ._LOGopCode)
        addToSymTable(opStr: "LOG10", type: ._unaryOpType, opcode: ._LOG10opCode)
        addToSymTable(opStr: "SIN", type: ._unaryOpType, opcode: ._SINopCode)
        addToSymTable(opStr: "COS", type: ._unaryOpType, opcode: ._COSopCode)
        addToSymTable(opStr: "TAN", type: ._unaryOpType, opcode: ._TANopCode)
        addToSymTable(opStr: "ATN", type: ._unaryOpType, opcode: ._ATNopCode)
        addToSymTable(opStr: "ATAN", type: ._unaryOpType, opcode: ._ATNopCode)
        addToSymTable(opStr: "SQR", type: ._unaryOpType, opcode: ._SQRopCode)
        addToSymTable(opStr: "SQRT", type: ._unaryOpType, opcode: ._SQRTopCode)
        addToSymTable(opStr: "ABS", type: ._unaryOpType, opcode: ._ABSOpCode)
        addToSymTable(opStr: "INT", type: ._unaryOpType, opcode: ._INTopCode)
        addToSymTable(opStr: "PI", type: ._readVarType, opcode: ._piOpCode)
    }
    
    func isStringInText(soughtStr: String, inString: String, startPos: Int) -> Bool {
        guard startPos > 0 && startPos <= inString.count else { return false }
        let adjustedPos = startPos - 1 // Convert 1-based to 0-based
        let inSuffix = String(inString.suffix(from: inString.index(inString.startIndex, offsetBy: adjustedPos)))
        if inSuffix.uppercased().hasPrefix(soughtStr.uppercased()) {
            return true
        }
        return false
    }
    
    func whereIsStringInText(soughtStr: String, inString: String, startPos: Int) -> Int {
        guard startPos > 0 && startPos <= inString.count else { return -1 }
        let adjustedPos = startPos - 1
        let inSuffix = String(inString.suffix(from: inString.index(inString.startIndex, offsetBy: adjustedPos)))
        if inSuffix.uppercased().hasPrefix(soughtStr.uppercased()) {
            return startPos
        }
        return -1
    }
    
    func storeParsedConst(value: Double) -> Int {
        var j: Int
        
        if gNumConsts > 0 {
            for j in 1..<gNumConsts {
                if value == gParsedConstants[j] { return j }
            }
        }
        
        if gNumConsts < _maxNumConsts {
            gNumConsts += 1
            gParsedConstants[gNumConsts] = value
            j = gNumConsts
        } else {
            parseError(errMsg: "Too many constants")
            j = 1
        }
        
        return j
    }
    
    func initNumSearchStrings() {
        for j in 1...10 {
            gNumStartString[j] = String(j - 1)
            gNumContentString[j] = gNumStartString[j]
        }
        
        gNumStartString[11] = "."
        gNumofNumStartStrings = 12
        
        gNumContentString[11] = "."
        gNumContentString[12] = "E-"
        gNumContentString[13] = "E+"
        gNumContentString[14] = "E"
        gNumofNumContentStrings = 15
    }
    
    func getIndexOfNextNumContentBit() -> Int {
        for j in 1..<gNumofNumContentStrings {
            if isStringInText(soughtStr: gNumContentString[j], inString: gTextPtr, startPos: gCharPos) {
                return j
            }
        }
        return 0
    }
    
    //--| SWIFT PARSE JRP |------------------------------------------------------------
    
    func parseInput(cmd: String) -> String {
        var resultString = "string \(cmd) Not Found"
        
        let inWords = getWords(inString: cmd)
        let inCount = inWords.count
        
        if inCount > 0 {
            if isStringInText(soughtStr: cmd, inString: exprString, startPos: 0) {
                let strLoc = whereIsStringInText(soughtStr: cmd, inString: exprString, startPos: 0)
                resultString = "string \(cmd) Found @\(strLoc)"
            }
            initNumSearchStrings()
        }
        
        return resultString
    }
    
    //--| GROK FutureBASIC Functions converted from ParseEvaluate.bas |-----------------
    
    func isNumeric(theString: String) -> Bool {
        var numeric = false
        let chars = Array(theString.utf8)
        var index = 0
        let endIndex = chars.count
        
        func nextChar() -> Int {
            if index < endIndex {
                let ch = Int(chars[index])
                index += 1
                return ch
            }
            return -1
        }
        
        var ch = nextChar()
        while ch == Int(_spaceChar.utf8.first!) {
            ch = nextChar()
        }
        
        if ch == Int("+".utf8.first!) || ch == Int("-".utf8.first!) {
            ch = nextChar()
        }
        
        var digitFound = false
        while ch >= Int("0".utf8.first!) && ch <= Int("9".utf8.first!) {
            digitFound = true
            ch = nextChar()
        }
        
        if digitFound {
            if ch == Int(".".utf8.first!) {
                ch = nextChar()
                while ch >= Int("0".utf8.first!) && ch <= Int("9".utf8.first!) {
                    ch = nextChar()
                }
            }
        } else {
            if ch == Int(".".utf8.first!) {
                ch = nextChar()
                digitFound = false
                while ch >= Int("0".utf8.first!) && ch <= Int("9".utf8.first!) {
                    digitFound = true
                    ch = nextChar()
                }
                if !digitFound {
                    return false
                }
            } else {
                return false
            }
        }
        
        if ch == Int("E".utf8.first!) || ch == Int("e".utf8.first!) {
            ch = nextChar()
            if ch == Int("+".utf8.first!) || ch == Int("-".utf8.first!) {
                ch = nextChar()
            }
            digitFound = false
            while ch >= Int("0".utf8.first!) && ch <= Int("9".utf8.first!) {
                digitFound = true
                ch = nextChar()
            }
            if !digitFound {
                return false
            }
        }
        
        while ch == Int(_spaceChar.utf8.first!) {
            ch = nextChar()
        }
        
        numeric = (ch == -1)
        return numeric
    }
    
    func parseNumber() -> Double {
        var numString = ""
        var j = getIndexOfNextNumContentBit()
        
        while j > 0 {
            numString += gNumContentString[j]
            let length = gNumContentString[j].count
            gCharPos += length
            j = getIndexOfNextNumContentBit()
        }
        
        if !isNumeric(theString: numString) {
            parseError(errMsg: "Bad number format")
        }
        
        return Double(numString) ?? 0.0
    }
    
    func skipSillyChars() {
        var continueParsing = true
        var endCommentSought = false
        
        while continueParsing && gCharPos <= gTextPtr.count {
            let charIndex = gCharPos - 1
            let theChar = charIndex < gTextPtr.count ? getChar(theString: gTextPtr, charIndex: charIndex) : ""
            
            if theChar == _commentChar {
                endCommentSought.toggle()
            } else if theChar != "" && theChar != _spaceChar && !endCommentSought {
                continueParsing = false
            }
            
            if continueParsing {
                gCharPos += 1
            }
        }
        
        if endCommentSought {
            parseError(errMsg: "Unterminated comment")
        }
    }
    
    func getLexeme() -> lexemeTypes? {
        var type: lexemeTypes? = nil
        if gParseError { return type }
        
        skipSillyChars()
        //print("getLexeme: charPos=\(gCharPos), current char='\(gCharPos <= gTextPtr.count ? getChar(theString: gTextPtr, charIndex: gCharPos - 1) : "EOF")'")
        
        for j in 1...gNumSyms {
            if isStringInText(soughtStr: gSymTable[j], inString: gTextPtr, startPos: gCharPos) {
                //print("Matched symbol: \(gSymTable[j])")
                type = gSymType[j]
                gCode = j
                gCharPos += gSymTable[j].count
                return type
            }
        }
        
        for j in 1..<gNumofNumStartStrings {
            if isStringInText(soughtStr: gNumStartString[j], inString: gTextPtr, startPos: gCharPos) {
                //print("Matched number start: \(gNumStartString[j])")
                let value = parseNumber()
                gCode = storeParsedConst(value: value)
                type = ._readConstType
                return type
            }
        }
        
        type = nil
        if gCharPos < gTextPtr.count {
            parseError(errMsg: "Name or symbol not recognisable")
        }
        
        return type
    }
    
    func getRightParenthesis(type: lexemeTypes?) -> lexemeTypes? {
        if gParseError { return type }
        
        if type != ._rightParenType {
            parseError(errMsg: "Expecting right parenthesis")
        } else {
            return getLexeme()
        }
        
        return type
    }
    
    func getLeftParenthesis(type: lexemeTypes?) -> lexemeTypes? {
        if gParseError { return type }
        
        if type != ._leftParenType {
            parseError(errMsg: "Expecting left parenthesis")
        } else {
            return getLexeme()
        }
        
        return type
    }
    
    func plantCode(code: Int) {
        if gParseError { return }
        
        var codeLength = gMyCodeArray[0]
        
        if codeLength < _maxCodeLength {
            codeLength += 1
            gMyCodeArray[0] = codeLength
            gMyCodeArray[codeLength] = code
        } else {
            parseError(errMsg: "Expression too long")
        }
    }
    
    func factor(type: lexemeTypes?) -> lexemeTypes? {
        if gParseError { return type }
        
        guard let currentType = type else {
            parseError(errMsg: "Syntax error")
            return nil
        }
        
        switch currentType {
        case ._readConstType:
            plantCode(code: evalOPcodes._readConstCode.rawValue)
            plantCode(code: gCode)
            return getLexeme()
            
        case ._readVarType:
            plantCode(code: gSymCode[gCode].rawValue)
            return getLexeme()
            
        case ._leftParenType:
            var newType = getLexeme()
            newType = expression(type: newType)
            return getRightParenthesis(type: newType)
            
        case ._plusMinusOpType:
            let tempCode = gSymCode[gCode]
            var newType = getLexeme()
            newType = factor(type: newType)
            if tempCode == ._minusOpCode {
                plantCode(code: evalOPcodes._unaryMinusCode.rawValue)
            }
            return newType
            
        case ._unaryOpType:
            let tempCode = gSymCode[gCode]
            var newType = getLexeme()
            newType = getLeftParenthesis(type: newType)
            newType = expression(type: newType)
            newType = getRightParenthesis(type: newType)
            plantCode(code: tempCode.rawValue)
            return newType
            
        default:
            parseError(errMsg: "Syntax Error")
            return nil
        }
    }
    
    func powerTerm(type: lexemeTypes?) -> lexemeTypes? {
        if gParseError { return type }
        
        var currentType = factor(type: type)
        
        while currentType == ._powerOpType {
            let tempCode = gSymCode[gCode]
            currentType = getLexeme()
            currentType = factor(type: currentType)
            plantCode(code: tempCode.rawValue)
        }
        
        return currentType
    }
    
    func term(type: lexemeTypes?) -> lexemeTypes? {
        if gParseError { return type }
        
        var currentType = powerTerm(type: type)
        
        while currentType == ._timesDivideOpType {
            let tempCode = gSymCode[gCode]
            currentType = getLexeme()
            currentType = powerTerm(type: currentType)
            plantCode(code: tempCode.rawValue)
        }
        
        return currentType
    }
    
    func expression(type: lexemeTypes?) -> lexemeTypes? {
        if gParseError { return type }
        
        var currentType = term(type: type)
        
        while currentType == ._plusMinusOpType {
            let tempCode = gSymCode[gCode]
            currentType = getLexeme()
            currentType = term(type: currentType)
            plantCode(code: tempCode.rawValue)
        }
        
        return currentType
    }
    
    func parseText(xVar: String, yVar: String, text: String) {
        clearParseError()
        
        gTextPtr = text
        gCharPos = 1
        gNumConsts = 0
        gMyCodeArray[0] = 0
        initSymbolTable()
        initNumSearchStrings()
        
        if !xVar.isEmpty {
            addToSymTable(opStr: xVar, type: ._readVarType, opcode: ._xVarOpCode)
        }
        if !yVar.isEmpty {
            addToSymTable(opStr: yVar, type: ._readVarType, opcode: ._yVarOpCode)
        }
        
        var type = getLexeme()
        
        if type == nil {
            parseError(errMsg: "Missing expression")
        } else {
            type = expression(type: type)
            skipSillyChars()
            
            if !gParseError {
                if type != nil {
                    parseError(errMsg: "Syntax error")
                } else if gCharPos != gTextPtr.count + 1 {
                    parseError(errMsg: "End of expression expected")
                }
            }
        }
    }
    
    func evaluate(codeArray: [Int], litConsts: [Double], xVar: Double, yVar: Double) -> (result: Double, error: Bool) {
        var index = 1
        var level = 0
        var evalErr = false
        let codeLength = codeArray[0]
        var stack = [Double](repeating: 0.0, count: _maxEvalStackSize)
        
        while index <= codeLength && !evalErr {
            let opcode = codeArray[index]
            
            switch evalOPcodes(rawValue: opcode) {
            case ._plusOpCode:
                level -= 1
                stack[level] = stack[level] + stack[level + 1]
                
            case ._minusOpCode:
                level -= 1
                stack[level] = stack[level] - stack[level + 1]
                
            case ._xVarOpCode:
                level += 1
                stack[level] = xVar
                
            case ._yVarOpCode:
                level += 1
                stack[level] = yVar
                
            case ._timesOpCode:
                level -= 1
                stack[level] = stack[level] * stack[level + 1]
                
            case ._divideOpCode:
                level -= 1
                if stack[level + 1] == 0 {
                    evalErr = true
                } else {
                    stack[level] = stack[level] / stack[level + 1]
                }
                
            case ._readConstCode:
                index += 1
                level += 1
                stack[level] = litConsts[codeArray[index]]
                
            case ._unaryMinusCode:
                stack[level] = -stack[level]
                
            case ._EXPopCode:
                stack[level] = exp(stack[level])
                
            case ._LOGopCode:
                if stack[level] <= 0 {
                    evalErr = true
                } else {
                    stack[level] = log(stack[level])
                }
                
            case ._LOG10opCode:
                if stack[level] <= 0 {
                    evalErr = true
                } else {
                    stack[level] = log10(stack[level])
                }
                
            case ._SQRopCode:
                stack[level] = stack[level] * stack[level]
                
            case ._SQRTopCode:
                if stack[level] < 0 {
                    evalErr = true
                } else {
                    stack[level] = sqrt(stack[level])
                }
                
            case ._SINopCode:
                stack[level] = sin(stack[level])
                
            case ._COSopCode:
                stack[level] = cos(stack[level])
                
            case ._TANopCode:
                stack[level] = tan(stack[level])
                
            case ._ATNopCode:
                stack[level] = atan(stack[level])
                
            case ._powerOpCode:
                level -= 1
                if stack[level] < 0 && stack[level + 1] != floor(stack[level + 1]) {
                    evalErr = true
                } else {
                    stack[level] = pow(stack[level], stack[level + 1])
                }
                
            case ._ABSOpCode:
                stack[level] = abs(stack[level])
                
            case ._INTopCode:
                stack[level] = floor(stack[level])
                
            case ._piOpCode:
                level += 1
                stack[level] = Double.pi
                
            default:
                evalErr = true
                print("Programming error: undefined opcode")
            }
            
            index += 1
        }
        
        return (stack[1], evalErr)
    }
}

/* Test The Output
let parser = parseEval(exprString: "10*(x + y)/2.0 + sin( π*0.5 )")
parser.parseText(xVar: "x", yVar: "y", text: parser.exprString)
if !gParseError {
    let result = parser.evaluate(codeArray: gMyCodeArray, litConsts: gParsedConstants, xVar: 1.0, yVar: 2.01)
    if !result.error {
        print("Result: \(String(format: "%.2f", result.result))")
    } else {
        print("Evaluation error")
    }
} else {
    print("Parse error")
}
*/

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

// $ swiftc -o parseEval parseEvalGrok.swift
// Death-Star:recursiveParser john$ ./parseEval
// Enter expression:
// 10*(x + y)/2.0 + sin( π*0.5 )
// Result: 16.05
// Death-Star:recursiveParser john$ 

