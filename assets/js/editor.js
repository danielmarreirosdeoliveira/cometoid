export function isAltStop(s) {
    return s === " " || s === "." || s === "\t" || s === "\n"
}

function isSentenceStop(s) {
    return s === "." || s === "," || s === ";"
}

function isWhitespace(s) {
    return s === " " || s === "\n"
}

export function insertLineAfterCurrent([selectionStart, value]) {

    let resultValue = value
    let offset = 1

    if (selectionStart === value.length) resultValue += "\n"
    else for (; selectionStart < value.length; selectionStart++) {
        if (value[selectionStart] === "\n") {
            resultValue = 
                value.slice(0, selectionStart) 
                + "\n" 
                + value.slice(selectionStart, value.length)
            break
        }
        else if (selectionStart + 1 === value.length) {
            resultValue += "\n"
            offset++
            break
        }
    }

    return [selectionStart + offset, resultValue]
}

function backwardsTowardsSentenceStart([selectionStart, value]) {

    if (selectionStart > 2) {
        if (value[selectionStart-1] === " " && value[selectionStart-2] === ".") {
            return backwardsTowardsSentenceStart([selectionStart-1, value])
        }
        if (value[selectionStart-1] === "\n" && value[selectionStart-2] === "\n") {
            return selectionStart - 1
        }
    }
    if (selectionStart > 0) {
        if (isSentenceStop(value[selectionStart-1])) selectionStart--
    }
    for (; selectionStart > 0; selectionStart--) {
        if (selectionStart - 1 === 0) {
            selectionStart --
            break;
        } else if (isSentenceStop(value[selectionStart-1])) {
            
            break;
        } else if (value[selectionStart-1] === "\n") {
            if (selectionStart > 1 && value[selectionStart-2] === "\n") {
                break
            }
        }
    }

    return selectionStart
}

function forwardTowardsSentenceStart([selectionStart, value]) {

    for (; selectionStart < value.length; selectionStart++) {
        if (isSentenceStop(value[selectionStart])) {
            if (selectionStart + 1 < value.length) selectionStart += 2
            break
        }
        if (value[selectionStart] === "\n" 
            && selectionStart + 1 < value.length 
            && value[selectionStart+1] === "\n") {

            selectionStart += 2
            break;
        }
    }
    return selectionStart
}

function wordPartLeft([selectionStart, value]) {

    let i = selectionStart
    if (i > 0) {
        if (isAltStop(value[i-1])) {
            for (; i > 0 && isAltStop(value[i-1]); i--);
        } else {
            for (; i > 0 && !isAltStop(value[i-1]); i--);
        }
    }
    return i
}

function wordLeft([selectionStart, value]) {

    let i = selectionStart
    if (i > 0) {
        if (isAltStop(value[i-1])) {
            for (; i > 0 && isAltStop(value[i-1]); i--);
        } 
        for (; i > 0 && !isAltStop(value[i-1]); i--);
    }
    return i
}

function wordPartRight([selectionStart, value]) {
   
    let i = selectionStart
    if (i < value.length) {
        if (isAltStop(value[i])) {
            for (; i < value.length && isAltStop(value[i]); i++);
        } else {
            for (; i < value.length && !isAltStop(value[i]); i++);
        }
    }
    return i
}

function wordRight([selectionStart, value]) {
   
    let i = selectionStart
    if (i < value.length) {
        if (isAltStop(value[i])) {
            for (; i < value.length && isAltStop(value[i]); i++);
        }
        for (; i < value.length && !isAltStop(value[i]); i++);
    }
    return i
}

function cleft([selectionStart, _value]) {
   
    return selectionStart > 0 ? selectionStart - 1 : selectionStart
}

function cright([selectionStart, value]) {
   
    return selectionStart < value.length -1 ? selectionStart + 1 : selectionStart
}

export function moveCaretForwardTowardsNextSentence(params) {

    return [forwardTowardsSentenceStart(params), params[1]]
}

export function moveCaretBackwardsTowardsSentenceStart(params) {

    return [backwardsTowardsSentenceStart(params), params[1]]
}

export function moveCaretWordLeft(params) {
    
    return [wordLeft(params), params[1]]
}

export function moveCaretWordPartLeft(params) {
    
    return [wordPartLeft(params), params[1]]
}

export function moveCaretWordRight(params) {

    return [wordRight(params), params[1]]
}

export function moveCaretWordPartRight(params) {

    return [wordPartRight(params), params[1]]
}

export function caretLeft(params) {

    return [cleft(params), params[1]]
}

export function caretRight(params) {

    return [cright(params), params[1]]
}

export function deleteBackwardsTowardsSentenceStart(params) {

    const [selectionStart_, value] = params
    let resultValue = value

    const selectionStart = backwardsTowardsSentenceStart(params)

    resultValue = 
        value.slice(0, selectionStart)
        + (selectionStart_ !== value.length && selectionStart !== 0
            && value[selectionStart_] !== " " ? " " : "")
        + value.slice(selectionStart_, value.length)

    return [selectionStart, resultValue]
}
