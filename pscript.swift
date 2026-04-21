// parseEval.swift
// pScript v0.8.40 - Copyright 2026 by John Roland Penner
// Based on Recursive Descent Parser by Robert Purves (2008)
// Last Updated: April 19, 2026
// 
// Milestone 8: FUNCTIONS | func definitions, local scope, return values, recursion
// Milestone 12: TIMER with INKEY$
// Milestone 13: WHILE
// Milestone 14: INKEY$ within TIMER
// Milestone 21: Double-Buffering Graphics Redraw
// Milestone 23: Multi-Dimensional Arrays
// Milestone 24: Logical Operators && || ^^ ! 
// Milestone 25: VAL(str) CHR$(num) ASC(str)
// Milestone 30: SPRITE() and FUNC() in timerON()
// Milestone 33: PLAY Sound command: PLAY(id, volume[, urlString])
// Milestone 34: TEXT command: TEXT(r,g,b,a) colour of TEXT Foreground
// Milestone 35: FILL command: FILL(r,g,b,a) colour of TEXT Background
// Milestone 36: MOUSEAT(); Error Reporting in CLI; and User Guide PDF.
// Milestone 37: MOD % Operator
// Milestone 38: DIST(x1,y1,x2,y2) with hypot() = 1.75× faster than pBasic SQRT()
// Milestone 39: Multi-Line IF { }
// Milestone 40: MORE for DIR HELP and LIST


/*

// FutureBasic Recursive Descent Parser Demo
// ParseEvaluate.fbas by Robert Purves (2000)
// Simple demo of Expression parsing and evaluation.
// Written for FBtoC   rp 20081005

A parser should:
(1) Accept valid expressions
(2) Reject invalid expressions
(3) Show the location of errors, and give good error messages.

ParseText understands the following lexemes:
+ - * / ^ ( )
EXP, LOG or LN, LOG10,
SIN, COS, TAN, ATN or ATAN, ABS, INT,
SQR (square), SQRT (square root)
Three special variables with names (simply "x", "y" and "z")
Numbers (such as 5, -3.1889, and 1e-10)

All of the above except numbers are recognised by way of the symbol table. 
The symbol table is composed, somewhat inelegantly, of three global arrays
which must be updated in Tandem:

dim gSymTable(_maxNumSymbols) as String
dim gSymType(_maxNumSymbols)  as Int
dim gSymCode(_maxNumSymbols)  as Int

FN InitSymbolTable enters the above lexemes into the symbol table.
The parser ignores white space or comments anywhere except inside another lexeme.

*/


import Foundation
import AVFoundation

// Milestone 22: Version string — update only after full test/validate cycle
let pScriptVersion: String = "pScript 0.8.40 • ©2026 by John Roland Penner"

//---| GLOBALS |-------

// Parse setup values
let _maxNumConsts: Int = 500
let _maxNumSymbols: Int = 200
let _maxCodeLength: Int = 1000
let _maxEvalStackSize: Int = 50
let _spaceChar: String = " "

// Output of a parse, and input to FN Evaluate
var gParsedConstants = [Double](repeating: 0.0, count: _maxNumConsts)
var gMyCodeArray = [Int](repeating: 0, count: _maxCodeLength + 1)

// Communication between Parse modules
var gNumConsts: Int = 0
var gCode: Int = 0
var gParseError: Bool = false
var gTextPtr: String = ""
var gCharPos: Int = 0

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
	case _keywordType
	case _assignOpType
	case _typeNameType
	case _compareOpType
	case _leftBracketType      // For array indexing [
	case _rightBracketType     // For array indexing ]
	case _leftBraceType        // Milestone 4: { for func bodies
	case _rightBraceType       // Milestone 4: } for func bodies
	case _logicalOpType        // Milestone 24: && || ^^ binary logical/bitwise operators
}

// Evaluate opcodes
enum evalOPcodes: Int {
	case _noOpCode
	case _plusOpCode
	case _minusOpCode
	case _timesOpCode
	case _divideOpCode
	case _modOpCode
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
	case _dateOpCode
	case _timeOpCode
	case _readConstCode
	case _RNDopCode			// Random number function
	case _LENopCode			// String Length function
	case _MIDopCode			// MID$() Substring Extraction
	// Milestone 1
	case _storeVarOpCode
	case _loadVarOpCode
	case _printOpCode
	case _tabOpCode
	case _clsOpCode
	case _inputOpCode
	case _endOpCode
	case _exitOpCode
	case _varDeclOpCode
	// Milestone 2
	case _equalOpCode
	case _greaterOpCode
	case _lessOpCode
	case _greaterEqOpCode
	case _lessEqOpCode
	case _notEqualOpCode
	case _forBeginOpCode
	case _forNextOpCode
	case _ifThenOpCode
	case _jumpOpCode
	case _jumpIfFalseOpCode
	// Milestone 3: Arrays
	case _arrayLoadOpCode		// Load value from array[index]
	case _arrayStoreOpCode		// Store value to array[index]
	case _redimOpCode			// Resize array
	// Milestone 4: Functions
	case _funcCallOpCode		// Call a user-defined function
	case _returnOpCode			// Return from a function
	// pBasic: App-only Commands (cursor, graphics, sound, etc)
	case _locateOpCode			// LOCATE row, col (like GW-BASIC)
	// Milestone 5: Timer
	case _timerDeclOpCode		// TIMER interval funcName  — declare interval + callback
	case _timerOnOpCode			// TIMERON  — start/resume the declared timer
	case _timerStopOpCode		// TIMERSTOP — suspend timer (remembers pending events)
	case _timerOffOpCode		// TIMEROFF — invalidate timer (must redeclare before TIMERON)
	// pBasic: Graphics commands (LINE, POINT, SAMPLE)
	case _pointOpCode			// POINT(x, y [,R,G,B,A])        — plot a pixel
	case _lineOpCode			// LINE(x1,y1,x2,y2 [,R,G,B,A])  — draw a line
	case _sampleOpCode			// SAMPLE(x, y, channel)         — read pixel channel (returns Float)
	case _clrOpCode				// CLR - clear graphics canvas (like CLS for text)
	// Milestone 10: WHILE loop
	case _whileOpCode			// WHILE (condition) { — test condition, jump past } if false
	case _whileEndOpCode		// } closing a WHILE block — jump back to WHILE line
	// Milestone 14: INKEY$ — non-blocking key read (pBasic.app only)
	case _inkeyOpCode			// INKEY$ — returns next queued key token, or "" if none waiting
	// Milestone 21: File I/O
	case _fileLoadOpCode		// fileLines[] = LOAD(urlString) — load text file into string array
	case _fileSaveOpCode		// SAVE urlExpr, arrayName[] — write string array to text file
	// PEN command
	case _penOpCode				// PEN size — set global pen width for LINE and POINT (logical points)
	// Milestone 19: Double-buffering
	case _bufferOpCode			// BUFFER / BUFFER:0 / BUFFER:1 — switch draw/display buffer targets
	// Milestone 22: Version and Beep
	case _versionOpCode			// VERSION$ — returns version string constant
	case _beepOpCode			// BEEP — triggers system bell
	// Milestone 23: Multi-dimensional array access
	case _arrayLoadMDOpCode		// Load value from array[i,j,...] — multi-dim
	case _arrayStoreMDOpCode	// Store value to array[i,j,...] — multi-dim
	// Milestone 24: Logical / bitwise operators
	case _logicalAndOpCode		// && — bitwise AND (ints) or logical AND (otherwise)
	case _logicalOrOpCode		// || — bitwise OR  (ints) or logical OR  (otherwise)
	case _logicalXorOpCode		// ^^ — bitwise XOR (ints) or logical XOR (otherwise)
	case _logicalNotOpCode		// !  — bitwise NOT (int)  or logical NOT (otherwise)
	// Milestone 26: String/character conversion functions
	case _VALopCode				// VAL(str)  — parse string to Float
	case _CHRopCode				// CHR$(num) — Unicode scalar value to one-char String
	case _ASCopCode				// ASC(str)  — first character of string to Unicode scalar Int
	// Milestone 26b: STR$ — numeric to string conversion
	case _STRopCode				// STR$(num) — convert numeric expression to String
	// Milestone 28: SAY — text-to-speech
	case _sayOpCode				// SAY string — speak string via AVSpeechSynthesizer
	case _sayStopOpCode			// SAY STOP — halt speech immediately
	// Milestone 30: SPRITE and GET — SpriteKit sprite management
	case _spriteOpCode			// SPRITE(id, x, y, rot, scale, hidden, alpha, imageURL)
	case _getOpCode				// GET(id, x1, y1, x2, y2) — capture canvas region as sprite texture
	case _mouseatOpCode			// mouseAT(X|Y|B) command — capture mouse coords + button
	case _playOpCode			// PLAY(id, vol, url) LOAD Sound; PLAY(id, vol) PLAY Sound
	case _soundOpCode			// SOUND(MIDInote, durationSecs, volume[0..1.0]
	case _fillOpCode			// FILL(r,g,b,a) — Sets Text Background Colour + Fill for Shapes
	case _textColorOpCode		// TEXT(r,g,b,a) — Sets Text Foreground Colour
	case _ifBeginOpCode			// Milestone 39: IF ( cond ) { — jump past } if false
	case _ifEndOpCode			// Milestone 39: } closing an IF block — no-op
	case _distOpCode			// Milestone 38: DIST(x1,y1,x2,y2) Hypotenuse = sqrt((x2-x1)² + (y2-y1)²)
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

var gTempStringForArray: String = ""
let _tempArrayStringVarIndex = 999999       // Special index for temp variable

//---| MILESTONE 1: VALUE TYPES & VARIABLES |-------

enum Value {
	case int(Int)
	case float(Double)
	case string(String)
	case bool(Bool)
	
	func toString() -> String {
		switch self {
		case .int(let i): return String(i)
		case .float(let f): return String(format: "%.6g", f)
		case .string(let s): return s
		case .bool(let b): return b ? "true" : "false"
		}
	}
	
	func toDouble() -> Double {
		switch self {
		case .int(let i): return Double(i)
		case .float(let f): return f
		case .bool(let b): return b ? 1.0 : 0.0
		case .string(_): return 0.0
		}
	}
	
	func toInt() -> Int {
		switch self {
		case .int(let i): return i
		case .float(let f): return Int(f)
		case .bool(let b): return b ? 1 : 0
		case .string(_): return 0
		}
	}
	
	func toBool() -> Bool {
		switch self {
		case .int(let i): return i != 0
		case .float(let f): return f != 0.0
		case .bool(let b): return b
		case .string(let s): return !s.isEmpty
		}
	}
}

enum VarType {
	case intType
	case floatType
	case stringType
	case boolType
	case intArrayType      // Int array
	case floatArrayType    // Float array
	case stringArrayType   // String array
	case boolArrayType     // Bool array
	
	// Helper to get base type from array type
	func baseType() -> VarType {
		switch self {
		case .intArrayType: return .intType
		case .floatArrayType: return .floatType
		case .stringArrayType: return .stringType
		case .boolArrayType: return .boolType
		default: return self
		}
	}
	
	// Check if this is an array type
	func isArray() -> Bool {
		switch self {
		case .intArrayType, .floatArrayType, .stringArrayType, .boolArrayType:
			return true
		default:
			return false
		}
	}
	
	// Get array type from base type
	static func arrayType(from baseType: VarType) -> VarType {
		switch baseType {
		case .intType: return .intArrayType
		case .floatType: return .floatArrayType
		case .stringType: return .stringArrayType
		case .boolType: return .boolArrayType
		default: return baseType
		}
	}
}

struct VariableInfo {
	var type: VarType
	var value: Value
	var arraySize: Int?        // Size of array if this is an array variable
}

var gVariables: [String: VariableInfo] = [:]
var gVariableTypes: [String: VarType] = [:]

/// Protects gVariables, gVariableTypes, gIntArrays, gFloatArrays,
/// gStringArrays, and gBoolArrays against concurrent access from the
/// main executor thread and gTimerQueue.
/// Acquired at every call site; helper functions (getArrayElement etc.)
/// are lock-free — callers hold the lock when invoking them.
var gVariablesLock = NSLock()

/// Protects the parser table counter variables gNumVarNames, gNumConsts,
/// and gNumStringConsts against concurrent increment from the timer
/// callback (gTimerQueue) while the main executor is running.
/// The underlying arrays (gVarNames, gParsedConstants, gStringConstants)
/// are pre-allocated at full capacity so no copy-on-write reallocation
/// occurs — only the counters need protection.
var gParserTablesLock = NSLock()

// Array storage - separate from scalar variables for efficiency
// Each array name maps to its data storage
var gIntArrays: [String: [Int]] = [:]
var gFloatArrays: [String: [Double]] = [:]
var gStringArrays: [String: [String]] = [:]
var gBoolArrays: [String: [Bool]] = [:]

// Milestone 23: dimension metadata for multi-dimensional arrays.
// Maps array name → ordered list of dimension sizes (e.g. [200,3] for a 200×3 array).
// 1D arrays have a single-element list. Protected by gVariablesLock.
var gArrayDimensions: [String: [Int]] = [:]


// Program storage
var gProgramLines: [String] = []

// String handling
let _stringConstMarker: Double = 1.23456789e100
let _stringVarMarker: Double = 9.87654321e100
var gStringConstants = [String](repeating: "", count: _maxNumConsts)
var gNumStringConsts: Int = 0
var gStringVarRefs = [Int](repeating: 0, count: _maxEvalStackSize)
var gStringConstRefs = [Int](repeating: 0, count: _maxEvalStackSize)
var gVarNames = [String](repeating: "", count: _maxNumSymbols)
var gNumVarNames: Int = 0

// Check if stdin is from a pipe (not interactive terminal)
let gStdinIsPiped = isatty(FileHandle.standardInput.fileDescriptor) == 0


//---| MILESTONE 2: CONTROL FLOW |-------

struct ForLoopInfo {
	var varName: String
	var endValue: Double
	var stepValue: Double
	var loopStartPC: Int
}

var gForLoopStack: [ForLoopInfo] = []


//---| MILESTONE 3: ARRAY HELPERS |-------

// Initialize an array with default values based on type.
// dims: full dimension list e.g. [200,3] for a 2D array; [500] for 1D.
// size must equal the product of all dims.
func initializeArray(name: String, size: Int, type: VarType, dims: [Int] = []) {
	gVariablesLock.lock()
	defer { gVariablesLock.unlock() }
	switch type {
	case .intArrayType:
		gIntArrays[name] = [Int](repeating: 0, count: size)
	case .floatArrayType:
		gFloatArrays[name] = [Double](repeating: 0.0, count: size)
	case .stringArrayType:
		gStringArrays[name] = [String](repeating: "", count: size)
	case .boolArrayType:
		gBoolArrays[name] = [Bool](repeating: false, count: size)
	default:
		break
	}
	// Store dimension metadata (defaults to [size] for 1D if dims not provided)
	gArrayDimensions[name] = dims.isEmpty ? [size] : dims
}

// Resize an array with logical-address-preserving copy.
// newDims: the new dimension list (must have same count as original dims).
// Values at logical addresses valid in BOTH old and new layouts are retained.
// Values at addresses that exceed any new dimension bound are truncated.
// New slots are zero/empty initialised.
func resizeArray(name: String, newSize: Int, type: VarType, newDims: [Int] = []) -> Bool {
	guard newSize > 0 else { return false }
	gVariablesLock.lock()
	defer { gVariablesLock.unlock() }

	// Retrieve old dimension metadata
	let oldDims = gArrayDimensions[name] ?? [newSize]  // fallback: treat as 1D

	// Compute strides for old and new layouts
	// stride[i] = product of all dimensions after i
	func computeStrides(_ dims: [Int]) -> [Int] {
		var strides = [Int](repeating: 1, count: dims.count)
		for i in stride(from: dims.count - 2, through: 0, by: -1) {
			strides[i] = strides[i + 1] * dims[i + 1]
		}
		return strides
	}

	// Convert a flat index to logical coordinates given dims
	func flatToCoords(_ flatIdx: Int, dims: [Int], strides: [Int]) -> [Int] {
		var coords = [Int](repeating: 0, count: dims.count)
		var remaining = flatIdx
		for i in 0..<dims.count {
			coords[i] = remaining / strides[i]
			remaining  = remaining % strides[i]
		}
		return coords
	}

	// Convert logical coordinates to flat index given strides
	func coordsToFlat(_ coords: [Int], strides: [Int]) -> Int {
		var flat = 0
		for i in 0..<coords.count { flat += coords[i] * strides[i] }
		return flat
	}

	// Check all coordinates are within new bounds
	func coordsInBounds(_ coords: [Int], dims: [Int]) -> Bool {
		for i in 0..<coords.count {
			if coords[i] >= dims[i] { return false }
		}
		return true
	}

	let resolvedNewDims = newDims.isEmpty ? [newSize] : newDims
	let oldStrides = computeStrides(oldDims)
	let newStrides = computeStrides(resolvedNewDims)

	switch type {
	case .intArrayType:
		guard let oldArr = gIntArrays[name] else { return false }
		var newArr = [Int](repeating: 0, count: newSize)
		for flatIdx in 0..<oldArr.count {
			let coords = flatToCoords(flatIdx, dims: oldDims, strides: oldStrides)
			if coordsInBounds(coords, dims: resolvedNewDims) {
				let newFlat = coordsToFlat(coords, strides: newStrides)
				newArr[newFlat] = oldArr[flatIdx]
			}
		}
		gIntArrays[name] = newArr

	case .floatArrayType:
		guard let oldArr = gFloatArrays[name] else { return false }
		var newArr = [Double](repeating: 0.0, count: newSize)
		for flatIdx in 0..<oldArr.count {
			let coords = flatToCoords(flatIdx, dims: oldDims, strides: oldStrides)
			if coordsInBounds(coords, dims: resolvedNewDims) {
				let newFlat = coordsToFlat(coords, strides: newStrides)
				newArr[newFlat] = oldArr[flatIdx]
			}
		}
		gFloatArrays[name] = newArr

	case .stringArrayType:
		guard let oldArr = gStringArrays[name] else { return false }
		var newArr = [String](repeating: "", count: newSize)
		for flatIdx in 0..<oldArr.count {
			let coords = flatToCoords(flatIdx, dims: oldDims, strides: oldStrides)
			if coordsInBounds(coords, dims: resolvedNewDims) {
				let newFlat = coordsToFlat(coords, strides: newStrides)
				newArr[newFlat] = oldArr[flatIdx]
			}
		}
		gStringArrays[name] = newArr

	case .boolArrayType:
		guard let oldArr = gBoolArrays[name] else { return false }
		var newArr = [Bool](repeating: false, count: newSize)
		for flatIdx in 0..<oldArr.count {
			let coords = flatToCoords(flatIdx, dims: oldDims, strides: oldStrides)
			if coordsInBounds(coords, dims: resolvedNewDims) {
				let newFlat = coordsToFlat(coords, strides: newStrides)
				newArr[newFlat] = oldArr[flatIdx]
			}
		}
		gBoolArrays[name] = newArr

	default:
		return false
	}

	// Update dimension metadata
	gArrayDimensions[name] = resolvedNewDims
	return true
}

// Get array element value
func getArrayElement(name: String, index: Int, type: VarType) -> Value? {
	switch type {
	case .intArrayType:
		guard let arr = gIntArrays[name], index >= 0, index < arr.count else { return nil }
		return .int(arr[index])
	case .floatArrayType:
		guard let arr = gFloatArrays[name], index >= 0, index < arr.count else { return nil }
		return .float(arr[index])
	case .stringArrayType:
		guard let arr = gStringArrays[name], index >= 0, index < arr.count else { return nil }
		return .string(arr[index])
	case .boolArrayType:
		guard let arr = gBoolArrays[name], index >= 0, index < arr.count else { return nil }
		return .bool(arr[index])
	default:
		return nil
	}
}

// Set array element value with type checking
func setArrayElement(name: String, index: Int, value: Value, type: VarType) -> Bool {
	switch type {
	case .intArrayType:
		guard var arr = gIntArrays[name], index >= 0, index < arr.count else { return false }
		// Type checking: only accept Int values
		guard case .int(let intVal) = value else { return false }
		arr[index] = intVal
		gIntArrays[name] = arr
		
	case .floatArrayType:
		guard var arr = gFloatArrays[name], index >= 0, index < arr.count else { return false }
		// Type checking: only accept Float values
		guard case .float(let floatVal) = value else { return false }
		arr[index] = floatVal
		gFloatArrays[name] = arr
		
	case .stringArrayType:
		guard var arr = gStringArrays[name], index >= 0, index < arr.count else { return false }
		// Type checking: only accept String values
		guard case .string(let strVal) = value else { return false }
		arr[index] = strVal
		gStringArrays[name] = arr
		
	case .boolArrayType:
		guard var arr = gBoolArrays[name], index >= 0, index < arr.count else { return false }
		// Type checking: only accept Bool values
		guard case .bool(let boolVal) = value else { return false }
		arr[index] = boolVal
		gBoolArrays[name] = arr
		
	default:
		return false
	}
	
	return true
}


//---| MILESTONE 4: FUNCTION DEFINITIONS & CALL STACK |-------

// Stores the definition of a user-defined function found during pre-scan
struct FunctionDef {
	var name: String            // Function name (lowercase for lookup)
	var params: [String]        // Parameter names (in order)
	var bodyStartLine: Int      // Index of first line inside { }
	var bodyEndLine: Int        // Index of line containing closing }
}

// One frame on the call stack per active function call.
// Saves the COMPLETE execution state of the calling line so that
// on RETURN we can inject the return value and continue mid-expression.
struct CallFrame {
	var funcName: String
	var localVariables: [String: VariableInfo]   // Local variable storage
	var localTypes: [String: VarType]             // Local type declarations
	// Saved calling-line execution state (restored on RETURN)
	var returnPC: Int                              // Line index of the call site
	var returnIndex: Int                           // Opcode index to resume (just after _funcCallOpCode block)
	var savedStack: [Double]                       // Full eval stack snapshot at call time
	var savedStackLevel: Int                       // Stack level at call time (before args were consumed)
	var savedStringConstRefs: [Int]                // gStringConstRefs snapshot
	var savedStringVarRefs: [Int]                  // gStringVarRefs snapshot
	// For-loop stack saved per frame (so nested functions don't corrupt outer loops)
	var savedForLoopStack: [ForLoopInfo]
	// Milestone 10: While-loop stack saved per frame (so nested functions don't
	// corrupt outer WHILE loops — each call frame gets a clean WHILE stack)
	var savedWhileLoopStack: [WhileLoopInfo]
}

// Global function definition table (populated during pre-scan)
var gFunctionDefs: [String: FunctionDef] = [:]

// Per-function local variable type registry — populated during parse phase.
// Keys: function name -> (var name -> VarType). Used to seed CallFrame.localTypes
// so that VAR declarations inside functions are truly local at runtime.
var gFunctionLocalTypes: [String: [String: VarType]] = [:]

// Set before parsing each line so parseVarDeclaration knows which function
// (if any) owns that line. nil = top-level code.
var gCurrentParseFuncName: String? = nil

// Milestone 10: Set before parsing each line so parseStatement() knows the
// current line index — needed to distinguish a WHILE-closing } from a func-closing }.
var gCurrentParseLineNum: Int = 0

// Call stack (grows with each function call, shrinks on return)
var gCallStack: [CallFrame] = []

// Sentinel used in the return-value double slot to signal a string return
let _returnStringMarker: Double = 5.55555555e99


//---| MILESTONE 10: WHILE LOOP STATE |-------

// WhileLoopInfo is used by the runtime stack to support future BREAK-inside-WHILE.
// For basic looping we use gWhilePairs / gWhileEnds (pre-scanned, no runtime push/pop needed).
struct WhileLoopInfo {
	var conditionPC: Int    // line index of the WHILE line
	var endPC: Int          // line index of the closing } line
}

// Runtime WHILE stack — currently used for save/restore across function calls.
// Reserved for BREAK support in a future milestone.
var gWhileLoopStack: [WhileLoopInfo] = []

// Pre-scan While{} and IF{}: populated by preScanBraceBlocks() before execution.
// gWhilePairs: WHILE-line-index  → closing-brace-line-index
// gWhileEnds:  closing-brace-line-index → WHILE-line-index
// gIfPairs / gIfEnds opening and closing brace for Multi-Line IF (cond) { }
// Both dicts together let the executor jump in either direction in O(1).
var gWhilePairs: [Int: Int] = [:]
var gWhileEnds:  [Int: Int] = [:]

// Milestone 39: MULTI-LINE IF { } Pairs
var gIfPairs: [Int: Int] = [:]
var gIfEnds:  [Int: Int] = [:]


//---| MILESTONE 5: TIMER STATE |-------
// NOTE: gVariables / gVariableTypes are accessed from both the main executor
// thread and the timer callback thread without synchronisation.  This is safe
// in practice for the intended use case (timer functions that read computed
// values such as TIME and route output through the delegate), but could
// theoretically cause a data race if a timer function reads/writes the same
// variable that the main program is simultaneously modifying.
// TODO: wrap gVariables access in a serial DispatchQueue mutex when full
// concurrent variable access is required (e.g. sprite state shared between
// game-loop timer and main input handler).

/// Declared timer interval in seconds (set by TIMER statement).
var gTimerInterval: Double = 1.0 / 60.0

/// Name of the pScript function to call on each timer tick (set by TIMER statement).
var gTimerFuncName: String = ""

/// The active DispatchSourceTimer, or nil if not yet created / invalidated.
var gTimerSource: DispatchSourceTimer? = nil

/// Delegate captured at TIMERON time so the timer callback can route
/// PRINT / LOCATE output to the correct terminal display.
/// NOTE FOR TERMINAL BUILD: this is always nil (CLI build has no delegate).
var gTimerDelegate: PScriptDelegate? = nil

/// Re-entrancy guard: set true while the timer callback is executing.
/// If the previous tick hasn't finished when the next fires, we skip the new tick.
/// Accessed only from the timer's serial DispatchQueue — no mutex needed.
var gTimerBusy: Bool = false

/// Set to true when the user presses CTRL+C in pBasic.app (or SIGINT in CLI).
/// Checked at the top of each opcode iteration in executeProgramWithControlFlow()
/// so that tight loops (FOR, nested functions) can be interrupted immediately.
/// Reset to false inside the break handler (self-clearing on first acted-upon check).
var gBreakRequested: Bool = false

/// Text editor used by the EDIT command.
/// Set to the .app name without extension — macOS `open -a` handles the rest.
/// Future: move to pTerm.app preferences panel.
let gEditorApp: String = "CotEditor"

/// Path of the most recently LOADed file.
/// Set by the LOAD command in processReplCommand().
/// Used by the EDIT command to open the file in gEditorApp.
/// Empty string means no file has been loaded this session.
var gLastLoadedFilePath: String = ""

/// Path of the most recently SAVEd file (from SAVE fileLines[] statement).
/// Used as the default output directory for subsequent SAVE calls.
/// Empty string means no file has been saved this session via pScript SAVE.
var gLastSaveFilePath: String = ""

/// Current pen width in logical points, used by LINE and POINT draw calls.
/// Default 1.0 = one logical point (2 physical pixels on Retina).
/// Set by the PEN statement. Passed to GraphicsLayer via pscriptPenSize().
var gPenSize: Double = 1.0
/// Current fill colour RGBA — used by PRINT text background and future shape commands.
/// Default (0,0,0,0) = transparent = no background drawn.
/// Set by the FILL statement. Passed to delegate at PRINT time. 
var gFillColor: (r: Double, g: Double, b: Double, a: Double) = (0.0, 0.0, 0.0, 0.0)
/// Current text colour RGBA — used by all PRINT statements.
/// Default (0, 0.91, 0.23, 1.0) = phosphor green.
/// Set by the TEXT statement.
var gTextColor: (r: Double, g: Double, b: Double, a: Double) = (0.0, 0.91, 0.23, 1.0)

/// Milestone 19: Active draw buffer index (0 or 1).
/// All POINT / LINE / CLR calls write to this buffer.
/// The display buffer is always the other one (1 - gDrawBuffer) after a swap.
/// BUFFER:1 → gDrawBuffer = 1 (draw to back, display front)
/// BUFFER:0 → gDrawBuffer = 0 (draw to front, display back — rare)
/// BUFFER   → swap: gDrawBuffer = 1 - gDrawBuffer, display swaps too
var gDrawBuffer: Int = 0

/// Dedicated serial queue on which all timer callbacks execute.
/// Serial = only one tick runs at a time; busy-guard handles the overlap case.
let gTimerQueue = DispatchQueue(label: "pscript.timer", qos: .userInteractive)

/// Lightweight call frame for function calls inside the timer executor.
/// Holds only the state the timer's innerLoop needs to restore on RETURN.
struct TimerCallFrame {
	var funcName:      String
	var returnPC:      Int
	var returnIndex:   Int
	var lineCodeArrays: [[Int]]
	var savedLevel:    Int
	var savedStack:    [Double]
	var savedStrConst: [Int]
	var savedStrVar:   [Int]
	var savedForStack: [ForLoopInfo]
	var savedWhileStack: [WhileLoopInfo]
	var localWhilePairs: [Int: Int]
	var localWhileEnds:  [Int: Int]
	var localIfPairs:    [Int: Int]    // Milestone 39
	var localIfEnds:     [Int: Int]    // Milestone 39
}

/// Start or resume the declared timer.
/// Validates that the declared function exists; calls timerOff() and returns
/// false if not found (per spec: "execute a TIMEROFF, and do nothing").
@discardableResult
func timerOn(delegate: PScriptDelegate?) -> Bool {
	guard !gTimerFuncName.isEmpty,
		  gFunctionDefs[gTimerFuncName.lowercased()] != nil else {
		// No valid function — invalidate and do nothing
		timerOff()
		return false
	}
	
	// If a source already exists (e.g. TIMERSTOP was called), resume it.
	// Only actually call resume() if it was suspended — calling resume()
	// on a running source decrements the suspend count below zero → trap.
	if let existing = gTimerSource {
		if gTimerIsSuspended {
			existing.resume()
			gTimerIsSuspended = false
		}
		return true
	}
	
	// Capture delegate for use inside callback
	gTimerDelegate = delegate
	
	// Create a new repeating timer on the dedicated serial queue
	let source = DispatchSource.makeTimerSource(queue: gTimerQueue)
	//print("DEBUG timerOn: gTimerInterval=\(gTimerInterval) gTimerFuncName=\(gTimerFuncName)")
	let clampedInterval = gTimerInterval.isFinite && gTimerInterval > 0 ? gTimerInterval : 0.016
	let intervalNS = UInt64(clampedInterval * 1_000_000_000)
	source.schedule(deadline: .now() + clampedInterval,
					repeating: .nanoseconds(Int(intervalNS)),
					leeway: .milliseconds(1))

	source.setEventHandler {
		// Re-entrancy guard: skip this tick if the previous one is still running
		guard !gTimerBusy else { return }
		gTimerBusy = true
		defer { gTimerBusy = false }

		// Look up the function definition — if it has disappeared (e.g. NEW was
		// called while the timer was running) just stop cleanly.
		let funcName = gTimerFuncName.lowercased()
		guard let fdef = gFunctionDefs[funcName] else {
			timerOff()
			return
		}

		// Guard against an empty body
		guard fdef.bodyStartLine < fdef.bodyEndLine else { return }

		// Build a fresh interpreter for this tick.
		// IMPORTANT: we do NOT call executeProgramWithControlFlow() here because
		// that function resets gFunctionDefs (via preScanFunctions()), gNumConsts,
		// gNumVarNames etc. — all of which belong to the main program.
		// Instead we parse and execute only the body lines directly.
		let interp = parseEval(exprString: "")
		interp.delegate = gTimerDelegate

		// Save all parse-state globals that executeProgramWithControlFlow would clobber.
		// Milestone 10: gWhilePairs, gWhileEnds, and gWhileLoopStack added to saved set
		// so that a timer firing during a WHILE loop cannot corrupt the main program's
		// WHILE pair tables or runtime stack.
		let savedFuncDefs     = gFunctionDefs      // preScanFunctions() clears this
		let savedForStack     = gForLoopStack
		let savedCallStack    = gCallStack
		let savedWhileStack   = gWhileLoopStack    // Milestone 10
		
		// Snapshot counters only — NOT the array contents.
		// The timer's parser appends after the existing entries (no reset),
		// and we restore the counters in defer to truncate those entries back out.
		// This prevents both the index-out-of-range crash and unbounded table growth.
		let savedNumConsts    = gNumConsts
		let savedNumStrConsts = gNumStringConsts
		let savedNumVarNames  = gNumVarNames
		
		gForLoopStack.removeAll()
		gCallStack.removeAll()
		gWhileLoopStack.removeAll()                // Milestone 10
		// NOTE: do NOT clear gWhilePairs / gWhileEnds here — the timer executor uses
		// localWhilePairs / localWhileEnds exclusively, and the main executor needs
		// gWhilePairs / gWhileEnds to remain intact while its WHILE loops are running.
		defer {
			// Truncate tables back to pre-tick length — discards timer's appended entries.
			// Array contents below these indices are untouched and still valid.
			gNumConsts        = savedNumConsts
			gNumStringConsts  = savedNumStrConsts
			gNumVarNames      = savedNumVarNames
			gFunctionDefs     = savedFuncDefs
			gForLoopStack     = savedForStack
			gCallStack        = savedCallStack
			gWhileLoopStack   = savedWhileStack    // Milestone 10
			// NOTE: gWhilePairs / gWhileEnds are NOT restored here — they were never
			// cleared, so the saved values equal the current values. The main executor's
			// WHILE pair tables are untouched throughout the timer callback.
		}

		// Re-initialise symbol table and number strings for the fresh interpreter.
		// CRITICAL: do NOT reset gNumConsts, gNumStringConsts, or gNumVarNames.
		// The main executor is concurrently reading gParsedConstants, gStringConstants,
		// and gVarNames — resetting the counters causes the timer's parser to overwrite
		// indices that the main program is actively using, corrupting its runtime state.
		// Instead, the timer's parser appends new constants/vars after the existing ones.
		// The timer's local lineCodeArrays reference these higher indices correctly.
		interp.initSymbolTable()
		interp.initNumSearchStrings()
		
		// Parse the body lines into bytecode.
		// Milestone 10: pre-scan WHILE pairs within the timer function body,
		// offset by bodyStartLine so line indices match the local lineCodeArrays indices.
		let bodyLines = Array(gProgramLines[fdef.bodyStartLine ..< fdef.bodyEndLine])

		// Milestone 39: unified brace pre-scan for timer body
		var localWhilePairs: [Int: Int] = [:]
		var localWhileEnds:  [Int: Int] = [:]
		var localIfPairs:    [Int: Int] = [:]
		var localIfEnds:     [Int: Int] = [:]
		enum TimerBraceOwner { case whileBlock, ifBlock }
		var timerBraceStack: [(owner: TimerBraceOwner, line: Int)] = []
		for (i, bline) in bodyLines.enumerated() {
			let trimmed = bline.trimmingCharacters(in: .whitespaces)
			let upper   = trimmed.uppercased()
			if upper.hasPrefix("WHILE ") || upper.hasPrefix("WHILE(") || upper == "WHILE" {
				timerBraceStack.append((owner: .whileBlock, line: i))
			} else if (upper.hasPrefix("IF ") || upper.hasPrefix("IF("))
					   && upper.hasSuffix("{") && !upper.contains("THEN") {
				timerBraceStack.append((owner: .ifBlock, line: i))
			} else if trimmed.hasPrefix("}") && !timerBraceStack.isEmpty {
				let top = timerBraceStack.removeLast()
				switch top.owner {
				case .whileBlock: localWhilePairs[top.line] = i; localWhileEnds[i] = top.line
				case .ifBlock:    localIfPairs[top.line]    = i; localIfEnds[i]    = top.line
				}
			}
		}

		var lineCodeArrays: [[Int]] = []
		var parseFailed = false
		for (i, line) in bodyLines.enumerated() {
			let trimmed = line.trimmingCharacters(in: .whitespaces)
			if trimmed.isEmpty || trimmed.hasPrefix("}") {
				if let _ = localWhileEnds[i] {
					lineCodeArrays.append([1, evalOPcodes._whileEndOpCode.rawValue])
				} else if let _ = localIfEnds[i] {
					lineCodeArrays.append([1, evalOPcodes._ifEndOpCode.rawValue])
				} else {
					lineCodeArrays.append([0])
				}
				continue
			}
			interp.exprString = trimmed
			gMyCodeArray = [Int](repeating: 0, count: _maxCodeLength + 1)
			if !interp.parseStatement() {
				//print("Timer: parse error at body line \(i + 1): \(trimmed)")
				parseFailed = true
				break
			}
			let cl = gMyCodeArray[0]
			var lca = [Int](repeating: 0, count: cl + 1)
			for j in 0...cl { lca[j] = gMyCodeArray[j] }
			lineCodeArrays.append(lca)
		}
		guard !parseFailed else { return }
		
		// Execute the bytecode lines directly — no call stack, no func-body skipping.
		// Milestone 10: _whileOpCode/_whileEndOpCode use localWhilePairs/localWhileEnds.
		// Milestone 14: _inkeyOpCode and _ifThenOpCode fixes applied.
		var timerWhileStack: [WhileLoopInfo] = []
		var timerForStack:   [ForLoopInfo]   = []   // Milestone 19: FOR/NEXT in timer
		
		// Option A: timer function call stack — supports func calls from within timer callbacks
		var timerCallStack: [TimerCallFrame] = []
		
		// Cache of parsed function bodies for this tick.
		// Each function is parsed once per tick and reused for all calls.
		// Prevents unbounded constant table growth when a function is called
		// multiple times (e.g. checkB0M called 12 times per tick in a loop).
		var parsedBodyCache: [String: (lines: [[Int]], localWhilePairs: [Int:Int], localWhileEnds: [Int:Int], localIfPairs: [Int:Int], localIfEnds: [Int:Int])] = [:]
		
		// Parse a named function's body into a fresh lineCodeArrays for the timer executor.
		// Returns nil if the function is not found or parse fails.
		func parseTimerFuncBody(funcName: String) -> (lines: [[Int]], localWhilePairs: [Int:Int], localWhileEnds: [Int:Int], localIfPairs: [Int:Int], localIfEnds: [Int:Int])? {
			if let cached = parsedBodyCache[funcName] { return cached }

			guard let fdef = gFunctionDefs[funcName] else { return nil }
			guard fdef.bodyStartLine < fdef.bodyEndLine else { return nil }
			let bLines = Array(gProgramLines[fdef.bodyStartLine ..< fdef.bodyEndLine])

			// Milestone 39: unified brace pre-scan — builds WHILE and IF tables in one pass
			var lwPairs: [Int: Int] = [:]
			var lwEnds:  [Int: Int] = [:]
			var liPairs: [Int: Int] = [:]
			var liEnds:  [Int: Int] = [:]
			enum PTFBraceOwner { case whileBlock, ifBlock }
			var ptfBraceStack: [(owner: PTFBraceOwner, line: Int)] = []
			for (i, bline) in bLines.enumerated() {
				let trimmed = bline.trimmingCharacters(in: .whitespaces)
				let upper   = trimmed.uppercased()
				if upper.hasPrefix("WHILE ") || upper.hasPrefix("WHILE(") || upper == "WHILE" {
					ptfBraceStack.append((owner: .whileBlock, line: i))
				} else if (upper.hasPrefix("IF ") || upper.hasPrefix("IF("))
						   && upper.hasSuffix("{") && !upper.contains("THEN") {
					ptfBraceStack.append((owner: .ifBlock, line: i))
				} else if trimmed.hasPrefix("}") && !ptfBraceStack.isEmpty {
					let top = ptfBraceStack.removeLast()
					switch top.owner {
					case .whileBlock: lwPairs[top.line] = i; lwEnds[i] = top.line
					case .ifBlock:    liPairs[top.line] = i; liEnds[i] = top.line
					}
				}
			}

			// Parse bytecode — emit _whileEndOpCode or _ifEndOpCode for closing braces
			var lca: [[Int]] = []
			for (i, line) in bLines.enumerated() {
				let trimmed = line.trimmingCharacters(in: .whitespaces)
				if trimmed.isEmpty || trimmed.hasPrefix("}") {
					if let _ = lwEnds[i] {
						lca.append([1, evalOPcodes._whileEndOpCode.rawValue])
					} else if let _ = liEnds[i] {
						lca.append([1, evalOPcodes._ifEndOpCode.rawValue])
					} else {
						lca.append([0])
					}
					continue
				}
				interp.exprString = trimmed
				gMyCodeArray = [Int](repeating: 0, count: _maxCodeLength + 1)
				guard interp.parseStatement() else { return nil }
				let cl = gMyCodeArray[0]
				var arr = [Int](repeating: 0, count: cl + 1)
				for j in 0...cl { arr[j] = gMyCodeArray[j] }
				lca.append(arr)
			}

			let result = (lca, lwPairs, lwEnds, liPairs, liEnds)
			parsedBodyCache[funcName] = result
			return result
		}

		var pc = 0
		
		// Reset per-line execution state at the start of each line
		var execIndex = 1
		var execLevel = 0
		var execStack    = [Double](repeating: 0.0, count: _maxEvalStackSize)
		var execStrConst = [Int](repeating: 0, count: _maxEvalStackSize)
		var execStrVar   = [Int](repeating: 0, count: _maxEvalStackSize)
		var resumingFromReturn = false
		
		bodyLoop: while true {
			// If we've run off the end of the current function's lines,
			// perform an implicit return (function ended without explicit RETURN).
			if pc >= lineCodeArrays.count {
				guard !timerCallStack.isEmpty else { break bodyLoop }
				// Implicit return — same as _returnOpCode but no return value
				let tcDone      = timerCallStack.removeLast()
				lineCodeArrays  = tcDone.lineCodeArrays
				localWhilePairs = tcDone.localWhilePairs
				localWhileEnds  = tcDone.localWhileEnds
				localIfPairs    = tcDone.localIfPairs    // Milestone 39
				localIfEnds     = tcDone.localIfEnds     // Milestone 39
				timerForStack   = tcDone.savedForStack
				timerWhileStack = tcDone.savedWhileStack
				
				pc              = tcDone.returnPC
				
				execLevel       = tcDone.savedLevel
				execStack       = tcDone.savedStack
				execStrConst    = tcDone.savedStrConst
				execStrVar      = tcDone.savedStrVar
				for i in 0..<_maxEvalStackSize {
					gStringConstRefs[i] = execStrConst[i]
					gStringVarRefs[i]   = execStrVar[i]
				}
				execIndex = tcDone.returnIndex
				resumingFromReturn = true
				continue bodyLoop
			}
			let codeArray = lineCodeArrays[pc]
			guard codeArray[0] > 0 else { pc += 1; continue }
			
			// Reset per-line execution state
			if resumingFromReturn {
				resumingFromReturn = false
				// execIndex, execLevel, execStack etc already restored from frame — don't reset
			} else {
				execIndex    = 1
				execLevel    = 0
				execStack    = [Double](repeating: 0.0, count: _maxEvalStackSize)
				execStrConst = [Int](repeating: 0, count: _maxEvalStackSize)
				execStrVar   = [Int](repeating: 0, count: _maxEvalStackSize)
			}
			
			// Label the inner opcode loop so _ifThenOpCode can break just this
			// line's opcodes without aborting the entire body (Bug 2 fix).
			innerLoop: while execIndex <= codeArray[0] {
				// Sync global string ref arrays
				for i in 0..<_maxEvalStackSize {
					gStringConstRefs[i] = execStrConst[i]
					gStringVarRefs[i]   = execStrVar[i]
				}

				let opcode = codeArray[execIndex]
				
				switch evalOPcodes(rawValue: opcode) {

				case ._readConstCode:
					execIndex += 1; execLevel += 1
					let ci = codeArray[execIndex]
					if ci < 0 { execStack[execLevel] = _stringConstMarker; execStrConst[execLevel] = -ci }
					else       { execStack[execLevel] = gParsedConstants[ci] }

				case ._loadVarOpCode:
					execIndex += 1
					let vni = codeArray[execIndex]
					let vn  = gVarNames[vni]
					execLevel += 1
					gVariablesLock.lock()
					let timerVI = gVariables[vn]
					gVariablesLock.unlock()
					if let vi = timerVI {
						if vi.type == .stringType {
							execStack[execLevel] = _stringVarMarker; execStrVar[execLevel] = vni
						} else {
							execStack[execLevel] = vi.value.toDouble()
						}
					} else { execStack[execLevel] = 0.0 }

				case ._storeVarOpCode:
					execIndex += 1
					let vni = codeArray[execIndex]
					let vn  = gVarNames[vni]
					gVariablesLock.lock()
					let timerVT = gVariableTypes[vn]
					gVariablesLock.unlock()
					guard let vt = timerVT else { break bodyLoop }
					let sv = execStack[execLevel]
					let val: Value
					switch vt {
					case .stringType:
						if sv == _stringConstMarker      { val = .string(gStringConstants[execStrConst[execLevel]]) }
						else if sv == _stringVarMarker   { val = gVariables[gVarNames[execStrVar[execLevel]]]?.value ?? .string("") }
						else                             { val = .string(sv == floor(sv) && abs(sv) < Double(Int.max) ? String(Int(sv)) : String(format:"%.6g",sv)) }
					case .intType:   val = .int(Int(sv))
					case .floatType: val = .float(sv)
					case .boolType:  val = .bool(sv != 0.0)
					default: break bodyLoop
					}
					gVariablesLock.lock()
				gVariables[vn] = VariableInfo(type: vt, value: val)
				gVariablesLock.unlock()
				execLevel -= 1
					
				case ._arrayLoadOpCode:
					execIndex += 1
					let alVni = codeArray[execIndex]
					let alVn  = gVarNames[alVni]
					let alIdx = Int(execStack[execLevel]); execLevel -= 1
					gVariablesLock.lock()
						let alVt = gVariableTypes[alVn]
						gVariablesLock.unlock()
					guard let alVt else {
						let tErrA = "Timer Error: Array \(alVn) not declared"
						print(tErrA); interp.delegate?.pscriptPrint(tErrA, newline: true)
						break
					}
					gVariablesLock.lock()
					let alVal = getArrayElement(name: alVn, index: alIdx, type: alVt)
					gVariablesLock.unlock()
					if let av = alVal {
						execLevel += 1
						if alVt.baseType() == .stringType {
							if case .string(let s) = av { gTempStringForArray = s }
							else { gTempStringForArray = "" }
							execStack[execLevel]  = _stringVarMarker
							execStrVar[execLevel] = _tempArrayStringVarIndex
						} else {
							execStack[execLevel] = av.toDouble()
						}
					} else {
						let tErrB = "Timer Error: Array index \(alIdx) out of bounds for \(alVn)"
						print(tErrB); interp.delegate?.pscriptPrint(tErrB, newline: true)
					}
					
				case ._arrayStoreOpCode:
					execIndex += 1
					let asVni = codeArray[execIndex]
					let asVn  = gVarNames[asVni]
					let asVal = execStack[execLevel]; execLevel -= 1
					let asIdx = Int(execStack[execLevel]); execLevel -= 1
					gVariablesLock.lock()
						let asVt = gVariableTypes[asVn]
						gVariablesLock.unlock()
						guard let asVt else {
							let tErrC = "Timer Error: Array \(asVn) not declared"
							print(tErrC); interp.delegate?.pscriptPrint(tErrC, newline: true)
							break
						}
					var asStoreVal: Value = .int(0)
					switch asVt.baseType() {
						case .intType:   asStoreVal = .int(Int(asVal))
						case .floatType: asStoreVal = .float(asVal)
						case .stringType:
							if asVal == _stringConstMarker {
								asStoreVal = .string(gStringConstants[execStrConst[execLevel + 2]])
							} else if asVal == _stringVarMarker {
								let si = execStrVar[execLevel + 2]
								if si == _tempArrayStringVarIndex {
									asStoreVal = .string(gTempStringForArray)
								} else {
									let sn = gVarNames[si]
									gVariablesLock.lock()
									let sv = gVariables[sn]?.value
									gVariablesLock.unlock()
									asStoreVal = sv ?? .string("")
								}
							} else {
								asStoreVal = .string(asVal == floor(asVal) && abs(asVal) < Double(Int.max)
									? String(Int(asVal)) : String(format: "%.6g", asVal))
							}
						case .boolType:  asStoreVal = .bool(asVal != 0.0)
							default:
								let tErrD = "Timer Error: Invalid array type for \(asVn)"
								print(tErrD); interp.delegate?.pscriptPrint(tErrD, newline: true)
								break
							}
					gVariablesLock.lock()
					let asOk = setArrayElement(name: asVn, index: asIdx, value: asStoreVal, type: asVt)
					gVariablesLock.unlock()
					if !asOk {
						let tErrE = "Timer Error: Array index \(asIdx) out of bounds for \(asVn)"
						print(tErrE); interp.delegate?.pscriptPrint(tErrE, newline: true)
					}

				case ._printOpCode:
					execIndex += 1
					let mode = codeArray[execIndex]
					if mode == 0 {
						if let d = interp.delegate { d.pscriptPrint("", newline: true) }
						else { print() }
					} else {
						let pv = execStack[execLevel]
						var out = ""
						if pv == _stringConstMarker      { out = gStringConstants[execStrConst[execLevel]] }
						else if pv == _stringVarMarker   { out = gVariables[gVarNames[execStrVar[execLevel]]]?.value.toString() ?? "" }
						else if pv == floor(pv) && abs(pv) < Double(Int.max) { out = String(Int(pv)) }
						else { out = String(format:"%.6g", pv) }
						if let d = interp.delegate { d.pscriptPrint(out, newline: mode != 2) }
						else { mode == 2 ? print(out, terminator:"") : print(out) }
						execLevel -= 1
					}

				case ._locateOpCode:
					let locCol = Int(execStack[execLevel]); execLevel -= 1
					let locRow = Int(execStack[execLevel]); execLevel -= 1
					if let d = interp.delegate { d.pscriptLocate(locRow, locCol) }
					else { print("\u{001B}[\(locRow);\(locCol)H", terminator:""); fflush(stdout) }

				case ._timeOpCode:
					execLevel += 1
					let tf = DateFormatter(); tf.dateFormat = "HH:mm:ss"
					let si = interp.storeStringConst(value: tf.string(from: Date()))
					execStack[execLevel] = _stringConstMarker; execStrConst[execLevel] = si

				case ._dateOpCode:
					execLevel += 1
					let df = DateFormatter(); df.dateFormat = "MMM d yyyy"
					let si = interp.storeStringConst(value: df.string(from: Date()))
					execStack[execLevel] = _stringConstMarker; execStrConst[execLevel] = si

				case ._plusOpCode:
					execLevel -= 1
					let lv = execStack[execLevel], rv = execStack[execLevel+1]
					let lStr = lv == _stringConstMarker || lv == _stringVarMarker
					let rStr = rv == _stringConstMarker || rv == _stringVarMarker
					if lStr && rStr {
						var ls = "", rs = ""
						if lv == _stringConstMarker { ls = gStringConstants[execStrConst[execLevel]] }
						else {
							gVariablesLock.lock()
							ls = gVariables[gVarNames[execStrVar[execLevel]]]?.value.toString() ?? ""
							gVariablesLock.unlock()
						}
						if rv == _stringConstMarker { rs = gStringConstants[execStrConst[execLevel+1]] }
						else {
							gVariablesLock.lock()
							rs = gVariables[gVarNames[execStrVar[execLevel+1]]]?.value.toString() ?? ""
							gVariablesLock.unlock()
						}
						let si = interp.storeStringConst(value: ls+rs)
						execStack[execLevel] = _stringConstMarker; execStrConst[execLevel] = si
					} else { execStack[execLevel] = lv + rv }

				case ._minusOpCode:  execLevel -= 1; execStack[execLevel] = execStack[execLevel] - execStack[execLevel+1]
				case ._timesOpCode:  execLevel -= 1; execStack[execLevel] = execStack[execLevel] * execStack[execLevel+1]
				case ._divideOpCode:
					execLevel -= 1
					if execStack[execLevel+1] != 0 { execStack[execLevel] = execStack[execLevel] / execStack[execLevel+1] }
				case ._modOpCode:                   // Milestone 37: % MOD operator
					execLevel -= 1
					if execStack[execLevel+1] != 0 {
						execStack[execLevel] = execStack[execLevel].truncatingRemainder(dividingBy: execStack[execLevel+1])
					}
				case ._unaryMinusCode: execStack[execLevel] = -execStack[execLevel]
				
				// Milestone 24: Logical / bitwise operators in timer callbacks
				case ._logicalAndOpCode:
					execLevel -= 1
					let tlaL = execStack[execLevel], tlaR = execStack[execLevel+1]
					if tlaL == floor(tlaL) && tlaR == floor(tlaR) &&
					   abs(tlaL) < Double(Int.max) && abs(tlaR) < Double(Int.max) {
						execStack[execLevel] = Double(Int(tlaL) & Int(tlaR))
					} else {
						execStack[execLevel] = (tlaL != 0.0 && tlaR != 0.0) ? 1.0 : 0.0
					}

				case ._logicalOrOpCode:
					execLevel -= 1
					let tloL = execStack[execLevel], tloR = execStack[execLevel+1]
					if tloL == floor(tloL) && tloR == floor(tloR) &&
					   abs(tloL) < Double(Int.max) && abs(tloR) < Double(Int.max) {
						execStack[execLevel] = Double(Int(tloL) | Int(tloR))
					} else {
						execStack[execLevel] = (tloL != 0.0 || tloR != 0.0) ? 1.0 : 0.0
					}

				case ._logicalXorOpCode:
					execLevel -= 1
					let tlxL = execStack[execLevel], tlxR = execStack[execLevel+1]
					if tlxL == floor(tlxL) && tlxR == floor(tlxR) &&
					   abs(tlxL) < Double(Int.max) && abs(tlxR) < Double(Int.max) {
						execStack[execLevel] = Double(Int(tlxL) ^ Int(tlxR))
					} else {
						let tlxLb = tlxL != 0.0, tlxRb = tlxR != 0.0
						execStack[execLevel] = (tlxLb != tlxRb) ? 1.0 : 0.0
					}

				case ._logicalNotOpCode:
					let tlnV = execStack[execLevel]
					if tlnV == floor(tlnV) && abs(tlnV) < Double(Int.max) {
						execStack[execLevel] = Double(~Int(tlnV))
					} else {
						execStack[execLevel] = (tlnV == 0.0) ? 1.0 : 0.0
					}

				case ._SINopCode:  execStack[execLevel] = sin(execStack[execLevel])
				case ._COSopCode:  execStack[execLevel] = cos(execStack[execLevel])
				case ._TANopCode:  execStack[execLevel] = tan(execStack[execLevel])
				case ._ATNopCode:  execStack[execLevel] = atan(execStack[execLevel])
				case ._ABSOpCode:  execStack[execLevel] = abs(execStack[execLevel])
				case ._INTopCode:  execStack[execLevel] = floor(execStack[execLevel])
				case ._SQRTopCode: execStack[execLevel] = sqrt(max(0, execStack[execLevel]))
				case ._SQRopCode:  execStack[execLevel] = execStack[execLevel] * execStack[execLevel]
				case ._EXPopCode:  execStack[execLevel] = exp(execStack[execLevel])
				case ._LOGopCode:  if execStack[execLevel] > 0 { execStack[execLevel] = log(execStack[execLevel]) }
				case ._piOpCode:   execLevel += 1; execStack[execLevel] = Double.pi
				case ._RNDopCode:  execStack[execLevel] = Double.random(in: 0.0..<1.0)

				// String-aware comparisons (Milestone 14)
				case ._equalOpCode:
					execLevel -= 1
					let tlEq = execStack[execLevel], trEq = execStack[execLevel+1]
					if tlEq == _stringConstMarker || tlEq == _stringVarMarker ||
					   trEq == _stringConstMarker || trEq == _stringVarMarker {
						var ls = "", rs = ""
						if tlEq == _stringConstMarker { ls = gStringConstants[execStrConst[execLevel]] }
						else if tlEq == _stringVarMarker { let vi=execStrVar[execLevel]; if vi == _tempArrayStringVarIndex { ls = gTempStringForArray } else if vi >= 1 { let vn=gVarNames[vi]; gVariablesLock.lock(); if let inf=gVariables[vn], case .string(let s)=inf.value{ls=s}; gVariablesLock.unlock() } }
						if trEq == _stringConstMarker { rs = gStringConstants[execStrConst[execLevel+1]] }
						else if trEq == _stringVarMarker { let vi=execStrVar[execLevel+1]; if vi == _tempArrayStringVarIndex { rs = gTempStringForArray } else if vi >= 1 { let vn=gVarNames[vi]; gVariablesLock.lock(); if let inf=gVariables[vn], case .string(let s)=inf.value{rs=s}; gVariablesLock.unlock() } }
						execStack[execLevel] = ls == rs ? 1 : 0
					} else { execStack[execLevel] = tlEq == trEq ? 1 : 0 }
				
				case ._notEqualOpCode:
					execLevel -= 1
					let tlNe = execStack[execLevel], trNe = execStack[execLevel+1]
					if tlNe == _stringConstMarker || tlNe == _stringVarMarker ||
					   trNe == _stringConstMarker || trNe == _stringVarMarker {
						var ls = "", rs = ""
						if tlNe == _stringConstMarker { ls = gStringConstants[execStrConst[execLevel]] }
						else if tlNe == _stringVarMarker { let vi=execStrVar[execLevel]; if vi == _tempArrayStringVarIndex { ls = gTempStringForArray } else if vi >= 1 { let vn=gVarNames[vi]; gVariablesLock.lock(); if let inf=gVariables[vn], case .string(let s)=inf.value{ls=s}; gVariablesLock.unlock() } }
						if trNe == _stringConstMarker { rs = gStringConstants[execStrConst[execLevel+1]] }
						else if trNe == _stringVarMarker { let vi=execStrVar[execLevel+1]; if vi == _tempArrayStringVarIndex { rs = gTempStringForArray } else if vi >= 1 { let vn=gVarNames[vi]; gVariablesLock.lock(); if let inf=gVariables[vn], case .string(let s)=inf.value{rs=s}; gVariablesLock.unlock() } }
						execStack[execLevel] = ls != rs ? 1 : 0
					} else { execStack[execLevel] = tlNe != trNe ? 1 : 0 }
					
				case ._greaterOpCode:
					execLevel -= 1
					let tlGt = execStack[execLevel], trGt = execStack[execLevel+1]
					if tlGt == _stringConstMarker || tlGt == _stringVarMarker ||
					   trGt == _stringConstMarker || trGt == _stringVarMarker {
						var ls = "", rs = ""
						if tlGt == _stringConstMarker { ls = gStringConstants[execStrConst[execLevel]] }
						else if tlGt == _stringVarMarker { let vi=execStrVar[execLevel]; if vi == _tempArrayStringVarIndex { ls = gTempStringForArray } else if vi >= 1 { let vn=gVarNames[vi]; gVariablesLock.lock(); if let inf=gVariables[vn], case .string(let s)=inf.value{ls=s}; gVariablesLock.unlock() } }
						if trGt == _stringConstMarker { rs = gStringConstants[execStrConst[execLevel+1]] }
						else if trGt == _stringVarMarker { let vi=execStrVar[execLevel+1]; if vi == _tempArrayStringVarIndex { rs = gTempStringForArray } else if vi >= 1 { let vn=gVarNames[vi]; gVariablesLock.lock(); if let inf=gVariables[vn], case .string(let s)=inf.value{rs=s}; gVariablesLock.unlock() } }
						execStack[execLevel] = ls > rs ? 1 : 0
					} else { execStack[execLevel] = tlGt > trGt ? 1 : 0 }
				
				case ._lessOpCode:
					execLevel -= 1
					let tlLt = execStack[execLevel], trLt = execStack[execLevel+1]
					if tlLt == _stringConstMarker || tlLt == _stringVarMarker ||
					   trLt == _stringConstMarker || trLt == _stringVarMarker {
						var ls = "", rs = ""
						if tlLt == _stringConstMarker { ls = gStringConstants[execStrConst[execLevel]] }
						else if tlLt == _stringVarMarker { let vi=execStrVar[execLevel]; if vi == _tempArrayStringVarIndex { ls = gTempStringForArray } else if vi >= 1 { let vn=gVarNames[vi]; gVariablesLock.lock(); if let inf=gVariables[vn], case .string(let s)=inf.value{ls=s}; gVariablesLock.unlock() } }
						if trLt == _stringConstMarker { rs = gStringConstants[execStrConst[execLevel+1]] }
						else if trLt == _stringVarMarker { let vi=execStrVar[execLevel+1]; if vi == _tempArrayStringVarIndex { rs = gTempStringForArray } else if vi >= 1 { let vn=gVarNames[vi]; gVariablesLock.lock(); if let inf=gVariables[vn], case .string(let s)=inf.value{rs=s}; gVariablesLock.unlock() } }
						execStack[execLevel] = ls < rs ? 1 : 0
					} else { execStack[execLevel] = tlLt < trLt ? 1 : 0 }
				
				case ._greaterEqOpCode:
					execLevel -= 1
					let tlGe = execStack[execLevel], trGe = execStack[execLevel+1]
					if tlGe == _stringConstMarker || tlGe == _stringVarMarker ||
					   trGe == _stringConstMarker || trGe == _stringVarMarker {
						var ls = "", rs = ""
						if tlGe == _stringConstMarker { ls = gStringConstants[execStrConst[execLevel]] }
						else if tlGe == _stringVarMarker { let vi=execStrVar[execLevel]; if vi == _tempArrayStringVarIndex { ls = gTempStringForArray } else if vi >= 1 { let vn=gVarNames[vi]; gVariablesLock.lock(); if let inf=gVariables[vn], case .string(let s)=inf.value{ls=s}; gVariablesLock.unlock() } }
						if trGe == _stringConstMarker { rs = gStringConstants[execStrConst[execLevel+1]] }
						else if trGe == _stringVarMarker { let vi=execStrVar[execLevel+1]; if vi == _tempArrayStringVarIndex { rs = gTempStringForArray } else if vi >= 1 { let vn=gVarNames[vi]; gVariablesLock.lock(); if let inf=gVariables[vn], case .string(let s)=inf.value{rs=s}; gVariablesLock.unlock() } }
						execStack[execLevel] = ls >= rs ? 1 : 0
					} else { execStack[execLevel] = tlGe >= trGe ? 1 : 0 }
				
				case ._lessEqOpCode:
					execLevel -= 1
					let tlLe = execStack[execLevel], trLe = execStack[execLevel+1]
					if tlLe == _stringConstMarker || tlLe == _stringVarMarker ||
					   trLe == _stringConstMarker || trLe == _stringVarMarker {
						var ls = "", rs = ""
						if tlLe == _stringConstMarker { ls = gStringConstants[execStrConst[execLevel]] }
						else if tlLe == _stringVarMarker { let vi=execStrVar[execLevel]; if vi == _tempArrayStringVarIndex { ls = gTempStringForArray } else if vi >= 1 { let vn=gVarNames[vi]; gVariablesLock.lock(); if let inf=gVariables[vn], case .string(let s)=inf.value{ls=s}; gVariablesLock.unlock() } }
						if trLe == _stringConstMarker { rs = gStringConstants[execStrConst[execLevel+1]] }
						else if trLe == _stringVarMarker { let vi=execStrVar[execLevel+1]; if vi == _tempArrayStringVarIndex { rs = gTempStringForArray } else if vi >= 1 { let vn=gVarNames[vi]; gVariablesLock.lock(); if let inf=gVariables[vn], case .string(let s)=inf.value{rs=s}; gVariablesLock.unlock() } }
						execStack[execLevel] = ls <= rs ? 1 : 0
					} else { execStack[execLevel] = tlLe <= trLe ? 1 : 0 }
				
				case ._ifThenOpCode:
					let cond = execStack[execLevel]; execLevel -= 1
					if cond == 0.0 {
						// IF false — skip remaining opcodes on THIS line only.
						// break innerLoop exits just the opcode loop, not the whole body.
						break innerLoop
					}
				
				case ._ifBeginOpCode:
					let cond = execStack[execLevel]; execLevel -= 1
					if cond == 0.0 {
						if let exitLine = localIfPairs[pc] {
							pc = exitLine
							break   // break switch → pc+=1 → lands on line after }
						}
						break bodyLoop
					}

				case ._ifEndOpCode:
					break   // no-op
				
				case ._clsOpCode:
					if let d = interp.delegate { d.pscriptCls() }
					else { print("\u{001B}[2J\u{001B}[H", terminator:"") }

				case ._tabOpCode:
					let n = Int(execStack[execLevel]); execLevel -= 1
					let spaces = String(repeating:" ", count: max(0,n))
					if let d = interp.delegate { d.pscriptPrint(spaces, newline:false) }
					else { print(spaces, terminator:"") }

				case ._LENopCode:
					let lv = execStack[execLevel]
					var len = 0
					if lv == _stringConstMarker { len = gStringConstants[execStrConst[execLevel]].count }
					else if lv == _stringVarMarker { len = gVariables[gVarNames[execStrVar[execLevel]]]?.value.toString().count ?? 0 }
					else { len = (lv==floor(lv) ? String(Int(lv)) : String(format:"%.6g",lv)).count }
					execStack[execLevel] = Double(len)

				// Milestone 10: WHILE inside timer function body
				case ._whileOpCode:
					let cond = execStack[execLevel]; execLevel -= 1
					//print("DEBUG WHILE pc=\(pc) cond=\(cond) depth=\(timerCallStack.count) localPairs=\(localWhilePairs)")
					if cond == 0.0 {
						if let exitLine = localWhilePairs[pc] {
							pc = exitLine
							break   // break switch → execIndex+=1 → inner while exits → pc+=1
						}
						break bodyLoop
					}
					timerWhileStack.append(WhileLoopInfo(conditionPC: pc, endPC: localWhilePairs[pc] ?? pc))

				case ._whileEndOpCode:
					//print("DEBUG WHILEEND pc=\(pc) localEnds=\(localWhileEnds)")
					if let whileLine = localWhileEnds[pc] {
						pc = whileLine - 1   // pc+=1 below brings it to whileLine
					}
				
				// Milestone 26: VAL CHR$ ASC inside timer callbacks
				case ._VALopCode:
					let tValRaw = execStack[execLevel]
					var tValSrc = ""
					if tValRaw == _stringConstMarker {
						tValSrc = gStringConstants[execStrConst[execLevel]]
					} else if tValRaw == _stringVarMarker {
						let vi = execStrVar[execLevel]
						if vi == _tempArrayStringVarIndex { tValSrc = gTempStringForArray }
						else if vi >= 1 { let vn=gVarNames[vi]; gVariablesLock.lock(); if let inf=gVariables[vn],case .string(let s)=inf.value{tValSrc=s}; gVariablesLock.unlock() }
					} else { break }
					let tValScanner = Scanner(string: tValSrc)
					tValScanner.charactersToBeSkipped = .whitespaces
					let tValResult: Double = tValScanner.scanDouble() ?? 0.0
					execStack[execLevel] = tValResult

				case ._CHRopCode:
					let tChrNum = Int(execStack[execLevel])
					var tChrResult = ""
					if let scalar = Unicode.Scalar(tChrNum) { tChrResult = String(scalar) }
					let tChrSI = interp.storeStringConst(value: tChrResult)
					execStack[execLevel] = _stringConstMarker
					execStrConst[execLevel] = tChrSI

				case ._STRopCode:
					let tStrRaw = execStack[execLevel]
					if tStrRaw != _stringConstMarker && tStrRaw != _stringVarMarker {
						let tStrResult = tStrRaw == floor(tStrRaw) && abs(tStrRaw) < Double(Int.max)
							? String(Int(tStrRaw)) : String(format: "%.6g", tStrRaw)
						let tStrSI = interp.storeStringConst(value: tStrResult)
						execStack[execLevel] = _stringConstMarker
						execStrConst[execLevel] = tStrSI
					}

				case ._ASCopCode:
					let tAscRaw = execStack[execLevel]
					var tAscSrc = ""
					if tAscRaw == _stringConstMarker {
						tAscSrc = gStringConstants[execStrConst[execLevel]]
					} else if tAscRaw == _stringVarMarker {
						let vi = execStrVar[execLevel]
						if vi == _tempArrayStringVarIndex { tAscSrc = gTempStringForArray }
						else if vi >= 1 { let vn=gVarNames[vi]; gVariablesLock.lock(); if let inf=gVariables[vn],case .string(let s)=inf.value{tAscSrc=s}; gVariablesLock.unlock() }
					}
					execStack[execLevel] = Double(tAscSrc.unicodeScalars.first.map { Int($0.value) } ?? 0)

				// Milestone 14: INKEY$ inside timer callback — Bug 1 fix.
				// Was incorrectly nested inside _whileEndOpCode; now a proper top-level case.
				case ._inkeyOpCode:
					execLevel += 1
					let timerInkey = interp.delegate?.pscriptInkey() ?? ""
					let timerInkeySI = interp.storeStringConst(value: timerInkey)
					execStack[execLevel] = _stringConstMarker
					execStrConst[execLevel] = timerInkeySI

				// Milestone 22: VERSION$ inside timer callback
				case ._versionOpCode:
					execLevel += 1
					let timerVerSI = interp.storeStringConst(value: pScriptVersion)
					execStack[execLevel] = _stringConstMarker
					execStrConst[execLevel] = timerVerSI

				// Milestone 22: BEEP inside timer callback
				case ._beepOpCode:
					if let d = interp.delegate {
						d.pscriptBell()
					} else {
						print("\u{0007}", terminator: "")
						fflush(stdout)
					}

				// Milestone 36: MOUSEAT inside timer callback
				case ._mouseatOpCode:
					execIndex += 1
					let tMouseAxis = codeArray[execIndex]
					execLevel += 1
					execStack[execLevel] = interp.delegate?.pscriptMouseAt(axis: tMouseAxis) ?? 0.0

				// Milestone 27: SAMPLE inside timer callback
				case ._sampleOpCode:
					execIndex += 1
					let tSampleArgCount = codeArray[execIndex]
					var tSampleResult = 0.0
					if tSampleArgCount == 4 {
						let tSampleSize = execStack[execLevel];        execLevel -= 1
						let tSampleChan = Int(execStack[execLevel]);   execLevel -= 1
						let tSampleY    = Int(execStack[execLevel]);   execLevel -= 1
						let tSampleX    = Int(execStack[execLevel]);   execLevel -= 1
						if let d = interp.delegate {
							tSampleResult = d.pscriptSample(x: tSampleX, y: tSampleY,
															 channel: tSampleChan,
															 sampleSize: tSampleSize)
						}
					} else {
						let _tsc = Int(execStack[execLevel]); execLevel -= 1
						let _tsy = Int(execStack[execLevel]); execLevel -= 1
						let _tsx = Int(execStack[execLevel]); execLevel -= 1
						_ = (_tsc, _tsy, _tsx)
					}
					execLevel += 1
					execStack[execLevel] = tSampleResult
					
				// Milestone 38: DIST inside timer callback
				case ._distOpCode:
					execIndex += 1
					let tdY2 = execStack[execLevel];     execLevel -= 1
					let tdX2 = execStack[execLevel];     execLevel -= 1
					let tdY1 = execStack[execLevel];     execLevel -= 1
					let tdX1 = execStack[execLevel];     execLevel -= 1
					execLevel += 1
					execStack[execLevel] = hypot(tdX2 - tdX1, tdY2 - tdY1)

				// Milestone 28: SAY inside timer callback
				case ._sayOpCode:
					let tSayRaw = execStack[execLevel]
					var tSayText = ""
					if tSayRaw == _stringConstMarker {
						tSayText = gStringConstants[execStrConst[execLevel]]
					} else if tSayRaw == _stringVarMarker {
						let vi = execStrVar[execLevel]
						if vi == _tempArrayStringVarIndex { tSayText = gTempStringForArray }
						else if vi >= 1 {
							let vn = gVarNames[vi]
							gVariablesLock.lock()
							if let inf = gVariables[vn], case .string(let s) = inf.value { tSayText = s }
							gVariablesLock.unlock()
						}
					} else {
						tSayText = tSayRaw == floor(tSayRaw) && abs(tSayRaw) < Double(Int.max)
							? String(Int(tSayRaw)) : String(format: "%.6g", tSayRaw)
					}
					execLevel -= 1
					if let d = interp.delegate { d.pscriptSay(tSayText) }
					else { print("[SAY] \(tSayText)") }
				
				// Milestone 28: SAY STOP inside timer callback — key use case:
				// timer fires, checks INKEY$, if ESC → SAY STOP to halt long utterance
				case ._sayStopOpCode:
					if let d = interp.delegate { d.pscriptSayStop() }
				
				// PLAY inside timer callback — pew pew! 🚀
				case ._playOpCode:
					execIndex += 1
					let tPlayMask = codeArray[execIndex]

					var tPlayURLStr = ""
					var tPlayVolume = -1.0
					var tPlayID     = 0

					if (tPlayMask >> 2) & 1 == 1 {
						let tURLRaw = execStack[execLevel]
						if tURLRaw == _stringConstMarker {
							tPlayURLStr = gStringConstants[execStrConst[execLevel]]
						} else if tURLRaw == _stringVarMarker {
							let vi = execStrVar[execLevel]
							if vi == _tempArrayStringVarIndex { tPlayURLStr = gTempStringForArray }
							else if vi >= 1 { let vn=gVarNames[vi]; gVariablesLock.lock(); if let inf=gVariables[vn],case .string(let s)=inf.value{tPlayURLStr=s}; gVariablesLock.unlock() }
						}
						execLevel -= 1
					}
					if (tPlayMask >> 1) & 1 == 1 {
						tPlayVolume = execStack[execLevel]; execLevel -= 1
					}
					if (tPlayMask >> 0) & 1 == 1 {
						tPlayID = Int(execStack[execLevel]); execLevel -= 1
					}

					if let d = interp.delegate {
						d.pscriptPlay(id: tPlayID, volume: tPlayVolume, urlString: tPlayURLStr)
					} else {
						cliPlay(id: tPlayID, volume: tPlayVolume, urlString: tPlayURLStr)
					}

				// Milestone 34: TEXT inside timer callback
				case ._textColorOpCode:
					let ttcA = execStack[execLevel];     execLevel -= 1
					let ttcB = execStack[execLevel];     execLevel -= 1
					let ttcG = execStack[execLevel];     execLevel -= 1
					let ttcR = execStack[execLevel];     execLevel -= 1
					let ttr = min(max(ttcR, 0.0), 1.0)
					let ttg = min(max(ttcG, 0.0), 1.0)
					let ttb = min(max(ttcB, 0.0), 1.0)
					let tta = min(max(ttcA, 0.0), 1.0)
					gTextColor = (ttr, ttg, ttb, tta)
					interp.delegate?.pscriptTextColor(r: ttr, g: ttg, b: ttb, a: tta)

				// Milestone 35: FILL inside timer callback
				case ._fillOpCode:
					let tFillA = execStack[execLevel];     execLevel -= 1
					let tFillB = execStack[execLevel];     execLevel -= 1
					let tFillG = execStack[execLevel];     execLevel -= 1
					let tFillR = execStack[execLevel];     execLevel -= 1
					let tfr = min(max(tFillR, 0.0), 1.0)
					let tfg = min(max(tFillG, 0.0), 1.0)
					let tfb = min(max(tFillB, 0.0), 1.0)
					let tfa = min(max(tFillA, 0.0), 1.0)
					gFillColor = (tfr, tfg, tfb, tfa)
					interp.delegate?.pscriptFill(r: tfr, g: tfg, b: tfb, a: tfa)

				// Milestone 33: SOUND inside timer callback
				case ._soundOpCode:
					let tSndVolume = execStack[execLevel];          execLevel -= 1
					let tSndDur    = execStack[execLevel];          execLevel -= 1
					let tSndNote   = Int(execStack[execLevel]);     execLevel -= 1
					if tSndNote >= 0 && tSndNote <= 127 {
						let tSndDurC = min(max(tSndDur, 0.0), 10.0)
						let tSndVolC = min(max(tSndVolume, 0.0), 1.0)
						if let d = interp.delegate {
							d.pscriptSound(midiNote: tSndNote,
										   duration: tSndDurC,
										   volume:   tSndVolC)
						} else {
							cliSound(midiNote: tSndNote, duration: tSndDurC, volume: tSndVolC)
						}
					} else {
						if let d = interp.delegate {
							d.pscriptPrint("Parser: MIDI note out of range [0-127]: \(tSndNote)",
										   newline: true)
						}
					}

				// Milestone 30: SPRITE inside timer callback
				case ._spriteOpCode:
					execIndex += 1
					let tSprMask = codeArray[execIndex]
					execIndex += 1
					let _ = codeArray[execIndex]   // argCount
					let tSentinel = Double.greatestFiniteMagnitude

					var tSlotVal = [Double](repeating: tSentinel, count: 8)
					var tSlotSC  = [Int](repeating: 0, count: 8)
					var tSlotSV  = [Int](repeating: 0, count: 8)

					for slotIndex in stride(from: 7, through: 0, by: -1) {
						guard (tSprMask >> slotIndex) & 1 == 1 else { continue }
						tSlotVal[slotIndex] = execStack[execLevel]
						tSlotSC[slotIndex]  = execStrConst[execLevel]
						tSlotSV[slotIndex]  = execStrVar[execLevel]
						execLevel -= 1
					}

					var tSprURL = ""
					let tURLraw = tSlotVal[7]
					if tURLraw == _stringConstMarker {
						tSprURL = gStringConstants[tSlotSC[7]]
					} else if tURLraw == _stringVarMarker {
						let vi = tSlotSV[7]
						if vi == _tempArrayStringVarIndex { tSprURL = gTempStringForArray }
						else if vi >= 1 { let vn = gVarNames[vi]; gVariablesLock.lock(); if let inf = gVariables[vn], case .string(let s) = inf.value { tSprURL = s }; gVariablesLock.unlock() }
					}

					let tSprID      = Int(tSlotVal[0])
					let tSprX       = tSlotVal[1]
					let tSprY       = tSlotVal[2]
					let tSprRot     = tSlotVal[3]
					let tSprScale   = tSlotVal[4]
					let tSprHiddenD = tSlotVal[5]
					let tSprAlpha   = tSlotVal[6]
					let tSprHidden  = (tSprMask >> 5) & 1 == 0 ? -1 : Int(tSprHiddenD)

					if let d = interp.delegate {
						d.pscriptSprite(id: tSprID,
										x: tSprX, y: tSprY,
										rotation: tSprRot,
										scale: tSprScale,
										hidden: tSprHidden,
										alpha: tSprAlpha,
										imageURL: tSprURL)
					}

				// Milestone 30: GET inside timer callback
				case ._getOpCode:
					execIndex += 1
					let _ = codeArray[execIndex]   // argCount
					let tGetY2 = Int(execStack[execLevel]); execLevel -= 1
					let tGetX2 = Int(execStack[execLevel]); execLevel -= 1
					let tGetY1 = Int(execStack[execLevel]); execLevel -= 1
					let tGetX1 = Int(execStack[execLevel]); execLevel -= 1
					let tGetID = Int(execStack[execLevel]); execLevel -= 1
					if let d = interp.delegate {
						d.pscriptSpriteGet(id: tGetID, x1: tGetX1, y1: tGetY1,
										   x2: tGetX2, y2: tGetY2)
					}
					
					// PEN inside timer callback — update global pen width
					case ._penOpCode:
						gPenSize = execStack[execLevel]; execLevel -= 1
						if let d = interp.delegate { d.pscriptPenSize(gPenSize) }
					
					// Milestone 36: POINT inside timer callback
					case ._pointOpCode:
						execIndex += 1
						let tPointArgCount = codeArray[execIndex]
						var tPr = 0.0, tPg = 0.91, tPb = 0.23, tPa = 1.0
						if tPointArgCount == 6 {
							tPa = execStack[execLevel]; execLevel -= 1
							tPb = execStack[execLevel]; execLevel -= 1
							tPg = execStack[execLevel]; execLevel -= 1
							tPr = execStack[execLevel]; execLevel -= 1
						}
						let tPyRaw = execStack[execLevel]; execLevel -= 1
						let tPxRaw = execStack[execLevel]; execLevel -= 1
						if tPxRaw.isFinite && tPyRaw.isFinite &&
						   tPxRaw > Double(Int.min) && tPxRaw < Double(Int.max) &&
						   tPyRaw > Double(Int.min) && tPyRaw < Double(Int.max) {
							if let d = interp.delegate {
								d.pscriptPoint(x: Int(tPxRaw), y: Int(tPyRaw),
											   r: tPr, g: tPg, b: tPb, a: tPa)
							}
						}

					// Milestone 36: LINE inside timer callback
					case ._lineOpCode:
						execIndex += 1
						let tLineArgCount = codeArray[execIndex]
						var tLr = 0.0, tLg = 0.91, tLb = 0.23, tLa = 1.0
						if tLineArgCount == 8 {
							tLa = execStack[execLevel]; execLevel -= 1
							tLb = execStack[execLevel]; execLevel -= 1
							tLg = execStack[execLevel]; execLevel -= 1
							tLr = execStack[execLevel]; execLevel -= 1
						}
						let tLy2Raw = execStack[execLevel]; execLevel -= 1
						let tLx2Raw = execStack[execLevel]; execLevel -= 1
						let tLy1Raw = execStack[execLevel]; execLevel -= 1
						let tLx1Raw = execStack[execLevel]; execLevel -= 1
						if tLx1Raw.isFinite && tLy1Raw.isFinite &&
						   tLx2Raw.isFinite && tLy2Raw.isFinite &&
						   tLx1Raw > Double(Int.min) && tLx1Raw < Double(Int.max) &&
						   tLy1Raw > Double(Int.min) && tLy1Raw < Double(Int.max) &&
						   tLx2Raw > Double(Int.min) && tLx2Raw < Double(Int.max) &&
						   tLy2Raw > Double(Int.min) && tLy2Raw < Double(Int.max) {
							if let d = interp.delegate {
								d.pscriptLine(x1: Int(tLx1Raw), y1: Int(tLy1Raw),
											  x2: Int(tLx2Raw), y2: Int(tLy2Raw),
											  r: tLr, g: tLg, b: tLb, a: tLa)
							}
						}

					// Milestone 36: CLR inside timer callback
					case ._clrOpCode:
						if let d = interp.delegate { d.pscriptClr() }
				
				// Milestone 19: BUFFER inside timer callback
				case ._bufferOpCode:
					execIndex += 1; let tbufDrawTo  = codeArray[execIndex]
					execIndex += 1; let tbufDisplay = codeArray[execIndex]
					if tbufDrawTo == -1 {
						gDrawBuffer = 1 - gDrawBuffer
						if let d = interp.delegate { d.pscriptBuffer(drawTo: gDrawBuffer, display: 1 - gDrawBuffer) }
					} else {
						gDrawBuffer = tbufDrawTo
						if let d = interp.delegate { d.pscriptBuffer(drawTo: tbufDrawTo, display: tbufDisplay) }
					}

				// Milestone 19: FOR/NEXT inside timer callbacks.
				// Uses a local timerForStack (declared below) so that timer
				// for-loops never corrupt the main executor's gForLoopStack.
				case ._forBeginOpCode:
					execIndex += 1; let tflvName = gVarNames[codeArray[execIndex]]
					execIndex += 1; let tfhasStep = codeArray[execIndex]
					var tfstepVal = 1.0
					if tfhasStep == 1 { tfstepVal = execStack[execLevel]; execLevel -= 1 }
					let tfendVal = execStack[execLevel]; execLevel -= 1
					// Initialise the loop variable in gVariables (timer functions
					// run without a call stack frame so use globals directly).
					gVariablesLock.lock()
					if gVariableTypes[tflvName] == nil {
						gVariableTypes[tflvName] = .floatType
						gVariables[tflvName] = VariableInfo(type: .floatType, value: .float(0.0))
					}
					gVariablesLock.unlock()
					timerForStack.append(ForLoopInfo(
						varName: tflvName,
						endValue: tfendVal,
						stepValue: tfstepVal,
						loopStartPC: pc + 1))

				case ._forNextOpCode:
					guard !timerForStack.isEmpty else { break }
					let tfli = timerForStack[timerForStack.count - 1]
					gVariablesLock.lock()
					let tfcurVI = gVariables[tfli.varName]
					gVariablesLock.unlock()
					let tfcur = (tfcurVI?.value.toDouble() ?? 0.0) + tfli.stepValue
					let tfnewV: Value = (tfcur == floor(tfcur)) ? .int(Int(tfcur)) : .float(tfcur)
					gVariablesLock.lock()
					gVariables[tfli.varName] = VariableInfo(
						type: gVariableTypes[tfli.varName] ?? .floatType, value: tfnewV)
					gVariablesLock.unlock()
					let tfcont = tfli.stepValue > 0 ? tfcur <= tfli.endValue
													: tfcur >= tfli.endValue
					execIndex += 1   // consume varNameIdx operand of NEXT
					if tfcont {
						// Jump back to loop start line
						pc = tfli.loopStartPC - 1
						break   // break switch → pc+=1 below → loopStartPC
					} else {
						timerForStack.removeLast()
					}

				// Ignore timer-control opcodes inside a timer callback (no recursion)
				case ._timerDeclOpCode: execIndex += 1   // skip funcNameIdx operand
				case ._timerOnOpCode, ._timerStopOpCode: break

				case ._timerOffOpCode:
					timerOff()
					break bodyLoop

				case ._varDeclOpCode:
					// VAR declarations inside timer callback functions are not supported.
					// The declaration emits an initialiser value onto the stack that
					// would corrupt execLevel if silently skipped.
					// Pop the initialiser value to keep the stack balanced, then
					// print a diagnostic and abort this timer tick cleanly.
					execLevel -= 1   // discard the initialiser value
					let tErrG = "Timer Error: VAR declaration inside timer function '\(gTimerFuncName)' — declare all variables at top level."
					print(tErrG)
					interp.delegate?.pscriptPrint(tErrG, newline: true)
					break bodyLoop   // abort this tick cleanly — timer keeps running
				
				// Function call inside timer callback
				case ._funcCallOpCode:
					execIndex += 1; let tcFnIdx  = codeArray[execIndex]
					execIndex += 1; let tcArgc   = codeArray[execIndex]
					let tcFnName = gVarNames[tcFnIdx].lowercased()

					// Timer functions are always zero-argument (game loop pattern).
					// Consume any args from the stack (defensive).
					for _ in 0..<tcArgc { execLevel -= 1 }

					// Parse the called function's body
					guard let parsed = parseTimerFuncBody(funcName: tcFnName) else {
						let tErrF = "Timer Error: timer cannot call undefined function '\(tcFnName)'"
						print(tErrF); interp.delegate?.pscriptPrint(tErrF, newline: true)
						break bodyLoop
					}

					// Push caller frame
					let tcFrame = TimerCallFrame(
						funcName:        tcFnName,
						returnPC:        pc,
						returnIndex:     execIndex + 1,
						lineCodeArrays:  lineCodeArrays,
						savedLevel:      execLevel,
						savedStack:      Array(execStack),
						savedStrConst:   Array(execStrConst),
						savedStrVar:     Array(execStrVar),
						savedForStack:   timerForStack,
						savedWhileStack: timerWhileStack,
						localWhilePairs: localWhilePairs,
						localWhileEnds:  localWhileEnds,
						localIfPairs:    localIfPairs,       // Milestone 39
						localIfEnds:     localIfEnds         // Milestone 39
					)
					timerCallStack.append(tcFrame)
					//print("DEBUG CALL \(tcFnName) depth=\(timerCallStack.count) pc=\(pc)")

					// Jump into called function
					lineCodeArrays  = parsed.lines
					localWhilePairs = parsed.localWhilePairs
					localWhileEnds  = parsed.localWhileEnds
					localIfPairs    = parsed.localIfPairs    // Milestone 39
					localIfEnds     = parsed.localIfEnds     // Milestone 39
					timerForStack   = []
					timerWhileStack = []
					pc              = -1   // bodyLoop does pc+=1, landing at line 0
					execLevel       = 0
					execStack       = [Double](repeating: 0.0, count: _maxEvalStackSize)
					execStrConst    = [Int](repeating: 0, count: _maxEvalStackSize)
					execStrVar      = [Int](repeating: 0, count: _maxEvalStackSize)
					break innerLoop

				// Option A: return from function call inside timer callback
				case ._returnOpCode:
					guard !timerCallStack.isEmpty else {
						break bodyLoop
					}
					let tcDone      = timerCallStack.removeLast()
					//print("DEBUG RETURN to \(tcDone.funcName) returnPC=\(tcDone.returnPC) returnIndex=\(tcDone.returnIndex) newDepth=\(timerCallStack.count)")
					lineCodeArrays  = tcDone.lineCodeArrays
					localWhilePairs = tcDone.localWhilePairs
					localWhileEnds  = tcDone.localWhileEnds
					localIfPairs    = tcDone.localIfPairs    // Milestone 39
					localIfEnds     = tcDone.localIfEnds     // Milestone 39
					timerForStack   = tcDone.savedForStack
					timerWhileStack = tcDone.savedWhileStack
					pc              = tcDone.returnPC
					execLevel       = tcDone.savedLevel
					execStack       = tcDone.savedStack
					execStrConst    = tcDone.savedStrConst
					execStrVar      = tcDone.savedStrVar
					for i in 0..<_maxEvalStackSize {
						gStringConstRefs[i] = execStrConst[i]
						gStringVarRefs[i]   = execStrVar[i]
					}
					execIndex = tcDone.returnIndex - 1
					resumingFromReturn = true
					continue bodyLoop   // reloads codeArray[returnPC], skips pc+=1
					
			default: break   // unknown opcode in timer body — skip silently
				}
				execIndex += 1
			}   // end innerLoop
			pc += 1
		}   // end bodyLoop
	}   // end setEventHandler closure
	
	source.resume()
	gTimerSource = source
	return true
}

/// Suspend the timer.  The timer source is kept alive; TIMERON resumes it.
/// Pending (undelivered) events are remembered by the OS — this matches
/// the GW-BASIC STOP semantics.
func timerStop() {
	guard let src = gTimerSource, !gTimerIsSuspended else { return }
	src.suspend()
	gTimerIsSuspended = true
}

/// Invalidate and release the timer.  After TIMEROFF the user must issue
/// a new TIMER declaration before TIMERON will work again.
// Track whether the timer is currently suspended (via TIMERSTOP) so that
// timerOff() knows whether it needs to resume before cancelling.
// A running source must NOT be resumed before cancel — that would
// decrement the suspend count below zero and trigger EXC_BREAKPOINT.
var gTimerIsSuspended: Bool = false

func timerOff() {
	if let src = gTimerSource {
		// DispatchSource rule: a suspended source must be resumed exactly once
		// before cancel(), otherwise the suspend count goes negative → hard trap.
		// We only resume here if TIMERSTOP had previously suspended it.
		if gTimerIsSuspended {
			src.resume()
			gTimerIsSuspended = false
		}
		src.cancel()
		gTimerSource = nil
	}
	gTimerFuncName = ""
	gTimerInterval = 1.0 / 60.0
	gTimerDelegate = nil
	gTimerBusy     = false
}


// pBasic Step 1: I/O delegate protocol — implemented by PScriptBridge in DeviceControl.swift.
// When delegate is nil the interpreter falls back to print()/readLine() (CLI behaviour).
// NOTE FOR TERMINAL BUILD: comment out this entire protocol block.
protocol PScriptDelegate: AnyObject {
	/// Output text to the terminal display (PRINT and TAB statements).
	func pscriptPrint(_ text: String, newline: Bool)
	/// Read a line of input — blocks the pScript background thread until the user submits.
	func pscriptInput(prompt: String?) -> String
	/// Clear the terminal screen (CLS statement).
	func pscriptCls()
	/// Ring the terminal bell (ASCII BEL).
	func pscriptBell()
	/// Move the cursor to the given row and col (1-based, GW-BASIC convention).
	/// Subsequent PRINT output begins from this position.
	func pscriptLocate(_ row: Int, _ col: Int)
	/// Plot a single pixel on the graphics canvas.
	/// x, y are in pBasic canvas coordinates (origin top-left, Y down).
	/// r, g, b, a are in 0.0–1.0 range. Called on background thread; impl must dispatch to main.
	func pscriptPoint(x: Int, y: Int, r: Double, g: Double, b: Double, a: Double)
	/// Draw a line on the graphics canvas between (x1,y1) and (x2,y2).
	/// Colour components in 0.0–1.0 range. Called on background thread; impl must dispatch to main.
	func pscriptLine(x1: Int, y1: Int, x2: Int, y2: Int, r: Double, g: Double, b: Double, a: Double)
	/// Clear the graphics canvas (CLR). Doesnt affect terminal text buffer. 
	func pscriptClr()
	/// Non-blocking key read. Returns the next queued key token, or "" if no key is waiting.
	/// Tokens: "^U" (↑) "^D" (↓) "^L" (←) "^R" (→) "RET" "DEL" "ESC" or single printable char.
	/// Thread-safe (NSLock in TerminalModel). Never blocks. pBasic.app only.
	func pscriptInkey() -> String
	/// Called via DispatchQueue.main.sync when RUN begins. Sets inkeyMode = true on
	/// TerminalModel so all key events route to the inkey queue. Also clears stale keys.
	func pscriptExecutionWillBegin()
	/// Called via DispatchQueue.main.sync when a program ends by any means (normal
	/// completion, END keyword, CTRL-C break, runtime error). Clears inkeyMode.
	func pscriptExecutionDidEnd()
	/// Set the pen width (logical points) for subsequent LINE and POINT calls.
	/// Called immediately when PEN statement executes.
	func pscriptPenSize(_ size: Double)
	/// Milestone 19: Switch the active draw buffer and display buffer.
	/// drawTo:  0 or 1 — index of CGContext that subsequent POINT/LINE/CLR write to.
	/// display: 0 or 1 — index of SKTexture that is presented to the screen.
	/// Called on the pScript background thread; impl must dispatch to main as needed.
	func pscriptBuffer(drawTo: Int, display: Int)
	/// Milestone 27: Read a pixel channel value from the graphics canvas.
	/// x, y: canvas coordinates (origin top-left, Y down).
	/// channel: 0=Red 1=Green 2=Blue 3=Alpha.
	/// sampleSize: 1.0 = single pixel; >1.0 = square area average (side = ceil(sampleSize)).
	/// Returns normalised value in 0.0–1.0. Called synchronously — blocks pScript thread.
	func pscriptSample(x: Int, y: Int, channel: Int, sampleSize: Double) -> Double
	/// Milestone 28: Speak a string via AVSpeechSynthesizer. Non-blocking.
	func pscriptSay(_ text: String)
	/// Milestone 28: Halt any speech in progress immediately.
	func pscriptSayStop()
	/// Milestone 30: Create or update a SpriteKit sprite by integer ID.
	/// Sentinel: Double.greatestFiniteMagnitude = leave numeric param unchanged; "" = leave imageURL unchanged; -1 = leave hidden unchanged.
	func pscriptSprite(id: Int, x: Double, y: Double, rotation: Double,
					   scale: Double, hidden: Int, alpha: Double, imageURL: String)
	/// Milestone 30: Capture a canvas region and assign as sprite texture (GET command).
	func pscriptSpriteGet(id: Int, x1: Int, y1: Int, x2: Int, y2: Int)
	/// Milestone 30: Remove all pBASIC sprites from the scene and free their memory.
	/// Called when the NEW command clears the program.
	func pscriptRemoveAllSprites()
	/// Milestone 36: Return current mouse position or button state in pBasic canvas coords.
	/// axis: 0=X (0–1259)  1=Y (0–999)  2=Button (0=none 1=left 2=right 3=both)
	func pscriptMouseAt(axis: Int) -> Double
	/// PLAY command — fire-and-forget sound playback.
	/// id: sound registry key.
	/// volume: 0.0=stop, -1.0=use last set volume, 0.0–1.0=set volume.
	/// urlString: "" = reuse existing player, non-empty = load new file.
	func pscriptPlay(id: Int, volume: Double, urlString: String)
	/// SOUND command — synthesise a sine tone at the given MIDI note.
	/// midiNote: 0–127  duration: 0.0–10.0 seconds  volume: 0.0–1.0
	func pscriptSound(midiNote: Int, duration: Double, volume: Double)
	/// FILL command — set persistent background fill colour for subsequent PRINT output.
	/// r, g, b, a in 0.0–1.0. (0,0,0,0) = transparent = default terminal appearance.
	func pscriptFill(r: Double, g: Double, b: Double, a: Double)
	/// TEXT command — set persistent text foreground colour for subsequent PRINT output.
	/// r, g, b, a in 0.0–1.0. Default is phosphor green (0, 0.91, 0.23, 1.0).
	func pscriptTextColor(r: Double, g: Double, b: Double, a: Double)
	/// Milestone 40: MORE pager — erase the pause prompt line synchronously.
	/// Called on the pScript background thread after the user presses Space.
	/// Must complete before any further output is enqueued.
	func pscriptErasePromptLine(width: Int)
	func pscriptPrintSync(_ text: String)
	/// To manage Timer
	func pscriptTimerDidStart()
	func pscriptTimerDidStop()
	
}


//---| PARSER CLASS |-------

class parseEval: NSObject {
	var exprString: String
	
	// pBasic Step 1: Delegate for app-side I/O (print, input, cls, bell).
	// When nil (CLI build), all I/O falls back to print()/readLine().
	// NOTE FOR TERMINAL BUILD: comment out this property declaration.
	weak var delegate: PScriptDelegate?
	
	init(exprString: String) {
		self.exprString = exprString
	}
	
	//--| UTILITY METHODS |-----
	
	func getChar(theString: String, charIndex: Int) -> String {
		if charIndex >= 0 && charIndex < theString.count {
			return String(theString[theString.index(theString.startIndex, offsetBy: charIndex)])
		}
		return ""
	}
	
	func midString(theString: String, charIndex: Int, range: Int) -> String {
		let start = theString.index(theString.startIndex, offsetBy: charIndex)
		let end = theString.index(theString.startIndex, offsetBy: min(charIndex + range, theString.count))
		return String(theString[start..<end])
	}
	
	//--| PARSE ERROR HANDLING |-----
	
	func clearParseError() {
		gParseError = false
	}
	
	func parseError(errMsg: String) {
		if gParseError { return }
		gParseError = true
		let msg = "Parser: \(errMsg)"
		if delegate != nil {
			delegate?.pscriptPrint(msg, newline: true)
		} else {
			print(msg)
		}
	}
	
	//--| SYMBOL TABLE |-----
	
	func addToSymTable(opStr: String, type: lexemeTypes, opcode: evalOPcodes) {
		if gNumSyms >= _maxNumSymbols - 1 {
			print("Symbol table full")
			return
		}
		
		let lenInsertStr = opStr.count
		if lenInsertStr < 1 { return }
		
		var insertIndex = 1
		while insertIndex <= gNumSyms && lenInsertStr <= gSymTable[insertIndex].count {
			if lenInsertStr == gSymTable[insertIndex].count && opStr.uppercased() == gSymTable[insertIndex].uppercased() {
				return
			}
			insertIndex += 1
		}
		
		// Shift elements to make room
		if insertIndex <= gNumSyms {
			for i in stride(from: gNumSyms, through: insertIndex, by: -1) {
				gSymTable[i + 1] = gSymTable[i]
				gSymType[i + 1] = gSymType[i]
				gSymCode[i + 1] = gSymCode[i]
			}
		}
		
		gSymTable[insertIndex] = opStr
		gSymType[insertIndex] = type
		gSymCode[insertIndex] = opcode
		gNumSyms += 1
	}
	
	func initSymbolTable() {
		gNumSyms = 0
		
		addToSymTable(opStr: "(", type: ._leftParenType, opcode: ._noOpCode)
		addToSymTable(opStr: ")", type: ._rightParenType, opcode: ._noOpCode)
		addToSymTable(opStr: ",", type: ._assignOpType, opcode: ._noOpCode)		// Allows multiple Function Arguments
		
		addToSymTable(opStr: "[", type: ._leftBracketType, opcode: ._noOpCode)
		addToSymTable(opStr: "]", type: ._rightBracketType, opcode: ._noOpCode)

		// Milestone 4: Braces for function bodies
		addToSymTable(opStr: "{", type: ._leftBraceType, opcode: ._noOpCode)
		addToSymTable(opStr: "}", type: ._rightBraceType, opcode: ._noOpCode)
		
		addToSymTable(opStr: "+", type: ._plusMinusOpType, opcode: ._plusOpCode)
		addToSymTable(opStr: "-", type: ._plusMinusOpType, opcode: ._minusOpCode)
		addToSymTable(opStr: "*", type: ._timesDivideOpType, opcode: ._timesOpCode)
		addToSymTable(opStr: "/", type: ._timesDivideOpType, opcode: ._divideOpCode)
		addToSymTable(opStr: "%", type: ._timesDivideOpType, opcode: ._modOpCode)
		// Milestone 24: logical/bitwise operators — ^^ and && and || registered BEFORE
		// their 1-char prefixes (^, future & |) so longest-match fires first in symbol scan.
		addToSymTable(opStr: "^^", type: ._logicalOpType, opcode: ._logicalXorOpCode)
		addToSymTable(opStr: "&&", type: ._logicalOpType, opcode: ._logicalAndOpCode)
		addToSymTable(opStr: "||", type: ._logicalOpType, opcode: ._logicalOrOpCode)
		addToSymTable(opStr: "!", type: ._logicalOpType, opcode: ._logicalNotOpCode)
		addToSymTable(opStr: "^", type: ._powerOpType, opcode: ._powerOpCode)
		addToSymTable(opStr: ":", type: ._assignOpType, opcode: ._noOpCode)
		addToSymTable(opStr: "=", type: ._assignOpType, opcode: ._noOpCode)
		
		// Comparison operators (longer first)
		addToSymTable(opStr: ">=", type: ._compareOpType, opcode: ._greaterEqOpCode)
		addToSymTable(opStr: "<=", type: ._compareOpType, opcode: ._lessEqOpCode)
		addToSymTable(opStr: "<>", type: ._compareOpType, opcode: ._notEqualOpCode)
		addToSymTable(opStr: "==", type: ._compareOpType, opcode: ._equalOpCode)
		addToSymTable(opStr: ">", type: ._compareOpType, opcode: ._greaterOpCode)
		addToSymTable(opStr: "<", type: ._compareOpType, opcode: ._lessOpCode)
		
		addToSymTable(opStr: "π", type: ._readVarType, opcode: ._piOpCode)
		addToSymTable(opStr: "PI", type: ._readVarType, opcode: ._piOpCode)
		addToSymTable(opStr: "DATE", type: ._readVarType, opcode: ._dateOpCode)
		addToSymTable(opStr: "TIME", type: ._readVarType, opcode: ._timeOpCode)
		
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
		addToSymTable(opStr: "RND", type: ._unaryOpType, opcode: ._RNDopCode)
		addToSymTable(opStr: "LEN", type: ._unaryOpType, opcode: ._LENopCode)
		addToSymTable(opStr: "MID$", type: ._unaryOpType, opcode: ._MIDopCode)
		// Milestone 26: String/character conversion functions
		addToSymTable(opStr: "VAL",  type: ._unaryOpType, opcode: ._VALopCode)
		addToSymTable(opStr: "CHR$", type: ._unaryOpType, opcode: ._CHRopCode)
		addToSymTable(opStr: "ASC",  type: ._unaryOpType, opcode: ._ASCopCode)
		addToSymTable(opStr: "STR$", type: ._unaryOpType, opcode: ._STRopCode)
		
		addToSymTable(opStr: "VAR", type: ._keywordType, opcode: ._varDeclOpCode)
		addToSymTable(opStr: "LET", type: ._keywordType, opcode: ._noOpCode)
		addToSymTable(opStr: "PRINT", type: ._keywordType, opcode: ._printOpCode)
		addToSymTable(opStr: "TAB", type: ._keywordType, opcode: ._noOpCode)
		addToSymTable(opStr: "CLS", type: ._keywordType, opcode: ._noOpCode)
		addToSymTable(opStr: "INPUT", type: ._keywordType, opcode: ._noOpCode)
		addToSymTable(opStr: "END", type: ._keywordType, opcode: ._noOpCode)
		addToSymTable(opStr: "EXIT", type: ._keywordType, opcode: ._noOpCode)
		addToSymTable(opStr: ";", type: ._assignOpType, opcode: ._noOpCode)     // We use ._assignOpType because its a punctuation-like operator, not consumed in expressions.
		addToSymTable(opStr: "FOR", type: ._keywordType, opcode: ._forBeginOpCode)
		addToSymTable(opStr: "TO", type: ._keywordType, opcode: ._noOpCode)
		addToSymTable(opStr: "STEP", type: ._keywordType, opcode: ._noOpCode)
		addToSymTable(opStr: "NEXT", type: ._keywordType, opcode: ._forNextOpCode)
		addToSymTable(opStr: "IF", type: ._keywordType, opcode: ._ifThenOpCode)
		addToSymTable(opStr: "THEN", type: ._keywordType, opcode: ._noOpCode)
		
		addToSymTable(opStr: "REDIM", type: ._keywordType, opcode: ._redimOpCode)

		// Milestone 4: Function keywords
		addToSymTable(opStr: "FUNC", type: ._keywordType, opcode: ._funcCallOpCode)
		addToSymTable(opStr: "RETURN", type: ._keywordType, opcode: ._returnOpCode)

		// pBasic: App-only Cursor / Graphics / Sound keywords
		addToSymTable(opStr: "LOCATE", type: ._keywordType, opcode: ._locateOpCode)

		// pBasic: Graphics keywords
		addToSymTable(opStr: "CLR",    type: ._keywordType, opcode: ._clrOpCode)
		addToSymTable(opStr: "LINE",   type: ._keywordType, opcode: ._lineOpCode)
		addToSymTable(opStr: "POINT",  type: ._keywordType, opcode: ._pointOpCode)
		// Milestone 27: SAMPLE registered as _unaryOpType so factor() treats it as
		// a value-producing expression (RHS of assignments, IF conditions, etc.)
		addToSymTable(opStr: "SAMPLE", type: ._unaryOpType, opcode: ._sampleOpCode)
		addToSymTable(opStr: "MOUSEAT", type: ._unaryOpType, opcode: ._mouseatOpCode)
		addToSymTable(opStr: "DIST", type: ._unaryOpType, opcode: ._distOpCode)
		// Milestone 33: PLAY and Sound Commands
		addToSymTable(opStr: "PLAY", type: ._keywordType, opcode: ._playOpCode)
		addToSymTable(opStr: "SOUND", type: ._keywordType, opcode: ._soundOpCode)
		addToSymTable(opStr: "FILL", type: ._keywordType, opcode: ._fillOpCode)
		addToSymTable(opStr: "TEXT", type: ._keywordType, opcode: ._textColorOpCode)
		
		// Milestone 5: Timer keywords
		// TIMERSTOP and TIMEROFF registered before TIMER so the longer strings
		// are matched first (symbol table is sorted longest-first within same length).
		addToSymTable(opStr: "TIMERSTOP", type: ._keywordType, opcode: ._timerStopOpCode)
		addToSymTable(opStr: "TIMEROFF",  type: ._keywordType, opcode: ._timerOffOpCode)
		addToSymTable(opStr: "TIMERON",   type: ._keywordType, opcode: ._timerOnOpCode)
		addToSymTable(opStr: "TIMER",     type: ._keywordType, opcode: ._timerDeclOpCode)

		// Milestone 10: WHILE loop keyword
		addToSymTable(opStr: "WHILE", type: ._keywordType, opcode: ._whileOpCode)

		// Milestone 14: INKEY$ — registered as _readVarType so factor() sees it
		// as a value-producing expression (used on RHS of assignments, e.g. k$ = INKEY$).
		// pBasic.app only — CLI delegate is nil so pscriptInkey() returns "" silently.
		addToSymTable(opStr: "INKEY$", type: ._readVarType, opcode: ._inkeyOpCode)

		// Milestone 21: File I/O keywords.
		// SAVE is a statement keyword (like PRINT).
		// LOAD is NOT registered here — it is recognised syntactically inside
		// parseFileLoadStatement() only, preventing any collision with factor().
		addToSymTable(opStr: "SAVE", type: ._keywordType, opcode: ._fileSaveOpCode)
		
		// PEN command — sets global pen width for LINE and POINT
		addToSymTable(opStr: "PEN", type: ._keywordType, opcode: ._penOpCode)

		// Milestone 19: Double-buffering
		// Milestone 19: Double-buffering
		addToSymTable(opStr: "BUFFER", type: ._keywordType, opcode: ._bufferOpCode)

		// Milestone 22: VERSION$ and BEEP
		// VERSION$ registered as _readVarType so factor() treats it as a value-producing expression
		// (same pattern as INKEY$ and TIME/DATE).
		addToSymTable(opStr: "VERSION$", type: ._readVarType, opcode: ._versionOpCode)
		addToSymTable(opStr: "BEEP", type: ._keywordType, opcode: ._beepOpCode)
		// Milestone 28: SAY — text-to-speech
		// SAY STOP is parsed specially in parseSayStatement() — STOP is not a keyword.
		addToSymTable(opStr: "SAY", type: ._keywordType, opcode: ._sayOpCode)
		
		// Milestone 30: SPRITE and GET
		addToSymTable(opStr: "SPRITE", type: ._keywordType, opcode: ._spriteOpCode)
		addToSymTable(opStr: "GET",    type: ._keywordType, opcode: ._getOpCode)
		
		addToSymTable(opStr: "INT", type: ._typeNameType, opcode: ._INTopCode)
		addToSymTable(opStr: "FLOAT", type: ._typeNameType, opcode: ._noOpCode)
		addToSymTable(opStr: "STRING", type: ._typeNameType, opcode: ._noOpCode)
		addToSymTable(opStr: "BOOL", type: ._typeNameType, opcode: ._noOpCode)
		
		// Milestone 32: Errors in pTerm; GOTO and GOSUB Depreciated. 
		addToSymTable(opStr: "GOTO", type: ._keywordType, opcode: ._noOpCode)
		addToSymTable(opStr: "GOSUB", type: ._keywordType, opcode: ._noOpCode)
		
	}
	
	//--| STRING/CONSTANT STORAGE |-----
	
	func storeParsedConst(value: Double) -> Int {
		gParserTablesLock.lock()
		defer { gParserTablesLock.unlock() }
		if gNumConsts > 0 {
			for j in 1...gNumConsts {
				if value == gParsedConstants[j] { return j }
			}
		}
		
		if gNumConsts < _maxNumConsts {
			gNumConsts += 1
			gParsedConstants[gNumConsts] = value
			return gNumConsts
		} else {
			parseError(errMsg: "Too many constants")
			return 1
		}
	}
	
	func storeStringConst(value: String) -> Int {
		gParserTablesLock.lock()
		defer { gParserTablesLock.unlock() }
		if gNumStringConsts > 0 {
			for j in 1...gNumStringConsts {
				if value == gStringConstants[j] { return j }
			}
		}
		
		if gNumStringConsts < _maxNumConsts - 1 {
			gNumStringConsts += 1
			gStringConstants[gNumStringConsts] = value
			return gNumStringConsts
		} else {
			parseError(errMsg: "Too many string constants")
			return 1
		}
	}
	
	func storeVarName(name: String) -> Int {
		gParserTablesLock.lock()
		defer { gParserTablesLock.unlock() }
		if gNumVarNames > 0 {
			for j in 1...gNumVarNames {
				if name == gVarNames[j] { return j }
			}
		}

		if gNumVarNames < _maxNumSymbols {
			gNumVarNames += 1
			gVarNames[gNumVarNames] = name
			return gNumVarNames
		} else {
			parseError(errMsg: "Too many variables")
			return 1
		}
	}
	
	//--| NUMBER PARSING |-----
	
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
	
	func isStringInText(soughtStr: String, inString: String, startPos: Int) -> Bool {
		guard startPos > 0 && startPos <= inString.count else { return false }
		let adjustedPos = startPos - 1
		let inSuffix = String(inString.suffix(from: inString.index(inString.startIndex, offsetBy: adjustedPos)))
		return inSuffix.uppercased().hasPrefix(soughtStr.uppercased())
	}
	
	func getIndexOfNextNumContentBit() -> Int {
		for j in 1..<gNumofNumContentStrings {
			if isStringInText(soughtStr: gNumContentString[j], inString: gTextPtr, startPos: gCharPos) {
				return j
			}
		}
		return 0
	}
	
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
		while ch == Int(_spaceChar.utf8.first!) { ch = nextChar() }
		
		if ch == Int("+".utf8.first!) || ch == Int("-".utf8.first!) { ch = nextChar() }
		
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
				if !digitFound { return false }
			} else {
				return false
			}
		}
		
		if ch == Int("E".utf8.first!) || ch == Int("e".utf8.first!) {
			ch = nextChar()
			if ch == Int("+".utf8.first!) || ch == Int("-".utf8.first!) { ch = nextChar() }
			digitFound = false
			while ch >= Int("0".utf8.first!) && ch <= Int("9".utf8.first!) {
				digitFound = true
				ch = nextChar()
			}
			if !digitFound { return false }
		}
		
		while ch == Int(_spaceChar.utf8.first!) { ch = nextChar() }
		
		numeric = (ch == -1)
		return numeric
	}
	
	func parseNumber() -> Double {
		var numString = ""
		var j = getIndexOfNextNumContentBit()
		
		while j > 0 {
			numString += gNumContentString[j]
			gCharPos += gNumContentString[j].count
			j = getIndexOfNextNumContentBit()
		}
		
		if !isNumeric(theString: numString) {
			parseError(errMsg: "Bad number format")
		}
		
		return Double(numString) ?? 0.0
	}
	
	//--| LEXER |-----
	
	func skipWhitespaceAndComments() {
		while gCharPos <= gTextPtr.count {
			let charIndex = gCharPos - 1
			
			// Check for end of string
			if charIndex >= gTextPtr.count {
				break
			}
			
			let theChar = getChar(theString: gTextPtr, charIndex: charIndex)
			
			// Check for // comment - skip to end of line
			if charIndex + 1 < gTextPtr.count {
				let nextChar = getChar(theString: gTextPtr, charIndex: charIndex + 1)
				if theChar == "/" && nextChar == "/" {
					// Skip rest of line
					gCharPos = gTextPtr.count + 1
					return
				}
			}
			
			// Skip whitespace
			if theChar == _spaceChar {
				gCharPos += 1
			} else {
				break
			}
		}
	}
	
	func parseStringLiteral() -> String {
		var result = ""
		gCharPos += 1
		
		while gCharPos <= gTextPtr.count {
			let ch = getChar(theString: gTextPtr, charIndex: gCharPos - 1)
			if ch == "\"" {
				gCharPos += 1
				return result
			}
			result += ch
			gCharPos += 1
		}
		
		parseError(errMsg: "Unterminated string literal")
		return result
	}
	
	func parseIdentifier() -> String {
		var result = ""
		
		while gCharPos <= gTextPtr.count {
			let ch = getChar(theString: gTextPtr, charIndex: gCharPos - 1)
			if ch.isEmpty { break }
			
			let isAlphaNum = (ch >= "a" && ch <= "z") || (ch >= "A" && ch <= "Z") ||
							(ch >= "0" && ch <= "9") || ch == "_" || ch == "$"
			
			if !isAlphaNum { break }
			
			result += ch
			gCharPos += 1
		}
		
		return result
	}
	
	func isAlphaNumeric(_ ch: String) -> Bool {
		if ch.isEmpty { return false }
		let c = ch.first!
		return (c >= "a" && c <= "z") || (c >= "A" && c <= "Z") ||
			   (c >= "0" && c <= "9") || c == "_" || c == "$"
	}
	
	func getLexeme() -> lexemeTypes? {
		var type: lexemeTypes? = nil
		if gParseError { return type }
		
		skipWhitespaceAndComments()
		
		// Check for string literal
		if gCharPos <= gTextPtr.count {
			let ch = getChar(theString: gTextPtr, charIndex: gCharPos - 1)
			if ch == "\"" {
				let strValue = parseStringLiteral()
				gCode = storeStringConst(value: strValue)
				gCode = -gCode
				type = ._readConstType
				return type
			}
		}
		
		// Check for numbers
		for j in 1..<gNumofNumStartStrings {
			if isStringInText(soughtStr: gNumStartString[j], inString: gTextPtr, startPos: gCharPos) {
				let value = parseNumber()
				gCode = storeParsedConst(value: value)
				type = ._readConstType
				return type
			}
		}
		
		// Check symbol table
		outer: for j in 1...gNumSyms {
			if isStringInText(soughtStr: gSymTable[j], inString: gTextPtr, startPos: gCharPos) {
				let symLen = gSymTable[j].count
				
				if gSymType[j] == ._keywordType || gSymType[j] == ._typeNameType ||
				   gSymType[j] == ._unaryOpType || gSymType[j] == ._readVarType {
						let nextPos = gCharPos + symLen - 1
						if nextPos < gTextPtr.count {
							let nextCh = getChar(theString: gTextPtr, charIndex: nextPos)
							if isAlphaNumeric(nextCh) {
								continue
							}
						}
					// Milestone 26: For _unaryOpType symbols (VAL, LEN, SIN, etc.),
					// require that a '(' follows (possibly after spaces).
					// If no '(' is found, this token is a user identifier, not a function call.
					// This prevents 'val' being mistaken for VAL when used as a variable name.
					if gSymType[j] == ._unaryOpType {
						var peekPos = gCharPos + symLen - 1
						var foundParen = false
						while peekPos < gTextPtr.count {
							let peekCh = getChar(theString: gTextPtr, charIndex: peekPos)
							if peekCh == " " { peekPos += 1; continue }
							if peekCh == "(" { foundParen = true; break }
							// Non-space, non-( character found — not a function call
							break
						}
						if !foundParen { continue }   // treat as identifier — skip this symbol
					}
				}
				
				type = gSymType[j]
				gCode = j
				gCharPos += symLen
				return type
			}
		}
		
		// Check for identifier
		if gCharPos <= gTextPtr.count {
			let ch = getChar(theString: gTextPtr, charIndex: gCharPos - 1)
			if (ch >= "a" && ch <= "z") || (ch >= "A" && ch <= "Z") || ch == "_" {
				let identifier = parseIdentifier()
				if !identifier.isEmpty {
					// Milestone 4: Check if this identifier is a known user function
					// If so, it will be handled as a function call in factor()
					gCode = storeVarName(name: identifier)
					type = ._readVarType
					return type
				}
			}
		}
		
		type = nil
		if gCharPos <= gTextPtr.count {
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
	
	//--| CODE GENERATION |-----
	
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
	
	//--| EXPRESSION PARSER |-----
	
	func factor(type: lexemeTypes?) -> lexemeTypes? {
		if gParseError { return type }
		
		guard let currentType = type else {
			parseError(errMsg: "Syntax Error")
			return nil
		}
		
		switch currentType {
		case ._readConstType:
			if gCode < 0 {
				plantCode(code: evalOPcodes._readConstCode.rawValue)
				plantCode(code: gCode)
			} else {
				plantCode(code: evalOPcodes._readConstCode.rawValue)
				plantCode(code: gCode)
			}
			return getLexeme()
			
		case ._readVarType:
			// First: check if this is a symbol-table value-producing opcode
			// (TIME, DATE, PI, INKEY$). These are registered as _readVarType
			// but must emit their specific opcode rather than a variable load.
			// We detect them by checking gSymCode[gCode] before consulting gVarNames,
			// BUT only when gCode refers to a symbol table entry — not a gVarNames entry.
			// We verify this by checking that gSymTable[gCode] matches the current
			// parse position in gTextPtr, preventing false matches when gCode happens
			// to equal a symbol index by coincidence.
			if gCode > 0 && gCode <= gNumSyms {
				let symOpCode = gSymCode[gCode]
				let symStr = gSymTable[gCode]
				// Confirm the symbol string actually appears at the current parse position
				// (adjusted back by symStr.count since getLexeme already advanced gCharPos)
				let matchPos = gCharPos - symStr.count
				let actualMatch = matchPos >= 1 &&
					isStringInText(soughtStr: symStr, inString: gTextPtr, startPos: matchPos)
				if actualMatch {
					switch symOpCode {
					case ._timeOpCode, ._dateOpCode, ._piOpCode:
						// Built-in value-producing symbols — emit opcode directly
						plantCode(code: symOpCode.rawValue)
						return getLexeme()
					case ._inkeyOpCode:
						// INKEY$ — emit opcode directly, no arguments
						plantCode(code: evalOPcodes._inkeyOpCode.rawValue)
						return getLexeme()
					case ._versionOpCode:
						// VERSION$ — emit opcode directly, no arguments
						plantCode(code: evalOPcodes._versionOpCode.rawValue)
						return getLexeme()
					default:
						break   // fall through to variable / function handling below
					}
				}
			}
			
			if gCode > 0 && gCode <= gNumVarNames {
				let varNameIdx = gCode  // SAVE the variable index before getLexeme changes gCode!
				let varName = gVarNames[varNameIdx]

				// Milestone 4: Check if this identifier is a user-defined function call
				// Peek at the next character: if it's '(' AND the name is in gFunctionDefs,
				// treat it as a function call expression.
				let nextType = getLexeme()
				if nextType == ._leftParenType && gFunctionDefs[varName.lowercased()] != nil {
					return parseFunctionCallExpression(funcName: varName.lowercased())
				} else if nextType == ._leftBracketType {
					// Array access: arr[index]
					return parseArrayAccess(varName: varName, isAssignment: false)
				} else {
					// Regular variable access
					plantCode(code: evalOPcodes._loadVarOpCode.rawValue)
					plantCode(code: varNameIdx)  // Use saved index, not gCode!
					return nextType
				}
			} else {
				plantCode(code: gSymCode[gCode].rawValue)
				return getLexeme()
			}
			
		case ._leftParenType:
			var newType = getLexeme()
			newType = logicalExpression(type: newType)
			return getRightParenthesis(type: newType)
			
		case ._plusMinusOpType:
			let tempCode = gSymCode[gCode]
			var newType = getLexeme()
			newType = factor(type: newType)
			if tempCode == ._minusOpCode {
				plantCode(code: evalOPcodes._unaryMinusCode.rawValue)
			}
			return newType

		case ._logicalOpType:
			// Milestone 24: unary ! prefix — only _logicalNotOpCode is valid here.
			// && || ^^ are binary and should never appear as a factor opener.
			let logUnaryCode = gSymCode[gCode]
			guard logUnaryCode == ._logicalNotOpCode else {
				parseError(errMsg: "Unexpected logical operator in expression")
				return nil
			}
			var newType = getLexeme()
			newType = factor(type: newType)
			plantCode(code: evalOPcodes._logicalNotOpCode.rawValue)
			return newType
			
		case ._unaryOpType:
			let tempCode = gSymCode[gCode]
			
			// Milestone 36: MOUSEAT(X|Y|B) — current mouse position / button state
			// Argument is an identifier: X=0, Y=1, B=2
			if tempCode == ._mouseatOpCode {
				var newType = getLexeme()                    // consume MOUSEAT keyword
				newType = getLeftParenthesis(type: newType)  // consume '(', advance to next token
				// Read axis identifier directly from source text —
				// X and Y are registered symbols so gSymTable[gCode] is unreliable here.
				// getLeftParenthesis() has already advanced gCharPos past '(' and whitespace,
				// so gCharPos now points at the axis letter. We read it raw.
				// getLexeme() inside getLeftParenthesis() already consumed the
				// axis token and stored it via storeVarName() — read from gVarNames.
				let axisRaw = gVarNames[gCode].uppercased()
				let axisCode: Int
				switch axisRaw {
				case "X": axisCode = 0
				case "Y": axisCode = 1
				case "B": axisCode = 2
				default:
					parseError(errMsg: "Expected X, Y, or B in MOUSEAT() — got '\(axisRaw)'")
					return newType
				}
				// getLexeme() consumed the axis identifier — call it once more
				// to consume ')' before passing to getRightParenthesis()
				newType = getLexeme()
				newType = getRightParenthesis(type: newType)
				plantCode(code: evalOPcodes._mouseatOpCode.rawValue)
				plantCode(code: axisCode)
				return newType
				}

				// Milestone 27: SAMPLE(x, y, channel, sampleSize) — 4 arguments
				if tempCode == ._sampleOpCode {
				// getLeftParenthesis() consumes '(' and returns the first token inside.
				// Do NOT call getLexeme() again before each argument — use the token
				// already returned by getLeftParenthesis() / comma-advance directly.
				var newType = getLexeme()                      // get '('
				newType = getLeftParenthesis(type: newType)    // validate '(' and return first token inside

				// x — newType is already the first token of the x expression
				newType = logicalExpression(type: newType)
				if gParseError { return newType }
				guard newType == ._assignOpType && gSymTable[gCode] == "," else {
					parseError(errMsg: "Expected , after SAMPLE x"); return newType
				}
				// y — advance past comma, then parse
				newType = logicalExpression(type: getLexeme())
				if gParseError { return newType }
				guard newType == ._assignOpType && gSymTable[gCode] == "," else {
					parseError(errMsg: "Expected , after SAMPLE y"); return newType
				}
				// channel (0=Red 1=Green 2=Blue 3=Alpha) — advance past comma, then parse
				newType = logicalExpression(type: getLexeme())
				if gParseError { return newType }
				guard newType == ._assignOpType && gSymTable[gCode] == "," else {
					parseError(errMsg: "Expected , after SAMPLE channel"); return newType
				}
				// sampleSize — advance past comma, then parse
				newType = logicalExpression(type: getLexeme())
				if gParseError { return newType }
				newType = getRightParenthesis(type: newType)
				plantCode(code: evalOPcodes._sampleOpCode.rawValue)
				plantCode(code: 4)
				return newType
				}
			
			// Milestone 38: DIST(x1, y1, x2, y2) — hypotenuse between two points
			if tempCode == ._distOpCode {
				var newType = getLexeme()                       // get '('
				newType = getLeftParenthesis(type: newType)     // validate '(' and return first token inside
				// x1
				newType = logicalExpression(type: newType)
				if gParseError { return newType }
				guard newType == ._assignOpType && gSymTable[gCode] == "," else {
					parseError(errMsg: "Expected , after DIST x1"); return newType
				}
				// y1
				newType = logicalExpression(type: getLexeme())
				if gParseError { return newType }
				guard newType == ._assignOpType && gSymTable[gCode] == "," else {
					parseError(errMsg: "Expected , after DIST y1"); return newType
				}
				// x2
				newType = logicalExpression(type: getLexeme())
				if gParseError { return newType }
				guard newType == ._assignOpType && gSymTable[gCode] == "," else {
					parseError(errMsg: "Expected , after DIST x2"); return newType
				}
				// y2
				newType = logicalExpression(type: getLexeme())
				if gParseError { return newType }
				newType = getRightParenthesis(type: newType)
				plantCode(code: evalOPcodes._distOpCode.rawValue)
				plantCode(code: 4)   // argCount — mirrors SAMPLE pattern
				return newType
				}

			// Special handling for MID$ function (3 arguments)
			if tempCode == ._MIDopCode {
				var newType = getLexeme()
				newType = getLeftParenthesis(type: newType)
				
				// First argument: string
				newType = expression(type: newType)
				if gParseError { return newType }
				
				// Expect comma
				guard newType == ._assignOpType && gSymTable[gCode] == "," else {
					parseError(errMsg: "Expected comma in MID$ function")
					return newType
				}
				
				// Second argument: index
				newType = getLexeme()
				newType = expression(type: newType)
				if gParseError { return newType }
				
				// Expect comma
				guard newType == ._assignOpType && gSymTable[gCode] == "," else {
					parseError(errMsg: "Expected comma in MID$ function")
					return newType
				}
				
				// Third argument: range
				newType = getLexeme()
				newType = expression(type: newType)
				if gParseError { return newType }
				
				newType = getRightParenthesis(type: newType)
				plantCode(code: tempCode.rawValue)
				return newType
			} else {
				// Normal unary operators (SIN, COS, LEN, VAL, CHR$, ASC, STR$, etc.)
				var newType = getLexeme()
				newType = getLeftParenthesis(type: newType)
				newType = expression(type: newType)
				newType = getRightParenthesis(type: newType)
				plantCode(code: tempCode.rawValue)
				return newType
			}
			
		case ._typeNameType:
			// INT is listed as _typeNameType for "var x : Int" declarations,
			// but INT(expr) is also a valid floor() call in expressions.
			let typeOpCode = gSymCode[gCode]
			if typeOpCode == ._INTopCode {
				var newType = getLexeme()
				newType = getLeftParenthesis(type: newType)
				newType = expression(type: newType)
				newType = getRightParenthesis(type: newType)
				plantCode(code: evalOPcodes._INTopCode.rawValue)
				return newType
			} else {
				parseError(errMsg: "Type name not valid in expression")
				return nil
			}

		default:
			parseError(errMsg: "Syntax Error")
			return nil
		}
	}

	// Milestone 4: Parse a user-defined function call used as an expression.
	// Called from factor() after we've already consumed the '(' token.
	// Emits: _funcCallOpCode, funcNameIdx, argCount, [argCount values pushed on stack]
	func parseFunctionCallExpression(funcName: String) -> lexemeTypes? {
		if gParseError { return nil }

		guard let funcDef = gFunctionDefs[funcName] else {
			parseError(errMsg: "Unknown function: \(funcName)")
			return nil
		}

		// We have already consumed '(' via getLexeme() in factor(), so we are
		// positioned just inside the argument list.
		var argCount = 0
		var type: lexemeTypes? = getLexeme()

		// Handle zero-argument functions: func foo() { ... }
		if type == ._rightParenType {
			type = getLexeme()
		} else {
			// Parse comma-separated argument expressions
			while true {
				type = logicalExpression(type: type)
				if gParseError { return nil }
				argCount += 1
				
				if type == ._assignOpType && gCode < gSymTable.count && gSymTable[gCode] == "," {
					// More arguments follow
					type = getLexeme()
				} else if type == ._rightParenType {
					type = getLexeme()
					break
				} else {
					parseError(errMsg: "Expected , or ) in function call to \(funcName)")
					return nil
				}
			}
		}

		if argCount != funcDef.params.count {
			parseError(errMsg: "Function \(funcName) expects \(funcDef.params.count) argument(s), got \(argCount)")
			return nil
		}

		// Emit function call opcode: _funcCallOpCode, nameIdx, argCount
		let nameIdx = storeVarName(name: funcName)
		plantCode(code: evalOPcodes._funcCallOpCode.rawValue)
		plantCode(code: nameIdx)
		plantCode(code: argCount)

		return type
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
	
	// Milestone 24: logicalExpression — top of the parse hierarchy.
	// Handles && || ^^ binary operators, which bind looser than comparisons.
	// This ensures "a > 0 && b > 0" parses as "(a > 0) && (b > 0)".
	// Both logical (boolean result) and bitwise (integer) behaviour are
	// determined at runtime by the executor based on operand values.
	func logicalExpression(type: lexemeTypes?) -> lexemeTypes? {
		if gParseError { return type }

		var currentType = comparison(type: type)

		while currentType == ._logicalOpType {
			let logOpCode = gSymCode[gCode]
			// Guard: only binary logical ops valid here (not unary !)
			guard logOpCode == ._logicalAndOpCode ||
				  logOpCode == ._logicalOrOpCode  ||
				  logOpCode == ._logicalXorOpCode else {
				break
			}
			currentType = getLexeme()
			currentType = comparison(type: currentType)
			plantCode(code: logOpCode.rawValue)
		}

		return currentType
	}

	func comparison(type: lexemeTypes?) -> lexemeTypes? {
		if gParseError { return type }
		
		var currentType = expression(type: type)
		
		if currentType == ._compareOpType {
			if gCode < 0 || gCode >= gSymCode.count {
				parseError(errMsg: "Internal error: symbol code out of range")
				return currentType
			}
			
			let compareOpCode = gSymCode[gCode]
			currentType = getLexeme()
			currentType = expression(type: currentType)
			plantCode(code: compareOpCode.rawValue)
		}
		
		return currentType
	}
	
	//--| STATEMENT PARSER |-----
	
	func parseVarDeclaration() -> Bool {
		if gParseError { return false }
		
		var type = getLexeme()
		guard type == ._readVarType else {
			parseError(errMsg: "Expected variable name after VAR")
			return false
		}
		
		let varName = gVarNames[gCode]
		var varType: VarType = .intType
		var isArray = false
		var arraySize = 0
		
		if varName.hasSuffix("$") {
			varType = .stringType
		}
		
		type = getLexeme()
		
		// Check for array declaration syntax: var myArray[size] or var myArray[d0,d1,...] (Milestone 23)
		if type == ._leftBracketType {
			isArray = true

			// Collect up to 8 dimension sizes, comma-separated inside [ ]
			var dimSizes: [Int] = []
			let maxDims = 8

			repeat {
				// Reset code array before parsing each dimension expression
				gMyCodeArray[0] = 0
				type = getLexeme()
				type = logicalExpression(type: type)
				if gParseError { return false }

				// Evaluate this dimension expression immediately
				let dimResult = evaluate(codeArray: gMyCodeArray, litConsts: gParsedConstants, xVar: 0, yVar: 0)
				if dimResult.error {
					parseError(errMsg: "Invalid array dimension size")
					return false
				}
				let dimVal = Int(dimResult.result)
				if dimVal <= 0 {
					parseError(errMsg: "Array dimension size must be positive")
					return false
				}
				dimSizes.append(dimVal)
				gMyCodeArray[0] = 0   // reset for next dim or rest of declaration

				// Continue if comma follows (more dimensions), stop if ]
				if type == ._assignOpType && gSymTable[gCode] == "," {
					if dimSizes.count >= maxDims {
						parseError(errMsg: "Array supports at most \(maxDims) dimensions")
						return false
					}
					// loop continues — getLexeme() at top of repeat will advance past comma
				} else if type == ._rightBracketType {
					break
				} else {
					parseError(errMsg: "Expected , or ] in array declaration")
					return false
				}
			} while true

			// Compute total flat size = product of all dimensions
			arraySize = dimSizes.reduce(1, *)
			if arraySize <= 0 {
				parseError(errMsg: "Array total size must be positive")
				return false
			}

			// Store dims for use in initializeArray below
			// (arrayDims captured here, passed to initializeArray after type is resolved)
			// We store in a local; initializeArray is called later after varType is known.
			// Temporarily stash dims — we pass them through a closure capture below.
			// Swift note: we use a local var captured by the initializeArray call site.
			let capturedDims = dimSizes

			type = getLexeme()

			// Check for type specification
			if type == ._assignOpType && gSymTable[gCode] == ":" {
				type = getLexeme()
				if type == ._typeNameType {
					let typeName = gSymTable[gCode].uppercased()
					switch typeName {
					case "INT":    varType = .intType
					case "FLOAT":  varType = .floatType
					case "STRING": varType = .stringType
					case "BOOL":   varType = .boolType
					default:       varType = .intType
					}
					type = getLexeme()
				} else {
					parseError(errMsg: "Expected type name after :")
					return false
				}
			}

			// Convert to array type
			varType = VarType.arrayType(from: varType)

			// Initialize array storage with full dimension metadata
			initializeArray(name: varName, size: arraySize, type: varType, dims: capturedDims)

			// Register type
			if let funcName = gCurrentParseFuncName {
				if gFunctionLocalTypes[funcName] == nil { gFunctionLocalTypes[funcName] = [:] }
				gFunctionLocalTypes[funcName]![varName] = varType
			} else {
				gVariableTypes[varName] = varType
				gVariables[varName] = VariableInfo(type: varType, value: .int(0), arraySize: arraySize)
			}

			return true
		}
		
		// Check for type specification: : Int, : Float, etc.
		if type == ._assignOpType && gSymTable[gCode] == ":" {
			type = getLexeme()
			
			if type == ._typeNameType {
				let typeName = gSymTable[gCode].uppercased()
				
				switch typeName {
				case "INT": varType = .intType
				case "FLOAT": varType = .floatType
				case "STRING": varType = .stringType
				case "BOOL": varType = .boolType
				default: varType = .intType
				}
				
				type = getLexeme()
			} else {
				parseError(errMsg: "Expected type name after :")
				return false
			}
		}
		
		// (Array declaration handled above — returns early. Scalar path continues below.)
		
		// For scalar variables, expect = assignment
		if type != ._assignOpType || gSymTable[gCode] != "=" {
			parseError(errMsg: "Expected = in variable declaration")
			return false
		}
		
		type = getLexeme()
		type = logicalExpression(type: type)
		
		if gParseError { return false }
		
		// If parsing a function body line, register type locally not globally
		if let funcName = gCurrentParseFuncName {
			if gFunctionLocalTypes[funcName] == nil { gFunctionLocalTypes[funcName] = [:] }
			gFunctionLocalTypes[funcName]![varName] = varType
		} else {
			gVariableTypes[varName] = varType
		}
		
		plantCode(code: evalOPcodes._storeVarOpCode.rawValue)
		plantCode(code: storeVarName(name: varName))
		
		return true
	}
	
	// Parse array indexing: arrayName[index] (1D) or arrayName[i,j,...] (MD, Milestone 23)
	// For isAssignment=false (read): indices are on stack, value is loaded.
	// For isAssignment=true (write):  indices are on stack, then value; store is emitted.
	func parseArrayAccess(varName: String, isAssignment: Bool) -> lexemeTypes? {
		if gParseError { return nil }

		// We've already seen the variable name and [
		// Parse comma-separated index expressions
		var dimCount = 0
		var type: lexemeTypes?

		repeat {
			type = getLexeme()
			type = logicalExpression(type: type)
			if gParseError { return nil }
			dimCount += 1

			if type == ._assignOpType && gSymTable[gCode] == "," {
				// more indices follow — continue loop
			} else if type == ._rightBracketType {
				break
			} else {
				parseError(errMsg: "Expected , or ] in array index")
				return nil
			}
		} while true

		let nameIdx = storeVarName(name: varName)

		if dimCount == 1 {
			// 1D fast path — existing opcodes, unchanged behaviour
			if isAssignment {
				plantCode(code: evalOPcodes._arrayStoreOpCode.rawValue)
				plantCode(code: nameIdx)
			} else {
				plantCode(code: evalOPcodes._arrayLoadOpCode.rawValue)
				plantCode(code: nameIdx)
			}
		} else {
			// Multi-dim path — Milestone 23
			if isAssignment {
				plantCode(code: evalOPcodes._arrayStoreMDOpCode.rawValue)
				plantCode(code: nameIdx)
				plantCode(code: dimCount)
			} else {
				plantCode(code: evalOPcodes._arrayLoadMDOpCode.rawValue)
				plantCode(code: nameIdx)
				plantCode(code: dimCount)
			}
		}

		return getLexeme()
	}
	
	func parseAssignment(varName: String) -> Bool {
		if gParseError { return false }
		
		var type = getLexeme()
		type = logicalExpression(type: type)
		
		if gParseError { return false }
		
		plantCode(code: evalOPcodes._storeVarOpCode.rawValue)
		plantCode(code: storeVarName(name: varName))
		
		return true
	}
	
	func parseArrayAssignment(varName: String) -> Bool {
		if gParseError { return false }

		// We've already consumed [ in parseStatement.
		// Parse comma-separated index expressions (1 for 1D, N for multi-dim — Milestone 23)
		var dimCount = 0
		var type: lexemeTypes?
		
		repeat {
			type = getLexeme()
			type = logicalExpression(type: type)
			if gParseError { return false }
			dimCount += 1

			if type == ._assignOpType && gSymTable[gCode] == "," {
				// more indices follow
			} else if type == ._rightBracketType {
				break
			} else {
				parseError(errMsg: "Expected , or ] in array index")
				return false
			}
		} while true

		// Now expect =
		type = getLexeme()
		guard type == ._assignOpType && gSymTable[gCode] == "=" else {
			parseError(errMsg: "Expected = after array index")
			return false
		}

		// Parse the value expression
		type = getLexeme()
		type = logicalExpression(type: type)
		if gParseError { return false }

		let nameIdx = storeVarName(name: varName)

		if dimCount == 1 {
			// 1D fast path — unchanged
			plantCode(code: evalOPcodes._arrayStoreOpCode.rawValue)
			plantCode(code: nameIdx)
		} else {
			// Multi-dim — Milestone 23
			// Stack: [i0, i1, ..., iN-1, value]
			plantCode(code: evalOPcodes._arrayStoreMDOpCode.rawValue)
			plantCode(code: nameIdx)
			plantCode(code: dimCount)
		}

		return true
	}
	
	func parsePrintStatement() -> Bool {
		if gParseError { return false }
		
		var type = getLexeme()
		
		// Check if this is an empty PRINT (just newline)
		if type == nil {
			plantCode(code: evalOPcodes._printOpCode.rawValue)
			plantCode(code: 0)  // Mode 0: newline only
			return true
		}
		
		// Check for semicolon immediately (edge case: "print ;")
		if type == ._assignOpType && gSymTable[gCode] == ";" {
			// Empty print with no newline - do nothing
			return true
		}
		
		// Parse the expression to print
		type = logicalExpression(type: type)
		
		if gParseError { return false }
		
		// Check for semicolon after expression
		var suppressNewline = false
		if type == ._assignOpType && gSymTable[gCode] == ";" {
			suppressNewline = true
			// Don't call getLexeme() - we're at end of statement
		}
		
		// Plant PRINT opcode with appropriate mode
		plantCode(code: evalOPcodes._printOpCode.rawValue)
		if suppressNewline {
			plantCode(code: 2)  // Mode 2: print value without newline
		} else {
			plantCode(code: 1)  // Mode 1: print value with newline
		}
		
		return true
	}
	
	// Parse LOCATE statement (GW-BASIC style: LOCATE row, col)
	// Where row is 1–25 and col is 1–80 (matching GW-BASIC)
	func parseLocateStatement() -> Bool {
		if gParseError { return false }

		// Parse row expression
		var type = getLexeme()
		type = logicalExpression(type: type)
		if gParseError { return false }

		// Expect comma separator
		guard type == ._assignOpType && gSymTable[gCode] == "," else {
			parseError(errMsg: "Expected , between row and col in LOCATE")
			return false
		}

		// Parse col expression
		type = getLexeme()
		type = logicalExpression(type: type)
		if gParseError { return false }

		// Emit LOCATE opcode — executor pops col then row off the stack
		plantCode(code: evalOPcodes._locateOpCode.rawValue)

		return true
	}
	
	// Parse POINT statement
	// Syntax: POINT(x, y)  or  POINT(x, y, R, G, B, A)
	// Emits: _pointOpCode, argCount (2 or 6) — args already on stack
	func parsePointStatement() -> Bool {
		if gParseError { return false }

		var type = getLexeme()
		guard type == ._leftParenType else {
			parseError(errMsg: "Expected ( after POINT")
			return false
		}

		// x
		type = getLexeme()
		type = logicalExpression(type: type)
		if gParseError { return false }
		guard type == ._assignOpType && gSymTable[gCode] == "," else {
			parseError(errMsg: "Expected , after POINT x")
			return false
		}

		// y
		type = getLexeme()
		type = logicalExpression(type: type)
		if gParseError { return false }

		var argCount = 2

		// Optional R, G, B, A
		if type == ._assignOpType && gSymTable[gCode] == "," {
			for i in 0..<4 {
				type = getLexeme()
				type = logicalExpression(type: type)
				if gParseError { return false }
				argCount += 1
				if i < 3 {
					guard type == ._assignOpType && gSymTable[gCode] == "," else {
						parseError(errMsg: "Expected , in POINT colour arguments")
						return false
					}
				}
			}
		}

		guard type == ._rightParenType else {
			parseError(errMsg: "Expected ) after POINT arguments")
			return false
		}

		plantCode(code: evalOPcodes._pointOpCode.rawValue)
		plantCode(code: argCount)
		return true
	}

	// Parse LINE statement
	// Syntax: LINE(x1, y1, x2, y2)  or  LINE(x1, y1, x2, y2, R, G, B, A)
	// Emits: _lineOpCode, argCount (4 or 8) — args already on stack
	func parseLineStatement() -> Bool {
		if gParseError { return false }

		var type = getLexeme()
		guard type == ._leftParenType else {
			parseError(errMsg: "Expected ( after LINE")
			return false
		}

		// x1
		type = getLexeme()
		type = logicalExpression(type: type)
		if gParseError { return false }
		guard type == ._assignOpType && gSymTable[gCode] == "," else {
			parseError(errMsg: "Expected , after LINE x1")
			return false
		}

		// y1
		type = getLexeme()
		type = logicalExpression(type: type)
		if gParseError { return false }
		guard type == ._assignOpType && gSymTable[gCode] == "," else {
			parseError(errMsg: "Expected , after LINE y1")
			return false
		}

		// x2
		type = getLexeme()
		type = logicalExpression(type: type)
		if gParseError { return false }
		guard type == ._assignOpType && gSymTable[gCode] == "," else {
			parseError(errMsg: "Expected , after LINE x2")
			return false
		}

		// y2
		type = getLexeme()
		type = logicalExpression(type: type)
		if gParseError { return false }

		var argCount = 4

		// Optional R, G, B, A
		if type == ._assignOpType && gSymTable[gCode] == "," {
			for i in 0..<4 {
				type = getLexeme()
				type = logicalExpression(type: type)
				if gParseError { return false }
				argCount += 1
				if i < 3 {
					guard type == ._assignOpType && gSymTable[gCode] == "," else {
						parseError(errMsg: "Expected , in LINE colour arguments")
						return false
					}
				}
			}
		}

		guard type == ._rightParenType else {
			parseError(errMsg: "Expected ) after LINE arguments")
			return false
		}

		plantCode(code: evalOPcodes._lineOpCode.rawValue)
		plantCode(code: argCount)
		return true
	}

	// Milestone 27: parseSampleStatement() — superseded by factor() ._unaryOpType handling.
	// SAMPLE is now registered as ._unaryOpType so it is parsed in factor() directly,
	// allowing it to appear on the RHS of assignments and in expressions.
	// This function is retained for reference but is no longer called.
	// Milestone 27: Parse SAMPLE statement/expression
	// Syntax: SAMPLE(x, y, channel, sampleSize)
	//   x, y        — pixel coordinates (origin top-left, Y down)
	//   channel     — 0=Red 1=Green 2=Blue 3=Alpha
	//   sampleSize  — 1.0 = single pixel; >1.0 = square area average (diameter in logical pixels)
	// Returns a Float in 0.0–1.0 pushed onto the eval stack.
	// Emits: _sampleOpCode, argCount (always 4)
	func parseSampleStatement() -> Bool {
		if gParseError { return false }

		var type = getLexeme()
		guard type == ._leftParenType else {
			parseError(errMsg: "Expected ( after SAMPLE")
			return false
		}

		// x
		type = getLexeme()
		type = logicalExpression(type: type)
		if gParseError { return false }
		guard type == ._assignOpType && gSymTable[gCode] == "," else {
			parseError(errMsg: "Expected , after SAMPLE x")
			return false
		}

		// y
		type = getLexeme()
		type = logicalExpression(type: type)
		if gParseError { return false }
		guard type == ._assignOpType && gSymTable[gCode] == "," else {
			parseError(errMsg: "Expected , after SAMPLE y")
			return false
		}

		// channel (0=Red 1=Green 2=Blue 3=Alpha)
		type = getLexeme()
		type = logicalExpression(type: type)
		if gParseError { return false }
		guard type == ._assignOpType && gSymTable[gCode] == "," else {
			parseError(errMsg: "Expected , after SAMPLE channel")
			return false
		}

		// sampleSize
		type = getLexeme()
		type = logicalExpression(type: type)
		if gParseError { return false }
		guard type == ._rightParenType else {
			parseError(errMsg: "Expected ) after SAMPLE arguments")
			return false
		}

		plantCode(code: evalOPcodes._sampleOpCode.rawValue)
		plantCode(code: 4)
		return true
	}
	
	// Parse SPRITE statement
	// Syntax: SPRITE(id, x, y, rotation, scale, hidden, alpha, imageURL)
	// Any argument except id may be omitted (empty slot = consecutive commas).
	// Emits: for each of the 8 slots, either the expression bytecode OR a
	// slot-absent marker (a string constant "" with a flag bit in argPresent).
	// Simpler approach: emit argPresent bitmask + all 8 slots, omitted numerics
	// use a pre-stored sentinel index, omitted string uses "".
	//
	// Actually simplest correct approach: emit only the arg COUNT and the
	// args that ARE present, identified by a bitmask stored before them.
	// Executor reads bitmask, pops only present args, uses defaults for absent.
	//
	// Emits: _spriteOpCode, presentMask (Int bitmask, bit N=1 means arg N present),
	//        then only the present args in order (id always present = bit 0 always set).
	func parseSpriteStatement() -> Bool {
		if gParseError { return false }

		var type = getLexeme()
		guard type == ._leftParenType else {
			parseError(errMsg: "Expected ( after SPRITE")
			return false
		}

		var presentMask = 0       // bit N set = argument N was supplied
		var argCount    = 0       // how many args actually emitted

		// ── Arg 0: id (required) ─────────────────────────────────────────────
		type = getLexeme()
		type = logicalExpression(type: type)
		if gParseError { return false }
		presentMask |= (1 << 0)
		argCount += 1

		// ── Args 1–7: optional slots separated by commas ─────────────────────
		// Slot is present if, after consuming the comma, the next token is NOT
		// another comma and NOT ")".
		for slotIndex in 1...7 {
			guard type == ._assignOpType && gSymTable[gCode] == "," else {
				// No more commas — remaining slots absent
				break
			}
			// Peek at what follows the comma
			type = getLexeme()
			let isCommaOrRParen = (type == ._assignOpType && gSymTable[gCode] == ",")
							   || (type == ._rightParenType)
			if isCommaOrRParen {
				// Empty slot — do not emit, do not set bit, do not consume token
				// (leave type as "," or ")" so next iteration / guard sees it)
			} else {
				// Non-empty slot — parse the expression (already consumed first token)
				type = logicalExpression(type: type)
				if gParseError { return false }
				presentMask |= (1 << slotIndex)
				argCount += 1
			}
		}

		guard type == ._rightParenType else {
			parseError(errMsg: "Expected ) after SPRITE arguments")
			return false
		}
		plantCode(code: evalOPcodes._spriteOpCode.rawValue)
		plantCode(code: presentMask)
		plantCode(code: argCount)
		return true
	}
	
	
	// Parse GET statement
	// Syntax: GET(spriteID, x1, y1, x2, y2)
	// All 5 arguments required.
	// Emits: _getOpCode, 5
	func parseGetStatement() -> Bool {
		if gParseError { return false }
		var type = getLexeme()
		guard type == ._leftParenType else {
			parseError(errMsg: "Expected ( after GET")
			return false
		}
		// spriteID
		type = getLexeme()
		type = logicalExpression(type: type)
		if gParseError { return false }
		// x1, y1, x2, y2
		let argNames = ["x1", "y1", "x2", "y2"]
		for name in argNames {
			guard type == ._assignOpType && gSymTable[gCode] == "," else {
				parseError(errMsg: "Expected , before GET \(name)")
				return false
			}
			type = getLexeme()
			type = logicalExpression(type: type)
			if gParseError { return false }
		}
		guard type == ._rightParenType else {
			parseError(errMsg: "Expected ) after GET arguments")
			return false
		}
		plantCode(code: evalOPcodes._getOpCode.rawValue)
		plantCode(code: 5)
		return true
	}
	
	
	// Milestone 5: Parse TIMER statement
	// Syntax: TIMER interval funcName
	// Stores interval (Double) and function name (identifier) into globals.
	// Does NOT start the timer — TIMERON does that.
	func parseTimerDeclStatement() -> Bool {
		if gParseError { return false }

		// Parse interval as a numeric expression
		var type = getLexeme()
		type = logicalExpression(type: type)
		if gParseError { return false }

		// Expect an identifier (function name) — not a keyword, not a paren
		guard type == ._readVarType, gCode >= 1, gCode <= gNumVarNames else {
			parseError(errMsg: "Expected function name after TIMER interval")
			return false
		}
		let funcNameIdx = storeVarName(name: gVarNames[gCode])

		// Emit: _timerDeclOpCode, funcNameIdx
		// The interval is already on the stack from the expression parse above.
		plantCode(code: evalOPcodes._timerDeclOpCode.rawValue)
		plantCode(code: funcNameIdx)

		return true
	}

	// Milestone 10: Parse WHILE statement
	// Syntax: WHILE (condition) {
	// The condition is enclosed in parentheses (mandatory).
	// The opening { may be on the same line or the next line — handled by preScanBraceBlocks().
	// Emits: _whileOpCode (condition already on stack from parsing the ( expr ) ).
	// The closing } line emits _whileEndOpCode — detected in parseStatement() via gCurrentParseLineNum.
	func parseWhileStatement() -> Bool {
		if gParseError { return false }

		// Expect opening parenthesis
		var type = getLexeme()
		guard type == ._leftParenType else {
			parseError(errMsg: "Expected ( after WHILE")
			return false
		}

		// Parse the condition expression
		type = getLexeme()
		type = logicalExpression(type: type)
		if gParseError { return false }

		// Expect closing parenthesis
		guard type == ._rightParenType else {
			parseError(errMsg: "Expected ) after WHILE condition")
			return false
		}

		// Emit WHILE opcode — condition is on the stack.
		// The executor reads gWhilePairs[pc] to find the exit line.
		plantCode(code: evalOPcodes._whileOpCode.rawValue)

		// The optional { on this line is consumed silently — it's structural,
		// not an executable token. preScanWhileLoops() already recorded the pair.
		return true
	}

	func parseTabStatement() -> Bool {
		if gParseError { return false }
		
		var type = getLexeme()
		
		// Expect (
		guard type == ._leftParenType else {
			parseError(errMsg: "Expected ( after TAB")
			return false
		}
		
		// Parse the column expression
		type = getLexeme()
		type = comparison(type: type)
		if gParseError { return false }
		
		// Expect )
		guard type == ._rightParenType else {
			parseError(errMsg: "Expected ) after TAB expression")
			return false
		}
		
		// Plant TAB opcode
		plantCode(code: evalOPcodes._tabOpCode.rawValue)
		
		return true
	}
	
	// Parse CLS statement
	func parseCLSStatement() -> Bool {
		if gParseError { return false }
		
		// CLS takes no arguments
		plantCode(code: evalOPcodes._clsOpCode.rawValue)
		
		return true
	}
	
	// Parse INPUT statement
	func parseInputStatement() -> Bool {
		if gParseError { return false }
		
		var type = getLexeme()
		var hasPrompt = false
		
		// Check if there's a prompt string: INPUT "prompt";
		if type == ._readConstType && gCode < 0 {
			// We have a string prompt - need to put it on the stack
			hasPrompt = true
			
			// Plant the string constant load (this puts prompt on stack)
			plantCode(code: evalOPcodes._readConstCode.rawValue)
			plantCode(code: gCode)
			
			// Expect semicolon after prompt
			type = getLexeme()
			guard type == ._assignOpType && gSymTable[gCode] == ";" else {
				parseError(errMsg: "Expected ; after INPUT prompt")
				return false
			}
			
			// Get the variable name
			type = getLexeme()
		}
		
		// Now we should have the variable name
		guard type == ._readVarType else {
			parseError(errMsg: "Expected variable name after INPUT")
			return false
		}
		
		let varName = gVarNames[gCode]
		
		// Plant INPUT opcode
		plantCode(code: evalOPcodes._inputOpCode.rawValue)
		plantCode(code: storeVarName(name: varName))
		plantCode(code: hasPrompt ? 1 : 0)  // Flag: 1 = has prompt on stack, 0 = no prompt
		
		return true
	}
	
	// Parse END statement
	func parseEndStatement() -> Bool {
		if gParseError { return false }
		
		// END takes no arguments
		plantCode(code: evalOPcodes._endOpCode.rawValue)
		
		return true
	}
	
	// Parse EXIT statement
	func parseExitStatement() -> Bool {
		if gParseError { return false }
		
		// EXIT takes no arguments
		plantCode(code: evalOPcodes._exitOpCode.rawValue)
		
		return true
	}
	
	func parseForStatement() -> Bool {
		if gParseError { return false }
		
		var type = getLexeme()
		guard type == ._readVarType else {
			parseError(errMsg: "Expected variable name after FOR")
			return false
		}
		
		let loopVarName = gVarNames[gCode]
		
		if gVariableTypes[loopVarName] == nil {
			gVariableTypes[loopVarName] = .intType
			gVariables[loopVarName] = VariableInfo(type: .intType, value: .int(0))
		}
		
		type = getLexeme()
		guard type == ._assignOpType && gSymTable[gCode] == "=" else {
			parseError(errMsg: "Expected = after FOR variable")
			return false
		}
		
		type = getLexeme()
		type = comparison(type: type)
		if gParseError { return false }
		
		plantCode(code: evalOPcodes._storeVarOpCode.rawValue)
		plantCode(code: storeVarName(name: loopVarName))
		
		guard type == ._keywordType && gSymTable[gCode].uppercased() == "TO" else {
			parseError(errMsg: "Expected TO in FOR statement")
			return false
		}
		
		type = getLexeme()
		type = comparison(type: type)
		if gParseError { return false }
		
		var hasStep = false
		if type == ._keywordType && gSymTable[gCode].uppercased() == "STEP" {
			hasStep = true
			type = getLexeme()
			type = comparison(type: type)
			if gParseError { return false }
		}
		
		plantCode(code: evalOPcodes._forBeginOpCode.rawValue)
		plantCode(code: storeVarName(name: loopVarName))
		plantCode(code: hasStep ? 1 : 0)
		
		return true
	}
	
	func parseNextStatement() -> Bool {
		if gParseError { return false }
		
		let type = getLexeme()
		
		var loopVarName = ""
		if type == ._readVarType {
			loopVarName = gVarNames[gCode]
		}
		
		plantCode(code: evalOPcodes._forNextOpCode.rawValue)
		if !loopVarName.isEmpty {
			plantCode(code: storeVarName(name: loopVarName))
		} else {
			plantCode(code: 0)
		}
		
		return true
	}
	
	func parseIfStatement() -> Bool {
		if gParseError { return false }

		var type = getLexeme()
		type = logicalExpression(type: type)
		if gParseError { return false }

		// Milestone 39: detect multi-line IF — { after condition instead of THEN
		if type == ._leftBraceType {
			// Plant ifBegin opcode — executor jumps past } if condition is false
			plantCode(code: evalOPcodes._ifBeginOpCode.rawValue)
			return true
		}

		// Existing single-line IF THEN handling — unchanged
		guard type == ._keywordType && gSymTable[gCode].uppercased() == "THEN" else {
			parseError(errMsg: "Expected THEN or { after IF condition")
			return false
		}

		plantCode(code: evalOPcodes._ifThenOpCode.rawValue)

		type = getLexeme()

		if type == ._keywordType {
			let keyword = gSymTable[gCode].uppercased()
			switch keyword {
			case "PRINT":      return parsePrintStatement()
			case "RETURN":     return parseReturnStatement()
			case "CLS":        return parseCLSStatement()
			case "END":        return parseEndStatement()
			case "NEXT":       return parseNextStatement()
			case "TIMEROFF":   plantCode(code: evalOPcodes._timerOffOpCode.rawValue);  return true
			case "TIMERSTOP":  plantCode(code: evalOPcodes._timerStopOpCode.rawValue); return true
			case "TIMERON":    plantCode(code: evalOPcodes._timerOnOpCode.rawValue);   return true
			case "LOCATE":     return parseLocateStatement()
			case "CLR":        plantCode(code: evalOPcodes._clrOpCode.rawValue); return true
			case "BEEP":       plantCode(code: evalOPcodes._beepOpCode.rawValue); return true
			case "PEN":
				var penType = getLexeme()
				penType = logicalExpression(type: penType)
				if gParseError { return false }
				plantCode(code: evalOPcodes._penOpCode.rawValue)
				return true
			case "POINT":   return parsePointStatement()
			case "LINE":    return parseLineStatement()
			case "SPRITE":  return parseSpriteStatement()
			case "GET":     return parseGetStatement()
			case "SAY":     return parseSayStatement()
			case "PLAY":    return parsePlayStatement()
			case "SOUND":   return parseSoundStatement()
			case "FILL":    return parseFillStatement()
			case "TEXT":    return parseTextColorStatement()
			default:
				parseError(errMsg: "Unsupported statement after THEN: \(keyword)")
				return false
			}
		} else if type == ._readVarType {
			let varName = gVarNames[gCode]
			type = getLexeme()
			if type == ._leftBracketType {
				return parseArrayAssignment(varName: varName)
			} else if type == ._assignOpType && gSymTable[gCode] == "=" {
				return parseAssignment(varName: varName)
			} else if type == ._leftParenType && gFunctionDefs[varName.lowercased()] != nil {
				_ = parseFunctionCallExpression(funcName: varName.lowercased())
				return !gParseError
			} else {
				parseError(errMsg: "Expected assignment or function call after THEN")
				return false
			}
		} else {
			parseError(errMsg: "Expected statement after THEN")
			return false
		}
	}

	// Milestone 4: Parse RETURN statement
	// Syntax: return <expression>
	// Emits the expression then _returnOpCode
	func parseReturnStatement() -> Bool {
		if gParseError { return false }

		var type = getLexeme()

		if type == nil {
			// return with no value - push 0.0
			plantCode(code: evalOPcodes._readConstCode.rawValue)
			let zeroIdx = storeParsedConst(value: 0.0)
			plantCode(code: zeroIdx)
		} else {
			type = logicalExpression(type: type)
			if gParseError { return false }
		}

		plantCode(code: evalOPcodes._returnOpCode.rawValue)
		return true
	}

	// Milestone 4: Parse FUNC definition header (skipped during normal execution).
	// Syntax: func name(param1, param2, ...) {
	// The body lines and closing } are handled by the pre-scanner.
	// This parser just validates the header and emits nothing —
	// func definitions are not executable statements, they are declarations.
	func parseFuncDefinition() -> Bool {
		// FUNC definitions are pre-scanned before execution.
		// During execution the executor skips over them entirely.
		// So this just needs to succeed silently.
		return true
	}
	
	// Milestone 21: Parse the RHS of a whole-array LOAD assignment.
	// Called from parseStatement() after the parser has already consumed:
	//   arrayName  [  ]  =
	// This function consumes:  LOAD  (  urlExpression  )
	// Emits: url-expression opcodes, _fileLoadOpCode, arrayNameIdx
	func parseFileLoadStatement(arrayName: String) -> Bool {
		if gParseError { return false }

		// Expect the literal identifier LOAD next in the token stream.
		// LOAD is not in the symbol table so getLexeme() returns it as _readVarType
		// with gVarNames[gCode] == "LOAD" (case-insensitive compare below).
		var type = getLexeme()
		guard type == ._readVarType,
			  gCode >= 1, gCode <= gNumVarNames,
			  gVarNames[gCode].uppercased() == "LOAD" else {
			parseError(errMsg: "Expected LOAD after \(arrayName)[] =")
			return false
		}

		// Expect opening parenthesis
		type = getLexeme()
		guard type == ._leftParenType else {
			parseError(errMsg: "Expected ( after LOAD")
			return false
		}

		// Parse the URL string expression (single argument)
		type = getLexeme()
		type = comparison(type: type)
		if gParseError { return false }

		// Expect closing parenthesis
		guard type == ._rightParenType else {
			parseError(errMsg: "Expected ) after LOAD argument")
			return false
		}

		// Emit: _fileLoadOpCode, arrayNameIdx
		// The URL string is already on the eval stack from the expression parse above.
		let arrayNameIdx = storeVarName(name: arrayName)
		plantCode(code: evalOPcodes._fileLoadOpCode.rawValue)
		plantCode(code: arrayNameIdx)

		return true
	}
	
	// Milestone 21: Parse a SAVE statement.
	// Syntax: SAVE urlExpr, arrayName[]
	//   urlExpr   — any string expression resolving to the output file path
	//   arrayName — must be a declared stringArrayType variable
	// Emits: url-expression opcodes (pushed onto eval stack), _fileSaveOpCode, arrayNameIdx
	// The executor pops the URL string at runtime, supporting variable paths.
	func parseFileSaveStatement() -> Bool {
		if gParseError { return false }

		// Parse the output URL expression (any string expression)
		var type = getLexeme()
		type = logicalExpression(type: type)
		if gParseError { return false }
		
		// Expect comma separator between URL and array name
		guard type == ._assignOpType && gSymTable[gCode] == "," else {
			parseError(errMsg: "Expected , after SAVE url (e.g. SAVE b$, fileLines[])")
			return false
		}

		// Expect the array variable name
		type = getLexeme()
		guard type == ._readVarType, gCode >= 1, gCode <= gNumVarNames else {
			parseError(errMsg: "Expected array name after SAVE url,")
			return false
		}
		let arrayName    = gVarNames[gCode]
		let arrayNameIdx = storeVarName(name: arrayName)

		// Expect empty brackets []
		type = getLexeme()
		guard type == ._leftBracketType else {
			parseError(errMsg: "Expected [] after SAVE array name (e.g. SAVE b$, fileLines[])")
			return false
		}
		type = getLexeme()
		guard type == ._rightBracketType else {
			parseError(errMsg: "Expected ] after SAVE array name")
			return false
		}

		// Emit: _fileSaveOpCode, arrayNameIdx
		// The URL string is already on the eval stack from the expression parse above.
		plantCode(code: evalOPcodes._fileSaveOpCode.rawValue)
		plantCode(code: arrayNameIdx)

		return true
	}

	// Milestone 23: Parse REDIM statement.
	// Syntax: REDIM arrayName[newD0, newD1, ...]
	// Rules:
	//   - Array must already be declared (type is fixed at declaration time)
	//   - Number of dimensions must match original declaration
	//   - Values at logical addresses valid in both old and new layouts are retained
	//   - Values at addresses exceeding any new bound are truncated
	//   - New slots are zero/empty initialised
	// Emits: _redimOpCode, nameIdx, dimCount, [dimCount const indices on stack]
	func parseRedimStatement() -> Bool {
		if gParseError { return false }

		// Expect array name
		var type = getLexeme()
		guard type == ._readVarType, gCode >= 1, gCode <= gNumVarNames else {
			parseError(errMsg: "Expected array name after REDIM")
			return false
		}
		let arrName = gVarNames[gCode]
		let nameIdx = storeVarName(name: arrName)

		// Expect [
		type = getLexeme()
		guard type == ._leftBracketType else {
			parseError(errMsg: "Expected [ after REDIM array name")
			return false
		}

		// Parse comma-separated dimension expressions
		var dimCount = 0
		repeat {
			type = getLexeme()
			type = logicalExpression(type: type)
			if gParseError { return false }
			dimCount += 1

			if type == ._assignOpType && gSymTable[gCode] == "," {
				// more dims
			} else if type == ._rightBracketType {
				break
			} else {
				parseError(errMsg: "Expected , or ] in REDIM dimensions")
				return false
			}
		} while true

		// Emit: _redimOpCode, nameIdx, dimCount
		// The dim expressions are already on the eval stack (pushed by comparison() above).
		plantCode(code: evalOPcodes._redimOpCode.rawValue)
		plantCode(code: nameIdx)
		plantCode(code: dimCount)

		return true
	}
	
	// Milestone 28: Parse SAY statement.
	// Syntax: SAY string-expression
	//         SAY STOP
	// SAY speaks the string asynchronously via AVSpeechSynthesizer.
	// SAY STOP halts any speech in progress immediately.
	// Emits: _sayOpCode (string expr already on stack) or _sayStopOpCode (no args).
	func parseSayStatement() -> Bool {
		if gParseError { return false }

		// Peek at next token — if it's the identifier STOP, emit sayStop.
		// Otherwise pass the already-fetched token directly to logicalExpression().
		var type = getLexeme()

		if type == ._readVarType, gCode >= 1, gCode <= gNumVarNames,
		   gVarNames[gCode].uppercased() == "STOP" {
			// SAY STOP — halt speech immediately, no arguments
			plantCode(code: evalOPcodes._sayStopOpCode.rawValue)
			return true
		}

		// SAY string — parse expression starting from already-fetched token
		type = logicalExpression(type: type)
		if gParseError { return false }

		plantCode(code: evalOPcodes._sayOpCode.rawValue)
		return true
	}
	
	// Milestone 33 - PLAY() statement
	/// PLAY(id [, volume [, urlString]])
	/// Bytecode: _playOpCode, presentMask
	/// presentMask bits: 0=id, 1=volume, 2=urlString
	/// Stack push order: id first (deepest), urlString last (top).
	/// Absent args use sentinels: volume=-1.0 (use last), urlString=""
	func parsePlayStatement() -> Bool {
		if gParseError { return false }

		// Consume '('
		var type = getLexeme()
		type = getLeftParenthesis(type: type)
		if gParseError { return false }

		var presentMask = 0

		// Arg 0: id (required)
		type = logicalExpression(type: type)
		if gParseError { return false }
		presentMask |= (1 << 0)

		// Arg 1: volume (optional)
		if type == ._assignOpType && gSymTable[gCode] == "," {
			type = logicalExpression(type: getLexeme())
			if gParseError { return false }
			presentMask |= (1 << 1)

			// Arg 2: urlString (optional, only if volume present)
			if type == ._assignOpType && gSymTable[gCode] == "," {
				type = logicalExpression(type: getLexeme())
				if gParseError { return false }
				presentMask |= (1 << 2)
			}
		}

		type = getRightParenthesis(type: type)
		if gParseError { return false }

		plantCode(code: evalOPcodes._playOpCode.rawValue)
		plantCode(code: presentMask)
		return true
	}
	
	/// SOUND(midiNote, duration, volume)
	/// All three args required.
	/// Bytecode: _soundOpCode (args left on stack in push order)
	/// Stack push order: midiNote first, duration second, volume third (top).
	func parseSoundStatement() -> Bool {
		if gParseError { return false }

		var type = getLexeme()
		type = getLeftParenthesis(type: type)
		if gParseError { return false }

		// midiNote
		type = logicalExpression(type: type)
		if gParseError { return false }
		guard type == ._assignOpType && gSymTable[gCode] == "," else {
			parseError(errMsg: "Expected , after SOUND midiNote"); return false
		}

		// duration
		type = logicalExpression(type: getLexeme())
		if gParseError { return false }
		guard type == ._assignOpType && gSymTable[gCode] == "," else {
			parseError(errMsg: "Expected , after SOUND duration"); return false
		}

		// volume
		type = logicalExpression(type: getLexeme())
		if gParseError { return false }

		type = getRightParenthesis(type: type)
		if gParseError { return false }

		plantCode(code: evalOPcodes._soundOpCode.rawValue)
		return true
	}
	
	/// FILL(r, g, b, a) — set persistent background fill colour for PRINT.
	/// All four args required, each 0.0–1.0.
	/// FILL(0,0,0,0) restores transparent default.
	/// Bytecode: _fillOpCode (r, g, b, a left on stack in push order)
	func parseFillStatement() -> Bool {
		if gParseError { return false }

		var type = getLexeme()
		type = getLeftParenthesis(type: type)
		if gParseError { return false }

		// r
		type = logicalExpression(type: type)
		if gParseError { return false }
		guard type == ._assignOpType && gSymTable[gCode] == "," else {
			parseError(errMsg: "Expected , after FILL r"); return false
		}

		// g
		type = logicalExpression(type: getLexeme())
		if gParseError { return false }
		guard type == ._assignOpType && gSymTable[gCode] == "," else {
			parseError(errMsg: "Expected , after FILL g"); return false
		}

		// b
		type = logicalExpression(type: getLexeme())
		if gParseError { return false }
		guard type == ._assignOpType && gSymTable[gCode] == "," else {
			parseError(errMsg: "Expected , after FILL b"); return false
		}

		// a
		type = logicalExpression(type: getLexeme())
		if gParseError { return false }

		type = getRightParenthesis(type: type)
		if gParseError { return false }

		plantCode(code: evalOPcodes._fillOpCode.rawValue)
		return true
	}
	
	/// TEXT(r, g, b, a) — set persistent text foreground colour for PRINT.
	/// All four args required, each 0.0–1.0.
	/// TEXT(0, 0.91, 0.23, 1.0) restores default phosphor green.
	func parseTextColorStatement() -> Bool {
		if gParseError { return false }

		var type = getLexeme()
		type = getLeftParenthesis(type: type)
		if gParseError { return false }

		// r
		type = logicalExpression(type: type)
		if gParseError { return false }
		guard type == ._assignOpType && gSymTable[gCode] == "," else {
			parseError(errMsg: "Expected , after TEXT r"); return false
		}

		// g
		type = logicalExpression(type: getLexeme())
		if gParseError { return false }
		guard type == ._assignOpType && gSymTable[gCode] == "," else {
			parseError(errMsg: "Expected , after TEXT g"); return false
		}

		// b
		type = logicalExpression(type: getLexeme())
		if gParseError { return false }
		guard type == ._assignOpType && gSymTable[gCode] == "," else {
			parseError(errMsg: "Expected , after TEXT b"); return false
		}

		// a
		type = logicalExpression(type: getLexeme())
		if gParseError { return false }

		type = getRightParenthesis(type: type)
		if gParseError { return false }

		plantCode(code: evalOPcodes._textColorOpCode.rawValue)
		return true
	}
	
	
	func parseStatement() -> Bool {
		if gParseError { return false }
		
		clearParseError()
		gTextPtr = exprString
		gCharPos = 1
		gMyCodeArray[0] = 0
		
		var type = getLexeme()
		
		if type == nil {
			return true
		}

		// Milestone 4 / 10 / 39: bare closing brace } — could close a FUNC body or IF or WHILE body.
		// Check gWhileEnds first (Milestone 10): if this line is a WHILE-closing brace,
		// emit _whileEndOpCode so the executor can jump back to re-test the condition.
		// Otherwise it's a func-closing brace — emit nothing (existing behaviour).
		if type == ._rightBraceType {
			if let _ = gWhileEnds[gCurrentParseLineNum] {
				plantCode(code: evalOPcodes._whileEndOpCode.rawValue)
				return true
			}
			if let _ = gIfEnds[gCurrentParseLineNum] {
				plantCode(code: evalOPcodes._ifEndOpCode.rawValue)
				return true
			}
			return true   // func-closing } — no opcode
		}
		
		if type == ._keywordType {
			let keyword = gSymTable[gCode].uppercased()
			
			switch keyword {
			case "VAR":
				return parseVarDeclaration()
			case "PRINT":
				return parsePrintStatement()
			case "TAB":
				return parseTabStatement()
			case "CLS": 
				return parseCLSStatement()
			case "INPUT": 
				return parseInputStatement()
			case "END":
				return parseEndStatement()
			case "EXIT":
				return parseExitStatement()
			case "FOR":
				return parseForStatement()
			case "NEXT":
				return parseNextStatement()
			case "IF":
				return parseIfStatement()
				
			case "PLAY": 
				return parsePlayStatement()
			case "SOUND":
				return parseSoundStatement()
			case "FILL": 
				return parseFillStatement()
			case "TEXT": 
				return parseTextColorStatement()
				
			case "GOTO":
				parseError(errMsg: "GOTO is deprecated — use FUNC() WHILE or FOR-NEXT")
				return false
				
			case "GOSUB":
				parseError(errMsg: "GOSUB is deprecated — use FUNC()")
				return false
				
			case "LET":
				type = getLexeme()
				if type == ._readVarType {
					let varName = gVarNames[gCode]
					type = getLexeme()
					if type == ._assignOpType {
						return parseAssignment(varName: varName)
					}
				}
				parseError(errMsg: "Invalid LET statement")
				return false
			
			case "FUNC":
				// func definition header line — skip silently (pre-scanned)
				return parseFuncDefinition()
			case "RETURN":
				return parseReturnStatement()
			case "LOCATE":
				return parseLocateStatement()
			// pBasic: Graphics commands
			case "CLR": 
				plantCode(code: evalOPcodes._clrOpCode.rawValue)
				return true
			case "POINT":
				return parsePointStatement()
			case "LINE":
				return parseLineStatement()
			// Milestone 5: Timer statements
			case "TIMER":
				return parseTimerDeclStatement()
			case "TIMERON":
				// No arguments — emit opcode only
				plantCode(code: evalOPcodes._timerOnOpCode.rawValue)
				return true
			case "TIMERSTOP":
				// No arguments — emit opcode only
				plantCode(code: evalOPcodes._timerStopOpCode.rawValue)
				return true
			case "TIMEROFF":
				// No arguments — emit opcode only
				plantCode(code: evalOPcodes._timerOffOpCode.rawValue)
				return true
				// Milestone 10: WHILE loop
			case "WHILE":
				return parseWhileStatement()
				// Milestone 19: Double-buffering
				// Syntax:
				//   BUFFER    — toggle: swap draw and display buffers
				//   BUFFER:0  — draw to buffer 0, display buffer 1
				//   BUFFER:1  — draw to buffer 1, display buffer 0
				// Emits: _bufferOpCode, drawTo, displayBuf
				// drawTo = -1 and displayBuf = -1 means "toggle at runtime"
			case "BUFFER":
				var bufDrawTo  = -1   // -1 = toggle sentinel
				var bufDisplay = -1
				// Peek at the raw character — do NOT call getLexeme() here.
				// getLexeme() calls skipWhitespaceAndComments() which would consume
				// any trailing // comment on the same line, corrupting gCharPos
				// for the next line's parse (e.g. "BUFFER  // comment" would eat
				// the comment and leave gCharPos past end-of-line).
				// Instead, skip only spaces manually, then check for literal ':'.
				var bufPeekPos = gCharPos
				while bufPeekPos <= gTextPtr.count {
					let ch = getChar(theString: gTextPtr, charIndex: bufPeekPos - 1)
					if ch == " " { bufPeekPos += 1 } else { break }
				}
				// Check if the next non-space character is ':'
				if bufPeekPos <= gTextPtr.count &&
				   getChar(theString: gTextPtr, charIndex: bufPeekPos - 1) == ":" {
					// Advance gCharPos past the colon
					gCharPos = bufPeekPos + 1
					// Now read the digit — skip spaces then expect '0' or '1'
					skipWhitespaceAndComments()
					guard gCharPos <= gTextPtr.count else {
						parseError(errMsg: "Expected 0 or 1 after BUFFER:")
						return false
					}
					let bufDigit = getChar(theString: gTextPtr, charIndex: gCharPos - 1)
					if bufDigit == "0" {
						gCharPos  += 1
						bufDrawTo  = 0   // BUFFER:0 — draw to 0, display 1
						bufDisplay = 1
					} else if bufDigit == "1" {
						gCharPos  += 1
						bufDrawTo  = 1   // BUFFER:1 — draw to 1, display 0
						bufDisplay = 0
					} else {
						parseError(errMsg: "BUFFER suffix must be 0 or 1")
						return false
					}
				}
				// No colon found — toggle form, bufDrawTo and bufDisplay stay -1.
				// gCharPos is unchanged — the rest of the line (comment or nothing)
				// will be consumed naturally by the caller.
				plantCode(code: evalOPcodes._bufferOpCode.rawValue)
				plantCode(code: bufDrawTo)
				plantCode(code: bufDisplay)
				return true
				
			// Milestone 22: BEEP
			case "BEEP":
				plantCode(code: evalOPcodes._beepOpCode.rawValue)
				return true
			// Milestone 21: File I/O
			case "SAVE":
				return parseFileSaveStatement()
			// PEN command — set global pen width
			case "PEN":
				var penType = getLexeme()
				penType = logicalExpression(type: penType)
				if gParseError { return false }
				plantCode(code: evalOPcodes._penOpCode.rawValue)
				return true
			// Milestone 23: REDIM — resize existing array, preserving logical addresses
			// Syntax: REDIM arrayName[newD0, newD1, ...]
			case "REDIM":
				return parseRedimStatement()

			// Milestone 28: SAY — text-to-speech
			case "SAY":
				return parseSayStatement()
				
			// Milestone 30: SPRITE and GET
			case "SPRITE":
				return parseSpriteStatement()
			case "GET":
				return parseGetStatement()
			
			default:
				parseError(errMsg: "Unknown keyword: \(keyword)")
				return false
			}
		}
		
		if type == ._readVarType {
			let varName = gVarNames[gCode]
			type = getLexeme()

			// Milestone 4: function call used as a statement (result discarded)
			// e.g. "hanoi(3, "A", "C", "B")" on its own line
			if type == ._leftParenType && gFunctionDefs[varName.lowercased()] != nil {
				_ = parseFunctionCallExpression(funcName: varName.lowercased())
				return !gParseError
			}
			
			// Check for array assignment: arr[...] = ...  or  arr[] = LOAD(url)
			if type == ._leftBracketType {
				// Milestone 21: Peek for empty [] — signals whole-array LOAD syntax.
				// Save lexer state so we can restore it if this turns out to be a
				// normal single-element assignment arr[expr] = value.
				let savedCharPos21 = gCharPos
				let savedCode21    = gCode
				let peekType21     = getLexeme()
				if peekType21 == ._rightBracketType {
					// Empty brackets confirmed — must be followed by = LOAD(url)
					let eqType21 = getLexeme()
					guard eqType21 == ._assignOpType && gSymTable[gCode] == "=" else {
						parseError(errMsg: "Expected = after \(varName)[]")
						return false
					}
					return parseFileLoadStatement(arrayName: varName)
				} else {
					// Non-empty brackets — restore lexer state and fall through to
					// normal single-element array assignment arr[expr] = value.
					gCharPos = savedCharPos21
					gCode    = savedCode21
					return parseArrayAssignment(varName: varName)
				}
			}
			
			// Check for scalar assignment: var = ...
			if type == ._assignOpType && gSymTable[gCode] == "=" {
				return parseAssignment(varName: varName)
			} else {
				// Expression evaluation
				gCharPos = 1
				gMyCodeArray[0] = 0
				type = getLexeme()
				type = comparison(type: type)
				return !gParseError
			}
		}
		
		// If we get here, try to evaluate as expression
		gCharPos = 1
		gMyCodeArray[0] = 0
		type = getLexeme()
		type = comparison(type: type)
		
		return !gParseError
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
			skipWhitespaceAndComments()
			
			if !gParseError {
				if type != nil {
					parseError(errMsg: "Syntax Error")
				} else if gCharPos != gTextPtr.count + 1 {
					parseError(errMsg: "End of expression expected")
				}
			}
		}
	}
	
	//--| EVALUATOR |-----
	
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
				let leftVal = stack[level]
				let rightVal = stack[level + 1]
				
				// Check if both operands are strings (concatenation)
				let leftIsString = (leftVal == _stringConstMarker || leftVal == _stringVarMarker)
				let rightIsString = (rightVal == _stringConstMarker || rightVal == _stringVarMarker)
				
				if leftIsString && rightIsString {
					// String concatenation
					var leftStr = ""
					var rightStr = ""
					
					// Get left string
					if leftVal == _stringConstMarker {
						let strIdx = gStringConstRefs[level]
						leftStr = gStringConstants[strIdx]
					} else if leftVal == _stringVarMarker {
						let varNameIdx = gStringVarRefs[level]
						if varNameIdx == _tempArrayStringVarIndex {
							leftStr = gTempStringForArray
						} else {
							let varName = gVarNames[varNameIdx]
							if let varInfo = gVariables[varName] {
								if case .string(let str) = varInfo.value {
									leftStr = str
								}
							}
						}
					}
					
					// Get right string
					if rightVal == _stringConstMarker {
						let strIdx = gStringConstRefs[level + 1]
						rightStr = gStringConstants[strIdx]
					} else if rightVal == _stringVarMarker {
						let varNameIdx = gStringVarRefs[level + 1]
						if varNameIdx == _tempArrayStringVarIndex {
							rightStr = gTempStringForArray
						} else {
							let varName = gVarNames[varNameIdx]
							if let varInfo = gVariables[varName] {
								if case .string(let str) = varInfo.value {
									rightStr = str
								}
							}
						}
					}
					
					// Concatenate and store result
					let result = leftStr + rightStr
					let strIdx = storeStringConst(value: result)
					stack[level] = _stringConstMarker
					gStringConstRefs[level] = strIdx
					
				} else {
					// Numeric addition
					stack[level] = leftVal + rightVal
				}
			
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
				let constIdx = codeArray[index]
				if constIdx < 0 {
					stack[level] = _stringConstMarker
					gStringConstRefs[level] = -constIdx
				} else {
					stack[level] = litConsts[constIdx]
				}
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
			case ._ABSOpCode:
				stack[level] = abs(stack[level])
			case ._INTopCode:
				stack[level] = floor(stack[level])
			case ._piOpCode:
				level += 1
				stack[level] = Double.pi
			case ._dateOpCode:
				level += 1
				let formatter = DateFormatter()
				formatter.dateFormat = "MMM d yyyy"
				let dateString = formatter.string(from: Date())
				let strIdx = storeStringConst(value: dateString)
				stack[level] = _stringConstMarker
				gStringConstRefs[level] = strIdx
			case ._timeOpCode:
				level += 1
				let formatter = DateFormatter()
				formatter.dateFormat = "HH:mm:ss"
				let timeString = formatter.string(from: Date())
				let strIdx = storeStringConst(value: timeString)
				stack[level] = _stringConstMarker
				gStringConstRefs[level] = strIdx
			case ._RNDopCode:
				stack[level] = Double.random(in: 0.0..<1.0)
				
			case ._LENopCode:
				// LEN function - get length of string
				let value = stack[level]
				var length = 0
				
				if value == _stringConstMarker {
					let strIdx = gStringConstRefs[level]
					length = gStringConstants[strIdx].count
				} else if value == _stringVarMarker {
					let varNameIdx = gStringVarRefs[level]
					
					if varNameIdx == _tempArrayStringVarIndex {
						length = gTempStringForArray.count
					} else {
						let varName = gVarNames[varNameIdx]
						if let varInfo = gVariables[varName] {
							if case .string(let str) = varInfo.value {
								length = str.count
							}
						}
					}
				} else {
					// If it's a number, convert to string and get length
					let strValue = (value == floor(value) && abs(value) < Double(Int.max)) 
						? String(Int(value)) 
						: String(format: "%.6g", value)
					length = strValue.count
				}
				
				stack[level] = Double(length)
			
			case ._MIDopCode:
				// MID$ function - extract substring
				// Stack has: [string, index, range]
				let rangeVal = Int(stack[level])
				level -= 1
				let indexVal = Int(stack[level])
				level -= 1
				let stringVal = stack[level]
				
				var sourceString = ""
				
				// Get the source string
				if stringVal == _stringConstMarker {
					let strIdx = gStringConstRefs[level]
					sourceString = gStringConstants[strIdx]
				} else if stringVal == _stringVarMarker {
					let varNameIdx = gStringVarRefs[level]
					
					if varNameIdx == _tempArrayStringVarIndex {
						sourceString = gTempStringForArray
					} else {
						let varName = gVarNames[varNameIdx]
						if let varInfo = gVariables[varName] {
							if case .string(let str) = varInfo.value {
								sourceString = str
							}
						}
					}
				} else {
					// Convert number to string
					sourceString = (stringVal == floor(stringVal) && abs(stringVal) < Double(Int.max)) 
						? String(Int(stringVal)) 
						: String(format: "%.6g", stringVal)
				}
				
				// Extract substring - proper bounds checking
				var result = ""
				let sourceLen = sourceString.count
				
				if indexVal >= 0 && indexVal < sourceLen && rangeVal > 0 {
					let startIdx = sourceString.index(sourceString.startIndex, offsetBy: indexVal)
					let actualRange = min(rangeVal, sourceLen - indexVal)  // Don't exceed string length
					let endIdx = sourceString.index(startIdx, offsetBy: actualRange)
					result = String(sourceString[startIdx..<endIdx])
				}
				
				// Store result as string constant
				let strIdx = storeStringConst(value: result)
				stack[level] = _stringConstMarker
				gStringConstRefs[level] = strIdx
				
			case ._equalOpCode:
				level -= 1
				stack[level] = (stack[level] == stack[level + 1]) ? 1.0 : 0.0
			case ._greaterOpCode:
				level -= 1
				stack[level] = (stack[level] > stack[level + 1]) ? 1.0 : 0.0
			case ._lessOpCode:
				level -= 1
				stack[level] = (stack[level] < stack[level + 1]) ? 1.0 : 0.0
			case ._greaterEqOpCode:
				level -= 1
				stack[level] = (stack[level] >= stack[level + 1]) ? 1.0 : 0.0
			case ._lessEqOpCode:
				level -= 1
				stack[level] = (stack[level] <= stack[level + 1]) ? 1.0 : 0.0
			case ._notEqualOpCode:
				level -= 1
				stack[level] = (stack[level] != stack[level + 1]) ? 1.0 : 0.0

			// Milestone 26: VAL CHR$ ASC in evaluate() — REPL support
			case ._VALopCode:
				let eValRaw = stack[level]
				var eValSrc = ""
				if eValRaw == _stringConstMarker {
					eValSrc = gStringConstants[gStringConstRefs[level]]
				} else if eValRaw == _stringVarMarker {
					let vi = gStringVarRefs[level]
					if vi == _tempArrayStringVarIndex { eValSrc = gTempStringForArray }
					else { let vn = gVarNames[vi]; if let inf = gVariables[vn], case .string(let s) = inf.value { eValSrc = s } }
				} else {
					break   // already numeric — pass through
				}
				let eValScanner = Scanner(string: eValSrc)
				eValScanner.charactersToBeSkipped = .whitespaces
				stack[level] = eValScanner.scanDouble() ?? 0.0

			case ._CHRopCode:
				let eChrNum = Int(stack[level])
				var eChrResult = ""
				if let scalar = Unicode.Scalar(eChrNum) { eChrResult = String(scalar) }
				let eChrSI = storeStringConst(value: eChrResult)
				stack[level] = _stringConstMarker
				gStringConstRefs[level] = eChrSI

			case ._STRopCode:
				let eStrRaw = stack[level]
				if eStrRaw != _stringConstMarker && eStrRaw != _stringVarMarker {
					let eStrResult = eStrRaw == floor(eStrRaw) && abs(eStrRaw) < Double(Int.max)
						? String(Int(eStrRaw)) : String(format: "%.6g", eStrRaw)
					let eStrSI = storeStringConst(value: eStrResult)
					stack[level] = _stringConstMarker
					gStringConstRefs[level] = eStrSI
				}

			case ._ASCopCode:
				let eAscRaw = stack[level]
				var eAscSrc = ""
				if eAscRaw == _stringConstMarker {
					eAscSrc = gStringConstants[gStringConstRefs[level]]
				} else if eAscRaw == _stringVarMarker {
					let vi = gStringVarRefs[level]
					if vi == _tempArrayStringVarIndex { eAscSrc = gTempStringForArray }
					else { let vn = gVarNames[vi]; if let inf = gVariables[vn], case .string(let s) = inf.value { eAscSrc = s } }
				}
				stack[level] = Double(eAscSrc.unicodeScalars.first.map { Int($0.value) } ?? 0)

			// Milestone 24: Logical / bitwise operators in evaluate() — REPL support
			case ._logicalAndOpCode:
				level -= 1
				let elaL = stack[level], elaR = stack[level+1]
				if elaL == floor(elaL) && elaR == floor(elaR) &&
				   abs(elaL) < Double(Int.max) && abs(elaR) < Double(Int.max) {
					stack[level] = Double(Int(elaL) & Int(elaR))
				} else {
					stack[level] = (elaL != 0.0 && elaR != 0.0) ? 1.0 : 0.0
				}

			case ._logicalOrOpCode:
				level -= 1
				let eloL = stack[level], eloR = stack[level+1]
				if eloL == floor(eloL) && eloR == floor(eloR) &&
				   abs(eloL) < Double(Int.max) && abs(eloR) < Double(Int.max) {
					stack[level] = Double(Int(eloL) | Int(eloR))
				} else {
					stack[level] = (eloL != 0.0 || eloR != 0.0) ? 1.0 : 0.0
				}

			case ._logicalXorOpCode:
				level -= 1
				let elxL = stack[level], elxR = stack[level+1]
				if elxL == floor(elxL) && elxR == floor(elxR) &&
				   abs(elxL) < Double(Int.max) && abs(elxR) < Double(Int.max) {
					stack[level] = Double(Int(elxL) ^ Int(elxR))
				} else {
					let elxLb = elxL != 0.0, elxRb = elxR != 0.0
					stack[level] = (elxLb != elxRb) ? 1.0 : 0.0
				}

			case ._logicalNotOpCode:
				let elnV = stack[level]
				if elnV == floor(elnV) && abs(elnV) < Double(Int.max) {
					stack[level] = Double(~Int(elnV))
				} else {
					stack[level] = (elnV == 0.0) ? 1.0 : 0.0
				}
				
				// Milestone 27: SAMPLE in evaluate() — REPL support (returns 0.0 in evaluate context)
				case ._sampleOpCode:
					index += 1
					let evSampleArgCount = codeArray[index]
					// Pop all arguments, push result (0.0 — no graphics in evaluate() context)
					// 4-arg: pop sampleSize, channel, y, x (4 pops) then push result = net -3
					// 3-arg legacy: pop channel, y, x (3 pops) then push result = net -2
					level -= (evSampleArgCount == 4) ? 3 : 2
					stack[level] = 0.0
					
				// Milestone 28: SAY in evaluate() — CLI/REPL: print with [SAY] prefix
				case ._sayOpCode:
					let evSayRaw = stack[level]
					var evSayText = ""
					if evSayRaw == _stringConstMarker {
						evSayText = gStringConstants[gStringConstRefs[level]]
					} else if evSayRaw == _stringVarMarker {
						let vi = gStringVarRefs[level]
						if vi == _tempArrayStringVarIndex { evSayText = gTempStringForArray }
						else { let vn = gVarNames[vi]; if let inf = gVariables[vn], case .string(let s) = inf.value { evSayText = s } }
					} else {
						evSayText = evSayRaw == floor(evSayRaw) && abs(evSayRaw) < Double(Int.max)
							? String(Int(evSayRaw)) : String(format: "%.6g", evSayRaw)
					}
					level -= 1
					print("[SAY] \(evSayText)")

				// Milestone 28: SAY STOP in evaluate() — no-op (no speech running in REPL)
				case ._sayStopOpCode:
					break   // no speech to stop in evaluate() context

				// Milestone 22: VERSION$ — push version string onto eval stack
				case ._versionOpCode:
					level += 1
					let verIdx = storeStringConst(value: pScriptVersion)
					stack[level] = _stringConstMarker
					gStringConstRefs[level] = verIdx

				// Milestone 22: BEEP — system bell
				case ._beepOpCode:
					print("\u{0007}", terminator: "")
					fflush(stdout)

				// Milestone 23: Multi-dim array load — supports REPL queries like: print myArray[1,2]
				case ._arrayLoadMDOpCode:
					index += 1; let evMDLNameIdx  = codeArray[index]
					index += 1; let evMDLDimCount = codeArray[index]
					let evMDLName = gVarNames[evMDLNameIdx]
					// Pop indices (iN-1 on top, i0 deepest)
					var evMDLIndices = [Int](repeating: 0, count: evMDLDimCount)
					for di in stride(from: evMDLDimCount - 1, through: 0, by: -1) {
						evMDLIndices[di] = Int(stack[level]); level -= 1
					}
					let evMDLDims = gArrayDimensions[evMDLName] ?? [1]
					var evMDLStrides = [Int](repeating: 1, count: evMDLDimCount)
					for si in stride(from: evMDLDimCount - 2, through: 0, by: -1) {
						evMDLStrides[si] = evMDLStrides[si + 1] * evMDLDims[si + 1]
					}
					var evMDLFlat = 0
					for di in 0..<evMDLDimCount { evMDLFlat += evMDLIndices[di] * evMDLStrides[di] }
					if let evMDLVT = gVariableTypes[evMDLName],
					   let evMDLVal = getArrayElement(name: evMDLName, index: evMDLFlat, type: evMDLVT) {
						level += 1
						if evMDLVT.baseType() == .stringType {
							if case .string(let s) = evMDLVal { gTempStringForArray = s }
							else { gTempStringForArray = "" }
							stack[level] = _stringVarMarker
							gStringVarRefs[level] = _tempArrayStringVarIndex
						} else {
							stack[level] = evMDLVal.toDouble()
						}
					} else {
						evalErr = true
						print("Error: MD array load failed for \(evMDLName)")
					}

				// Milestone 23: Multi-dim array store — supports REPL assignment like: myArray[1,2] = 7
				case ._arrayStoreMDOpCode:
					index += 1; let evMDSNameIdx  = codeArray[index]
					index += 1; let evMDSDimCount = codeArray[index]
					let evMDSName = gVarNames[evMDSNameIdx]
					// Pop value first, then indices
					let evMDSVal = stack[level]
					let evMDSSC  = gStringConstRefs[level]
					_ = gStringVarRefs[level]   // string var path uses gTempStringForArray directly
					level -= 1
					var evMDSIndices = [Int](repeating: 0, count: evMDSDimCount)
					for di in stride(from: evMDSDimCount - 1, through: 0, by: -1) {
						evMDSIndices[di] = Int(stack[level]); level -= 1
					}
					let evMDSDims = gArrayDimensions[evMDSName] ?? [1]
					var evMDSStrides = [Int](repeating: 1, count: evMDSDimCount)
					for si in stride(from: evMDSDimCount - 2, through: 0, by: -1) {
						evMDSStrides[si] = evMDSStrides[si + 1] * evMDSDims[si + 1]
					}
					var evMDSFlat = 0
					for di in 0..<evMDSDimCount { evMDSFlat += evMDSIndices[di] * evMDSStrides[di] }
					if let evMDSVT = gVariableTypes[evMDSName] {
						let evMDSValue: Value
						switch evMDSVT.baseType() {
						case .intType:   evMDSValue = .int(Int(evMDSVal))
						case .floatType: evMDSValue = .float(evMDSVal)
						case .stringType:
							if evMDSVal == _stringConstMarker      { evMDSValue = .string(gStringConstants[evMDSSC]) }
							else if evMDSVal == _stringVarMarker   { evMDSValue = .string(gTempStringForArray) }
							else { evMDSValue = .string(evMDSVal == floor(evMDSVal) && abs(evMDSVal) < Double(Int.max)
								? String(Int(evMDSVal)) : String(format: "%.6g", evMDSVal)) }
						case .boolType:  evMDSValue = .bool(evMDSVal != 0.0)
						default: evalErr = true; evMDSValue = .int(0)
						}
						if !evalErr {
							_ = setArrayElement(name: evMDSName, index: evMDSFlat, value: evMDSValue, type: evMDSVT)
						}
					} else {
						evalErr = true
						print("Error: MD array store failed for \(evMDSName)")
					}

				case ._loadVarOpCode:
				index += 1
				let varNameIdx = codeArray[index]
				let varName = gVarNames[varNameIdx]
				level += 1
				if let varInfo = gVariables[varName] {
					switch varInfo.type {
					case .stringType:
						stack[level] = _stringVarMarker
						gStringVarRefs[level] = varNameIdx
					case .intType, .floatType, .boolType:
						stack[level] = varInfo.value.toDouble()
					case .intArrayType, .floatArrayType, .stringArrayType, .boolArrayType:
						print("Error: Cannot use array variable without index")
						evalErr = true
					}
				} else {
					stack[level] = 0.0
				}
			case ._storeVarOpCode:
				index += 1
				let varNameIdx = codeArray[index]
				let varName = gVarNames[varNameIdx]
				guard let declaredType = gVariableTypes[varName] else {
					evalErr = true
					print("Error: Variable \(varName) not declared")
					break
				}
				let stackValue = stack[level]
				var value: Value
				switch declaredType {
				case .stringType:
					if stackValue == _stringConstMarker {
						let strIdx = gStringConstRefs[level]
						value = .string(gStringConstants[strIdx])
					} else if stackValue == _stringVarMarker {
						let srcVarIdx = gStringVarRefs[level]
						let srcVarName = gVarNames[srcVarIdx]
						if let srcVarInfo = gVariables[srcVarName] {
							value = srcVarInfo.value
						} else {
							value = .string("")
						}
					} else {
						if stackValue == floor(stackValue) && abs(stackValue) < Double(Int.max) {
							value = .string(String(Int(stackValue)))
						} else {
							value = .string(String(format: "%.6g", stackValue))
						}
					}
				case .intType:
					value = .int(Int(stackValue))
				case .floatType:
					value = .float(stackValue)
				case .boolType:
					value = .bool(stackValue != 0.0)
				case .intArrayType, .floatArrayType, .stringArrayType, .boolArrayType:
					print("Error: Cannot assign to array variable without index")
					evalErr = true
					value = .int(0)
				}
				gVariables[varName] = VariableInfo(type: declaredType, value: value)
				level -= 1
			case ._printOpCode:
				index += 1
				let printMode = codeArray[index]
				if printMode == 0 {
					print()
				} else {
					let value = stack[level]
					if value == _stringConstMarker {
						let strIdx = gStringConstRefs[level]
						if printMode == 2 {
							print(gStringConstants[strIdx], terminator: "")
						} else {
							print(gStringConstants[strIdx])
						}
					} else if value == _stringVarMarker {
						let varNameIdx = gStringVarRefs[level]
						
						if varNameIdx == _tempArrayStringVarIndex {
							if printMode == 2 {
								print(gTempStringForArray, terminator: "")
							} else {
								print(gTempStringForArray)
							}
						} else {
							let varName = gVarNames[varNameIdx]
							if let varInfo = gVariables[varName] {
								if printMode == 2 {
									print(varInfo.value.toString(), terminator: "")
								} else {
									print(varInfo.value.toString())
								}
							} else {
								if printMode == 2 {
									print("", terminator: "")
								} else {
									print("")
								}
							}
						}
					} else if value == floor(value) && abs(value) < Double(Int.max) {
						if printMode == 2 {
							print(Int(value), terminator: "")
						} else {
							print(Int(value))
						}
					} else {
						if printMode == 2 {
							print(String(format: "%.6g", value), terminator: "")
						} else {
							print(String(format: "%.6g", value))
						}
					}
					level -= 1
				}
			case ._tabOpCode:
				let numSpaces = Int(stack[level])
				level -= 1
				for _ in 0..<numSpaces {
					print(" ", terminator: "")
				}
			case ._clsOpCode: 
				// Clear screen using ANSI escape codes
				print("\u{001B}[2J\u{001B}[H", terminator: "")
				
				
			case ._inputOpCode:
				// INPUT command - read from user
				index += 1
				let varNameIdx = codeArray[index]
				let varName = gVarNames[varNameIdx]
				index += 1
				let hasPrompt = codeArray[index]
				
				// Print prompt if provided (only if stdin is NOT piped)
				if hasPrompt == 1 {
					// Prompt string is on stack
					let promptValue = stack[level]
					if !gStdinIsPiped {
						// Only show prompt if stdin is interactive (not piped)
						if promptValue == _stringConstMarker {
							let strIdx = gStringConstRefs[level]
							print(gStringConstants[strIdx], terminator: "")
						} else if promptValue == _stringVarMarker {
							let srcVarIdx = gStringVarRefs[level]
							let srcVarName = gVarNames[srcVarIdx]
							if let srcVarInfo = gVariables[srcVarName] {
								print(srcVarInfo.value.toString(), terminator: "")
							}
						}
					}
					level -= 1
				} else {
					// Default prompt (only if stdin is NOT piped)
					if !gStdinIsPiped {
						print("? ", terminator: "")
					}
				}
				
				// Flush output to ensure prompt appears before input
				fflush(stdout)
				
				// Read input
				guard let input = readLine() else {
					evalErr = true
					break
				}
				
				// Determine variable type and store
				if let varType = gVariableTypes[varName] {
					let value: Value
					switch varType {
					case .stringType:
						value = .string(input)
					case .intType:
						value = .int(Int(input) ?? 0)
					case .floatType:
						value = .float(Double(input) ?? 0.0)
					case .boolType:
						value = .bool(!input.isEmpty && input != "0")
					default:
						evalErr = true
						print("Error: Cannot INPUT to array variable")
						value = .string("")
					}
					gVariables[varName] = VariableInfo(type: varType, value: value)
				} else {
					// Auto-declare as String if not declared
					let value = Value.string(input)
					gVariableTypes[varName] = .stringType
					gVariables[varName] = VariableInfo(type: .stringType, value: value)
				}
				
				
			case ._arrayLoadOpCode:
				index += 1
				let varNameIdx = codeArray[index]
				let varName = gVarNames[varNameIdx]
				let arrayIndex = Int(stack[level])
				level -= 1
				
				guard let varType = gVariableTypes[varName] else {
					print("Error: Array \(varName) not declared")
					evalErr = true
					break
				}
				
				if let value = getArrayElement(name: varName, index: arrayIndex, type: varType) {
					level += 1
					
					if varType.baseType() == .stringType {
						if case .string(let str) = value {
							gTempStringForArray = str
							stack[level] = _stringVarMarker
							gStringVarRefs[level] = _tempArrayStringVarIndex
						} else {
							gTempStringForArray = ""
							stack[level] = _stringVarMarker
							gStringVarRefs[level] = _tempArrayStringVarIndex
						}
					} else {
						stack[level] = value.toDouble()
					}
				} else {
					print("Error: Array index \(arrayIndex) out of bounds for \(varName)")
					evalErr = true
				}
				
			case ._arrayStoreOpCode:
				index += 1
				let varNameIdx = codeArray[index]
				let varName = gVarNames[varNameIdx]
				let value = stack[level]
				level -= 1
				let arrayIndex = Int(stack[level])
				level -= 1
				
				guard let varType = gVariableTypes[varName] else {
					print("Error: Array \(varName) not declared")
					evalErr = true
					break
				}
				
				let valueToStore: Value
				switch varType.baseType() {
				case .intType:
					valueToStore = .int(Int(value))
				case .floatType:
					valueToStore = .float(value)
				case .stringType:
					if value == _stringConstMarker {
						let strIdx = gStringConstRefs[level + 2]
						valueToStore = .string(gStringConstants[strIdx])
					} else if value == _stringVarMarker {
						let srcVarIdx = gStringVarRefs[level + 2]
						let srcVarName = gVarNames[srcVarIdx]
						if let srcVarInfo = gVariables[srcVarName] {
							valueToStore = srcVarInfo.value
						} else {
							valueToStore = .string("")
						}
					} else {
						valueToStore = .string(String(format: "%.6g", value))
					}
				case .boolType:
					valueToStore = .bool(value != 0.0)
				default:
					print("Error: Invalid array base type")
					evalErr = true
					valueToStore = .int(0)
				}
				
				if !setArrayElement(name: varName, index: arrayIndex, value: valueToStore, type: varType) {
					print("Error: Array index \(arrayIndex) out of bounds or type mismatch for \(varName)")
					evalErr = true
				}
				
			case ._forBeginOpCode, ._forNextOpCode, ._ifThenOpCode, ._jumpOpCode, ._jumpIfFalseOpCode:
				print("Control flow statements must be in a program (use line numbers)")
				evalErr = true
			default:
				evalErr = true
				print("Programming error: undefined opcode \(opcode)")
			}
			
			index += 1
		}
		
		return (stack[1], evalErr)
	}
	
	//--| PROGRAM EXECUTOR |-----

	// Milestone 4: Pre-scan gProgramLines to find all func definitions.
	// Populates gFunctionDefs. Must be called before parsing or executing.
	func preScanFunctions() {
		gFunctionDefs.removeAll()

		var i = 0
		while i < gProgramLines.count {
			let line = gProgramLines[i].trimmingCharacters(in: .whitespaces)
			let upper = line.uppercased()

			// Look for: func name(...) {
			if upper.hasPrefix("FUNC ") || upper.hasPrefix("FUNC\t") {
				// Extract everything after FUNC keyword
				var rest = String(line.dropFirst(4)).trimmingCharacters(in: .whitespaces)

				// Find the function name (up to '(')
				guard let parenOpen = rest.firstIndex(of: "(") else { i += 1; continue }
				let funcName = String(rest[rest.startIndex..<parenOpen]).trimmingCharacters(in: .whitespaces).lowercased()

				guard !funcName.isEmpty else { i += 1; continue }

				// Find the closing ')'
				guard let parenClose = rest.firstIndex(of: ")") else { i += 1; continue }

				// Extract parameter names (comma-separated, may be empty)
				let paramStr = String(rest[rest.index(after: parenOpen)..<parenClose])
				let params: [String]
				if paramStr.trimmingCharacters(in: .whitespaces).isEmpty {
					params = []
				} else {
					params = paramStr.components(separatedBy: ",").map {
						$0.trimmingCharacters(in: .whitespaces)
					}.filter { !$0.isEmpty }
				}

				// The opening { may be on the same line (after ')') or on the next line
				rest = String(rest[rest.index(after: parenClose)...]).trimmingCharacters(in: .whitespaces)

				var bodyStart: Int
				if rest.hasPrefix("{") {
					// Opening brace on same line as func header
					bodyStart = i + 1
				} else {
					// Opening brace on next line
					i += 1
					if i >= gProgramLines.count { break }
					bodyStart = i + 1
				}

				// Find matching closing }
				// Track brace depth so nested {} are handled (e.g., future if/while blocks)
				var depth = 1
				var bodyEnd = bodyStart
				while bodyEnd < gProgramLines.count && depth > 0 {
					let bline = gProgramLines[bodyEnd].trimmingCharacters(in: .whitespaces)
					for ch in bline {
						if ch == "{" { depth += 1 }
						else if ch == "}" { depth -= 1; if depth == 0 { break } }
					}
					if depth > 0 { bodyEnd += 1 }
				}

				let def = FunctionDef(name: funcName, params: params, bodyStartLine: bodyStart, bodyEndLine: bodyEnd)
				gFunctionDefs[funcName] = def
			}

			i += 1
		}
	}

	// Milestone 39: Unified brace block pre-scanner.
	// Replaces preScanWhileLoops(). Populates all four tables in one pass:
	//   gWhilePairs / gWhileEnds  — WHILE line ↔ closing } line
	//   gIfPairs    / gIfEnds     — IF line    ↔ closing } line
	// Must be called after preScanFunctions() so func-body braces are
	// already known and excluded from WHILE/IF pairing.
	//
	// Algorithm: single top-to-bottom walk with a unified brace stack.
	// Each entry records both the owner kind (WHILE or IF) and the line index.
	// When a } is found, pop the stack and route to the correct table.
	enum BraceOwner { case whileBlock, ifBlock }

	func preScanBraceBlocks() {
		gWhilePairs.removeAll()
		gWhileEnds.removeAll()
		gIfPairs.removeAll()
		gIfEnds.removeAll()

		// Build skip-sets for func header and closing lines —
		// same logic as the original preScanWhileLoops().
		var funcHeaderLines  = Set<Int>()
		var funcClosingLines = Set<Int>()
		for (_, def) in gFunctionDefs {
			if def.bodyStartLine > 0 {
				funcHeaderLines.insert(def.bodyStartLine - 1)
			}
			funcClosingLines.insert(def.bodyEndLine)
		}

		// Unified stack — each entry is (owner, line-index-of-opening-keyword)
		var braceStack: [(owner: BraceOwner, line: Int)] = []

		for (i, line) in gProgramLines.enumerated() {
			if funcHeaderLines.contains(i)  { continue }
			if funcClosingLines.contains(i) { continue }

			let trimmed = line.trimmingCharacters(in: .whitespaces)
			let upper   = trimmed.uppercased()

			// WHILE header — push whileBlock
			if upper.hasPrefix("WHILE ") || upper.hasPrefix("WHILE(") {
				braceStack.append((owner: .whileBlock, line: i))

			// IF multi-line header — IF ( cond ) { on same line
			// Detected by: starts with IF, ends with {, does NOT contain THEN
			} else if upper.hasPrefix("IF ") || upper.hasPrefix("IF(") {
				if upper.hasSuffix("{") && !upper.contains("THEN") {
					braceStack.append((owner: .ifBlock, line: i))
				}
				// Single-line IF THEN — no brace, ignore here

			// Standalone { on its own line — opening brace of a block
			// whose keyword was on the previous line. No push needed —
			// the keyword line is already on the stack.
			} else if upper == "{" || (upper.hasPrefix("{") && !upper.hasPrefix("{{")) {
				_ = i   // explicit no-op

			// Closing } — pop stack and record in the correct table
			} else if trimmed.hasPrefix("}") && !braceStack.isEmpty {
				let top = braceStack.removeLast()
				switch top.owner {
				case .whileBlock:
					gWhilePairs[top.line] = i
					gWhileEnds[i]         = top.line
				case .ifBlock:
					gIfPairs[top.line] = i
					gIfEnds[i]         = top.line
				}
			}
		}
		// Unmatched entries → syntax error; executor will report at runtime.
	}
	
	func executeProgramWithControlFlow() {
		clearParseError()
		initSymbolTable()
		initNumSearchStrings()
		gNumConsts = 0
		gNumStringConsts = 0
		gNumVarNames = 0
		gForLoopStack.removeAll()
		gCallStack.removeAll()
		gFunctionLocalTypes.removeAll()
		gCurrentParseFuncName = nil
		gCurrentParseLineNum = 0					// Milestone 10
		gWhileLoopStack.removeAll()					// Milestone 10
		gIfPairs.removeAll()						// Milestone 39
		gIfEnds.removeAll()							// Milestone 39
		
		// Milestone 4: Pre-scan for function definitions BEFORE parsing any lines
		preScanFunctions()

		// Milestone 10 and 39: Pre-scan for IF / WHILE / } pairs (must follow preScanFunctions
		// so func-owned braces are already excluded from WHILE pairing)
		preScanBraceBlocks()
		
		// Set of all line indices that belong to func headers/bodies —
		// skipped during top-level execution, executed only via _funcCallOpCode.
		var funcBodyLines = Set<Int>()
		for (_, def) in gFunctionDefs {
			funcBodyLines.insert(def.bodyStartLine - 1)   // header line
			if def.bodyStartLine <= def.bodyEndLine {
				for li in def.bodyStartLine...def.bodyEndLine { funcBodyLines.insert(li) }
			}
		}
		
		// Build a line-index -> function-name map for body lines (not header line)
		// so the parse loop can set gCurrentParseFuncName correctly.
		var lineToFuncName: [Int: String] = [:]
		for (name, def) in gFunctionDefs {
			if def.bodyStartLine <= def.bodyEndLine {
				for li in def.bodyStartLine...def.bodyEndLine {
					lineToFuncName[li] = name
				}
			}
			
			/* DEBUG: print function bounds
			//print("DEBUG func '\(name)': bodyStart=\(def.bodyStartLine) bodyEnd=\(def.bodyEndLine)")
			if def.bodyStartLine <= def.bodyEndLine {
				for li in def.bodyStartLine...def.bodyEndLine {
					print("  line \(li): \(gProgramLines[li])")
				}
			} */
		}
		
		// Parse all lines into bytecode arrays.
		// Milestone 10: gCurrentParseLineNum is set before each line so that
		// parseStatement() can distinguish a WHILE-closing } from a func-closing }.
		var lineCodeArrays: [[Int]] = []
		for (lineNum, line) in gProgramLines.enumerated() {
			if line.trimmingCharacters(in: .whitespaces).isEmpty {
				lineCodeArrays.append([0]); continue
			}
			// Tell parseVarDeclaration which function (if any) owns this line
			gCurrentParseFuncName = lineToFuncName[lineNum]
			// Milestone 10: tell parseStatement() the current line index
			gCurrentParseLineNum = lineNum
			exprString = line
			gMyCodeArray = [Int](repeating: 0, count: _maxCodeLength + 1)
			if !parseStatement() {
				gCurrentParseFuncName = nil
				gCurrentParseLineNum = 0
				let parseErrMsg = "Parser: Error on line \(lineNum + 1): \(line)"
				if let d = delegate {
					d.pscriptPrint(parseErrMsg, newline: true)
				} else {
					print(parseErrMsg)
				}
				delegate?.pscriptExecutionDidEnd()
				return
			}
			gCurrentParseFuncName = nil
			let cl = gMyCodeArray[0]
			var lca = [Int](repeating: 0, count: cl + 1)
			for i in 0...cl { lca[i] = gMyCodeArray[i] }
			lineCodeArrays.append(lca)
		}
		gCurrentParseLineNum = 0   // reset after parse phase
		
		
		// ---- Unified execution state ----
		// These vars are promoted outside the per-line loop so that _funcCallOpCode /
		// _returnOpCode can save and restore them as part of the call stack frame.
		var pc = 0
		var execCodeArray = [Int]()
		var execIndex = 1
		var execLevel = 0
		var execStack = [Double](repeating: 0.0, count: _maxEvalStackSize)
		var execStringConsts = [Int](repeating: 0, count: _maxEvalStackSize)
		var execStringVars   = [Int](repeating: 0, count: _maxEvalStackSize)
		var insideFunction = false

		// Helper: copy global string ref arrays into exec arrays (and back)
		func saveStringRefs() {
			for i in 0..<_maxEvalStackSize {
				execStringConsts[i] = gStringConstRefs[i]
				execStringVars[i]   = gStringVarRefs[i]
			}
		}
		func restoreStringRefs() {
			for i in 0..<_maxEvalStackSize {
				gStringConstRefs[i] = execStringConsts[i]
				gStringVarRefs[i]   = execStringVars[i]
			}
		}

		// ---- Local scope helpers ----
		func resolveVarRead(varName: String) -> (value: Value?, isString: Bool, varNameIdx: Int) {
			if !gCallStack.isEmpty {
				let frame = gCallStack[gCallStack.count - 1]
				if let varInfo = frame.localVariables[varName] {
					return (varInfo.value, varInfo.type == .stringType, storeVarName(name: varName))
				}
			}
			gVariablesLock.lock()
			let val  = gVariables[varName]?.value
			let isSt = gVariables[varName]?.type == .stringType
			gVariablesLock.unlock()
			return (val, isSt, storeVarName(name: varName))
		}

		func resolveVarType(varName: String) -> VarType? {
			if !gCallStack.isEmpty {
				let frame = gCallStack[gCallStack.count - 1]
				if let t = frame.localTypes[varName] { return t }
			}
			gVariablesLock.lock()
			let t = gVariableTypes[varName]
			gVariablesLock.unlock()
			return t
		}

		func storeVar(varName: String, value: Value) {
			if !gCallStack.isEmpty {
				let frameIdx = gCallStack.count - 1
				if gCallStack[frameIdx].localTypes[varName] != nil {
					gCallStack[frameIdx].localVariables[varName] = VariableInfo(
						type: gCallStack[frameIdx].localTypes[varName]!, value: value)
					return
				}
			}
			gVariablesLock.lock()
			if let t = gVariableTypes[varName] {
				gVariables[varName] = VariableInfo(type: t, value: value)
			}
			gVariablesLock.unlock()
		}

		// ---- Advance pc to the next executable line ----
		// Returns false when program ends.
		func loadNextLine() -> Bool {
			while pc < gProgramLines.count {
				if !insideFunction && funcBodyLines.contains(pc) { pc += 1; continue }
				if lineCodeArrays[pc][0] == 0 { pc += 1; continue }
				execCodeArray = lineCodeArrays[pc]
				execIndex = 1
				execLevel = 0
				execStack = [Double](repeating: 0.0, count: _maxEvalStackSize)
				execStringConsts = [Int](repeating: 0, count: _maxEvalStackSize)
				execStringVars   = [Int](repeating: 0, count: _maxEvalStackSize)
				// sync global string refs to exec arrays
				for i in 0..<_maxEvalStackSize {
					execStringConsts[i] = gStringConstRefs[i]
					execStringVars[i]   = gStringVarRefs[i]
				}
				return true
			}
			return false
		}
		
		// ---- Main execution loop ----
		guard loadNextLine() else { return }

		lineLoop: while true {
			// Keep executing opcodes on the current line.
			// codeLength is re-read inside the loop condition so that when _returnOpCode
			// switches execCodeArray to the calling line mid-execution, the loop
			// correctly continues with the new line's length rather than the old one.
			var evalErr = false

			innerLoop: while execIndex <= execCodeArray[0] && !evalErr {
				
				// CTRL+C / BREAK check — one Bool read per opcode, negligible cost.
				// Tight FOR loops are interruptible because this fires every opcode cycle.
				if gBreakRequested {
					gBreakRequested = false
					timerOff()
					if let d = delegate {
						d.pscriptPrint("", newline: true)
						d.pscriptPrint("Break", newline: true)
					} else {
						print("\nBreak")
					}
					return
				}
				
				// Keep global string ref arrays in sync with exec arrays
				for i in 0..<_maxEvalStackSize {
					gStringConstRefs[i] = execStringConsts[i]
					gStringVarRefs[i]   = execStringVars[i]
				}

				let opcode = execCodeArray[execIndex]

				switch evalOPcodes(rawValue: opcode) {

				case ._plusOpCode:
					execLevel -= 1
					let lv = execStack[execLevel], rv = execStack[execLevel + 1]
					let lIsStr = (lv == _stringConstMarker || lv == _stringVarMarker)
					let rIsStr = (rv == _stringConstMarker || rv == _stringVarMarker)
					if lIsStr && rIsStr {
						var ls = "", rs = ""
						if lv == _stringConstMarker { ls = gStringConstants[execStringConsts[execLevel]] }
						else if lv == _stringVarMarker {
							let vi = execStringVars[execLevel]
							if vi == _tempArrayStringVarIndex { ls = gTempStringForArray }
							else { let vn = gVarNames[vi]; let (v,_,_) = resolveVarRead(varName:vn); if let sv=v, case .string(let s)=sv{ls=s} }
						}
						if rv == _stringConstMarker { rs = gStringConstants[execStringConsts[execLevel+1]] }
						else if rv == _stringVarMarker {
							let vi = execStringVars[execLevel+1]
							if vi == _tempArrayStringVarIndex { rs = gTempStringForArray }
							else { let vn = gVarNames[vi]; let (v,_,_) = resolveVarRead(varName:vn); if let sv=v, case .string(let s)=sv{rs=s} }
						}
						let cat = ls + rs; let si = storeStringConst(value: cat)
						execStack[execLevel] = _stringConstMarker; execStringConsts[execLevel] = si
					} else { execStack[execLevel] = lv + rv }

				case ._minusOpCode:
					execLevel -= 1; execStack[execLevel] = execStack[execLevel] - execStack[execLevel+1]
				case ._timesOpCode:
					execLevel -= 1; execStack[execLevel] = execStack[execLevel] * execStack[execLevel+1]
				case ._divideOpCode:
					execLevel -= 1
					if execStack[execLevel+1] == 0 { evalErr = true }
					else { execStack[execLevel] = execStack[execLevel] / execStack[execLevel+1] }
				case ._modOpCode:                   // Milestone 37: % MOD operator
					execLevel -= 1
					if execStack[execLevel+1] == 0 {
						let modErrMsg = "Parser: MOD by zero"
						if let d = delegate { d.pscriptPrint(modErrMsg, newline: true) }
						else { print(modErrMsg) }
						evalErr = true
					} else {
						execStack[execLevel] = execStack[execLevel].truncatingRemainder(dividingBy: execStack[execLevel+1])
					}
				case ._powerOpCode:
					execLevel -= 1
					execStack[execLevel] = pow(execStack[execLevel], execStack[execLevel+1])

				// Milestone 24: Logical / bitwise operators
				// Dual-mode: both operands whole numbers → bitwise integer operation
				//            otherwise → logical (non-zero = true, result 1.0 or 0.0)
				case ._logicalAndOpCode:
					execLevel -= 1
					let laL = execStack[execLevel], laR = execStack[execLevel+1]
					if laL == floor(laL) && laR == floor(laR) &&
					   abs(laL) < Double(Int.max) && abs(laR) < Double(Int.max) {
						execStack[execLevel] = Double(Int(laL) & Int(laR))
					} else {
						execStack[execLevel] = (laL != 0.0 && laR != 0.0) ? 1.0 : 0.0
					}

				case ._logicalOrOpCode:
					execLevel -= 1
					let loL = execStack[execLevel], loR = execStack[execLevel+1]
					if loL == floor(loL) && loR == floor(loR) &&
					   abs(loL) < Double(Int.max) && abs(loR) < Double(Int.max) {
						execStack[execLevel] = Double(Int(loL) | Int(loR))
					} else {
						execStack[execLevel] = (loL != 0.0 || loR != 0.0) ? 1.0 : 0.0
					}

				case ._logicalXorOpCode:
					execLevel -= 1
					let lxL = execStack[execLevel], lxR = execStack[execLevel+1]
					if lxL == floor(lxL) && lxR == floor(lxR) &&
					   abs(lxL) < Double(Int.max) && abs(lxR) < Double(Int.max) {
						execStack[execLevel] = Double(Int(lxL) ^ Int(lxR))
					} else {
						let lxLb = lxL != 0.0, lxRb = lxR != 0.0
						execStack[execLevel] = (lxLb != lxRb) ? 1.0 : 0.0
					}

				case ._logicalNotOpCode:
					let lnV = execStack[execLevel]
					if lnV == floor(lnV) && abs(lnV) < Double(Int.max) {
						execStack[execLevel] = Double(~Int(lnV))
					} else {
						execStack[execLevel] = (lnV == 0.0) ? 1.0 : 0.0
					}

				case ._unaryMinusCode:
					execStack[execLevel] = -execStack[execLevel]

				case ._readConstCode:
					execIndex += 1; execLevel += 1
					let ci = execCodeArray[execIndex]
					if ci < 0 { execStack[execLevel] = _stringConstMarker; execStringConsts[execLevel] = -ci }
					else { execStack[execLevel] = gParsedConstants[ci] }

				case ._EXPopCode:  execStack[execLevel] = exp(execStack[execLevel])
				case ._LOGopCode:
					if execStack[execLevel] <= 0 { evalErr = true }
					else { execStack[execLevel] = log(execStack[execLevel]) }
				case ._LOG10opCode:
					if execStack[execLevel] <= 0 { evalErr = true }
					else { execStack[execLevel] = log10(execStack[execLevel]) }
				case ._SQRopCode:  execStack[execLevel] = execStack[execLevel] * execStack[execLevel]
				case ._SQRTopCode:
					if execStack[execLevel] < 0 { evalErr = true }
					else { execStack[execLevel] = sqrt(execStack[execLevel]) }
				case ._SINopCode:  execStack[execLevel] = sin(execStack[execLevel])
				case ._COSopCode:  execStack[execLevel] = cos(execStack[execLevel])
				case ._TANopCode:  execStack[execLevel] = tan(execStack[execLevel])
				case ._ATNopCode:  execStack[execLevel] = atan(execStack[execLevel])
				case ._ABSOpCode:  execStack[execLevel] = abs(execStack[execLevel])
				case ._INTopCode:  execStack[execLevel] = floor(execStack[execLevel])
				case ._piOpCode:   execLevel += 1; execStack[execLevel] = Double.pi
				case ._RNDopCode:  execStack[execLevel] = Double.random(in: 0.0..<1.0)

				case ._dateOpCode:
					execLevel += 1
					let df = DateFormatter(); df.dateFormat = "MMM d yyyy"
					let si = storeStringConst(value: df.string(from: Date()))
					execStack[execLevel] = _stringConstMarker; execStringConsts[execLevel] = si
				case ._timeOpCode:
					execLevel += 1
					let tf = DateFormatter(); tf.dateFormat = "HH:mm:ss"
					let si = storeStringConst(value: tf.string(from: Date()))
					execStack[execLevel] = _stringConstMarker; execStringConsts[execLevel] = si

				case ._LENopCode:
					let lv = execStack[execLevel]; var length = 0
					if lv == _stringConstMarker { length = gStringConstants[execStringConsts[execLevel]].count }
					else if lv == _stringVarMarker {
						let vi = execStringVars[execLevel]
						if vi == _tempArrayStringVarIndex { length = gTempStringForArray.count }
						else { let vn = gVarNames[vi]; let (v,_,_) = resolveVarRead(varName:vn); if let sv=v,case .string(let s)=sv{length=s.count} }
					} else {
						let sv = (lv==floor(lv) && abs(lv)<Double(Int.max)) ? String(Int(lv)) : String(format:"%.6g",lv)
						length = sv.count
					}
					execStack[execLevel] = Double(length)

				case ._MIDopCode:
					let rangeVal = Int(execStack[execLevel]); execLevel -= 1
					let indexVal = Int(execStack[execLevel]); execLevel -= 1
					let sv = execStack[execLevel]
					var src = ""
					if sv == _stringConstMarker { src = gStringConstants[execStringConsts[execLevel]] }
					else if sv == _stringVarMarker {
						let vi = execStringVars[execLevel]
						if vi == _tempArrayStringVarIndex { src = gTempStringForArray }
						else { let vn = gVarNames[vi]; let (v,_,_) = resolveVarRead(varName:vn); if let s2=v,case .string(let s)=s2{src=s} }
					} else { src = (sv==floor(sv)&&abs(sv)<Double(Int.max)) ? String(Int(sv)) : String(format:"%.6g",sv) }
					var midRes = ""
					let sl = src.count
					if indexVal >= 0 && indexVal < sl && rangeVal > 0 {
						let si2 = src.index(src.startIndex, offsetBy: indexVal)
						let ei2 = src.index(si2, offsetBy: min(rangeVal, sl-indexVal))
						midRes = String(src[si2..<ei2])
					}
					let msi = storeStringConst(value: midRes)
					execStack[execLevel] = _stringConstMarker; execStringConsts[execLevel] = msi

				// Milestone 26: VAL(str) — parse string to Float using Scanner
				// Strips leading whitespace, reads as far as numeric content allows.
				// Returns 0.0 for empty or non-numeric strings.
				case ._VALopCode:
					let valRaw = execStack[execLevel]
					var valSrc = ""
					if valRaw == _stringConstMarker {
						valSrc = gStringConstants[execStringConsts[execLevel]]
					} else if valRaw == _stringVarMarker {
						let vi = execStringVars[execLevel]
						if vi == _tempArrayStringVarIndex { valSrc = gTempStringForArray }
						else { let vn = gVarNames[vi]; let (v,_,_) = resolveVarRead(varName: vn); if let sv2=v, case .string(let s)=sv2 { valSrc=s } }
					} else {
						// Already a number on the stack — pass through unchanged
						break
					}
					let valScanner = Scanner(string: valSrc)
					valScanner.charactersToBeSkipped = .whitespaces
					execStack[execLevel] = valScanner.scanDouble() ?? 0.0
				
				// Milestone 26: CHR$(num) — Unicode scalar value to one-char String
				// Supports full Unicode range (0–0x10FFFF, excluding surrogates).
				// Returns "" for invalid scalar values.
				case ._CHRopCode:
					let chrNum = Int(execStack[execLevel])
					var chrResult = ""
					if let scalar = Unicode.Scalar(chrNum) {
						chrResult = String(scalar)
					}
					let chrSI = storeStringConst(value: chrResult)
					execStack[execLevel] = _stringConstMarker
					execStringConsts[execLevel] = chrSI

				// Milestone 26b: STR$(num) — convert numeric value to string
				case ._STRopCode:
					let strRaw = execStack[execLevel]
					var strResult = ""
					if strRaw == _stringConstMarker {
						// Already a string — pass through unchanged
						break
					} else if strRaw == _stringVarMarker {
						// Already a string var — pass through unchanged
						break
					} else {
						// Numeric → format as string
						if strRaw == floor(strRaw) && abs(strRaw) < Double(Int.max) {
							strResult = String(Int(strRaw))
						} else {
							strResult = String(format: "%.6g", strRaw)
						}
						let strSI = storeStringConst(value: strResult)
						execStack[execLevel] = _stringConstMarker
						execStringConsts[execLevel] = strSI
					}

				// Milestone 26: ASC(str) — Unicode scalar value of first character
				// Returns 0 for empty string. Supports full Unicode including emoji.
				case ._ASCopCode:
					let ascRaw = execStack[execLevel]
					var ascSrc = ""
					if ascRaw == _stringConstMarker {
						ascSrc = gStringConstants[execStringConsts[execLevel]]
					} else if ascRaw == _stringVarMarker {
						let vi = execStringVars[execLevel]
						if vi == _tempArrayStringVarIndex { ascSrc = gTempStringForArray }
						else { let vn = gVarNames[vi]; let (v,_,_) = resolveVarRead(varName: vn); if let sv2=v, case .string(let s)=sv2 { ascSrc=s } }
					}
					let ascResult = ascSrc.unicodeScalars.first.map { Int($0.value) } ?? 0
					execStack[execLevel] = Double(ascResult)
					
					// Milestone 14: string-aware comparisons.
					// If either operand is a string marker, resolve both to actual String values
					// before comparing.  Required for INKEY$ comparisons (if k$ == "^U").
					// Inline resolution follows the same pattern as _plusOpCode above.
					case ._equalOpCode:
						execLevel -= 1
						let lEq = execStack[execLevel], rEq = execStack[execLevel+1]
						if lEq == _stringConstMarker || lEq == _stringVarMarker ||
						   rEq == _stringConstMarker || rEq == _stringVarMarker {
							var ls = "", rs = ""
							if lEq == _stringConstMarker { ls = gStringConstants[execStringConsts[execLevel]] }
							else if lEq == _stringVarMarker { let vi=execStringVars[execLevel]; if vi == _tempArrayStringVarIndex { ls = gTempStringForArray } else { let vn=gVarNames[vi]; let (v,_,_)=resolveVarRead(varName:vn); if let sv=v, case .string(let s)=sv{ls=s} } }
							if rEq == _stringConstMarker { rs = gStringConstants[execStringConsts[execLevel+1]] }
							else if rEq == _stringVarMarker { let vi=execStringVars[execLevel+1]; if vi == _tempArrayStringVarIndex { rs = gTempStringForArray } else { let vn=gVarNames[vi]; let (v,_,_)=resolveVarRead(varName:vn); if let sv=v, case .string(let s)=sv{rs=s} } }
							execStack[execLevel] = ls == rs ? 1.0 : 0.0
						} else { execStack[execLevel] = lEq == rEq ? 1.0 : 0.0 }
						case ._notEqualOpCode:
							execLevel -= 1
							let lNe = execStack[execLevel], rNe = execStack[execLevel+1]
							if lNe == _stringConstMarker || lNe == _stringVarMarker ||
							   rNe == _stringConstMarker || rNe == _stringVarMarker {
								var ls = "", rs = ""
								if lNe == _stringConstMarker { ls = gStringConstants[execStringConsts[execLevel]] }
								else if lNe == _stringVarMarker { let vi=execStringVars[execLevel]; if vi == _tempArrayStringVarIndex { ls = gTempStringForArray } else { let vn=gVarNames[vi]; let (v,_,_)=resolveVarRead(varName:vn); if let sv=v, case .string(let s)=sv{ls=s} } }
								if rNe == _stringConstMarker { rs = gStringConstants[execStringConsts[execLevel+1]] }
								else if rNe == _stringVarMarker { let vi=execStringVars[execLevel+1]; if vi == _tempArrayStringVarIndex { rs = gTempStringForArray } else { let vn=gVarNames[vi]; let (v,_,_)=resolveVarRead(varName:vn); if let sv=v, case .string(let s)=sv{rs=s} } }
								execStack[execLevel] = ls != rs ? 1.0 : 0.0
							} else { execStack[execLevel] = lNe != rNe ? 1.0 : 0.0 }
						case ._greaterOpCode:
							execLevel -= 1
							let lGt = execStack[execLevel], rGt = execStack[execLevel+1]
							if lGt == _stringConstMarker || lGt == _stringVarMarker ||
							   rGt == _stringConstMarker || rGt == _stringVarMarker {
								var ls = "", rs = ""
								if lGt == _stringConstMarker { ls = gStringConstants[execStringConsts[execLevel]] }
								else if lGt == _stringVarMarker { let vi=execStringVars[execLevel]; if vi == _tempArrayStringVarIndex { ls = gTempStringForArray } else { let vn=gVarNames[vi]; let (v,_,_)=resolveVarRead(varName:vn); if let sv=v, case .string(let s)=sv{ls=s} } }
								if rGt == _stringConstMarker { rs = gStringConstants[execStringConsts[execLevel+1]] }
								else if rGt == _stringVarMarker { let vi=execStringVars[execLevel+1]; if vi == _tempArrayStringVarIndex { rs = gTempStringForArray } else { let vn=gVarNames[vi]; let (v,_,_)=resolveVarRead(varName:vn); if let sv=v, case .string(let s)=sv{rs=s} } }
								execStack[execLevel] = ls > rs ? 1.0 : 0.0
							} else { execStack[execLevel] = lGt > rGt ? 1.0 : 0.0 }
						case ._lessOpCode:
							execLevel -= 1
							let lLt = execStack[execLevel], rLt = execStack[execLevel+1]
							if lLt == _stringConstMarker || lLt == _stringVarMarker ||
							   rLt == _stringConstMarker || rLt == _stringVarMarker {
								var ls = "", rs = ""
								if lLt == _stringConstMarker { ls = gStringConstants[execStringConsts[execLevel]] }
								else if lLt == _stringVarMarker { let vi=execStringVars[execLevel]; if vi == _tempArrayStringVarIndex { ls = gTempStringForArray } else { let vn=gVarNames[vi]; let (v,_,_)=resolveVarRead(varName:vn); if let sv=v, case .string(let s)=sv{ls=s} } }
								if rLt == _stringConstMarker { rs = gStringConstants[execStringConsts[execLevel+1]] }
								else if rLt == _stringVarMarker { let vi=execStringVars[execLevel+1]; if vi == _tempArrayStringVarIndex { rs = gTempStringForArray } else { let vn=gVarNames[vi]; let (v,_,_)=resolveVarRead(varName:vn); if let sv=v, case .string(let s)=sv{rs=s} } }
								execStack[execLevel] = ls < rs ? 1.0 : 0.0
							} else { execStack[execLevel] = lLt < rLt ? 1.0 : 0.0 }
						case ._greaterEqOpCode:
							execLevel -= 1
							let lGe = execStack[execLevel], rGe = execStack[execLevel+1]
							if lGe == _stringConstMarker || lGe == _stringVarMarker ||
							   rGe == _stringConstMarker || rGe == _stringVarMarker {
								var ls = "", rs = ""
								if lGe == _stringConstMarker { ls = gStringConstants[execStringConsts[execLevel]] }
								else if lGe == _stringVarMarker { let vi=execStringVars[execLevel]; if vi == _tempArrayStringVarIndex { ls = gTempStringForArray } else { let vn=gVarNames[vi]; let (v,_,_)=resolveVarRead(varName:vn); if let sv=v, case .string(let s)=sv{ls=s} } }
								if rGe == _stringConstMarker { rs = gStringConstants[execStringConsts[execLevel+1]] }
								else if rGe == _stringVarMarker { let vi=execStringVars[execLevel+1]; if vi == _tempArrayStringVarIndex { rs = gTempStringForArray } else { let vn=gVarNames[vi]; let (v,_,_)=resolveVarRead(varName:vn); if let sv=v, case .string(let s)=sv{rs=s} } }
								execStack[execLevel] = ls >= rs ? 1.0 : 0.0
							} else { execStack[execLevel] = lGe >= rGe ? 1.0 : 0.0 }
						case ._lessEqOpCode:
							execLevel -= 1
							let lLe = execStack[execLevel], rLe = execStack[execLevel+1]
							if lLe == _stringConstMarker || lLe == _stringVarMarker ||
							   rLe == _stringConstMarker || rLe == _stringVarMarker {
								var ls = "", rs = ""
								if lLe == _stringConstMarker { ls = gStringConstants[execStringConsts[execLevel]] }
								else if lLe == _stringVarMarker { let vi=execStringVars[execLevel]; if vi == _tempArrayStringVarIndex { ls = gTempStringForArray } else { let vn=gVarNames[vi]; let (v,_,_)=resolveVarRead(varName:vn); if let sv=v, case .string(let s)=sv{ls=s} } }
								if rLe == _stringConstMarker { rs = gStringConstants[execStringConsts[execLevel+1]] }
								else if rLe == _stringVarMarker { let vi=execStringVars[execLevel+1]; if vi == _tempArrayStringVarIndex { rs = gTempStringForArray } else { let vn=gVarNames[vi]; let (v,_,_)=resolveVarRead(varName:vn); if let sv=v, case .string(let s)=sv{rs=s} } }
								execStack[execLevel] = ls <= rs ? 1.0 : 0.0
							} else { execStack[execLevel] = lLe <= rLe ? 1.0 : 0.0 }

				case ._loadVarOpCode:
					execIndex += 1
					let varNameIdx = execCodeArray[execIndex]
					let varName = gVarNames[varNameIdx]
					execLevel += 1
					let (varVal, isStr, nameIdx) = resolveVarRead(varName: varName)
					if let v = varVal {
						if isStr { execStack[execLevel] = _stringVarMarker; execStringVars[execLevel] = nameIdx }
						else { execStack[execLevel] = v.toDouble() }
					} else { execStack[execLevel] = 0.0 }

				case ._storeVarOpCode:
					execIndex += 1
					let varNameIdx = execCodeArray[execIndex]
					let varName = gVarNames[varNameIdx]
					guard let declaredType = resolveVarType(varName: varName) else {
						let errMsg5a = "Parse Error: Variable \(varName) not declared"
						print(errMsg5a); delegate?.pscriptPrint(errMsg5a, newline: true)
						evalErr = true; break
					}
					let sv2 = execStack[execLevel]
					var value: Value
					switch declaredType {
					case .stringType:
						if sv2 == _stringConstMarker {
							value = .string(gStringConstants[execStringConsts[execLevel]])
						} else if sv2 == _stringVarMarker {
							let srcIdx = execStringVars[execLevel]
							if srcIdx == _tempArrayStringVarIndex { value = .string(gTempStringForArray) }
							else { let sn = gVarNames[srcIdx]; let (v2,_,_)=resolveVarRead(varName:sn); value=v2 ?? .string("") }
						} else {
							value = .string(sv2==floor(sv2)&&abs(sv2)<Double(Int.max) ? String(Int(sv2)) : String(format:"%.6g",sv2))
						}
					case .intType:   value = .int(Int(sv2))
					case .floatType: value = .float(sv2)
					case .boolType:  value = .bool(sv2 != 0.0)
					default: evalErr = true; value = .int(0)
					}
					storeVar(varName: varName, value: value)
					execLevel -= 1

				case ._printOpCode:
					execIndex += 1
					let printMode = execCodeArray[execIndex]
					if printMode == 0 {
						// pBasic Step 1: empty PRINT (newline only)
						if let d = delegate {
							d.pscriptPrint("", newline: true)
						} else {
							// NOTE FOR TERMINAL BUILD: this branch is the original behaviour
							print()
						}
					} else {
						let pv = execStack[execLevel]
						var outStr = ""
						var gotStr = false
						if pv == _stringConstMarker {
							outStr = gStringConstants[execStringConsts[execLevel]]; gotStr = true
						} else if pv == _stringVarMarker {
							let vi = execStringVars[execLevel]
							if vi == _tempArrayStringVarIndex { outStr = gTempStringForArray; gotStr = true }
							else { let vn=gVarNames[vi]; let (v,_,_)=resolveVarRead(varName:vn); outStr=v?.toString() ?? ""; gotStr=true }
						}
						if !gotStr {
							// Format numeric value as string
							if pv == floor(pv) && abs(pv) < Double(Int.max) {
								outStr = String(Int(pv))
							} else {
								outStr = String(format:"%.6g", pv)
							}
						}
						// pBasic Step 1: route output through delegate when available
						if let d = delegate {
							// printMode 2 = no newline (semicolon), printMode 1 = newline
							d.pscriptPrint(outStr, newline: printMode != 2)
						} else {
							// NOTE FOR TERMINAL BUILD: original print() fallback
							if printMode == 2 {
								print(outStr, terminator:"")
							} else {
								print(outStr)
							}
						}
						execLevel -= 1
					}
				
				case ._tabOpCode:
					let n = Int(execStack[execLevel]); execLevel -= 1
					// pBasic Step 1: TAB output routed through delegate
					let spaces = String(repeating: " ", count: max(0, n))
					if let d = delegate {
						d.pscriptPrint(spaces, newline: false)
					} else {
						// NOTE FOR TERMINAL BUILD: original behaviour
						print(spaces, terminator:"")
					}
				
				case ._clsOpCode:
					// pBasic Step 1: CLS routed through delegate
					if let d = delegate {
						d.pscriptCls()
					} else {
						// NOTE FOR TERMINAL BUILD: original ANSI escape fallback
						print("\u{001B}[2J\u{001B}[H", terminator:"")
					}

				case ._inputOpCode:
					execIndex += 1; let varNameIdx2 = execCodeArray[execIndex]
					execIndex += 1; let hasPrompt = execCodeArray[execIndex]
					let varName2 = gVarNames[varNameIdx2]
				
					// pBasic Step 1: resolve prompt string (used by both delegate and fallback)
					var promptString: String? = nil
					if hasPrompt == 1 {
						let pv2 = execStack[execLevel]
						if pv2 == _stringConstMarker {
							promptString = gStringConstants[execStringConsts[execLevel]]
						} else if pv2 == _stringVarMarker {
							let vi = execStringVars[execLevel]
							let vn = gVarNames[vi]
							let (v,_,_) = resolveVarRead(varName: vn)
							promptString = v?.toString() ?? ""
						}
						execLevel -= 1
					}
				
					// pBasic Step 1: route input through delegate when available
					let inp: String
					if let d = delegate {
						// Delegate blocks the background thread via semaphore until
						// the user submits input in the app UI (implemented in Step 2).
						inp = d.pscriptInput(prompt: promptString)
					} else {
						// NOTE FOR TERMINAL BUILD: original readLine() fallback
						if let p = promptString {
							if !gStdinIsPiped { print(p, terminator:"") }
						} else {
							if !gStdinIsPiped { print("? ", terminator:"") }
						}
						fflush(stdout)
						guard let line = readLine() else { evalErr = true; break }
						inp = line
					}
				
					// Store the input value into the target variable (unchanged logic)
					if let vt = resolveVarType(varName: varName2) {
						let iv: Value
						switch vt {
						case .stringType: iv = .string(inp)
						case .intType:    iv = .int(Int(inp) ?? 0)
						case .floatType:  iv = .float(Double(inp) ?? 0.0)
						case .boolType:   iv = .bool(!inp.isEmpty && inp != "0")
						default: evalErr = true; iv = .string("")
						}
						storeVar(varName: varName2, value: iv)
					} else {
						gVariableTypes[varName2] = .stringType
						gVariables[varName2] = VariableInfo(type: .stringType, value: .string(inp))
					}

				case ._endOpCode:
					// Milestone 5: ensure any running timer is stopped cleanly on END
					timerOff()
					delegate?.pscriptExecutionDidEnd()
					return
				case ._exitOpCode: exit(0)

				case ._arrayLoadOpCode:
					execIndex += 1
					let varNameIdx3 = execCodeArray[execIndex]
					let varName3 = gVarNames[varNameIdx3]
					let ai3 = Int(execStack[execLevel]); execLevel -= 1
					guard let vt3 = resolveVarType(varName: varName3) else {
						let errMsg5c = "Parse Error: Array \(varName3) not declared"
						print(errMsg5c); delegate?.pscriptPrint(errMsg5c, newline: true)
						evalErr = true; break
					}
					gVariablesLock.lock()
					let av3 = getArrayElement(name: varName3, index: ai3, type: vt3)
					gVariablesLock.unlock()
					if let av = av3 {
						execLevel += 1
						if vt3.baseType() == .stringType {
							if case .string(let s) = av { gTempStringForArray = s }
							else { gTempStringForArray = "" }
							execStack[execLevel] = _stringVarMarker; execStringVars[execLevel] = _tempArrayStringVarIndex
						} else { execStack[execLevel] = av.toDouble() }
					} else {
						let errMsg5b = "Print Error: Array index \(ai3) out of bounds for \(varName3)"
						print(errMsg5b); delegate?.pscriptPrint(errMsg5b, newline: true)
						evalErr = true
					}

				case ._arrayStoreOpCode:
					execIndex += 1
					let varNameIdx4 = execCodeArray[execIndex]
					let varName4 = gVarNames[varNameIdx4]
					let asVal = execStack[execLevel]; execLevel -= 1
					let asIdx = Int(execStack[execLevel]); execLevel -= 1
					guard let vt4 = resolveVarType(varName: varName4) else {
						let errMsg5d = "Parse Error: Array \(varName4) not declared"
						print(errMsg5d); delegate?.pscriptPrint(errMsg5d, newline: true)
						evalErr = true; break
					}
					let asv: Value
					switch vt4.baseType() {
					case .intType:    asv = .int(Int(asVal))
					case .floatType:  asv = .float(asVal)
					case .stringType:
						if asVal == _stringConstMarker { asv = .string(gStringConstants[execStringConsts[execLevel+2]]) }
						else if asVal == _stringVarMarker {
							let si5 = execStringVars[execLevel+2]
							// Guard against _tempArrayStringVarIndex (999999) — this sentinel
							// means the value came from a previous array element read and is
							// sitting in gTempStringForArray, not in gVarNames.
							if si5 == _tempArrayStringVarIndex {
								asv = .string(gTempStringForArray)
							} else {
								let sn5 = gVarNames[si5]
								let (v5,_,_) = resolveVarRead(varName: sn5)
								asv = v5 ?? .string("")
							}
						} else { asv = .string(String(format:"%.6g",asVal)) }
					case .boolType:   asv = .bool(asVal != 0.0)
					default: print("Error: Invalid array base type"); evalErr = true; asv = .int(0)
					}
					gVariablesLock.lock()
					let asOk = setArrayElement(name: varName4, index: asIdx, value: asv, type: vt4)
					gVariablesLock.unlock()
					if !asOk {
						let errMsg5e = "Parse Error: Array index \(asIdx) out of bounds for \(varName4)"
						print(errMsg5e); delegate?.pscriptPrint(errMsg5e, newline: true)
						evalErr = true
					}
					
					// Milestone 23: Multi-dim array load — arrayName[i0,i1,...,iN-1]
					// Bytecode: _arrayLoadMDOpCode, nameIdx, dimCount
					// Stack on entry (bottom→top): i0, i1, ..., iN-1
					case ._arrayLoadMDOpCode:
						execIndex += 1
						let mdLoadNameIdx = execCodeArray[execIndex]
						execIndex += 1
						let mdLoadDimCount = execCodeArray[execIndex]
						let mdLoadName = gVarNames[mdLoadNameIdx]

						// Pop indices from stack (iN-1 on top, i0 deepest)
						var mdLoadIndices = [Int](repeating: 0, count: mdLoadDimCount)
						for di in stride(from: mdLoadDimCount - 1, through: 0, by: -1) {
							mdLoadIndices[di] = Int(execStack[execLevel]); execLevel -= 1
						}

						guard let mdLoadVT = resolveVarType(varName: mdLoadName) else {
							print("Error: Array \(mdLoadName) not declared"); evalErr = true; break
						}

						// Compute flat index using stored dimension strides
						gVariablesLock.lock()
						let mdLoadDims = gArrayDimensions[mdLoadName] ?? [1]
						gVariablesLock.unlock()

						if mdLoadDims.count != mdLoadDimCount {
							print("Error: \(mdLoadName) has \(mdLoadDims.count) dimension(s), got \(mdLoadDimCount) index(es)")
							evalErr = true; break
						}

						// Compute strides and flat index
						var mdLoadFlat = 0
							// strides computed right-to-left
							var mdLoadStrides = [Int](repeating: 1, count: mdLoadDimCount)
							for si in stride(from: mdLoadDimCount - 2, through: 0, by: -1) {
								mdLoadStrides[si] = mdLoadStrides[si + 1] * mdLoadDims[si + 1]
							}
						for di in 0..<mdLoadDimCount {
							if mdLoadIndices[di] < 0 || mdLoadIndices[di] >= mdLoadDims[di] {
								print("Error: Index \(mdLoadIndices[di]) out of bounds for dimension \(di) of \(mdLoadName) (size \(mdLoadDims[di]))")
								evalErr = true; break
							}
							mdLoadFlat += mdLoadIndices[di] * mdLoadStrides[di]
						}
						if evalErr { break }

						// Load from flat index using existing helper
						gVariablesLock.lock()
						let mdLoadVal = getArrayElement(name: mdLoadName, index: mdLoadFlat, type: mdLoadVT)
						gVariablesLock.unlock()

						if let av = mdLoadVal {
							execLevel += 1
							if mdLoadVT.baseType() == .stringType {
								if case .string(let s) = av { gTempStringForArray = s }
								else { gTempStringForArray = "" }
								execStack[execLevel] = _stringVarMarker
								execStringVars[execLevel] = _tempArrayStringVarIndex
							} else {
								execStack[execLevel] = av.toDouble()
							}
						} else {
							print("Error: Flat index \(mdLoadFlat) out of bounds for \(mdLoadName)")
							evalErr = true
						}

					// Milestone 23: Multi-dim array store — arrayName[i0,i1,...,iN-1] = value
					// Bytecode: _arrayStoreMDOpCode, nameIdx, dimCount
					// Stack on entry (bottom→top): i0, i1, ..., iN-1, value
					case ._arrayStoreMDOpCode:
						execIndex += 1
						let mdStoreNameIdx = execCodeArray[execIndex]
						execIndex += 1
						let mdStoreDimCount = execCodeArray[execIndex]
						let mdStoreName = gVarNames[mdStoreNameIdx]

						// Pop value first (top of stack), then indices
						let mdStoreVal = execStack[execLevel]
						let mdStoreSC  = execStringConsts[execLevel]
						let mdStoreSV  = execStringVars[execLevel]
						execLevel -= 1

						var mdStoreIndices = [Int](repeating: 0, count: mdStoreDimCount)
						for di in stride(from: mdStoreDimCount - 1, through: 0, by: -1) {
							mdStoreIndices[di] = Int(execStack[execLevel]); execLevel -= 1
						}

						guard let mdStoreVT = resolveVarType(varName: mdStoreName) else {
							print("Error: Array \(mdStoreName) not declared"); evalErr = true; break
						}

						gVariablesLock.lock()
						let mdStoreDims = gArrayDimensions[mdStoreName] ?? [1]
						gVariablesLock.unlock()

						if mdStoreDims.count != mdStoreDimCount {
							print("Error: \(mdStoreName) has \(mdStoreDims.count) dimension(s), got \(mdStoreDimCount) index(es)")
							evalErr = true; break
						}

						// Compute strides and flat index
						var mdStoreStrides = [Int](repeating: 1, count: mdStoreDimCount)
						for si in stride(from: mdStoreDimCount - 2, through: 0, by: -1) {
							mdStoreStrides[si] = mdStoreStrides[si + 1] * mdStoreDims[si + 1]
						}
						var mdStoreFlat = 0
						for di in 0..<mdStoreDimCount {
							if mdStoreIndices[di] < 0 || mdStoreIndices[di] >= mdStoreDims[di] {
								print("Error: Index \(mdStoreIndices[di]) out of bounds for dimension \(di) of \(mdStoreName) (size \(mdStoreDims[di]))")
								evalErr = true; break
							}
							mdStoreFlat += mdStoreIndices[di] * mdStoreStrides[di]
						}
						if evalErr { break }

						// Build Value to store
						let mdStoreValue: Value
						switch mdStoreVT.baseType() {
						case .intType:   mdStoreValue = .int(Int(mdStoreVal))
						case .floatType: mdStoreValue = .float(mdStoreVal)
						case .stringType:
							if mdStoreVal == _stringConstMarker {
								mdStoreValue = .string(gStringConstants[mdStoreSC])
							} else if mdStoreVal == _stringVarMarker {
								if mdStoreSV == _tempArrayStringVarIndex {
									mdStoreValue = .string(gTempStringForArray)
								} else {
									let sn = gVarNames[mdStoreSV]
									let (v,_,_) = resolveVarRead(varName: sn)
									mdStoreValue = v ?? .string("")
								}
							} else {
								mdStoreValue = .string(mdStoreVal == floor(mdStoreVal) && abs(mdStoreVal) < Double(Int.max)
									? String(Int(mdStoreVal)) : String(format: "%.6g", mdStoreVal))
							}
						case .boolType:  mdStoreValue = .bool(mdStoreVal != 0.0)
						default: print("Error: Invalid array base type"); evalErr = true; mdStoreValue = .int(0)
						}
						if evalErr { break }

						gVariablesLock.lock()
						let mdStoreOk = setArrayElement(name: mdStoreName, index: mdStoreFlat, value: mdStoreValue, type: mdStoreVT)
						gVariablesLock.unlock()
						if !mdStoreOk {
							print("Error: Flat index \(mdStoreFlat) out of bounds for \(mdStoreName)")
							evalErr = true
						}

					// Milestone 23: REDIM — resize with logical-address-preserving copy
					// Bytecode: _redimOpCode, nameIdx, dimCount
					// Stack on entry (bottom→top): d0, d1, ..., dN-1 (new dimension sizes)
					case ._redimOpCode:
						execIndex += 1
						let rdNameIdx  = execCodeArray[execIndex]
						execIndex += 1
						let rdDimCount = execCodeArray[execIndex]
						let rdName     = gVarNames[rdNameIdx]

						// Pop new dimension sizes (dN-1 on top, d0 deepest)
						var rdNewDims = [Int](repeating: 0, count: rdDimCount)
						for di in stride(from: rdDimCount - 1, through: 0, by: -1) {
							rdNewDims[di] = Int(execStack[execLevel]); execLevel -= 1
						}

						// Validate: array must be declared
						guard let rdVarType = resolveVarType(varName: rdName) else {
							print("Error: REDIM — array '\(rdName)' not declared"); evalErr = true; break
						}
						guard rdVarType.isArray() else {
							print("Error: REDIM — '\(rdName)' is not an array"); evalErr = true; break
						}

						// Validate: dimension count must match original
						gVariablesLock.lock()
						let rdOldDims = gArrayDimensions[rdName] ?? []
						gVariablesLock.unlock()
						if !rdOldDims.isEmpty && rdOldDims.count != rdDimCount {
							print("Error: REDIM — '\(rdName)' was declared with \(rdOldDims.count) dimension(s); cannot REDIM to \(rdDimCount)")
							evalErr = true; break
						}

						// Validate all new dims positive
						var rdNewSize = 1
						for d in rdNewDims {
							if d <= 0 { print("Error: REDIM dimension must be positive"); evalErr = true; break }
							rdNewSize *= d
						}
						if evalErr { break }

						if !resizeArray(name: rdName, newSize: rdNewSize, type: rdVarType, newDims: rdNewDims) {
							print("Error: REDIM failed for '\(rdName)'"); evalErr = true
						}

					case ._forBeginOpCode:
					execIndex += 1; let lvName = gVarNames[execCodeArray[execIndex]]
					execIndex += 1; let hasStep = execCodeArray[execIndex]
					var stepVal = 1.0
					if hasStep == 1 { stepVal = execStack[execLevel]; execLevel -= 1 }
					let endVal = execStack[execLevel]; execLevel -= 1
					gForLoopStack.append(ForLoopInfo(varName: lvName, endValue: endVal, stepValue: stepVal, loopStartPC: pc + 1))

				case ._forNextOpCode:
					guard !gForLoopStack.isEmpty else {
						let errMsg5f = "Parse Error: NEXT without FOR"
						print(errMsg5f); delegate?.pscriptPrint(errMsg5f, newline: true)
						evalErr = true; break
					}
					let li = gForLoopStack[gForLoopStack.count - 1]
					let (cv,_,_) = resolveVarRead(varName: li.varName)
					guard let cvi = cv else {
						let errMsg5g = "Parse Error: Loop variable not found"
						print(errMsg5g); delegate?.pscriptPrint(errMsg5g, newline: true)
						evalErr = true; break
					}
					let cur = cvi.toDouble() + li.stepValue
					let newV: Value = (cur==floor(cur)) ? .int(Int(cur)) : .float(cur)
					storeVar(varName: li.varName, value: newV)
					let cont = li.stepValue > 0 ? cur <= li.endValue : cur >= li.endValue
					execIndex += 1
					if cont {
						pc = li.loopStartPC - 1
						// load the loop-start line and break inner loop to re-enter
						pc += 1
						if loadNextLine() { continue lineLoop } else { return }
					} else {
						gForLoopStack.removeLast()
					}

				case ._ifThenOpCode:
					let cond = execStack[execLevel]; execLevel -= 1
					if cond == 0.0 { break innerLoop }   // skip rest of line
				
				// Milestone 39: IF { } — multi-line IF block
				case ._ifBeginOpCode:
					let cond = execStack[execLevel]; execLevel -= 1
					if cond == 0.0 {
						// Condition false — jump to line after closing }
						guard let exitLine = gIfPairs[pc] else {
							let errMsg = "Parser: IF at line \(pc+1) has no matching }"
							if let d = delegate { d.pscriptPrint(errMsg, newline: true) }
							else { print(errMsg) }
							evalErr = true; break
						}
						pc = exitLine
						pc += 1
						if loadNextLine() { continue lineLoop } else { return }
					}
					// Condition true — fall through into body

				case ._ifEndOpCode:
					break   // no-op — fall through to next line
				
				// Milestone 10: WHILE — test condition, jump past } if false, fall through if true
				case ._whileOpCode:
					let cond = execStack[execLevel]; execLevel -= 1
					if cond == 0.0 {
						// Condition false — jump to the line AFTER the closing }
						guard let exitLine = gWhilePairs[pc] else {
							let errMsg5h = "Parse Error: WHILE at line \(pc+1) has no matching }"
							print(errMsg5h); delegate?.pscriptPrint(errMsg5h, newline: true)
							evalErr = true; break
						}
						// Set pc to the closing } line, then let pc += 1 at the bottom
						// of lineLoop advance past it to the first line after the loop.
						pc = exitLine
						pc += 1
						if loadNextLine() { continue lineLoop } else { return }
					}
					// Condition true — fall through into body (no stack push needed for basic looping)

				// Milestone 10: WHILE end — unconditional jump back to WHILE line to re-test
				case ._whileEndOpCode:
					guard let whileLine = gWhileEnds[pc] else {
						let errMsg5i = "Parse Error: } at line \(pc+1) has no matching WHILE"
						print(errMsg5i); delegate?.pscriptPrint(errMsg5i, newline: true)
						evalErr = true; break
					}
					// Jump back to the WHILE line so its condition is re-evaluated
					pc = whileLine
					if loadNextLine() { continue lineLoop } else { return }

				// Milestone 4: Function call — save full execution state, jump to body
				case ._funcCallOpCode:
					execIndex += 1; let fnIdx = execCodeArray[execIndex]
					execIndex += 1; let argc = execCodeArray[execIndex]
					let fnName = gVarNames[fnIdx]
					guard let fdef = gFunctionDefs[fnName] else {
						let errMsg5j = "Parse Error: Function '\(fnName)' not defined"
						print(errMsg5j); delegate?.pscriptPrint(errMsg5j, newline: true)
						evalErr = true; break
					}
					// Collect arg values (bottom to top: arg0 at level-(argc-1), argN-1 at level)
					var argVals  = [Double](repeating: 0.0, count: argc)
					var argSCRefs = [Int](repeating: 0, count: argc)
					var argSVRefs = [Int](repeating: 0, count: argc)
					for ai in 0..<argc {
						let sp = execLevel - (argc - 1 - ai)
						argVals[ai]   = execStack[sp]
						argSCRefs[ai] = execStringConsts[sp]
						argSVRefs[ai] = execStringVars[sp]
					}
					let savedLevel = execLevel - argc   // level BEFORE any args

					// Build local vars from params
					var localVars: [String: VariableInfo] = [:]
					var localTypes: [String: VarType] = [:]
					for (pi, pn) in fdef.params.enumerated() {
						let av = argVals[pi]
						if av == _stringConstMarker {
							let s = argSCRefs[pi] >= 1 ? gStringConstants[argSCRefs[pi]] : ""
							localVars[pn] = VariableInfo(type:.stringType, value:.string(s)); localTypes[pn] = .stringType
						} else if av == _stringVarMarker {
							var s = ""
							let si = argSVRefs[pi]
							if si == _tempArrayStringVarIndex { s = gTempStringForArray }
							else if si >= 1 { let sn=gVarNames[si]; let (v,_,_)=resolveVarRead(varName:sn); if let sv=v,case .string(let ss)=sv{s=ss} }
							localVars[pn] = VariableInfo(type:.stringType, value:.string(s)); localTypes[pn] = .stringType
						} else {
							localVars[pn] = VariableInfo(type:.floatType, value:.float(av)); localTypes[pn] = .floatType
						}
					}

					// Merge VAR-declared locals from parse-time registry into frame.
					// This ensures that vars declared with VAR inside the function body
					// are truly local — typed and initialised in the frame, never touching globals.
					if let funcLocals = gFunctionLocalTypes[fnName] {
						for (vn, vt) in funcLocals {
							if localTypes[vn] == nil {          // don't overwrite params
								localTypes[vn] = vt
								switch vt {
								case .stringType: localVars[vn] = VariableInfo(type: vt, value: .string(""))
								case .floatType:  localVars[vn] = VariableInfo(type: vt, value: .float(0.0))
								case .boolType:   localVars[vn] = VariableInfo(type: vt, value: .bool(false))
								default:          localVars[vn] = VariableInfo(type: vt, value: .int(0))
								}
							}
						}
					}

					// Push call frame with COMPLETE calling-line state.
					// Milestone 10: savedWhileLoopStack captures any WHILE loops active
					// at the call site so they are restored correctly on RETURN.
					let frame = CallFrame(
						funcName: fnName,
						localVariables: localVars,
						localTypes: localTypes,
						returnPC: pc,
						returnIndex: execIndex + 1,       // opcode after _funcCallOpCode block
						savedStack: Array(execStack),
						savedStackLevel: savedLevel,
						savedStringConstRefs: Array(execStringConsts),
						savedStringVarRefs:   Array(execStringVars),
						savedForLoopStack: gForLoopStack,
						savedWhileLoopStack: gWhileLoopStack   // Milestone 10
					)
					gCallStack.append(frame)
					gForLoopStack.removeAll()
					gWhileLoopStack.removeAll()    // Milestone 10: fresh WHILE stack for callee
					insideFunction = true

					// Jump into function body
					pc = fdef.bodyStartLine - 1
					pc += 1
					if loadNextLine() { continue lineLoop } else { return }

				// Milestone 4: Return — restore calling-line state, push return value, continue
				case ._returnOpCode:
					//print("DEBUG RETURN at pc=\(pc) callStackDepth=\(gCallStack.count) topFrame=\(gCallStack.last?.funcName ?? "none")")
					guard !gCallStack.isEmpty else {
						let errMsg5k = "Parse Error: RETURN outside function"
						print(errMsg5k); delegate?.pscriptPrint(errMsg5k, newline: true)
						evalErr = true; break
					}
					// Capture return value before restoring stack
					let rv = execStack[execLevel]
					var retIsStr = false; var retStrVal = ""
					if rv == _stringConstMarker {
						retIsStr = true
						let rsi = execStringConsts[execLevel]
						retStrVal = rsi >= 1 && rsi <= gNumStringConsts ? gStringConstants[rsi] : ""
					} else if rv == _stringVarMarker {
						retIsStr = true
						let rvi = execStringVars[execLevel]
						if rvi == _tempArrayStringVarIndex { retStrVal = gTempStringForArray }
						else if rvi >= 1 { let rn=gVarNames[rvi]; let (v,_,_)=resolveVarRead(varName:rn); if let sv=v,case .string(let s)=sv{retStrVal=s} }
					}

					// Pop frame and fully restore calling-line execution state.
					// Milestone 10: restore the caller's WHILE loop stack.
					let done = gCallStack.removeLast()
					gForLoopStack   = done.savedForLoopStack
					gWhileLoopStack = done.savedWhileLoopStack   // Milestone 10
					insideFunction = !gCallStack.isEmpty

					execStack        = done.savedStack
					execStringConsts = done.savedStringConstRefs
					execStringVars   = done.savedStringVarRefs
					// Sync global string refs
					for i in 0..<_maxEvalStackSize {
						gStringConstRefs[i] = execStringConsts[i]
						gStringVarRefs[i]   = execStringVars[i]
					}

					// Push return value at savedStackLevel + 1
					execLevel = done.savedStackLevel + 1
					if retIsStr {
						let nsi = storeStringConst(value: retStrVal)
						execStack[execLevel] = _stringConstMarker; execStringConsts[execLevel] = nsi
						gStringConstRefs[execLevel] = nsi
					} else {
						execStack[execLevel] = rv
					}

					// Restore calling line and resume from returnIndex
					pc = done.returnPC
					execCodeArray = lineCodeArrays[pc]
					execIndex = done.returnIndex - 1   // will be incremented by loop
					// (continue innerLoop picks up at returnIndex)
				
				// Milestone 14: INKEY$ — non-blocking key read.
				// Calls delegate?.pscriptInkey() which dequeues from the thread-safe inkeyQueue.
				// Returns "" if no key is waiting. Pushes result as a string constant.
				// CLI build (delegate == nil): always pushes "" — correct, INKEY$ is app-only.
				case ._inkeyOpCode:
					execLevel += 1
					let inkeyResult = delegate?.pscriptInkey() ?? ""
					let inkeySI = storeStringConst(value: inkeyResult)
					execStack[execLevel] = _stringConstMarker
					execStringConsts[execLevel] = inkeySI

				// Milestone 22: VERSION$ — push version string onto eval stack
				case ._versionOpCode:
					execLevel += 1
					let verSI = storeStringConst(value: pScriptVersion)
					execStack[execLevel] = _stringConstMarker
					execStringConsts[execLevel] = verSI

				// Milestone 22: BEEP — system bell via delegate or ASCII BEL fallback
				case ._beepOpCode:
					if let d = delegate {
						d.pscriptBell()
					} else {
						print("\u{0007}", terminator: "")
						fflush(stdout)
					}

				case ._locateOpCode:
						// LOCATE row, col — move cursor (GW-BASIC 1-based convention)
						// Stack order: row was pushed first, col second → pop col then row.
						let locCol = Int(execStack[execLevel]); execLevel -= 1
						let locRow = Int(execStack[execLevel]); execLevel -= 1
					// pBasic: route through delegate when available (app UI cursor move)
					if let d = delegate {
						d.pscriptLocate(locRow, locCol)
					} else {
						// CLI fallback: ANSI cursor position escape (already 1-based)
						print("\u{001B}[\(locRow);\(locCol)H", terminator: "")
						fflush(stdout)
					}

				// Milestone 5: Timer opcodes
				case ._timerDeclOpCode:
					// Stack has the interval value; next word in code is funcNameIdx.
					// Store into globals — does NOT start the timer.
					execIndex += 1
					let funcNameIdx = execCodeArray[execIndex]
					gTimerInterval = execStack[execLevel]; execLevel -= 1
					gTimerFuncName = gVarNames[funcNameIdx]

				case ._timerOnOpCode:
					// Start or resume the declared timer.
					// Passes current delegate so the callback can route UI output correctly.
					// If the declared function doesn't exist, timerOn() calls timerOff() and
					// returns false — timer stays off, no crash.
					timerOn(delegate: delegate)

				case ._timerStopOpCode:
					// Suspend timer (OS remembers pending events; TIMERON resumes).
					timerStop()

				case ._timerOffOpCode:
					// Invalidate timer completely (must redeclare with TIMER before TIMERON).
					timerOff()

				// pBasic: Graphics — POINT
				case ._pointOpCode:
					execIndex += 1
					let pointArgCount = execCodeArray[execIndex]
					// Default phosphor green
					var pr = 0.0, pg = 0.91, pb = 0.23, pa = 1.0
					if pointArgCount == 6 {
						// Pop A, B, G, R (reverse order — last pushed is on top)
						pa = execStack[execLevel];     execLevel -= 1
						pb = execStack[execLevel];     execLevel -= 1
						pg = execStack[execLevel];     execLevel -= 1
						pr = execStack[execLevel];     execLevel -= 1
					}
					let pyRaw = execStack[execLevel]; execLevel -= 1
					let pxRaw = execStack[execLevel]; execLevel -= 1
					// Guard against inf/nan/overflow before casting to Int
					if pxRaw.isFinite && pyRaw.isFinite &&
					   pxRaw > Double(Int.min) && pxRaw < Double(Int.max) &&
					   pyRaw > Double(Int.min) && pyRaw < Double(Int.max) {
						let px = Int(pxRaw), py = Int(pyRaw)
						if let d = delegate {
							d.pscriptPoint(x: px, y: py, r: pr, g: pg, b: pb, a: pa)
						}
					}

				// pBasic: Graphics — LINE
				case ._lineOpCode:
					execIndex += 1
					let lineArgCount = execCodeArray[execIndex]
					// Default phosphor green
					var lr = 0.0, lg = 0.91, lb = 0.23, la = 1.0
					if lineArgCount == 8 {
						// Pop A, B, G, R (reverse order — last pushed is on top)
						la = execStack[execLevel];     execLevel -= 1
						lb = execStack[execLevel];     execLevel -= 1
						lg = execStack[execLevel];     execLevel -= 1
						lr = execStack[execLevel];     execLevel -= 1
					}
					let ly2Raw = execStack[execLevel]; execLevel -= 1
					let lx2Raw = execStack[execLevel]; execLevel -= 1
					let ly1Raw = execStack[execLevel]; execLevel -= 1
					let lx1Raw = execStack[execLevel]; execLevel -= 1
					// Guard against inf/nan/overflow before casting to Int
					if lx1Raw.isFinite && ly1Raw.isFinite &&
					   lx2Raw.isFinite && ly2Raw.isFinite &&
					   lx1Raw > Double(Int.min) && lx1Raw < Double(Int.max) &&
					   ly1Raw > Double(Int.min) && ly1Raw < Double(Int.max) &&
					   lx2Raw > Double(Int.min) && lx2Raw < Double(Int.max) &&
					   ly2Raw > Double(Int.min) && ly2Raw < Double(Int.max) {
						let lx1 = Int(lx1Raw), ly1 = Int(ly1Raw)
						let lx2 = Int(lx2Raw), ly2 = Int(ly2Raw)
						if let d = delegate {
							d.pscriptLine(x1: lx1, y1: ly1, x2: lx2, y2: ly2, r: lr, g: lg, b: lb, a: la)
						}
					}

				// pBasic: Graphics - CLR (clear Canvas)
				case ._clrOpCode: 
					if let d = delegate {
						d.pscriptClr()
					}
					
					// Milestone 19: BUFFER — switch draw/display buffer targets
					case ._bufferOpCode:
						execIndex += 1; let bufDrawTo  = execCodeArray[execIndex]
						execIndex += 1; let bufDisplay = execCodeArray[execIndex]
						if bufDrawTo == -1 {
							// Toggle form: swap draw and display atomically
							gDrawBuffer = 1 - gDrawBuffer
							if let d = delegate { d.pscriptBuffer(drawTo: gDrawBuffer, display: 1 - gDrawBuffer) }
						} else {
							// Explicit form: BUFFER:0 or BUFFER:1
							gDrawBuffer = bufDrawTo
							if let d = delegate { d.pscriptBuffer(drawTo: bufDrawTo, display: bufDisplay) }
						}

					// PEN — set global pen width and notify delegate
					case ._penOpCode:
						gPenSize = execStack[execLevel]; execLevel -= 1
						if let d = delegate { d.pscriptPenSize(gPenSize) }

					// Milestone 21: LOAD — fileLines[] = LOAD(urlString)
					// The URL string is on top of the eval stack.
					// The next word in the code stream is the arrayNameIdx.
					case ._fileLoadOpCode:
						execIndex += 1
						let loadArrayNameIdx = execCodeArray[execIndex]
						let loadArrayName    = gVarNames[loadArrayNameIdx]

						// Resolve URL string from stack
						let loadURLraw = execStack[execLevel]; execLevel -= 1
						var loadURLStr = ""
						if loadURLraw == _stringConstMarker {
							loadURLStr = gStringConstants[execStringConsts[execLevel + 1]]
						} else if loadURLraw == _stringVarMarker {
							let vi = execStringVars[execLevel + 1]
							if vi == _tempArrayStringVarIndex { loadURLStr = gTempStringForArray }
							else if vi >= 1 { let vn=gVarNames[vi]; let (v,_,_)=resolveVarRead(varName:vn); if let sv=v,case .string(let s)=sv{loadURLStr=s} }
						}
						// Note: execLevel was already decremented above; string refs are at level+1

						// Verify target is a declared string array
						guard let loadVarType = resolveVarType(varName: loadArrayName),
							  loadVarType == .stringArrayType else {
							if let d = delegate { d.pscriptPrint("Parse Error: \(loadArrayName) is not a String array", newline: true) }
							else { print("Parse Error: \(loadArrayName) is not a String array") }
							evalErr = true; break
						}

						// Resolve file URL using priority rules (spec order):
						//   1. No path component → Documents directory
						//   2. Relative path     → append to Documents directory
						//   3. ~/ prefix         → expand from NSHomeDirectory()
						//   4. Absolute path     → use as-is
						//   5. Not found anywhere → try Bundle.main.bundlePath/bundleDemos/
						let fileManager = FileManager.default
						var resolvedLoadPath = ""
						let loadTrimmed = loadURLStr.trimmingCharacters(in: .whitespaces)

						func documentsDir() -> String {
							return fileManager.urls(for: .documentDirectory, in: .userDomainMask)
								.first?.path ?? NSHomeDirectory()
						}

						if loadTrimmed.isEmpty {
							if let d = delegate { d.pscriptPrint("Parse Error: LOAD requires a filename", newline: true) }
							else { print("Parse Error: LOAD requires a filename") }
							evalErr = true; break
						} else if loadTrimmed.hasPrefix("/") {
							// Absolute path
							resolvedLoadPath = loadTrimmed
						} else if loadTrimmed.hasPrefix("~/") {
							// Tilde expansion
							resolvedLoadPath = (NSHomeDirectory() as NSString)
								.appendingPathComponent(String(loadTrimmed.dropFirst(2)))
						} else {
							// Relative path — try Documents directory first
							let docsPath = (documentsDir() as NSString)
								.appendingPathComponent(loadTrimmed)
							if fileManager.fileExists(atPath: docsPath) {
								resolvedLoadPath = docsPath
							} else {
								// Fall back to Bundle demos directory
								let bundlePath = (Bundle.main.bundlePath as NSString)
									.appendingPathComponent("bundleDemos")
								resolvedLoadPath = (bundlePath as NSString)
									.appendingPathComponent(loadTrimmed)
							}
						}

						// Check file exists
						guard fileManager.fileExists(atPath: resolvedLoadPath) else {
							if let d = delegate { d.pscriptPrint("Error: File not found: \(loadTrimmed)", newline: true) }
							else { print("Error: File not found: \(loadTrimmed)") }
							evalErr = true; break
						}

						// Open file handle for chunked reading
						guard let loadHandle = FileHandle(forReadingAtPath: resolvedLoadPath) else {
							if let d = delegate { d.pscriptPrint("Error: Cannot open file: \(loadTrimmed)", newline: true) }
							else { print("Error: Cannot open file: \(loadTrimmed)") }
							evalErr = true; break
						}

						// Read file in chunks, checking gBreakRequested between chunks
						var loadedData = Data()
						let loadChunkSize = 65536
						var loadInterrupted = false
						while true {
							if gBreakRequested {
								gBreakRequested = false
								loadInterrupted = true
								break
							}
							let chunk = loadHandle.readData(ofLength: loadChunkSize)
							if chunk.isEmpty { break }
							loadedData.append(chunk)
							// Warn if extremely large
							if loadedData.count > 50_000 * 80 {
								if let d = delegate { d.pscriptPrint("Warning: File is very large — truncating at limit", newline: true) }
								else { print("Warning: File is very large — truncating at limit") }
								break
							}
						}
						loadHandle.closeFile()

						if loadInterrupted {
							if let d = delegate { d.pscriptPrint("Warning: Load interrupted", newline: true) }
							else { print("Warning: Load interrupted") }
							break  // leave array unchanged on interrupt
						}

						// Decode and split on newlines
						guard let loadString = String(data: loadedData, encoding: .utf8) ??
											  String(data: loadedData, encoding: .isoLatin1) else {
							if let d = delegate { d.pscriptPrint("Error: File encoding not supported", newline: true) }
							else { print("Error: File encoding not supported") }
							evalErr = true; break
						}

						var loadLines = loadString.components(separatedBy: .newlines)

						// Discard trailing empty element produced by a final newline
						if loadLines.last == "" { loadLines.removeLast() }

						// Warn if line count exceeds threshold
						let loadLineCount = loadLines.count
						if loadLineCount > 50_000 {
							if let d = delegate { d.pscriptPrint("Warning: File has \(loadLineCount) lines — exceeds 50,000 line limit", newline: true) }
							else { print("Warning: File has \(loadLineCount) lines — exceeds 50,000 line limit") }
						}

						// Auto-REDIM if file has more lines than current array size.
						// Size to loadLineCount + 1 so that fileLines[loadLineCount] == ""
						// after population — giving while-loop termination code a clean
						// empty sentinel slot beyond the last line of content.
						gVariablesLock.lock()
						let currentLoadSize = gStringArrays[loadArrayName]?.count ?? 0
						gVariablesLock.unlock()
						if loadLineCount + 1 > currentLoadSize && loadLineCount <= 50_000 {
							_ = resizeArray(name: loadArrayName, newSize: loadLineCount + 1, type: .stringArrayType)
						}

						// Populate the string array.
						// Empty lines between content → stored as "\n" (spec).
						// Lines beyond array capacity are silently dropped.
						gVariablesLock.lock()
						let safeCount = min(loadLineCount, gStringArrays[loadArrayName]?.count ?? 0)
						for li in 0..<safeCount {
							let rawLine = loadLines[li]
							gStringArrays[loadArrayName]?[li] = rawLine.isEmpty ? "\n" : rawLine
						}
						gVariablesLock.unlock()

						// Record the loaded file path for EDIT and SAVE default directory
						gLastLoadedFilePath = resolvedLoadPath

					// Milestone 21: SAVE — SAVE urlExpr, arrayName[]
					// Stack: URL string is on top (pushed by parser).
					// Code stream: next word is arrayNameIdx.
					case ._fileSaveOpCode:
						execIndex += 1
						let saveArrayNameIdx = execCodeArray[execIndex]
						let saveArrayName    = gVarNames[saveArrayNameIdx]

						// Pop the output URL string from the eval stack
						let saveURLraw = execStack[execLevel]; execLevel -= 1
						var saveURLStr = ""
						if saveURLraw == _stringConstMarker {
							saveURLStr = gStringConstants[execStringConsts[execLevel + 1]]
						} else if saveURLraw == _stringVarMarker {
							let vi = execStringVars[execLevel + 1]
							if vi == _tempArrayStringVarIndex { saveURLStr = gTempStringForArray }
							else if vi >= 1 { let vn=gVarNames[vi]; let (v,_,_)=resolveVarRead(varName:vn); if let sv=v,case .string(let s)=sv{saveURLStr=s} }
						}

						// Verify target is a declared string array
						guard let saveVarType = resolveVarType(varName: saveArrayName),
							  saveVarType == .stringArrayType else {
							if let d = delegate { d.pscriptPrint("Parse Error: \(saveArrayName) is not a String array", newline: true) }
							else { print("Parse Error: \(saveArrayName) is not a String array") }
							evalErr = true; break
						}

						// Resolve output path using same priority rules as LOAD:
						//   Absolute /path  → use as-is
						//   ~/path          → expand from NSHomeDirectory()
						//   relative/path   → append to directory of gLastLoadedFilePath if set,
						//                     otherwise append to Documents directory
						let fileManager2 = FileManager.default
						var saveOutputPath = ""
						let saveTrimmed = saveURLStr.trimmingCharacters(in: .whitespaces)

						if saveTrimmed.isEmpty {
							if let d = delegate { d.pscriptPrint("Parse Error: SAVE requires a filename", newline: true) }
							else { print("Parse Error: SAVE requires a filename") }
							evalErr = true; break
						} else if saveTrimmed.hasPrefix("/") {
							// Absolute path — use as-is
							saveOutputPath = saveTrimmed
						} else if saveTrimmed.hasPrefix("~/") {
							// Tilde expansion
							saveOutputPath = (NSHomeDirectory() as NSString)
								.appendingPathComponent(String(saveTrimmed.dropFirst(2)))
						} else {
							// Relative path — resolve against same directory as loaded file,
							// or Documents if no file has been loaded yet this session.
							let baseDir: String
							if !gLastLoadedFilePath.isEmpty {
								baseDir = (gLastLoadedFilePath as NSString).deletingLastPathComponent
							} else {
								baseDir = fileManager2.urls(for: .documentDirectory, in: .userDomainMask)
									.first?.path ?? NSHomeDirectory()
							}
							saveOutputPath = (baseDir as NSString).appendingPathComponent(saveTrimmed)
						}

						// Build output string from array.
						// Skip elements == "" (empty string — unwritten slots).
						// Write elements == "\n" as blank lines.
						// Write all other elements followed by \n.
						gVariablesLock.lock()
						let saveArr = gStringArrays[saveArrayName] ?? []
						gVariablesLock.unlock()

						var saveContent = ""
						var saveInterrupted = false
						for elem in saveArr {
							if gBreakRequested {
								gBreakRequested = false
								saveInterrupted = true
								break
							}
							if elem == "" { continue }          // unwritten slot — skip
							if elem == "\n" { saveContent += "\n"; continue }  // blank line
							saveContent += elem + "\n"
						}

						if saveInterrupted {
							if let d = delegate { d.pscriptPrint("Warning: Save interrupted — original file unchanged", newline: true) }
							else { print("Warning: Save interrupted — original file unchanged") }
							break  // atomic write not started — original safe
						}

						// Write atomically — temp file renamed on success, original never corrupted
						do {
							let saveURL = URL(fileURLWithPath: saveOutputPath)
							try saveContent.write(to: saveURL, atomically: true, encoding: .utf8)
							gLastSaveFilePath = saveOutputPath
						} catch {
							if let d = delegate { d.pscriptPrint("Error: Save failed — \(error.localizedDescription)", newline: true) }
							else { print("Error: Save failed — \(error.localizedDescription)") }
							evalErr = true; break
						}

					// Milestone 36: MOUSEAT(X|Y|B) — current mouse position / button state
					// axis: 0=X  1=Y  2=B(utton)
					case ._mouseatOpCode:
						execIndex += 1
						let mouseAxis = execCodeArray[execIndex]
						execLevel += 1
						execStack[execLevel] = delegate?.pscriptMouseAt(axis: mouseAxis) ?? 0.0

					// Milestone 27: SAMPLE(x, y, channel, sampleSize) — pixel readback
					// Bytecode: _sampleOpCode, argCount (always 4)
					// Stack on entry (bottom→top): x, y, channel, sampleSize
					// channel: 0=Red 1=Green 2=Blue 3=Alpha
					// Returns normalised 0.0–1.0 value pushed onto stack.
					case ._sampleOpCode:
						execIndex += 1
						let sampleArgCount = execCodeArray[execIndex]
						var sampleResult = 0.0
						if sampleArgCount == 4 {
							let sampleSize    = execStack[execLevel];          execLevel -= 1
							let sampleChan    = Int(execStack[execLevel]);     execLevel -= 1
							let sampleY       = Int(execStack[execLevel]);     execLevel -= 1
							let sampleX       = Int(execStack[execLevel]);     execLevel -= 1
							if let d = delegate {
								sampleResult = d.pscriptSample(x: sampleX, y: sampleY,
															   channel: sampleChan,
															   sampleSize: sampleSize)
							}
						} else {
							// Legacy 3-arg form — consume and return 0
							let _sc = Int(execStack[execLevel]); execLevel -= 1
							let _sy = Int(execStack[execLevel]); execLevel -= 1
							let _sx = Int(execStack[execLevel]); execLevel -= 1
							_ = (_sc, _sy, _sx)
						}
						execLevel += 1
						execStack[execLevel] = sampleResult
					
					// Milestone 38: DIST(x1, y1, x2, y2) — Euclidean distance
					case ._distOpCode:
						execIndex += 1
						let distY2 = execStack[execLevel];     execLevel -= 1
						let distX2 = execStack[execLevel];     execLevel -= 1
						let distY1 = execStack[execLevel];     execLevel -= 1
						let distX1 = execStack[execLevel];     execLevel -= 1
						execLevel += 1
						execStack[execLevel] = hypot(distX2 - distX1, distY2 - distY1)
					
					// Milestone 28: SAY — speak string via AVSpeechSynthesizer
					// String expression is on top of eval stack.
					case ._sayOpCode:
						let sayRaw = execStack[execLevel]
						var sayText = ""
						if sayRaw == _stringConstMarker {
							sayText = gStringConstants[execStringConsts[execLevel]]
						} else if sayRaw == _stringVarMarker {
							let vi = execStringVars[execLevel]
							if vi == _tempArrayStringVarIndex { sayText = gTempStringForArray }
							else { let vn = gVarNames[vi]; let (v,_,_) = resolveVarRead(varName: vn); if let sv = v, case .string(let s) = sv { sayText = s } }
						} else {
							// Numeric — convert to string
							sayText = sayRaw == floor(sayRaw) && abs(sayRaw) < Double(Int.max)
								? String(Int(sayRaw)) : String(format: "%.6g", sayRaw)
						}
						execLevel -= 1
						if let d = delegate {
							d.pscriptSay(sayText)
						} else {
							// CLI fallback: print to stdout with [SAY] prefix
							print("[SAY] \(sayText)")
						}
					
					// Milestone 28: SAY STOP — halt speech immediately
					case ._sayStopOpCode:
						if let d = delegate {
							d.pscriptSayStop()
						}
					
					// PLAY(id [, volume [, urlString]]) — fire-and-forget sound playback
					case ._playOpCode:
						execIndex += 1
						let playMask = execCodeArray[execIndex]

						// Collect args from stack — pushed id first (deepest), urlString last (top)
						var playURLStr  = ""
						var playVolume  = -1.0   // sentinel: use last set volume
						var playID      = 0

						// Pop in reverse push order: urlString first if present
						if (playMask >> 2) & 1 == 1 {
							let urlRaw = execStack[execLevel]
							if urlRaw == _stringConstMarker {
								playURLStr = gStringConstants[execStringConsts[execLevel]]
							} else if urlRaw == _stringVarMarker {
								let vi = execStringVars[execLevel]
								if vi == _tempArrayStringVarIndex { playURLStr = gTempStringForArray }
								else { let vn=gVarNames[vi]; let (v,_,_)=resolveVarRead(varName:vn); if let sv=v,case .string(let s)=sv{playURLStr=s} }
							}
							execLevel -= 1
						}
						if (playMask >> 1) & 1 == 1 {
							playVolume = execStack[execLevel]; execLevel -= 1
						}
						if (playMask >> 0) & 1 == 1 {
							playID = Int(execStack[execLevel]); execLevel -= 1
						}

						if let d = delegate {
							d.pscriptPlay(id: playID, volume: playVolume, urlString: playURLStr)
						} else {
							// CLI: use global registry
							cliPlay(id: playID, volume: playVolume, urlString: playURLStr)
						}

					// Milestone 33: SOUND(midiNote, duration, volume)
					case ._soundOpCode:
						let sndVolume  = execStack[execLevel];          execLevel -= 1
						let sndDur     = execStack[execLevel];          execLevel -= 1
						let sndNote    = Int(execStack[execLevel]);     execLevel -= 1
						// Validate range
						guard sndNote >= 0 && sndNote <= 127 else {
							let sndErr = "Parser: MIDI note out of range [0-127]: \(sndNote)"
							if let d = delegate { d.pscriptPrint(sndErr, newline: true) }
							else { print(sndErr) }
							break
						}
						let sndDurClamped = min(max(sndDur, 0.0), 10.0)
						let sndVolClamped = min(max(sndVolume, 0.0), 1.0)
						if let d = delegate {
							d.pscriptSound(midiNote: sndNote,
										   duration: sndDurClamped,
										   volume:   sndVolClamped)
						} else {
							cliSound(midiNote: sndNote, duration: sndDurClamped, volume: sndVolClamped)
						}

					// Milestone 35: FILL(r, g, b, a) — set persistent text background colour
					case ._fillOpCode:
						let fillA = execStack[execLevel];     execLevel -= 1
						let fillB = execStack[execLevel];     execLevel -= 1
						let fillG = execStack[execLevel];     execLevel -= 1
						let fillR = execStack[execLevel];     execLevel -= 1
						let fr = min(max(fillR, 0.0), 1.0)
						let fg = min(max(fillG, 0.0), 1.0)
						let fb = min(max(fillB, 0.0), 1.0)
						let fa = min(max(fillA, 0.0), 1.0)
						gFillColor = (fr, fg, fb, fa)
						delegate?.pscriptFill(r: fr, g: fg, b: fb, a: fa)

					// Milestone 34: TEXT(r, g, b, a) — set persistent text foreground colour
					case ._textColorOpCode:
						let tcA = execStack[execLevel];     execLevel -= 1
						let tcB = execStack[execLevel];     execLevel -= 1
						let tcG = execStack[execLevel];     execLevel -= 1
						let tcR = execStack[execLevel];     execLevel -= 1
						let tr = min(max(tcR, 0.0), 1.0)
						let tg = min(max(tcG, 0.0), 1.0)
						let tb = min(max(tcB, 0.0), 1.0)
						let ta = min(max(tcA, 0.0), 1.0)
						gTextColor = (tr, tg, tb, ta)
						delegate?.pscriptTextColor(r: tr, g: tg, b: tb, a: ta)

					// Milestone 30: SPRITE(id, x, y, rotation, scale, hidden, alpha, imageURL)
					// Bytecode: _spriteOpCode, presentMask, argCount
					// presentMask: bit N set = argument N was supplied and is on the stack.
					// Args are pushed in order (0=id first, 7=imageURL last) — pop in reverse.
					// Absent args use defaults: x/y/rot/scale/alpha → sentinel, hidden → -1, imageURL → ""
					case ._spriteOpCode:
						execIndex += 1
						let sprMask  = execCodeArray[execIndex]
						execIndex += 1
						let _        = execCodeArray[execIndex]   // argCount (unused here)
						let sentinel30 = Double.greatestFiniteMagnitude

						// Collect present args from stack into a fixed array indexed by slot.
						// Stack order: id pushed first → deepest; imageURL pushed last → top.
						// We pop from top (slot 7) down to slot 0.
						var slotVal  = [Double](repeating: sentinel30, count: 8)
						var slotSC   = [Int](repeating: 0, count: 8)
						var slotSV   = [Int](repeating: 0, count: 8)

						for slotIndex in stride(from: 7, through: 0, by: -1) {
							guard (sprMask >> slotIndex) & 1 == 1 else { continue }
							slotVal[slotIndex] = execStack[execLevel]
							slotSC[slotIndex]  = execStringConsts[execLevel]
							slotSV[slotIndex]  = execStringVars[execLevel]
							execLevel -= 1
						}

						// Resolve imageURL (slot 7) — string or empty
						var sprImageURL = ""
						let urlRaw = slotVal[7]
						if urlRaw == _stringConstMarker {
							sprImageURL = gStringConstants[slotSC[7]]
						} else if urlRaw == _stringVarMarker {
							let vi = slotSV[7]
							if vi == _tempArrayStringVarIndex { sprImageURL = gTempStringForArray }
							else { let vn = gVarNames[vi]; let (v,_,_) = resolveVarRead(varName: vn); if let sv = v, case .string(let s) = sv { sprImageURL = s } }
						}
						// If slot 7 absent, sprImageURL stays ""

						// Resolve numeric slots (0=id, 1=x, 2=y, 3=rot, 4=scale, 5=hidden, 6=alpha)
						let sprID       = Int(slotVal[0])
						let sprX        = slotVal[1]   // sentinel if absent
						let sprY        = slotVal[2]
						let sprRotation = slotVal[3]
						let sprScale    = slotVal[4]
						let sprHiddenD  = slotVal[5]
						let sprAlpha    = slotVal[6]
						let sprHidden   = (sprMask >> 5) & 1 == 0 ? -1 : Int(sprHiddenD)

						if let d = delegate {
							d.pscriptSprite(id: sprID,
											x: sprX, y: sprY,
											rotation: sprRotation,
											scale: sprScale,
											hidden: sprHidden,
											alpha: sprAlpha,
											imageURL: sprImageURL)
						}

					// Milestone 30: GET(spriteID, x1, y1, x2, y2)
					// Bytecode: _getOpCode, 5
					// Stack push order: id, x1, y1, x2, y2  →  pop y2 first, id last.
					case ._getOpCode:
						execIndex += 1
						let _ = execCodeArray[execIndex]   // argCount (always 5)
						let getY2 = Int(execStack[execLevel]); execLevel -= 1
						let getX2 = Int(execStack[execLevel]); execLevel -= 1
						let getY1 = Int(execStack[execLevel]); execLevel -= 1
						let getX1 = Int(execStack[execLevel]); execLevel -= 1
						let getID = Int(execStack[execLevel]); execLevel -= 1
						if let d = delegate {
							d.pscriptSpriteGet(id: getID, x1: getX1, y1: getY1, x2: getX2, y2: getY2)
						}
					
				default:
					let errMsg5l = "Syntax Error: undefined opcode \(opcode) at line \(pc+1)"
					print(errMsg5l); delegate?.pscriptPrint(errMsg5l, newline: true)
					evalErr = true
				}

				execIndex += 1
			} // end innerLoop
			
			if evalErr {
				let runtimeErrMsg = "Parser: Runtime error at line \(pc + 1)"
				if let d = delegate {
					d.pscriptPrint(runtimeErrMsg, newline: true)
				} else {
					print(runtimeErrMsg)
				}
				timerOff()
				delegate?.pscriptExecutionDidEnd()
				return
			}
			
			pc += 1
			guard loadNextLine() else { break lineLoop }
		} // end lineLoop

		// Program fell off the end — stop any running timer
		timerOff()
		delegate?.pscriptExecutionDidEnd()
	}
}

//--| REPL COMMANDS |-----

// Reset parser mechanics only (NOT variables)
func resetParserState() {
	gParseError = false
	gTextPtr = ""
	gCharPos = 0
	gCode = 0
	// DO NOT reset gVariables or gVariableTypes - preserve REPL state
	// DO NOT reset gNumConsts - constants can persist
	// Only reset the temporary code array
	gMyCodeArray = [Int](repeating: 0, count: _maxCodeLength + 1)
}

/// Parse a LINE RANGE argument string into zero-based (startIndex, endIndex) inclusive.
/// Supports four forms:
///   ""    → entire listing  (0, count-1)
///   "-N"  → start to N     (0, (N/10)-1)
///   "N-"  → N to end       ((N/10)-1, count-1)
///   "N-M" → N to M         ((N/10)-1, (M/10)-1)
/// Returns nil if the argument is present but malformed.
/// All indices are clamped to 0...(count-1).
func parseLineRange(_ arg: String, count: Int) -> (start: Int, end: Int)? {
	guard count > 0 else { return (0, 0) }
	let trimmed = arg.trimmingCharacters(in: .whitespaces)

	// Empty → whole listing
	if trimmed.isEmpty { return (0, count - 1) }

	// "-N" → start to N
	if trimmed.hasPrefix("-") {
		let rest = String(trimmed.dropFirst())
		guard let n = Int(rest), n > 0 else { return nil }
		let endIdx = max(0, min(count - 1, (n / 10) - 1))
		return (0, endIdx)
	}

	// "N-" or "N-M"
	if trimmed.hasSuffix("-") {
		let rest = String(trimmed.dropLast())
		guard let n = Int(rest), n > 0 else { return nil }
		let startIdx = max(0, min(count - 1, (n / 10) - 1))
		return (startIdx, count - 1)
	}

	// "N-M"
	if trimmed.contains("-") {
		let parts = trimmed.components(separatedBy: "-")
		guard parts.count == 2,
			  let n = Int(parts[0]), n > 0,
			  let m = Int(parts[1]), m > 0 else { return nil }
		let startIdx = max(0, min(count - 1, (n / 10) - 1))
		let endIdx   = max(0, min(count - 1, (m / 10) - 1))
		guard startIdx <= endIdx else { return nil }
		return (startIdx, endIdx)
	}

	return nil   // malformed
}

func processReplCommand(_ input: String, output: ((String) -> Void)? = nil, delegate: PScriptDelegate? = nil) -> Bool {
	
	// pBasic Step 2: single emit helper — routes to delegate output when
	// available, falls back to print() for the CLI build.
	let emit: (String) -> Void = output ?? { print($0) }
	
	// Milestone 40: MORE pager — wraps emit for DIR, HELP, LIST only.
	// Counts lines; pauses every 24 with a prompt; Space/RET continues,
	// CTRL-C aborts. PRINT during RUN is completely unaffected.
	var moreLineCount = 0
	var moreAborted   = false

	let pagedEmit: (String) -> Void = { line in
		guard !moreAborted else { return }
		emit(line)
		moreLineCount += 1
		guard moreLineCount >= 23 else { return }
		moreLineCount = 0

		// Show the prompt (no newline — keeps cursor on the same line for overwrite)
		let morePrompt = " —————| Space to Continue • CTRL-C to Break |————— "
		delegate?.pscriptPrintSync(morePrompt)
		
		// Wait for Space / RET / CTRL-C
		#if PBASIC_APP
		// App path: poll pscriptInkey() on the background thread.
		// Enable inkeyMode temporarily so key events route to the inkey queue.
		delegate?.pscriptExecutionWillBegin()   // sets inkeyMode = true, clears queue
		defer { delegate?.pscriptExecutionDidEnd() }   // clears inkeyMode on exit
		while true {
			if gBreakRequested { gBreakRequested = false; moreAborted = true; break }
			let k = delegate?.pscriptInkey() ?? ""
			if k == " " || k == "RET" { break }
			Thread.sleep(forTimeInterval: 0.05)
		}
		#else
		// CLI path: enter raw mode, poll cliReadInkey(), restore terminal.
		if !gRawModeActive && !gStdinIsPiped { enterRawMode() }
		while true {
			if gBreakRequested { gBreakRequested = false; moreAborted = true; break }
			let k = cliReadInkey()
			if k == " " || k == "RET" { break }
			Thread.sleep(forTimeInterval: 0.05)
		}
		if gRawModeActive { restoreTerminal() }
		#endif

		// Erase the prompt line synchronously via delegate before any further
		// output is enqueued — prevents next line from sharing the prompt row.
		delegate?.pscriptErasePromptLine(width: morePrompt.count)
	}
	
	let trimmed = input.trimmingCharacters(in: .whitespaces)
	let upper = trimmed.uppercased()
	
	if upper == "NEW" {
		gProgramLines.removeAll()
		gVariables.removeAll()
		gVariableTypes.removeAll()
		gFunctionDefs.removeAll()
		gCallStack.removeAll()
		gWhilePairs.removeAll()
		gWhileEnds.removeAll()
		gWhileLoopStack.removeAll()
		gArrayDimensions.removeAll()
		timerOff()
		delegate?.pscriptRemoveAllSprites()
		emit("Program cleared")
		return true
	}
	
	if upper == "LIST" || upper.hasPrefix("LIST ") || upper.hasPrefix("LIST-") {
			if gProgramLines.isEmpty {
				emit("Program is empty")
				return true
			}
			// Extract optional range argument (everything after "LIST")
			let listArg = trimmed.count > 4
				? String(trimmed.dropFirst(4)).trimmingCharacters(in: .whitespaces)
				: ""
			guard let range = parseLineRange(listArg, count: gProgramLines.count) else {
				emit("Usage: LIST  or  LIST -N  or  LIST N-  or  LIST N-M")
				return true
			}
			for index in range.start ... range.end {
				guard !moreAborted else { break }
				let lineNum = (index + 1) * 10
				pagedEmit("\(lineNum) \(gProgramLines[index])")
			}
			return true
		}
	
	if upper == "RUN" {
		if gProgramLines.isEmpty {
			emit("No program to run")
		} else {
			let parser = parseEval(exprString: "")
			// pBasic Step 2: wire delegate so RUN output goes to the terminal display.
			// CLI build: if no delegate was passed in (app delegate is nil in CLI),
			// and stdin is a tty, wire a CLIDelegate so INKEY$ works from the REPL.
			#if !PBASIC_APP
			let activeDelegate: PScriptDelegate?
			if delegate == nil && !gStdinIsPiped {
				activeDelegate = CLIDelegate()
			} else {
				activeDelegate = delegate
			}
			parser.delegate = activeDelegate
			#else
			parser.delegate = delegate
			#endif
			// Milestone 14: activate inkeyMode for the entire program run.
			// DispatchQueue.main.sync is required — processReplCommand() is called
			// from the pScript background thread (Lesson 4, LessonsLearned.txt).
			// The defer covers all exit paths: normal end, END keyword, CTRL-C,
			// and runtime error.  exit(0) from EXIT kills the process — defer
			// never fires but inkeyMode being stuck is irrelevant (process is dead).
			// The timer fires during this window — inkeyMode is already true, so
			// keys queue normally and pscriptInkey() drains them from gTimerQueue.
			if let d = parser.delegate {
				#if !PBASIC_APP
				if !gStdinIsPiped { enterRawMode() }
				#endif
				if delegate != nil {
					DispatchQueue.main.sync { d.pscriptExecutionWillBegin() }
				}
			}
			defer {
				#if !PBASIC_APP
				restoreTerminal()
				#endif
				if let d = parser.delegate, delegate != nil {
					DispatchQueue.main.sync { d.pscriptExecutionDidEnd() }
				}
			}
			parser.executeProgramWithControlFlow()
		}
		return true
	}
	
	if upper.hasPrefix("LOAD ") {
		let filename = String(trimmed.dropFirst(5)).trimmingCharacters(in: CharacterSet(charactersIn: "\" "))
		
		let fileManager = FileManager.default
		guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
			emit("Error: Could not access Documents directory")
			return true
		}
		
		let fileURL = documentsURL.appendingPathComponent(filename)
		
		guard fileManager.fileExists(atPath: fileURL.path) else {
			emit("Error: File '\(filename)' not found in Documents directory")
			emit("Path: \(fileURL.path)")
			return true
		}
		
		do {
			let contents = try String(contentsOf: fileURL, encoding: .utf8)
			
			gProgramLines.removeAll()
			gVariables.removeAll()
			gVariableTypes.removeAll()
			gFunctionDefs.removeAll()
			gCallStack.removeAll()
			gWhilePairs.removeAll()
			gWhileEnds.removeAll()
			gWhileLoopStack.removeAll()
			gArrayDimensions.removeAll()   // Milestone 23
			timerOff()
			
			let lines = contents.components(separatedBy: .newlines)
			for line in lines {
				let trimmedLine = line.trimmingCharacters(in: .whitespaces)
				if !trimmedLine.isEmpty && !trimmedLine.hasPrefix("//") {
					gProgramLines.append(trimmedLine)
				}
			}
			
			// Remember the full path so EDIT can open it later
				gLastLoadedFilePath = fileURL.path
				emit("Loaded \(gProgramLines.count) lines from \(filename)")
			} catch {
				emit("Error loading file: \(error.localizedDescription)")
			}
			
			return true
		}
	
	if upper.hasPrefix("SAVE ") {
		let filename = String(trimmed.dropFirst(5)).trimmingCharacters(in: CharacterSet(charactersIn: "\" "))
		
		if gProgramLines.isEmpty {
			emit("Error: No program to save")
			return true
		}
		
		let fileManager = FileManager.default
		guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
			emit("Error: Could not access Documents directory")
			return true
		}
		
		let fileURL = documentsURL.appendingPathComponent(filename)
		let contents = gProgramLines.joined(separator: "\n") + "\n"
		
		do {
			try contents.write(to: fileURL, atomically: true, encoding: .utf8)
			emit("Saved \(gProgramLines.count) lines to \(filename)")
			emit("Path: \(fileURL.path)")
		} catch {
			emit("Error saving file: \(error.localizedDescription)")
		}
		
		return true
	}
	
	if upper.hasPrefix("DELETE ") || upper.hasPrefix("DEL ") ||
	   upper.hasPrefix("DELETE-") || upper.hasPrefix("DEL-") {
		// Extract argument (everything after "DELETE" or "DEL")
		let deleteCmd  = upper.hasPrefix("DEL ") || upper.hasPrefix("DEL-") ? "DEL" : "DELETE"
		let deleteArg  = String(trimmed.dropFirst(deleteCmd.count))
						 .trimmingCharacters(in: .whitespaces)

		if gProgramLines.isEmpty {
			emit("Program is empty")
			return true
		}

		// Single line number with no dash → existing single-line delete behaviour
		if let lineNum = Int(deleteArg) {
			let lineIndex = (lineNum / 10) - 1
			if lineIndex >= 0 && lineIndex < gProgramLines.count {
				gProgramLines.remove(at: lineIndex)
				emit("Line \(lineNum) deleted")
			} else {
				emit("Line \(lineNum) not found")
			}
			return true
		}

		// Range form
		guard let range = parseLineRange(deleteArg, count: gProgramLines.count) else {
			emit("Usage: DELETE N  or  DELETE -N  or  DELETE N-  or  DELETE N-M")
			return true
		}
		let deleteCount = range.end - range.start + 1
		gProgramLines.removeSubrange(range.start ... range.end)
		emit("Deleted \(deleteCount) line(s)")
		return true
	}
	
	let words = trimmed.split(separator: " ", maxSplits: 1)
	if let lineNum = Int(words[0]) {
		if words.count == 1 {
			emit("To delete line \(lineNum), use: DELETE \(lineNum)")
			return true
		} else {
			let code = String(words[1])

			// First pass: exact match → replace in place
			for (index, _) in gProgramLines.enumerated() {
				if (index + 1) * 10 == lineNum {
					gProgramLines[index] = code
					return true
				}
			}
			
			// No exact match → find correct insertion point
			var insertIndex = 0
			for (index, _) in gProgramLines.enumerated() {
				if lineNum < (index + 1) * 10 { break }
				insertIndex = index + 1
			}
			gProgramLines.insert(code, at: insertIndex)
			return true
		}
	}
	
	if upper == "HELP" {
		pagedEmit("pScript 0.8.40 \u{2022} Copyright 2026 John Roland Penner")
		pagedEmit("")
		pagedEmit("REPL Commands:")
		pagedEmit("  NEW, DIR, LOAD, SAVE, LIST, EDIT, RUN, CLS, CLR, EXIT")
		pagedEmit("  ⬆️  Use Up-Arrow for REPL Command History")
		pagedEmit("  10 FOR N = 1 to 10  Prefix w Line Numbers to Enter Code")
		pagedEmit("  DIR [path]  (e.g., DIR, DIR pBasic, DIR ~/Pictures)")
		pagedEmit("  LOAD file.bas, SAVE file.bas  (files in ~/Documents/)")
		pagedEmit("  LIST [range]  Lists range of Lines (line nums for display only)")
		pagedEmit("  EDIT  Opens the current file in Text Editor (EDITOR$) ")
		pagedEmit("  DELETE linenum  (remove program line[s])")
		pagedEmit("")
		pagedEmit("Keywords:")
		pagedEmit("  VAR name : Type = value    (Types: Int, Float, String, Bool)")
		pagedEmit("  VAR myArray[200,3] : Float (Multi-Dimensional Arrays supported)")
		pagedEmit("  CLS, CLR, BUFFER, TAB(n), LEN(), MID$(), LOCATE(row,col) ")
		pagedEmit("  PRINT expression; or expression       (; suppresses newline)")
		pagedEmit("      Concatenate Multiple Strings with + ")
		pagedEmit("  INPUT var or INPUT \"prompt\"; var")
		pagedEmit("      Supports Piped Input from Terminal. ")
		pagedEmit("      e.g. echo \"John\" | pscript yourname.bas")
		pagedEmit("")
		pagedEmit("Flow Control: FOR, TO, STEP, NEXT, IF, THEN")
		pagedEmit("  FOR var = start TO end [STEP n] ... NEXT var")
		pagedEmit("  IF condition THEN statement")
		pagedEmit("  WHILE (condition) { ... }")
		pagedEmit("  END, EXIT (to shell)")
		pagedEmit("")
		pagedEmit("Functions:")
		pagedEmit("  FUNC name(param1, param2) {")
		pagedEmit("      var local : Type = value")
		pagedEmit("      return expression")
		pagedEmit("  }")
		pagedEmit("  Call with: myFunc()")
		pagedEmit("  Return Values: var myVal : Float = 0.0")
		pagedEmit("      myVal = myFunc(arg1, arg2)")
		pagedEmit("  Recursive calls supported.")
		pagedEmit("")
		pagedEmit("File Handling:")
		pagedEmit("  Text files are read as an Array of Strings: ")
		pagedEmit("  var fileLines[255] : String")
		pagedEmit("  var a$ : String = \"inFile.txt\"")
		pagedEmit("  var b$ : String = \"outFile.txt\"")
		pagedEmit("  fileLines[] = LOAD(a$)")
		pagedEmit("  SAVE b$, fileLines[]")
		pagedEmit("")
		pagedEmit("Timer:")
		pagedEmit("  TIMER 0.25 funcName  (declare interval in seconds + callback)")
		pagedEmit("  TIMERON              (start or resume timer)")
		pagedEmit("  TIMERSTOP            (suspend timer, remembers pending events)")
		pagedEmit("  TIMEROFF             (invalidate timer; must redeclare to restart)")
		pagedEmit("  Timer auto-stops on END, runtime error, or program completion.")
		pagedEmit("  NOTE: FUNC() in Timer Calls can NOT pass variables; use Globals.")
		pagedEmit("")
		pagedEmit("Sprites:")
		pagedEmit("  SPRITE(id, x, y, rotation, scale, hidden, alpha, imageURL)")
		pagedEmit("      Create or update Sprites. Comma syntax — any argument ")
		pagedEmit("      except id may be omitted. Emoji textures: imageURL = \"@🛸\" ")
		pagedEmit("    Declare Sprite: ")
		pagedEmit("      SPRITE(1, 630.0, 500.0, 0, 2.5, 1, 1.0, \"@😎\") ")
		pagedEmit("      SPRITE(1, 630.0, 500.0, 0, 2.5, 1, 1.0, \"viper.png\") ")
		pagedEmit("    Move Sprite: SPRITE(1, shipX, shipY, shipRot, , , , ) ")
		pagedEmit("    Hide Sprite: SPRITE(1, , , , , 0, , ) ")
		pagedEmit("")
		pagedEmit("Operators:")
		pagedEmit("  Math: + - * / ^ %    Comparison: == <> > < >= <=")
		pagedEmit("  Boolean: && || ^^ !  Logical Compare: AND OR XOR NOT")
		pagedEmit("")
		pagedEmit("Math Functions:")
		pagedEmit("  SIN COS TAN ATAN SQRT SQR DIST EXP LOG LOG10 ABS INT RND")
		pagedEmit("  LEN() MID$() VAL(str) STR$(exp) CHR$(num) ASC(str)")
		pagedEmit("  Constants: PI, DATE, TIME, INKEY$ == ^U ^D ^L ^R ")
		pagedEmit("")
		pagedEmit("Usage:")
		pagedEmit("  Interactive: type statements at > prompt")
		pagedEmit("  Program: linenum statement  (e.g., 10 PRINT \"Hello\")")
		pagedEmit("  Run file: pscript filename.bas")
		pagedEmit("  Piped Input from Terminal: echo \"John\" | pscript yourname.bas")
		pagedEmit("")
		return true
	}
	
	// CLS command in REPL
	if upper == "CLS" {
		// In the app, CLS routes through the delegate via _clsOpCode.
		// In the CLI, emit the ANSI escape sequence directly.
		if output != nil {
			// App: emit a blank string — the delegate's pscriptCls() will be
			// triggered separately when CLS is parsed as a pScript statement.
			// For the REPL meta-command, clear the screen via a direct call
			// using the same delegate path by running it as a pScript line.
			// (handled by falling through to the statement executor below)
			return false   // let startPScriptREPL() handle it as a statement
		} else {
			// CLI: ANSI escape
			print("\u{001B}[2J\u{001B}[H", terminator: "")
		}
		return true
	}
	
	// DIR command in REPL
	if upper == "DIR" || upper.hasPrefix("DIR ") {
		let fileManager = FileManager.default
		var targetPath: String

		if upper == "DIR" {
			guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
				emit("Error: Could not access Documents directory")
				return true
			}
			targetPath = documentsURL.path
		} else {
			let argument = String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespaces)

			if argument.hasPrefix("~/") {
				let relativePath = String(argument.dropFirst(2))
				targetPath = (NSHomeDirectory() as NSString).appendingPathComponent(relativePath)
			} else if argument.hasPrefix("/") {
				targetPath = argument
			} else {
				guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
					emit("Error: Could not access Documents directory")
					return true
				}
				targetPath = documentsURL.appendingPathComponent(argument).path
			}
		}

		var isDirectory: ObjCBool = false
		guard fileManager.fileExists(atPath: targetPath, isDirectory: &isDirectory), isDirectory.boolValue else {
			emit("Error: Directory not found: \(targetPath)")
			return true
		}

		let displayPath = targetPath.replacingOccurrences(of: NSHomeDirectory(), with: "~")
		emit("Directory of: \(displayPath)")

		guard let contents = try? fileManager.contentsOfDirectory(atPath: targetPath) else {
			emit("Error: Could not read directory contents")
			return true
		}

		let visibleFiles = contents.filter { filename in
			if filename.hasPrefix(".") { return false }
			if filename.hasPrefix("Icon") && filename.contains("\r") { return false }
			return true
		}.sorted {
			$0.localizedCaseInsensitiveCompare($1) == .orderedAscending
		}

		if visibleFiles.isEmpty {
			emit("(empty directory)")
			return true
		}

		for filename in visibleFiles {
			guard !moreAborted else { break }
			let filePath = (targetPath as NSString).appendingPathComponent(filename)

			guard let attributes = try? fileManager.attributesOfItem(atPath: filePath) else { continue }

			var isDir = false
			if let fileType = attributes[FileAttributeKey.type] as? FileAttributeType {
				isDir = (fileType == FileAttributeType.typeDirectory)
			}

			var sizeString = ""
			if !isDir {
				if let size = attributes[FileAttributeKey.size] as? Int64 {
					if size < 100_000 {
						sizeString = "\(size)"
					} else if size < 1_000_000 {
						sizeString = "\(size / 1024)K"
					} else {
						let sizeMB = Double(size) / 1_048_576.0
						sizeString = String(format: "%.1fM", sizeMB)
					}
				}
			}

			var dateString = ""
			if let modDate = attributes[FileAttributeKey.modificationDate] as? Date {
				let formatter = DateFormatter()
				formatter.dateFormat = "MMM dd HH:mm"
				dateString = formatter.string(from: modDate)
			}

			var displayName = filename
			if displayName.count > 24 { displayName = String(displayName.prefix(24)) }
			if isDir { displayName = "/\(displayName)" }

			let paddedName = displayName.padding(toLength: 26, withPad: " ", startingAt: 0)
			let paddedSize = sizeString.count > 0
				? String(repeating: " ", count: max(0, 10 - sizeString.count)) + sizeString
				: String(repeating: " ", count: 10)

			pagedEmit("\(paddedName)\(paddedSize)\t\(dateString)")
		}

		return true
	}
	
	// EDIT command — open the last loaded file in the configured text editor.
	// Uses macOS `open -a appName filePath` so no hardcoded editor path is needed.
	// The file is always closed after LOAD so the editor has full read/write access.
	// Workflow: LOAD file → EDIT → edit + save in editor → Up Arrow in REPL → LOAD again → RUN.
	if upper == "EDIT" {
		guard !gLastLoadedFilePath.isEmpty else {
			emit("No file loaded — use LOAD \"filename\" first")
			return true
		}
		let task = Process()
		task.launchPath = "/usr/bin/open"
		task.arguments  = ["-a", gEditorApp, gLastLoadedFilePath]
		do {
			try task.run()
			emit("Opening \(gLastLoadedFilePath) in \(gEditorApp)")
		} catch {
			emit("Error opening editor: \(error.localizedDescription)")
		}
		return true
	}

	return false
}


//--| MAIN REPL |-----

// pScriptMain() wraps all file-scope executable code that would otherwise
// be top-level statements — illegal in an app target.
// Called only from the #if !PBASIC_APP block below.
// pBasic.app never calls this; its entry point is the @main struct in pTermApp.swift. 


// MARK: ── CLI Terminal Raw Mode & INKEY$ Support ─────────────────────────────
// All code in this section is compiled only for the pScript CLI target.
// pBasic.app never sees any of this — it uses PScriptBridge in DeviceControl.swift.

/// Saved terminal state — restored when raw mode is exited.
var gSavedTermios = termios()
var gRawModeActive = false

/// Put stdin into raw mode: character-at-a-time, no echo, non-blocking.
/// Safe to call only when stdin is a tty (not a pipe).
/// Saves original termios into gSavedTermios for later restore.
func enterRawMode() {
	guard !gRawModeActive else { return }
	guard tcgetattr(STDIN_FILENO, &gSavedTermios) == 0 else { return }
	var raw = gSavedTermios
	// Disable canonical mode (line buffering) and echo
	raw.c_lflag &= ~tcflag_t(ICANON | ECHO)
	// Read returns immediately with whatever is available (VMIN=0, VTIME=0)
	withUnsafeMutableBytes(of: &raw.c_cc) { ptr in
		ptr[Int(VMIN)]  = 0
		ptr[Int(VTIME)] = 0
	}
	guard tcsetattr(STDIN_FILENO, TCSANOW, &raw) == 0 else { return }
	// Set stdin non-blocking so read() returns immediately if no bytes available
	let flags = fcntl(STDIN_FILENO, F_GETFL, 0)
	_ = fcntl(STDIN_FILENO, F_SETFL, flags | O_NONBLOCK)
	gRawModeActive = true
}

/// Restore stdin to the state saved by enterRawMode().
/// Safe to call even if enterRawMode() was never called.
func restoreTerminal() {
	guard gRawModeActive else { return }
	// Restore blocking mode first
	let flags = fcntl(STDIN_FILENO, F_GETFL, 0)
	_ = fcntl(STDIN_FILENO, F_SETFL, flags & ~O_NONBLOCK)
	// Restore original termios
	tcsetattr(STDIN_FILENO, TCSANOW, &gSavedTermios)
	gRawModeActive = false
}

/// Non-blocking read of one INKEY$ token from stdin.
/// Called only when stdin is a tty and raw mode is active.
/// Returns a token string, or "" if no key is currently available.
/// Token conventions match pBasic.app (LessonsLearned §8):
///   Arrow keys : "^U" (up)  "^D" (down)  "^L" (left)  "^R" (right)
///   Special    : "RET"  "DEL"  "ESC"
///   Printable  : single character string (e.g. "A", "3", " ")
///   Nothing    : ""
func cliReadInkey() -> String {
	var buf = [UInt8](repeating: 0, count: 3)
	let n = read(STDIN_FILENO, &buf, 3)
	guard n > 0 else { return "" }   // no bytes available → no key

	// 3-byte ANSI escape sequence: ESC [ x
	if n == 3 && buf[0] == 0x1B && buf[1] == 0x5B {
		switch buf[2] {
		case 0x41: return "^U"   // ESC [ A — Up Arrow
		case 0x42: return "^D"   // ESC [ B — Down Arrow
		case 0x43: return "^R"   // ESC [ C — Right Arrow
		case 0x44: return "^L"   // ESC [ D — Left Arrow
		default:   return ""     // unknown escape sequence — discard
		}
	}

	// 1-byte sequences
	switch buf[0] {
	case 0x1B:        return "ESC"   // ESC alone
	case 0x0D, 0x0A:  return "RET"   // CR or LF — Return key
	case 0x7F, 0x08:  return "DEL"   // DEL or BS — Delete/Backspace
	case 0x03:                        // CTRL-C — set break flag, return ESC-like token
		gBreakRequested = true
		return "ESC"
	default:
		// Printable ASCII
		if buf[0] >= 32 && buf[0] < 127 {
			return String(UnicodeScalar(buf[0]))
		}
		return ""   // non-printable — discard
	}
}

/// Minimal CLI implementation of PScriptDelegate.
/// Compiled only for the pScript CLI target (#if !PBASIC_APP).
/// Provides INKEY$ support via cliReadInkey() when stdin is a tty.
/// All other methods fall back to the same print()/readLine()/ANSI
/// behaviour that the executor used before delegates existed.
/// Active 'say' process for CLI text-to-speech. nil if not speaking.
/// Accessed only from pscriptSay/pscriptSayStop — both called from pScript bg thread.
var gCliSayTask: Process? = nil

/// Terminate any running CLI 'say' process immediately.
func cliSayStop() {
	if let task = gCliSayTask, task.isRunning {
		task.terminate()
	}
	gCliSayTask = nil
}

/// CLI sound player registry — keyed by PLAY ID.
/// Mirrors PScriptBridge.soundPlayers for the CLI build.
var gCliSoundPlayers: [Int: AVAudioPlayer] = [:]
var gCliSoundVolumes: [Int: Double] = [:]

/// CLI implementation of PLAY — uses AVAudioPlayer directly.
func cliPlay(id: Int, volume: Double, urlString: String) {
	// Load new player if URL provided
	if !urlString.isEmpty {
		let fileManager = FileManager.default
		var resolvedPath = ""
		let trimmed = urlString.trimmingCharacters(in: .whitespaces)

		if trimmed.hasPrefix("/") {
			resolvedPath = trimmed
		} else if trimmed.hasPrefix("~/") {
			resolvedPath = (NSHomeDirectory() as NSString)
				.appendingPathComponent(String(trimmed.dropFirst(2)))
		} else {
			let docsDir = fileManager.urls(for: .documentDirectory,
										   in: .userDomainMask).first?.path
						  ?? NSHomeDirectory()
			resolvedPath = (docsDir as NSString).appendingPathComponent(trimmed)
		}

		guard fileManager.fileExists(atPath: resolvedPath),
			  let player = try? AVAudioPlayer(contentsOf: URL(fileURLWithPath: resolvedPath)) else {
			print("Parser: PLAY — sound file not found: \(trimmed)")
			return
		}
		player.prepareToPlay()
		gCliSoundPlayers[id] = player
		gCliSoundVolumes[id] = volume >= 0 ? volume : 1.0
		// URL provided = load/register only — do not auto-play.
		// Playback is always triggered by a subsequent PLAY(id) call.
		return
	}

	// Look up player
	guard let player = gCliSoundPlayers[id] else {
		print("Parser: PLAY — sound ID \(id) not yet specified, please provide sound URL")
		return
	}

	// volume == 0.0 → stop
	if volume == 0.0 {
		player.stop()
		return
	}

	// Apply volume (-1.0 sentinel = use last set volume)
	let vol = volume < 0 ? (gCliSoundVolumes[id] ?? 1.0) : volume
	gCliSoundVolumes[id] = vol
	player.volume = Float(vol)

	// Fire and forget — restart from beginning
	player.currentTime = 0
	player.play()
}


/// Milestone 33: CLI audio engine for SOUND command.
/// Created lazily on first SOUND call — persists for process lifetime.
var gCliAudioEngine:     AVAudioEngine?      = nil
var gCliSoundVoices:     [AVAudioPlayerNode] = []
var gCliSoundVoiceIndex: Int                 = 0   // round-robin cursor

/// Lazily initialise the CLI audio engine and 8-voice player pool.
/// Safe to call multiple times — returns immediately if already set up.
func cliEnsureAudioEngine() {
	guard gCliAudioEngine == nil else { return }
	let engine = AVAudioEngine()
	for _ in 0..<8 {
		let node = AVAudioPlayerNode()
		engine.attach(node)
		engine.connect(node, to: engine.mainMixerNode, format: nil)
		gCliSoundVoices.append(node)
	}
	do { try engine.start() } catch {
		print("Parser: SOUND — audio engine failed to start: \(error)")
		return
	}
	gCliAudioEngine = engine
}

/// CLI implementation of SOUND — synthesises a sine wave buffer and
/// schedules it on the next available voice in the round-robin pool.
func cliSound(midiNote: Int, duration: Double, volume: Double) {
	cliEnsureAudioEngine()
	guard let engine = gCliAudioEngine else { return }

	// MIDI → frequency
	let freq = 440.0 * pow(2.0, (Double(midiNote) - 69.0) / 12.0)

	// Sample rate from engine output node
	let sampleRate = engine.outputNode.outputFormat(forBus: 0).sampleRate
	guard sampleRate > 0 else { return }

	let frameCount = AVAudioFrameCount(sampleRate * duration)
	guard frameCount > 0 else { return }

	// Build stereo sine buffer
	let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2)!
	guard let buffer = AVAudioPCMBuffer(pcmFormat: format,
										frameCapacity: frameCount) else { return }
	buffer.frameLength = frameCount

	let omega = 2.0 * Double.pi * freq / sampleRate
	if let left  = buffer.floatChannelData?[0],
	   let right = buffer.floatChannelData?[1] {
		for i in 0..<Int(frameCount) {
			let sample = Float(sin(omega * Double(i)) * volume)
			left[i]  = sample
			right[i] = sample
		}
	}

	// Round-robin voice selection
	let voice = gCliSoundVoices[gCliSoundVoiceIndex % gCliSoundVoices.count]
	gCliSoundVoiceIndex += 1

	if !voice.isPlaying { voice.play() }
	voice.scheduleBuffer(buffer, completionHandler: nil)
}


final class CLIDelegate: PScriptDelegate {

	func pscriptPrint(_ text: String, newline: Bool) {
		if newline { print(text) } else { print(text, terminator: "") }
		fflush(stdout)
	}
	
	func pscriptPrintSync(_ text: String) {
		print(text)
	}
	
	func pscriptInput(prompt: String?) -> String {
		if let p = prompt {
			if !gStdinIsPiped { print(p, terminator: ""); fflush(stdout) }
		} else {
			if !gStdinIsPiped { print("? ", terminator: ""); fflush(stdout) }
		}
		// INPUT needs a line — temporarily restore terminal to canonical mode
		// so readLine() works correctly, then re-enter raw mode afterwards.
		restoreTerminal()
		let line = readLine() ?? ""
		if !gStdinIsPiped { enterRawMode() }
		return line
	}

	func pscriptCls() {
		print("\u{001B}[2J\u{001B}[H", terminator: "")
		fflush(stdout)
	}

	func pscriptBell() {
		print("\u{0007}", terminator: "")
		fflush(stdout)
	}

	func pscriptLocate(_ row: Int, _ col: Int) {
		print("\u{001B}[\(row);\(col)H", terminator: "")
		fflush(stdout)
	}

	func pscriptPoint(x: Int, y: Int, r: Double, g: Double, b: Double, a: Double) {
		// Graphics not supported in CLI — silently ignored
	}

	func pscriptLine(x1: Int, y1: Int, x2: Int, y2: Int,
					 r: Double, g: Double, b: Double, a: Double) {
		// Graphics not supported in CLI — silently ignored
	}

	func pscriptClr() {
		// Graphics not supported in CLI — silently ignored
	}

	func pscriptInkey() -> String {
		// Only attempt a read if raw mode is active (stdin is a tty, program running)
		guard gRawModeActive else { return "" }
		return cliReadInkey()
	}

	func pscriptExecutionWillBegin() {
		// Raw mode is managed by pScriptMain() around the run call —
		// nothing to do here for the CLI delegate.
	}

	func pscriptExecutionDidEnd() {
		// Raw mode is managed by pScriptMain() around the run call —
		// nothing to do here for the CLI delegate.
	}
	
	func pscriptTimerDidStart() {}
	func pscriptTimerDidStop()  {}
	func pscriptPenSize(_ size: Double) {}				// CLI: graphics not supported — no-op
	func pscriptBuffer(drawTo: Int, display: Int) {}	// CLI: graphics not supported — no-op
	func pscriptSample(x: Int, y: Int, channel: Int, sampleSize: Double) -> Double { return 0.0 }
	// STR$ handled entirely in executor — no delegate method needed
	func pscriptSay(_ text: String) {
		// CLI: use macOS 'say' command via Process — non-blocking (detached)
		// Captures the process handle in a global so pscriptSayStop() can terminate it.
		// 'say' uses the system default voice and language automatically.
		cliSayStop()   // stop any previous utterance before starting new one
		let task = Process()
		task.launchPath = "/usr/bin/say"
		task.arguments  = [text]
		do {
			try task.run()
			gCliSayTask = task   // retain for possible SAY STOP
			task.waitUntilExit()  // block until spoken — matches pTerm.app queue behaviour
			gCliSayTask = nil
		} catch {
			print("[SAY] \(text)")   // fallback: print if say command fails
		}
	}

	func pscriptSayStop() {
		cliSayStop()
	}
	
	func pscriptSprite(id: Int, x: Double, y: Double, rotation: Double,
		   scale: Double, hidden: Int, alpha: Double, imageURL: String) {}
	func pscriptSpriteGet(id: Int, x1: Int, y1: Int, x2: Int, y2: Int) {}
	
	func pscriptRemoveAllSprites() {}   // CLI: no sprites — no-op
	func pscriptMouseAt(axis: Int) -> Double { return 0.0 }   // CLI: no mouse — no-op
	func pscriptPlay(id: Int, volume: Double, urlString: String) {
		cliPlay(id: id, volume: volume, urlString: urlString)
	}
	func pscriptSound(midiNote: Int, duration: Double, volume: Double) {
		cliSound(midiNote: midiNote, duration: duration, volume: volume)
	}
	func pscriptFill(r: Double, g: Double, b: Double, a: Double) {
		// CLI: text background not supported — no-op
	}
	func pscriptTextColor(r: Double, g: Double, b: Double, a: Double) {
		// CLI: text colour not supported — no-op
	}
	
	func pscriptErasePromptLine(width: Int) {
		print("\u{001B}[1A\u{001B}[2K", terminator: "")
		fflush(stdout)
	}

}

// MARK: ── End CLI Terminal Raw Mode & INKEY$ Support ─────────────────────────

func pScriptMain() {

	// ── CLI readline history via libedit (dlopen — zero latency, already loaded) ──
	// libedit ships on every macOS and is always in the dyld shared cache.
	// dlopen on an already-loaded library is a reference-count increment only.
	// If loading fails for any reason we fall back silently to plain readLine().
	typealias ReadlineFn   = @convention(c) (UnsafePointer<CChar>?) -> UnsafeMutablePointer<CChar>?
	typealias AddHistoryFn = @convention(c) (UnsafePointer<CChar>?) -> Void

	var libeditReadline:   ReadlineFn?   = nil
	var libeditAddHistory: AddHistoryFn? = nil

	if let handle = dlopen("/usr/lib/libedit.dylib", RTLD_LAZY | RTLD_GLOBAL) {
		if let rSym = dlsym(handle, "readline"),
		   let hSym = dlsym(handle, "add_history") {
			libeditReadline   = unsafeBitCast(rSym, to: ReadlineFn.self)
			libeditAddHistory = unsafeBitCast(hSym, to: AddHistoryFn.self)
		}
		// Note: we intentionally do NOT dlclose(handle) — the library stays
		// resident for the lifetime of the process (which is what we want).
	}

	/// Read one line from stdin with libedit line-editing + history if available,
	/// otherwise fall back to Swift's readLine().  Returns nil on EOF.
	func readInputLine(prompt: String) -> String? {
		if let rl = libeditReadline {
			guard let rawPtr = rl(prompt) else { return nil }   // EOF → nil
			let line = String(cString: rawPtr)
			free(rawPtr)   // readline malloc's the buffer — caller must free
			return line
		} else {
			// Fallback: plain readLine() (no arrow-key history)
			print(prompt, terminator: "")
			fflush(stdout)
			return readLine()
		}
	}

	/// Add a line to libedit history (no-op if libedit not available).
	func addInputHistory(_ line: String) {
		guard let ah = libeditAddHistory, !line.isEmpty else { return }
		ah(line)
	}
	// ── end libedit setup ──

	// Check for command-line file argument
	var startedFromFile = false
	if CommandLine.arguments.count > 1 {
		startedFromFile = true
		// Non-interactive mode: load and run file
		let filename = CommandLine.arguments[1]
		
		// Determine file path
		let fileManager = FileManager.default
		var filePath = filename
		
		// If not an absolute path, check current directory first, then Documents
		if !filename.hasPrefix("/") && !filename.hasPrefix("~") {
			let currentDir = FileManager.default.currentDirectoryPath
			let currentDirPath = (currentDir as NSString).appendingPathComponent(filename)
			
			if fileManager.fileExists(atPath: currentDirPath) {
				filePath = currentDirPath
			} else if let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
				filePath = documentsURL.appendingPathComponent(filename).path
			}
		} else if filename.hasPrefix("~/") {
			// Handle tilde expansion
			let relativePath = String(filename.dropFirst(2))
			filePath = (NSHomeDirectory() as NSString).appendingPathComponent(relativePath)
		}
		
		// Check if file exists
		guard fileManager.fileExists(atPath: filePath) else {
			print("Error: File '\(filename)' not found")
			exit(1)
		}
		
		// Load file contents
		do {
			let contents = try String(contentsOfFile: filePath, encoding: .utf8)
			
			// Clear any existing state
			gProgramLines.removeAll()
			gVariables.removeAll()
			gVariableTypes.removeAll()
			gFunctionDefs.removeAll()
			gCallStack.removeAll()
			gWhilePairs.removeAll()     // Milestone 10
			gWhileEnds.removeAll()      // Milestone 10
			gWhileLoopStack.removeAll() // Milestone 10
			gFillColor = (0.0, 0.0, 0.0, 0.0)         // Milestone 35: reset fill to transparent
			gTextColor  = (0.0, 0.91, 0.23, 1.0)        // Milestone 34: reset text to phosphor green
			
			// Split into lines and add to program
			let lines = contents.components(separatedBy: .newlines)
			for line in lines {
				let trimmedLine = line.trimmingCharacters(in: .whitespaces)
				if !trimmedLine.isEmpty && !trimmedLine.hasPrefix("//") {
					gProgramLines.append(trimmedLine)
				}
			}
			
			// Run the program.
			// Wire CLIDelegate so INKEY$, LOCATE, and PRINT route correctly.
			// Enter raw mode only when stdin is a tty (not a pipe) so that
			// INKEY$ can read arrow keys and ESC without line buffering.
			let parser = parseEval(exprString: "")
			let cliDelegate = CLIDelegate()
			parser.delegate = cliDelegate
			if !gStdinIsPiped { enterRawMode() }
			defer { restoreTerminal() }
			parser.executeProgramWithControlFlow()
			
		} catch {
			print("Error loading file: \(error.localizedDescription)")
			exit(1)
		}
		
		// After running from commandline, fall through to REPL (don't exit)
	}
	
	// Interactive REPL mode
	if !startedFromFile {
		// Only show banner if starting interactively (not from file)
		print("pScript v0.8.40 \u{2022} Copyright 2026 John Roland Penner")
		print("Type HELP for Commands and Expressions.")
		print()
	}
	print("Ready")
	
	while true {
		guard let input = readInputLine(prompt: "> ") else {
			break
		}
		
		let trimmed = input.trimmingCharacters(in: .whitespaces)
		if trimmed.isEmpty {
			continue
		}

		// Record accepted non-empty lines in libedit history (or no-op if fallback)
		addInputHistory(trimmed)

		if trimmed.uppercased() == "QUIT" || trimmed.uppercased() == "EXIT" {
			// Milestone 5: clean up timer before exit
			timerOff()
			break
		}
		
		if processReplCommand(trimmed) {
			continue
		}
		
		resetParserState()
				
		let parser = parseEval(exprString: trimmed)
		let replDelegate = CLIDelegate()
		parser.delegate = replDelegate
		parser.initSymbolTable()
		parser.initNumSearchStrings()
		
		if parser.parseStatement() {
			if gMyCodeArray[0] > 0 {
				gProgramLines = [trimmed]
				parser.executeProgramWithControlFlow()
			}
		}
		// note: parseError() already reported via delegate — no else needed
	}
	
	print("Goodbye!")
}

// Call pScriptMain() only when building the command-line tool.
// In the pBasic.app target, PBASIC_APP is defined in:
//   Build Settings → Swift Compiler - Custom Flags → Active Compilation Conditions
// which suppresses this call entirely — leaving zero top-level executable statements.
//
// Compile CLI: swiftc -o pscript parseEval.swift
// Run CLI:     ./pscript
#if !PBASIC_APP
pScriptMain()
#endif
// Compile: swiftc -o pscript parseEval.swift
// Run: ./pscript

