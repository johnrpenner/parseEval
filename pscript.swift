// pScript v0.7.0 - Copyright 2026 by John Roland Penner
// Based on Recursive Descent Parser by Robert Purves (2008)
//  
// Milestone 4: FUNCTIONS
// Implements: func definitions, local scope, return values, recursion
// Updated: February 22, 2026 
// Milestone 9: TIMER
// Implements: TIMER interval funcName, TIMERON, TIMERSTOP, TIMEROFF
// Updated: March 5, 2026
// Milestone 10: WHILE
// Implements: WHILE (condition) { body } — top-test loop, brace syntax
// Updated: March 6, 2026


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

//---| GLOBALS |-------

// Parse setup values
let _maxNumConsts: Int = 100
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

// Array storage - separate from scalar variables for efficiency
// Each array name maps to its data storage
var gIntArrays: [String: [Int]] = [:]
var gFloatArrays: [String: [Double]] = [:]
var gStringArrays: [String: [String]] = [:]
var gBoolArrays: [String: [Bool]] = [:]


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

// Initialize an array with default values based on type
func initializeArray(name: String, size: Int, type: VarType) {
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
}

// Resize an array, preserving existing values
func resizeArray(name: String, newSize: Int, type: VarType) -> Bool {
	guard newSize > 0 else { return false }
	
	switch type {
	case .intArrayType:
		guard var arr = gIntArrays[name] else { return false }
		let oldSize = arr.count
		if newSize > oldSize {
			// Expand: add zero-filled elements
			arr.append(contentsOf: [Int](repeating: 0, count: newSize - oldSize))
		} else if newSize < oldSize {
			// Shrink: truncate
			arr = Array(arr[0..<newSize])
		}
		gIntArrays[name] = arr
		
	case .floatArrayType:
		guard var arr = gFloatArrays[name] else { return false }
		let oldSize = arr.count
		if newSize > oldSize {
			arr.append(contentsOf: [Double](repeating: 0.0, count: newSize - oldSize))
		} else if newSize < oldSize {
			arr = Array(arr[0..<newSize])
		}
		gFloatArrays[name] = arr
		
	case .stringArrayType:
		guard var arr = gStringArrays[name] else { return false }
		let oldSize = arr.count
		if newSize > oldSize {
			arr.append(contentsOf: [String](repeating: "", count: newSize - oldSize))
		} else if newSize < oldSize {
			arr = Array(arr[0..<newSize])
		}
		gStringArrays[name] = arr
		
	case .boolArrayType:
		guard var arr = gBoolArrays[name] else { return false }
		let oldSize = arr.count
		if newSize > oldSize {
			arr.append(contentsOf: [Bool](repeating: false, count: newSize - oldSize))
		} else if newSize < oldSize {
			arr = Array(arr[0..<newSize])
		}
		gBoolArrays[name] = arr
		
	default:
		return false
	}
	
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

// Pre-scan results: populated by preScanWhileLoops() before execution.
// gWhilePairs: WHILE-line-index  → closing-brace-line-index
// gWhileEnds:  closing-brace-line-index → WHILE-line-index
// Both dicts together let the executor jump in either direction in O(1).
var gWhilePairs: [Int: Int] = [:]
var gWhileEnds:  [Int: Int] = [:]


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

/// Dedicated serial queue on which all timer callbacks execute.
/// Serial = only one tick runs at a time; busy-guard handles the overlap case.
let gTimerQueue = DispatchQueue(label: "pscript.timer", qos: .userInteractive)

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
	let intervalNS = UInt64(gTimerInterval * 1_000_000_000)
	source.schedule(deadline: .now() + gTimerInterval,
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
		let savedNumConsts    = gNumConsts
		let savedNumStrConsts = gNumStringConsts
		let savedNumVarNames  = gNumVarNames
		let savedParsedConsts = gParsedConstants
		let savedStrConsts    = gStringConstants
		let savedVarNames     = gVarNames
		let savedFuncDefs     = gFunctionDefs      // preScanFunctions() clears this
		let savedForStack     = gForLoopStack
		let savedCallStack    = gCallStack
		let savedWhileStack   = gWhileLoopStack    // Milestone 10
		let savedWhilePairs   = gWhilePairs        // Milestone 10
		let savedWhileEnds    = gWhileEnds         // Milestone 10
		gForLoopStack.removeAll()
		gCallStack.removeAll()
		gWhileLoopStack.removeAll()                // Milestone 10
		gWhilePairs.removeAll()                    // Milestone 10
		gWhileEnds.removeAll()                     // Milestone 10
		defer {
			// Always restore everything so the main program is unaffected
			gNumConsts        = savedNumConsts
			gNumStringConsts  = savedNumStrConsts
			gNumVarNames      = savedNumVarNames
			gParsedConstants  = savedParsedConsts
			gStringConstants  = savedStrConsts
			gVarNames         = savedVarNames
			gFunctionDefs     = savedFuncDefs
			gForLoopStack     = savedForStack
			gCallStack        = savedCallStack
			gWhileLoopStack   = savedWhileStack    // Milestone 10
			gWhilePairs       = savedWhilePairs    // Milestone 10
			gWhileEnds        = savedWhileEnds     // Milestone 10
		}

		// Re-initialise symbol table and number strings for the fresh interpreter
		interp.initSymbolTable()
		interp.initNumSearchStrings()
		// Reset parse counters so the body lines parse into a clean slate
		gNumConsts       = 0
		gNumStringConsts = 0
		gNumVarNames     = 0

		// Parse the body lines into bytecode.
		// Milestone 10: pre-scan WHILE pairs within the timer function body,
		// offset by bodyStartLine so line indices match the local lineCodeArrays indices.
		let bodyLines = Array(gProgramLines[fdef.bodyStartLine ..< fdef.bodyEndLine])

		// Build local WHILE pair tables for the timer body (indices relative to bodyLines)
		var localWhilePairs: [Int: Int] = [:]
		var localWhileEnds:  [Int: Int] = [:]
		var whileStack: [Int] = []
		for (i, bline) in bodyLines.enumerated() {
			let trimmed = bline.trimmingCharacters(in: .whitespaces)
			let upper = trimmed.uppercased()
			if upper.hasPrefix("WHILE ") || upper.hasPrefix("WHILE(") || upper == "WHILE" {
				whileStack.append(i)
			} else if trimmed.hasPrefix("}") && !whileStack.isEmpty {
				let whileLine = whileStack.removeLast()
				localWhilePairs[whileLine] = i
				localWhileEnds[i] = whileLine
			}
		}

		var lineCodeArrays: [[Int]] = []
		var parseFailed = false
		for (i, line) in bodyLines.enumerated() {
			let trimmed = line.trimmingCharacters(in: .whitespaces)
			if trimmed.isEmpty || trimmed.hasPrefix("}") {
				// Emit _whileEndOpCode if this } closes a WHILE in the timer body
				if let _ = localWhileEnds[i] {
					var lca = [Int](repeating: 0, count: 2)
					lca[0] = 1
					lca[1] = evalOPcodes._whileEndOpCode.rawValue
					lineCodeArrays.append(lca)
				} else {
					lineCodeArrays.append([0])
				}
				continue
			}
			interp.exprString = trimmed
			gMyCodeArray = [Int](repeating: 0, count: _maxCodeLength + 1)
			if !interp.parseStatement() {
				print("Timer: parse error at body line \(i + 1): \(trimmed)")
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
		// Milestone 10: _whileOpCode and _whileEndOpCode handled using localWhilePairs
		// and localWhileEnds (local to this timer invocation, no global mutation).
		var timerWhileStack: [WhileLoopInfo] = []
		var pc = 0
		bodyLoop: while pc < lineCodeArrays.count {
			let codeArray = lineCodeArrays[pc]
			guard codeArray[0] > 0 else { pc += 1; continue }

			var execIndex = 1
			var execLevel = 0
			var execStack    = [Double](repeating: 0.0, count: _maxEvalStackSize)
			var execStrConst = [Int](repeating: 0, count: _maxEvalStackSize)
			var execStrVar   = [Int](repeating: 0, count: _maxEvalStackSize)

			while execIndex <= codeArray[0] {
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
					if let vi = gVariables[vn] {
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
					guard let vt = gVariableTypes[vn] else { break bodyLoop }
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
					gVariables[vn] = VariableInfo(type: vt, value: val)
					execLevel -= 1

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
						else { ls = gVariables[gVarNames[execStrVar[execLevel]]]?.value.toString() ?? "" }
						if rv == _stringConstMarker { rs = gStringConstants[execStrConst[execLevel+1]] }
						else { rs = gVariables[gVarNames[execStrVar[execLevel+1]]]?.value.toString() ?? "" }
						let si = interp.storeStringConst(value: ls+rs)
						execStack[execLevel] = _stringConstMarker; execStrConst[execLevel] = si
					} else { execStack[execLevel] = lv + rv }
				case ._minusOpCode:  execLevel -= 1; execStack[execLevel] = execStack[execLevel] - execStack[execLevel+1]
				case ._timesOpCode:  execLevel -= 1; execStack[execLevel] = execStack[execLevel] * execStack[execLevel+1]
				case ._divideOpCode:
					execLevel -= 1
					if execStack[execLevel+1] != 0 { execStack[execLevel] = execStack[execLevel] / execStack[execLevel+1] }
				case ._unaryMinusCode: execStack[execLevel] = -execStack[execLevel]
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
				
				// Milestone 14: string-aware comparisons in timer executor.
				// Required for INKEY$-driven game loops (timer fires each tick, checks key).
				// Inline resolution uses gVariables directly (no resolveVarRead closure here).
				// Note: timer body uses execStrConst / execStrVar (local copies of refs).
				case ._equalOpCode:
					execLevel -= 1
					let tlEq = execStack[execLevel], trEq = execStack[execLevel+1]
					if tlEq == _stringConstMarker || tlEq == _stringVarMarker ||
					   trEq == _stringConstMarker || trEq == _stringVarMarker {
						var ls = "", rs = ""
						if tlEq == _stringConstMarker { ls = gStringConstants[execStrConst[execLevel]] }
						else if tlEq == _stringVarMarker { let vi=execStrVar[execLevel]; if vi == _tempArrayStringVarIndex { ls = gTempStringForArray } else if vi >= 1 { let vn=gVarNames[vi]; if let inf=gVariables[vn], case .string(let s)=inf.value{ls=s} } }
						if trEq == _stringConstMarker { rs = gStringConstants[execStrConst[execLevel+1]] }
						else if trEq == _stringVarMarker { let vi=execStrVar[execLevel+1]; if vi == _tempArrayStringVarIndex { rs = gTempStringForArray } else if vi >= 1 { let vn=gVarNames[vi]; if let inf=gVariables[vn], case .string(let s)=inf.value{rs=s} } }
						execStack[execLevel] = ls == rs ? 1 : 0
					} else { execStack[execLevel] = tlEq == trEq ? 1 : 0 }
				case ._notEqualOpCode:
					execLevel -= 1
					let tlNe = execStack[execLevel], trNe = execStack[execLevel+1]
					if tlNe == _stringConstMarker || tlNe == _stringVarMarker ||
					   trNe == _stringConstMarker || trNe == _stringVarMarker {
						var ls = "", rs = ""
						if tlNe == _stringConstMarker { ls = gStringConstants[execStrConst[execLevel]] }
						else if tlNe == _stringVarMarker { let vi=execStrVar[execLevel]; if vi == _tempArrayStringVarIndex { ls = gTempStringForArray } else if vi >= 1 { let vn=gVarNames[vi]; if let inf=gVariables[vn], case .string(let s)=inf.value{ls=s} } }
						if trNe == _stringConstMarker { rs = gStringConstants[execStrConst[execLevel+1]] }
						else if trNe == _stringVarMarker { let vi=execStrVar[execLevel+1]; if vi == _tempArrayStringVarIndex { rs = gTempStringForArray } else if vi >= 1 { let vn=gVarNames[vi]; if let inf=gVariables[vn], case .string(let s)=inf.value{rs=s} } }
						execStack[execLevel] = ls != rs ? 1 : 0
					} else { execStack[execLevel] = tlNe != trNe ? 1 : 0 }
				case ._greaterOpCode:
					execLevel -= 1
					let tlGt = execStack[execLevel], trGt = execStack[execLevel+1]
					if tlGt == _stringConstMarker || tlGt == _stringVarMarker ||
					   trGt == _stringConstMarker || trGt == _stringVarMarker {
						var ls = "", rs = ""
						if tlGt == _stringConstMarker { ls = gStringConstants[execStrConst[execLevel]] }
						else if tlGt == _stringVarMarker { let vi=execStrVar[execLevel]; if vi == _tempArrayStringVarIndex { ls = gTempStringForArray } else if vi >= 1 { let vn=gVarNames[vi]; if let inf=gVariables[vn], case .string(let s)=inf.value{ls=s} } }
						if trGt == _stringConstMarker { rs = gStringConstants[execStrConst[execLevel+1]] }
						else if trGt == _stringVarMarker { let vi=execStrVar[execLevel+1]; if vi == _tempArrayStringVarIndex { rs = gTempStringForArray } else if vi >= 1 { let vn=gVarNames[vi]; if let inf=gVariables[vn], case .string(let s)=inf.value{rs=s} } }
						execStack[execLevel] = ls > rs ? 1 : 0
					} else { execStack[execLevel] = tlGt > trGt ? 1 : 0 }
				case ._lessOpCode:
					execLevel -= 1
					let tlLt = execStack[execLevel], trLt = execStack[execLevel+1]
					if tlLt == _stringConstMarker || tlLt == _stringVarMarker ||
					   trLt == _stringConstMarker || trLt == _stringVarMarker {
						var ls = "", rs = ""
						if tlLt == _stringConstMarker { ls = gStringConstants[execStrConst[execLevel]] }
						else if tlLt == _stringVarMarker { let vi=execStrVar[execLevel]; if vi == _tempArrayStringVarIndex { ls = gTempStringForArray } else if vi >= 1 { let vn=gVarNames[vi]; if let inf=gVariables[vn], case .string(let s)=inf.value{ls=s} } }
						if trLt == _stringConstMarker { rs = gStringConstants[execStrConst[execLevel+1]] }
						else if trLt == _stringVarMarker { let vi=execStrVar[execLevel+1]; if vi == _tempArrayStringVarIndex { rs = gTempStringForArray } else if vi >= 1 { let vn=gVarNames[vi]; if let inf=gVariables[vn], case .string(let s)=inf.value{rs=s} } }
						execStack[execLevel] = ls < rs ? 1 : 0
					} else { execStack[execLevel] = tlLt < trLt ? 1 : 0 }
				case ._greaterEqOpCode:
					execLevel -= 1
					let tlGe = execStack[execLevel], trGe = execStack[execLevel+1]
					if tlGe == _stringConstMarker || tlGe == _stringVarMarker ||
					   trGe == _stringConstMarker || trGe == _stringVarMarker {
						var ls = "", rs = ""
						if tlGe == _stringConstMarker { ls = gStringConstants[execStrConst[execLevel]] }
						else if tlGe == _stringVarMarker { let vi=execStrVar[execLevel]; if vi == _tempArrayStringVarIndex { ls = gTempStringForArray } else if vi >= 1 { let vn=gVarNames[vi]; if let inf=gVariables[vn], case .string(let s)=inf.value{ls=s} } }
						if trGe == _stringConstMarker { rs = gStringConstants[execStrConst[execLevel+1]] }
						else if trGe == _stringVarMarker { let vi=execStrVar[execLevel+1]; if vi == _tempArrayStringVarIndex { rs = gTempStringForArray } else if vi >= 1 { let vn=gVarNames[vi]; if let inf=gVariables[vn], case .string(let s)=inf.value{rs=s} } }
						execStack[execLevel] = ls >= rs ? 1 : 0
					} else { execStack[execLevel] = tlGe >= trGe ? 1 : 0 }
				case ._lessEqOpCode:
					execLevel -= 1
					let tlLe = execStack[execLevel], trLe = execStack[execLevel+1]
					if tlLe == _stringConstMarker || tlLe == _stringVarMarker ||
					   trLe == _stringConstMarker || trLe == _stringVarMarker {
						var ls = "", rs = ""
						if tlLe == _stringConstMarker { ls = gStringConstants[execStrConst[execLevel]] }
						else if tlLe == _stringVarMarker { let vi=execStrVar[execLevel]; if vi == _tempArrayStringVarIndex { ls = gTempStringForArray } else if vi >= 1 { let vn=gVarNames[vi]; if let inf=gVariables[vn], case .string(let s)=inf.value{ls=s} } }
						if trLe == _stringConstMarker { rs = gStringConstants[execStrConst[execLevel+1]] }
						else if trLe == _stringVarMarker { let vi=execStrVar[execLevel+1]; if vi == _tempArrayStringVarIndex { rs = gTempStringForArray } else if vi >= 1 { let vn=gVarNames[vi]; if let inf=gVariables[vn], case .string(let s)=inf.value{rs=s} } }
						execStack[execLevel] = ls <= rs ? 1 : 0
					} else { execStack[execLevel] = tlLe <= trLe ? 1 : 0 }

				case ._ifThenOpCode:
					let cond = execStack[execLevel]; execLevel -= 1
					if cond == 0.0 {
						break bodyLoop   // IF false — skip rest of body
					}

				case ._returnOpCode:
					break bodyLoop   // RETURN — stop executing body lines cleanly

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
				// Uses local pair tables (localWhilePairs / localWhileEnds) so the
				// global gWhilePairs / gWhileEnds are never touched from this thread.
				case ._whileOpCode:
					let cond = execStack[execLevel]; execLevel -= 1
					if cond == 0.0 {
						// Condition false — jump past the closing }
						if let exitLine = localWhilePairs[pc] {
							pc = exitLine
							// Continue outer while loop (will hit guard codeArray[0]>0 and pc+=1)
							break   // break switch, then execIndex+=1 finishes inner while
						}
						// No matching } found — stop body execution
						break bodyLoop
					}
					// Condition true — push onto local timer while stack, fall through into body
					timerWhileStack.append(WhileLoopInfo(conditionPC: pc, endPC: localWhilePairs[pc] ?? pc))

				case ._whileEndOpCode:
					// Jump back to the matching WHILE line to re-test condition
					if let whileLine = localWhileEnds[pc] {
						pc = whileLine - 1   // will be incremented to whileLine by pc += 1 below
					}
					// If timerWhileStack is non-empty the WHILE opcode will handle pop on false

					// Milestone 14: INKEY$ inside timer callback.
					// inkeyMode is already true (set when RUN began); keys have been queuing.
					// pscriptInkey() is NSLock-protected — safe to call from gTimerQueue.
					// Pushes result as a string constant onto the eval stack.
					case ._inkeyOpCode:
						execLevel += 1
						let timerInkey = interp.delegate?.pscriptInkey() ?? ""
						let timerInkeySI = interp.storeStringConst(value: timerInkey)
						execStack[execLevel] = _stringConstMarker
						execStrConst[execLevel] = timerInkeySI

					// Ignore timer-control opcodes inside a timer callback (no recursion)
					case ._timerDeclOpCode: execIndex += 1   // skip funcNameIdx operand
					case ._timerOnOpCode, ._timerStopOpCode, ._timerOffOpCode: break

				default: break   // unknown opcode in timer body — skip silently
				}
				execIndex += 1
			}
			pc += 1
		}
	}
	
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
		print("Parse error: \(errMsg)")
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
		addToSymTable(opStr: "SAMPLE", type: ._keywordType, opcode: ._sampleOpCode)
		
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
		
		addToSymTable(opStr: "INT", type: ._typeNameType, opcode: ._INTopCode)
		addToSymTable(opStr: "FLOAT", type: ._typeNameType, opcode: ._noOpCode)
		addToSymTable(opStr: "STRING", type: ._typeNameType, opcode: ._noOpCode)
		addToSymTable(opStr: "BOOL", type: ._typeNameType, opcode: ._noOpCode)
	}
	
	//--| STRING/CONSTANT STORAGE |-----
	
	func storeParsedConst(value: Double) -> Int {
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
		if gNumStringConsts > 0 {
			for j in 1...gNumStringConsts {
				if value == gStringConstants[j] { return j }
			}
		}
		
		if gNumStringConsts < _maxNumConsts {
			gNumStringConsts += 1
			gStringConstants[gNumStringConsts] = value
			return gNumStringConsts
		} else {
			parseError(errMsg: "Too many string constants")
			return 1
		}
	}
	
	func storeVarName(name: String) -> Int {
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
		for j in 1...gNumSyms {
			if isStringInText(soughtStr: gSymTable[j], inString: gTextPtr, startPos: gCharPos) {
				let symLen = gSymTable[j].count
				
				if gSymType[j] == ._keywordType || gSymType[j] == ._typeNameType || gSymType[j] == ._unaryOpType {
					let nextPos = gCharPos + symLen - 1
					if nextPos < gTextPtr.count {
						let nextCh = getChar(theString: gTextPtr, charIndex: nextPos)
						if isAlphaNumeric(nextCh) {
							continue
						}
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
			parseError(errMsg: "Syntax error")
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
			if gCode > 0 && gCode <= gNumVarNames {
				let varNameIdx = gCode  // SAVE the variable index before getLexeme changes gCode!
				let varName = gVarNames[varNameIdx]

				// Milestone 14: INKEY$ — emit _inkeyOpCode directly, no arguments.
				// Registered as _readVarType so it arrives in factor() as a value.
				// Runtime: delegate?.pscriptInkey() is called; returns "" if no key waiting.
				if varName.uppercased() == "INKEY$" {
					plantCode(code: evalOPcodes._inkeyOpCode.rawValue)
					return getLexeme()
				}

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
				// Normal unary operators (SIN, COS, LEN, etc.)
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
				type = comparison(type: type)
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
		
		// Check for array declaration syntax: var myArray[size]
		if type == ._leftBracketType {
			isArray = true
			type = getLexeme()
			
			// Parse the array size (must be a constant or expression)
			type = comparison(type: type)
			if gParseError { return false }
			
			// For now, we need to evaluate the size expression immediately
			// This is a simplification - size must be a literal number for now
			guard type == ._rightBracketType else {
				parseError(errMsg: "Expected ] after array size")
				return false
			}
			
			// Evaluate the size expression to get the actual size
			let sizeResult = evaluate(codeArray: gMyCodeArray, litConsts: gParsedConstants, xVar: 0, yVar: 0)
			if sizeResult.error {
				parseError(errMsg: "Invalid array size")
				return false
			}
			
			arraySize = Int(sizeResult.result)
			if arraySize <= 0 {
				parseError(errMsg: "Array size must be positive")
				return false
			}
			
			// Reset code array for the rest of the declaration
			gMyCodeArray[0] = 0
			
			type = getLexeme()
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
		
		// Convert to array type if this is an array declaration
		if isArray {
			varType = VarType.arrayType(from: varType)
			
			// Initialize the array storage
			initializeArray(name: varName, size: arraySize, type: varType)
			
			// Store array info: if inside a function body at parse time, register locally
			if let funcName = gCurrentParseFuncName {
				if gFunctionLocalTypes[funcName] == nil { gFunctionLocalTypes[funcName] = [:] }
				gFunctionLocalTypes[funcName]![varName] = varType
			} else {
				gVariableTypes[varName] = varType
				gVariables[varName] = VariableInfo(type: varType, value: .int(0), arraySize: arraySize)
			}
			
			// Array declarations don't need an = assignment
			return true
		}
		
		// For scalar variables, expect = assignment
		if type != ._assignOpType || gSymTable[gCode] != "=" {
			parseError(errMsg: "Expected = in variable declaration")
			return false
		}
		
		type = getLexeme()
		type = comparison(type: type)
		
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
	
	// Parse array indexing: arrayName[index]
	func parseArrayAccess(varName: String, isAssignment: Bool) -> lexemeTypes? {
		if gParseError { return nil }
		
		// We've already seen the variable name and [
		// Now parse the index expression
		var type = getLexeme()
		type = comparison(type: type)
		
		if gParseError { return nil }
		
		guard type == ._rightBracketType else {
			parseError(errMsg: "Expected ] after array index")
			return nil
		}
		
		// Now the stack has the index value
		// Emit appropriate opcode
		if isAssignment {
			// For assignment: arr[i] = value
			// Stack will be: [index, value]
			// We need to emit store opcode
			plantCode(code: evalOPcodes._arrayStoreOpCode.rawValue)
			plantCode(code: storeVarName(name: varName))
		} else {
			// For reading: x = arr[i]
			// Stack has: [index]
			// Emit load opcode
			plantCode(code: evalOPcodes._arrayLoadOpCode.rawValue)
			plantCode(code: storeVarName(name: varName))
		}
		
		return getLexeme()
	}
	
	func parseAssignment(varName: String) -> Bool {
		if gParseError { return false }
		
		var type = getLexeme()
		type = comparison(type: type)
		
		if gParseError { return false }
		
		plantCode(code: evalOPcodes._storeVarOpCode.rawValue)
		plantCode(code: storeVarName(name: varName))
		
		return true
	}
	
	func parseArrayAssignment(varName: String) -> Bool {
		if gParseError { return false }
		
		// We've already consumed [ in parseStatement
		// Parse index expression
		var type = getLexeme()
		type = comparison(type: type)
		if gParseError {
			return false
		}
		
		guard type == ._rightBracketType else {
			parseError(errMsg: "Expected ] after array index")
			return false
		}
		
		// Now expect =
		type = getLexeme()
		guard type == ._assignOpType && gSymTable[gCode] == "=" else {
			parseError(errMsg: "Expected = after array index")
			return false
		}
		
		// Parse the value expression
		type = getLexeme()
		type = comparison(type: type)
		if gParseError {
			return false
		}
		
		// Stack now has: [index, value]
		plantCode(code: evalOPcodes._arrayStoreOpCode.rawValue)
		plantCode(code: storeVarName(name: varName))
		
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
		type = comparison(type: type)
		
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
		type = comparison(type: type)
		if gParseError { return false }

		// Expect comma separator
		guard type == ._assignOpType && gSymTable[gCode] == "," else {
			parseError(errMsg: "Expected , between row and col in LOCATE")
			return false
		}

		// Parse col expression
		type = getLexeme()
		type = comparison(type: type)
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
		type = comparison(type: type)
		if gParseError { return false }
		guard type == ._assignOpType && gSymTable[gCode] == "," else {
			parseError(errMsg: "Expected , after POINT x")
			return false
		}

		// y
		type = getLexeme()
		type = comparison(type: type)
		if gParseError { return false }

		var argCount = 2

		// Optional R, G, B, A
		if type == ._assignOpType && gSymTable[gCode] == "," {
			for i in 0..<4 {
				type = getLexeme()
				type = comparison(type: type)
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
		type = comparison(type: type)
		if gParseError { return false }
		guard type == ._assignOpType && gSymTable[gCode] == "," else {
			parseError(errMsg: "Expected , after LINE x1")
			return false
		}

		// y1
		type = getLexeme()
		type = comparison(type: type)
		if gParseError { return false }
		guard type == ._assignOpType && gSymTable[gCode] == "," else {
			parseError(errMsg: "Expected , after LINE y1")
			return false
		}

		// x2
		type = getLexeme()
		type = comparison(type: type)
		if gParseError { return false }
		guard type == ._assignOpType && gSymTable[gCode] == "," else {
			parseError(errMsg: "Expected , after LINE x2")
			return false
		}

		// y2
		type = getLexeme()
		type = comparison(type: type)
		if gParseError { return false }

		var argCount = 4

		// Optional R, G, B, A
		if type == ._assignOpType && gSymTable[gCode] == "," {
			for i in 0..<4 {
				type = getLexeme()
				type = comparison(type: type)
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

	// Parse SAMPLE statement/expression
	// Syntax: SAMPLE(x, y, channel)  — channel: 0=A 1=R 2=G 3=B
	// Returns a Float pushed onto the eval stack.
	// Emits: _sampleOpCode, argCount (always 3)
	// NOTE: execution is stubbed — SAMPLE read-back is deferred to a future milestone.
	func parseSampleStatement() -> Bool {
		if gParseError { return false }

		var type = getLexeme()
		guard type == ._leftParenType else {
			parseError(errMsg: "Expected ( after SAMPLE")
			return false
		}

		// x
		type = getLexeme()
		type = comparison(type: type)
		if gParseError { return false }
		guard type == ._assignOpType && gSymTable[gCode] == "," else {
			parseError(errMsg: "Expected , after SAMPLE x")
			return false
		}

		// y
		type = getLexeme()
		type = comparison(type: type)
		if gParseError { return false }
		guard type == ._assignOpType && gSymTable[gCode] == "," else {
			parseError(errMsg: "Expected , after SAMPLE y")
			return false
		}

		// channel
		type = getLexeme()
		type = comparison(type: type)
		if gParseError { return false }

		guard type == ._rightParenType else {
			parseError(errMsg: "Expected ) after SAMPLE arguments")
			return false
		}

		plantCode(code: evalOPcodes._sampleOpCode.rawValue)
		plantCode(code: 3)
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
		type = comparison(type: type)
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
	// The opening { may be on the same line or the next line — handled by preScanWhileLoops().
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
		type = comparison(type: type)
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
		type = comparison(type: type)
		if gParseError { return false }
		
		guard type == ._keywordType && gSymTable[gCode].uppercased() == "THEN" else {
			parseError(errMsg: "Expected THEN after IF condition")
			return false
		}
		
		// The condition result is on the stack
		// Plant ifThen opcode - if false (0), skip rest of execution for this line
		plantCode(code: evalOPcodes._ifThenOpCode.rawValue)
		
		// Now parse the statement after THEN
		type = getLexeme()
		
		if type == ._keywordType {
			let keyword = gSymTable[gCode].uppercased()
			switch keyword {
			case "PRINT":
				return parsePrintStatement()
			case "RETURN":
				return parseReturnStatement()
			case "CLS":
				return parseCLSStatement()
			case "END":
				return parseEndStatement()
			case "NEXT":
				return parseNextStatement()
			// Milestone 14: timer control and locate allowed after THEN
			// (needed for game loops: if k$ == "ESC" then timeroff)
			case "TIMEROFF":
				plantCode(code: evalOPcodes._timerOffOpCode.rawValue)
				return true
			case "TIMERSTOP":
				plantCode(code: evalOPcodes._timerStopOpCode.rawValue)
				return true
			case "TIMERON":
				plantCode(code: evalOPcodes._timerOnOpCode.rawValue)
				return true
			case "LOCATE":
				return parseLocateStatement()
			case "CLR":
				plantCode(code: evalOPcodes._clrOpCode.rawValue)
				return true
			default:
				parseError(errMsg: "Unsupported statement after THEN: \(keyword)")
				return false
			}
		} else if type == ._readVarType {
			// Variable assignment or array assignment after THEN
			let varName = gVarNames[gCode]
			type = getLexeme()

			if type == ._leftBracketType {
				// Array assignment: arr[expr] = value
				return parseArrayAssignment(varName: varName)
			} else if type == ._assignOpType && gSymTable[gCode] == "=" {
				return parseAssignment(varName: varName)
			} else {
				parseError(errMsg: "Expected assignment after THEN")
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
			type = comparison(type: type)
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

		// Milestone 4 / 10: bare closing brace } — could close a func body or a WHILE body.
		// Check gWhileEnds first (Milestone 10): if this line is a WHILE-closing brace,
		// emit _whileEndOpCode so the executor can jump back to re-test the condition.
		// Otherwise it's a func-closing brace — emit nothing (existing behaviour).
		if type == ._rightBraceType {
			if gWhileEnds[gCurrentParseLineNum] != nil {
				// This } closes a WHILE block — emit the loop-back opcode
				plantCode(code: evalOPcodes._whileEndOpCode.rawValue)
			}
			// func-closing } emits nothing — executor uses preScanFunctions() bodyEndLine
			return true
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
			case "SAMPLE":
				return parseSampleStatement()
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
			
			// Check for array assignment: arr[...] = ...
			if type == ._leftBracketType {
				return parseArrayAssignment(varName: varName)
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
					parseError(errMsg: "Syntax error")
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

	// Milestone 10: Pre-scan gProgramLines to find all WHILE / } pairs.
	// Populates gWhilePairs (WHILE-line → closing-brace-line) and
	// gWhileEnds (closing-brace-line → WHILE-line).
	// Must be called after preScanFunctions() so that func-body braces are
	// already known and can be excluded from WHILE pairing.
	//
	// Algorithm: walk lines top-to-bottom; push WHILE line indices onto a
	// stack; when a } is found that is NOT a func-body closer, pop the stack
	// and record the pair.  Brace depth tracking handles nested WHILEs.
	func preScanWhileLoops() {
		gWhilePairs.removeAll()
		gWhileEnds.removeAll()

		// Build a set of ALL line indices that belong to func bodies
		// (including the closing } line of each func) — these braces are
		// already claimed by preScanFunctions() and must not be re-used for WHILE.
		var funcOwnedLines = Set<Int>()
		for (_, def) in gFunctionDefs {
			// Header line (bodyStartLine - 1) and all body lines including closing }
			if def.bodyStartLine > 0 { funcOwnedLines.insert(def.bodyStartLine - 1) }
			for li in def.bodyStartLine...max(def.bodyStartLine, def.bodyEndLine) {
				funcOwnedLines.insert(li)
			}
		}

		// Stack of WHILE-line indices waiting for their matching }
		var whileStack: [Int] = []

		for (i, line) in gProgramLines.enumerated() {
			// Skip lines owned by func bodies — their braces are not WHILE braces
			if funcOwnedLines.contains(i) { continue }

			let trimmed = line.trimmingCharacters(in: .whitespaces)
			let upper = trimmed.uppercased()

			// Detect a WHILE header: must start with WHILE followed by space or (
			if upper.hasPrefix("WHILE ") || upper.hasPrefix("WHILE(") {
				// The { may be on this line or the next.
				// Either way, this line index is the WHILE line — push it.
				whileStack.append(i)
			} else if upper == "{" || (upper.hasPrefix("{") && !upper.hasPrefix("{{")) {
				// A standalone { on its own line that is NOT a func opener.
				// This is the opening brace of a WHILE whose condition was on the
				// previous line.  No action needed — the WHILE line is already
				// on the stack; we just note this so the closing } pairs correctly.
				// (No push — the WHILE line index already on the stack is correct.)
				_ = i  // explicit no-op; prevents "unused" warning
			} else if trimmed.hasPrefix("}") && !whileStack.isEmpty {
				// Closing brace — pop the most recent WHILE and record the pair
				let whileLine = whileStack.removeLast()
				gWhilePairs[whileLine] = i
				gWhileEnds[i] = whileLine
			}
		}

		// Any unmatched WHILE entries indicate a syntax error in the program;
		// we leave them on the stack and let the executor report a runtime error.
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
		gCurrentParseLineNum = 0                   // Milestone 10
		gWhileLoopStack.removeAll()                // Milestone 10

		// Milestone 4: Pre-scan for function definitions BEFORE parsing any lines
		preScanFunctions()

		// Milestone 10: Pre-scan for WHILE / } pairs (must follow preScanFunctions
		// so func-owned braces are already excluded from WHILE pairing)
		preScanWhileLoops()

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
				print("Parse error at line \(lineNum + 1): \(line)")
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
			return (gVariables[varName]?.value, gVariables[varName]?.type == .stringType, storeVarName(name: varName))
		}

		func resolveVarType(varName: String) -> VarType? {
			if !gCallStack.isEmpty {
				let frame = gCallStack[gCallStack.count - 1]
				if let t = frame.localTypes[varName] { return t }
			}
			return gVariableTypes[varName]
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
			if let t = gVariableTypes[varName] {
				gVariables[varName] = VariableInfo(type: t, value: value)
			}
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
				case ._powerOpCode:
					execLevel -= 1
					execStack[execLevel] = pow(execStack[execLevel], execStack[execLevel+1])
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
						evalErr = true; print("Error: Variable \(varName) not declared"); break
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
					return
				case ._exitOpCode: exit(0)

				case ._arrayLoadOpCode:
					execIndex += 1
					let varNameIdx3 = execCodeArray[execIndex]
					let varName3 = gVarNames[varNameIdx3]
					let ai3 = Int(execStack[execLevel]); execLevel -= 1
					guard let vt3 = resolveVarType(varName: varName3) else {
						print("Error: Array \(varName3) not declared"); evalErr = true; break
					}
					if let av = getArrayElement(name: varName3, index: ai3, type: vt3) {
						execLevel += 1
						if vt3.baseType() == .stringType {
							if case .string(let s) = av { gTempStringForArray = s }
							else { gTempStringForArray = "" }
							execStack[execLevel] = _stringVarMarker; execStringVars[execLevel] = _tempArrayStringVarIndex
						} else { execStack[execLevel] = av.toDouble() }
					} else { print("Error: Array index \(ai3) out of bounds for \(varName3)"); evalErr = true }

				case ._arrayStoreOpCode:
					execIndex += 1
					let varNameIdx4 = execCodeArray[execIndex]
					let varName4 = gVarNames[varNameIdx4]
					let asVal = execStack[execLevel]; execLevel -= 1
					let asIdx = Int(execStack[execLevel]); execLevel -= 1
					guard let vt4 = resolveVarType(varName: varName4) else {
						print("Error: Array \(varName4) not declared"); evalErr = true; break
					}
					let asv: Value
					switch vt4.baseType() {
					case .intType:    asv = .int(Int(asVal))
					case .floatType:  asv = .float(asVal)
					case .stringType:
						if asVal == _stringConstMarker { asv = .string(gStringConstants[execStringConsts[execLevel+2]]) }
						else if asVal == _stringVarMarker {
							let si5=execStringVars[execLevel+2]; let sn5=gVarNames[si5]
							let (v5,_,_)=resolveVarRead(varName:sn5); asv=v5 ?? .string("")
						} else { asv = .string(String(format:"%.6g",asVal)) }
					case .boolType:   asv = .bool(asVal != 0.0)
					default: print("Error: Invalid array base type"); evalErr = true; asv = .int(0)
					}
					if !setArrayElement(name: varName4, index: asIdx, value: asv, type: vt4) {
						print("Error: Array index \(asIdx) out of bounds for \(varName4)"); evalErr = true
					}

				case ._forBeginOpCode:
					execIndex += 1; let lvName = gVarNames[execCodeArray[execIndex]]
					execIndex += 1; let hasStep = execCodeArray[execIndex]
					var stepVal = 1.0
					if hasStep == 1 { stepVal = execStack[execLevel]; execLevel -= 1 }
					let endVal = execStack[execLevel]; execLevel -= 1
					gForLoopStack.append(ForLoopInfo(varName: lvName, endValue: endVal, stepValue: stepVal, loopStartPC: pc + 1))

				case ._forNextOpCode:
					guard !gForLoopStack.isEmpty else { print("Error: NEXT without FOR"); evalErr = true; break }
					let li = gForLoopStack[gForLoopStack.count - 1]
					let (cv,_,_) = resolveVarRead(varName: li.varName)
					guard let cvi = cv else { print("Error: Loop variable not found"); evalErr = true; break }
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

				// Milestone 10: WHILE — test condition, jump past } if false, fall through if true
				case ._whileOpCode:
					let cond = execStack[execLevel]; execLevel -= 1
					if cond == 0.0 {
						// Condition false — jump to the line AFTER the closing }
						guard let exitLine = gWhilePairs[pc] else {
							print("Error: WHILE at line \(pc+1) has no matching }"); evalErr = true; break
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
						print("Error: } at line \(pc+1) has no matching WHILE"); evalErr = true; break
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
						print("Error: Function '\(fnName)' not defined"); evalErr = true; break
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
					guard !gCallStack.isEmpty else {
						print("Error: RETURN outside function"); evalErr = true; break
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
					let py = Int(execStack[execLevel]); execLevel -= 1
					let px = Int(execStack[execLevel]); execLevel -= 1
					if let d = delegate {
						d.pscriptPoint(x: px, y: py, r: pr, g: pg, b: pb, a: pa)
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
					let ly2 = Int(execStack[execLevel]); execLevel -= 1
					let lx2 = Int(execStack[execLevel]); execLevel -= 1
					let ly1 = Int(execStack[execLevel]); execLevel -= 1
					let lx1 = Int(execStack[execLevel]); execLevel -= 1
					if let d = delegate {
						d.pscriptLine(x1: lx1, y1: ly1, x2: lx2, y2: ly2, r: lr, g: lg, b: lb, a: la)
					}

				// pBasic: Graphics - CLR (clear Canvas)
				case ._clrOpCode: 
					if let d = delegate {
						d.pscriptClr()
					}
					
				// pBasic: Graphics — SAMPLE (stubbed — deferred to future milestone)
				case ._sampleOpCode:
					execIndex += 1
					// _ = execCodeArray[execIndex]  // argCount (always 3) — consumed but unused
					let _sampleChannel = Int(execStack[execLevel]); execLevel -= 1
					let _sampleY       = Int(execStack[execLevel]); execLevel -= 1
					let _sampleX       = Int(execStack[execLevel]); execLevel -= 1
					// Stub: push 0.0 as placeholder return value
					execLevel += 1
					execStack[execLevel] = 0.0
					print("SAMPLE(\(_sampleX), \(_sampleY), \(_sampleChannel)) — not yet implemented")
					
				default:
					evalErr = true
					print("Programming error: undefined opcode \(opcode) at line \(pc+1)")
				}

				execIndex += 1
			} // end innerLoop

			if evalErr {
				print("Runtime error at line \(pc + 1)")
				// Milestone 5: stop timer on runtime error so it doesn't keep firing
				timerOff()
				return
			}

			pc += 1
			guard loadNextLine() else { break lineLoop }
		} // end lineLoop

		// Program fell off the end — stop any running timer
		timerOff()
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

func processReplCommand(_ input: String, output: ((String) -> Void)? = nil, delegate: PScriptDelegate? = nil) -> Bool {

	// pBasic Step 2: single emit helper — routes to delegate output when
	// available, falls back to print() for the CLI build.
	let emit: (String) -> Void = output ?? { print($0) }

	let trimmed = input.trimmingCharacters(in: .whitespaces)
	let upper = trimmed.uppercased()
	
	if upper == "NEW" {
		gProgramLines.removeAll()
		gVariables.removeAll()
		gVariableTypes.removeAll()
		gFunctionDefs.removeAll()
		gCallStack.removeAll()
		gWhilePairs.removeAll()    // Milestone 10
		gWhileEnds.removeAll()     // Milestone 10
		gWhileLoopStack.removeAll() // Milestone 10
		// Milestone 5: also stop any running timer on NEW
		timerOff()
		emit("Program cleared")
		return true
	}
	
	if upper == "LIST" {
		if gProgramLines.isEmpty {
			emit("Program is empty")
		} else {
			for (index, line) in gProgramLines.enumerated() {
				let lineNum = (index + 1) * 10
				emit("\(lineNum) \(line)")
			}
		}
		return true
	}
	
	if upper == "RUN" {
		if gProgramLines.isEmpty {
			emit("No program to run")
		} else {
			let parser = parseEval(exprString: "")
			// pBasic Step 2: wire delegate so RUN output goes to the terminal display
			parser.delegate = delegate
			// Milestone 14: activate inkeyMode for the entire program run.
			// DispatchQueue.main.sync is required — processReplCommand() is called
			// from the pScript background thread (Lesson 4, LessonsLearned.txt).
			// The defer covers all exit paths: normal end, END keyword, CTRL-C,
			// and runtime error.  exit(0) from EXIT kills the process — defer
			// never fires but inkeyMode being stuck is irrelevant (process is dead).
			// The timer fires during this window — inkeyMode is already true, so
			// keys queue normally and pscriptInkey() drains them from gTimerQueue.
			if let d = delegate {
				DispatchQueue.main.sync { d.pscriptExecutionWillBegin() }
			}
			defer {
				if let d = delegate {
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
			gWhilePairs.removeAll()     // Milestone 10
			gWhileEnds.removeAll()      // Milestone 10
			gWhileLoopStack.removeAll() // Milestone 10
			// Milestone 5: stop any running timer before loading new program
			timerOff()
			
			let lines = contents.components(separatedBy: .newlines)
			for line in lines {
				let trimmedLine = line.trimmingCharacters(in: .whitespaces)
				if !trimmedLine.isEmpty && !trimmedLine.hasPrefix("//") {
					gProgramLines.append(trimmedLine)
				}
			}
			
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
	
	if upper.hasPrefix("DELETE ") || upper.hasPrefix("DEL ") {
		let parts = trimmed.split(separator: " ")
		if parts.count >= 2, let lineNum = Int(parts[1]) {
			let lineIndex = (lineNum / 10) - 1
			if lineIndex >= 0 && lineIndex < gProgramLines.count {
				gProgramLines.remove(at: lineIndex)
				emit("Line \(lineNum) deleted")
			} else {
				emit("Line \(lineNum) not found")
			}
		} else {
			emit("Usage: DELETE linenum  (e.g., DELETE 20)")
		}
		return true
	}
	
	let words = trimmed.split(separator: " ", maxSplits: 1)
	if let lineNum = Int(words[0]) {
		if words.count == 1 {
			emit("To delete line \(lineNum), use: DELETE \(lineNum)")
			return true
		} else {
			let code = String(words[1])
			var insertIndex = 0
			
			for (index, _) in gProgramLines.enumerated() {
				let existingLineNum = (index + 1) * 10
				if lineNum < existingLineNum { break }
				insertIndex = index + 1
			}
			
			let targetLineNum = insertIndex * 10
			if insertIndex < gProgramLines.count && lineNum == targetLineNum {
				gProgramLines[insertIndex] = code
			} else {
				gProgramLines.insert(code, at: insertIndex)
			}
			
			return true
		}
	}
	
	if upper == "HELP" {
		emit("pScript v0.7.0 \u{2022} Copyright 2026 John Roland Penner")
		emit("")
		emit("REPL Commands:")
		emit("  NEW, LIST, RUN, CLS, QUIT")
		emit("  LOAD \"file.bas\", SAVE \"file.bas\"  (files in ~/Documents/)")
		emit("  DELETE linenum  (remove program line)")
		emit("  DIR [path]  (e.g., DIR, DIR pBasic, DIR ~/Pictures)")
		emit("")
		emit("Keywords:")
		emit("  VAR name : Type = value    (Int, Float, String, Bool)")
		emit("  VAR arr[size] : Type       (1D arrays)")
		emit("  PRINT expr; or expr        (; suppresses newline)")
		emit("  INPUT var or INPUT \"prompt\"; var")
		emit("  FOR var = start TO end [STEP n] ... NEXT var")
		emit("  IF condition THEN statement")
		emit("  WHILE (condition) { ... }")
		emit("  TAB(n), LEN(), MID$(), CLS, END, EXIT")
		emit("")
		emit("Functions (Milestone 4):")
		emit("  func name(param1, param2) {")
		emit("      var local : Type = value")
		emit("      return expression")
		emit("  }")
		emit("  Call: var result = name(arg1, arg2)")
		emit("  Recursive calls supported.")
		emit("")
		emit("Timer:")
		emit("  TIMER 1.0 funcName   (declare interval in seconds + callback)")
		emit("  TIMERON              (start or resume timer)")
		emit("  TIMERSTOP            (suspend timer, remembers pending events)")
		emit("  TIMEROFF             (invalidate timer; must redeclare to restart)")
		emit("  Timer auto-stops on END, runtime error, or program completion.")
		emit("")
		emit("Operators:")
		emit("  Math: + - * / ^            Comparison: == <> > < >= <=")
		emit("")
		emit("Built-in Functions:")
		emit("  SIN COS TAN ATAN SQRT SQR EXP LOG LOG10 ABS INT RND")
		emit("  LEN() MID$()")
		emit("  Constants: PI, DATE, TIME")
		emit("")
		emit("Usage:")
		emit("  Interactive: type statements at > prompt")
		emit("  Program: linenum statement  (e.g., 10 PRINT \"Hello\")")
		emit("  Run file: ./pscript filename.bas")
		emit("  STDIN: echo "John Penner" | pscript ~/reverse.bas")
		emit("")
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
			
			emit("\(paddedName)\(paddedSize)\t\(dateString)")
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
			
			// Split into lines and add to program
			let lines = contents.components(separatedBy: .newlines)
			for line in lines {
				let trimmedLine = line.trimmingCharacters(in: .whitespaces)
				if !trimmedLine.isEmpty && !trimmedLine.hasPrefix("//") {
					gProgramLines.append(trimmedLine)
				}
			}
			
			// Run the program
			let parser = parseEval(exprString: "")
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
		print("pScript v0.7.1 \u{2022} Copyright 2026 John Roland Penner")
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
		parser.initSymbolTable()
		parser.initNumSearchStrings()
		
		if parser.parseStatement() {
			if gMyCodeArray[0] > 0 {
				let result = parser.evaluate(codeArray: gMyCodeArray, litConsts: gParsedConstants, xVar: 1.0, yVar: 2.01)
				if !result.error {
					// Statement executed successfully
				} else {
					print("Runtime error")
				}
			}
		} else {
			print("Syntax error")
		}
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

