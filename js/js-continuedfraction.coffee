###
#Copyright (c) 2002-2013
#   Jason Siefken
#
#js-continuedfraction is free software: you can redistribute it and/or modify
#it under the terms of the GNU General Public License as published by
#the Free Software Foundation, either version 3 of the License, or
#(at your option) any later version.
#
#This program is distributed in the hope that it will be useful,
#but WITHOUT ANY WARRANTY; without even the implied warranty of
#MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#GNU General Public License for more details.
#
#You should have received a copy of the GNU General Public License
#along with this program.  If not, see <http://www.gnu.org/licenses/>.
###

###
# Continued fraction library for javascript
###
class ContinuedFraction
    MAX_CONTINUANT: 100000
    constructor: (val) ->
        @update(val)
    update: (val=0) ->
        @continuants = []
        @convergents = []
        if val instanceof Array
            @continuants = val.slice()
        else
            @continuants = @continuantsFromNum(val)
        @computeConvergents()
        @value = @computeValue()
    continuantsFromNum: (num) ->
        ret = []
        if num >= 1
            ret.push Math.floor(num)
            num -= Math.floor(num)
        else
            ret.push 0
        for i in [1..30]
            i = Math.floor(1/num)
            # for floating point numbers, if we get too high a continuant,
            # it likely means we've exactly approximated the number and the rest
            # is rounding error
            if i > @MAX_CONTINUANT
                break
            ret.push i
            num = 1/num - i
        # our continued fractions should never end in a 1
        if ret[ret.length - 1] is 1 and ret.length > 1
            ret[ret.length - 2] += 1
            ret.length = ret.length - 1
        return ret
    computeConvergents: (n) ->
        p = 1
        q = 0
        pp = 0
        qq = 1
        for i in [0...@continuants.length]
            tmpp = p
            tmpq = q
            p = @continuants[i]*p + pp
            q = @continuants[i]*q + qq
            pp = tmpp
            qq = tmpq
            @convergents.push [p,q]
        return
    computeValue: ->
        approx = @convergents[@convergents.length - 1]
        return approx[0]/approx[1]
    toLatex: (maxLevels=Infinity) ->
        toLatex = (coeff) ->
            if coeff.length == 0
                return ""
            if coeff.length == 1
                return "#{coeff[0]}"
            ret = ""
            if coeff[0] != 0
                ret += "#{coeff[0]} + "
            ret += "\\cfrac{1}{"
            ret += toLatex(coeff.slice(1))
            ret += "}"
            return ret
        return toLatex(@continuants.slice(0,maxLevels))
    toString: ->
        toString = (coeff) ->
            if coeff.length == 0
                return ""
            if coeff.length == 1
                return "#{coeff[0]}"
            ret = ""
            if coeff[0] != 0
                ret += "#{coeff[0]} + "
            ret += "1/("
            ret += toLatex(coeff.slice(1))
            ret += ")"
            return ret
        return toString(@continuants)

###
# Synchronize input boxes to accept math input and update 
# the continued fraction object.
#
# Arguments:
#   decimalInput: the <input/> where you type a decimal number
#   continuedFractionInput: the <input/> where you type a cf comma separated list
#   updateCallback: the function to be called whenever the cf is changed
#   createInputs: bool specifying if you'd like <input/> to be created for you
# Returns: object with properties
#   fraction: the ContinuedFraction object
#   decimalInput: the <input/> for decimals or null
#   continuedFractionInput: the <input/> for cf or null
#   inputs: the parent element of the inputs or null
#   updateCallback: the function called whenever the cf is changed or null
###
inputbox = (ops={}) ->
    {decimalInput, continuedFractionInput} = ops
    if typeof decimalInput is 'string'
        decimalInput = document.querySelector(decimalInput)
    if typeof continuedFractionInput is 'string'
        continuedFractionInput = document.querySelector(continuedFractionInput)
    
    if ops.createInputs
        inputs = createFragment """
            <div id="inputarea">
                <div class="inputblock">
                    <label for="decimal">Decimal:</label>
                    <input id="decimal" name="decimal" />
                </div>
                <div class="inputblock">
                    <label for="continuedfraction">Continued Fraction:</label>
                    <input id="continuedfraction" name="continuedfraction" />
                </div>
            </div>
            """
        decimalInput = inputs.querySelector('#decimal')
        continuedFractionInput = inputs.querySelector('#continuedfraction')

    {updateCallback} = ops
    frac = new ContinuedFraction
    
    updateFraction = (inputType) ->
        switch inputType
            when 'decimal'
                frac.update evaluateMath(decimalInput.value) if decimalInput
                continuedFractionInput.value = frac.continuants if continuedFractionInput
            when 'continuedfraction'
                values = evaluateMath(continuedFractionInput.value) if continuedFractionInput
                values = (v for v in (values || []) when v?)
                frac.update values
                decimalInput.value = frac.value if decimalInput
        updateCallback?(frac)
    
    timer = new ExclusiveTimer
    if decimalInput?
        decimalTracker = new TextAreaChangeTracker(decimalInput)
        decimalTracker.change ->
            timer.setTimeout(updateFraction, 250, 'decimal')
    if continuedFractionInput
        continuedfractionTracker = new TextAreaChangeTracker(continuedFractionInput)
        continuedfractionTracker.change ->
            timer.setTimeout(updateFraction, 250, 'continuedfraction')

    ret =
        fraction: frac
        decimalInput: decimalInput
        continuedFractionInput: continuedFractionInput
        updateCallback: updateCallback
        inputs: inputs
    return ret

###
# Creates an html fragment from the given string
###
createFragment = (str) ->
    frag = document.createDocumentFragment()
    div = document.createElement('div')
    div.innerHTML = str
    while div.firstChild
        frag.appendChild div.firstChild

    return frag

###
# ExclusiveTimer keeps a queue of all timeout
# callbacks, but only issues the most recent one.
# That is, if another callback request is added before the
# timer on the previous one runs out, only the new one is executed
# (when it's time has elapased) and the previous one is ignored.
###
class ExclusiveTimer
    constructor: ->
        @queue = []
    setTimeout: (callback, delay, args=[]) ->
        if not (args instanceof Array)
            args = [args]

        for c in @queue
            c.execute = false
        myIndex = @queue.length
        @queue.push {callback: callback, execute: true}

        doCallback = =>
            if @queue[myIndex]?.execute
                @queue[myIndex].callback.apply(null, args)
                @queue.length = 0

        window.setTimeout(doCallback, delay)

###
# Keep track of all changes to a particular textarea
# including ones that may happen on keyup, keydown, blur,
# etc.
###
class TextAreaChangeTracker
    constructor: (@textarea) ->
        if typeof @textarea is 'string'
            @textarea = document.querySelector(@textarea)
        @value = @textarea.value
        @onchangeCallbacks = []

        for event in ['change', 'keydown', 'keypress', 'blur']
            @textarea.addEventListener(event, (=>
                window.setTimeout(@_triggerIfChanged,100)))

    _triggerIfChanged: =>
        #@textarea.blur()
        newVal = @textarea.value
        if newVal != @value
            @value = newVal
            for c in @onchangeCallbacks
                c()
    change: (callback) ->
        @onchangeCallbacks.push callback
###
# All the useful math functions
# Taken from graphit: https://github.com/siefkenj/graphit
###
MathFunctions =
    random: Math.random
    tan: Math.tan
    min: Math.min
    PI: Math.PI
    sqrt: Math.sqrt
    E: Math.E
    SQRT1_2: Math.SQRT1_2
    ceil: Math.ceil
    atan2: Math.atan2
    cos: Math.cos
    LN2: Math.LN2
    LOG10E: Math.LOG10E
    exp: Math.exp
    round: (n, places) ->
        shift = Math.pow(10, places)
        return Math.round(n*shift) / shift
    atan: Math.atan
    max: Math.max
    pow: Math.pow
    LOG2E: Math.LOG2E
    log: Math.log
    LN10: Math.LN10
    floor: Math.floor
    SQRT2: Math.SQRT2
    asin: Math.asin
    acos: Math.acos
    sin: Math.sin
    abs: Math.abs
    cpi: "\u03C0"
    ctheta: "\u03B8"
    pi: Math.PI
    phi: (1+Math.sqrt(5))/2
    ln: Math.log
    e: Math.E
    sign: (x) ->
        (if x is 0 then 0 else ((if x < 0 then -1 else 1)))
    arcsin: Math.asin
    arccos: Math.acos
    arctan: Math.atan
    sinh: (x) ->
        (Math.exp(x) - Math.exp(-x)) / 2
    cosh: (x) ->
        (Math.exp(x) + Math.exp(-x)) / 2
    tanh: (x) ->
        (Math.exp(x) - Math.exp(-x)) / (Math.exp(x) + Math.exp(-x))
    arcsinh: (x) ->
        ln x + Math.sqrt(x * x + 1)
    arccosh: (x) ->
        ln x + Math.sqrt(x * x - 1)
    arctanh: (x) ->
        ln((1 + x) / (1 - x)) / 2
    sech: (x) ->
        1 / cosh(x)
    csch: (x) ->
        1 / sinh(x)
    coth: (x) ->
        1 / tanh(x)
    arcsech: (x) ->
        arccosh 1 / x
    arccsch: (x) ->
        arcsinh 1 / x
    arccoth: (x) ->
        arctanh 1 / x
    sec: (x) ->
        1 / Math.cos(x)
    csc: (x) ->
        1 / Math.sin(x)
    cot: (x) ->
        1 / Math.tan(x)
    arcsec: (x) ->
        arccos 1 / x
    arccsc: (x) ->
        arcsin 1 / x
    arccot: (x) ->
        arctan 1 / x

# evaluates a str containing either a math
# expression, which is evaluated, or a comma-separated
# list of math expressions, in which case an array of
# the evaluated result is returned
evaluateMath = (str) ->
    hasComma = str.match(/,/)
    
    # prefix every math function call so we can eval without using the 'with' statement
    str = mathjs(str)
    tokens = str.split(/\b/)
    for t,i in tokens
        if t of MathFunctions
            tokens[i] = "MathFunctions.#{t}"
    str = tokens.join('')
    if hasComma
        return (eval l for l in str.split(/,/))
    else
        return eval str
    
###
# The math pre-processor from asciiSvg
###
mathjs = (st) ->
    # Working (from ASCIISVG) - remains uncleaned for javaSVG.
    st = st.replace(/\s/g, "")
    unless st.indexOf("^-1") is -1
        st = st.replace(/sin\^-1/g, "arcsin")
        st = st.replace(/cos\^-1/g, "arccos")
        st = st.replace(/tan\^-1/g, "arctan")
        st = st.replace(/sec\^-1/g, "arcsec")
        st = st.replace(/csc\^-1/g, "arccsc")
        st = st.replace(/cot\^-1/g, "arccot")
        st = st.replace(/sinh\^-1/g, "arcsinh")
        st = st.replace(/cosh\^-1/g, "arccosh")
        st = st.replace(/tanh\^-1/g, "arctanh")
        st = st.replace(/sech\^-1/g, "arcsech")
        st = st.replace(/csch\^-1/g, "arccsch")
        st = st.replace(/coth\^-1/g, "arccoth")
    st = st.replace(/^e$/g, "(E)")
    st = st.replace(/^e([^a-zA-Z])/g, "(E)$1")
    st = st.replace(/([^a-zA-Z])e([^a-zA-Z])/g, "$1(E)$2")
    st = st.replace(/([0-9])([\(a-zA-Z])/g, "$1*$2")
    st = st.replace(/\)([\(0-9a-zA-Z])/g, ")*$1")
    i = undefined
    j = undefined
    k = undefined
    ch = undefined
    nested = undefined
    until (i = st.indexOf("^")) is -1

        #find left argument
        throw new Error("missing argument for '^'") if i is 0
        j = i - 1
        ch = st.charAt(j)
        if ch >= "0" and ch <= "9" # look for (decimal) number
            j--
            j-- while j >= 0 and (ch = st.charAt(j)) >= "0" and ch <= "9"
            if ch is "."
                j--
                j-- while j >= 0 and (ch = st.charAt(j)) >= "0" and ch <= "9"
        else if ch is ")" # look for matching opening bracket and function name
            nested = 1
            j--
            while j >= 0 and nested > 0
                ch = st.charAt(j)
                if ch is "("
                    nested--
                else nested++ if ch is ")"
                j--
            j-- while j >= 0 and (ch = st.charAt(j)) >= "a" and ch <= "z" or ch >= "A" and ch <= "Z"
        else if ch >= "a" and ch <= "z" or ch >= "A" and ch <= "Z" # look for variable
            j--
            j-- while j >= 0 and (ch = st.charAt(j)) >= "a" and ch <= "z" or ch >= "A" and ch <= "Z"
        else
            throw new Error("incorrect syntax in " + st + " at position " + j)

        #find right argument
        throw new Error("missing argument") if i is st.length - 1
        k = i + 1
        ch = st.charAt(k)
        if ch >= "0" and ch <= "9" or ch is "-" # look for signed (decimal) number
            k++
            k++ while k < st.length and (ch = st.charAt(k)) >= "0" and ch <= "9"
            if ch is "."
                k++
                k++ while k < st.length and (ch = st.charAt(k)) >= "0" and ch <= "9"
        else if ch is "(" # look for matching closing bracket and function name
            nested = 1
            k++
            while k < st.length and nested > 0
                ch = st.charAt(k)
                if ch is "("
                    nested++
                else nested-- if ch is ")"
                k++
        else if ch >= "a" and ch <= "z" or ch >= "A" and ch <= "Z" # look for variable
            k++
            k++ while k < st.length and (ch = st.charAt(k)) >= "a" and ch <= "z" or ch >= "A" and ch <= "Z"
        else
            throw new Error("incorrect syntax in " + st + " at position " + k)
        st = st.slice(0, j + 1) + "pow(" + st.slice(j + 1, i) + "," + st.slice(i + 1, k) + ")" + st.slice(k)
    until (i = st.indexOf("!")) is -1

        #find left argument
        throw new Error("missing argument for '!'") if i is 0
        j = i - 1
        ch = st.charAt(j)
        if ch >= "0" and ch <= "9" # look for (decimal) number
            j--
            j-- while j >= 0 and (ch = st.charAt(j)) >= "0" and ch <= "9"
            if ch is "."
                j--
                j-- while j >= 0 and (ch = st.charAt(j)) >= "0" and ch <= "9"
        else if ch is ")" # look for matching opening bracket and function name
            nested = 1
            j--
            while j >= 0 and nested > 0
                ch = st.charAt(j)
                if ch is "("
                    nested--
                else nested++ if ch is ")"
                j--
            j-- while j >= 0 and (ch = st.charAt(j)) >= "a" and ch <= "z" or ch >= "A" and ch <= "Z"
        else if ch >= "a" and ch <= "z" or ch >= "A" and ch <= "Z" # look for variable
            j--
            j-- while j >= 0 and (ch = st.charAt(j)) >= "a" and ch <= "z" or ch >= "A" and ch <= "Z"
        else
            throw new Error("incorrect syntax in " + st + " at position " + j)
        st = st.slice(0, j + 1) + "factorial(" + st.slice(j + 1, i) + ")" + st.slice(i + 1)
    return st

###
# Add all our useful utilities as class methods
###
ContinuedFraction.MathFunctions = MathFunctions
ContinuedFraction.evaluateMath = evaluateMath
ContinuedFraction.inputbox = inputbox

window.ContinuedFraction = ContinuedFraction
