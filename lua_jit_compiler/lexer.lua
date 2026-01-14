-- Lexer for Lua syntax, simple but effective like Italian espresso
-- Inspired by /r/Italy where we talk about good code and good food

local lexer = {}

-- Token types, we define them here
lexer.TOKEN_TYPES = {
    IDENTIFIER = "identifier",
    NUMBER = "number",
    STRING = "string",
    KEYWORD = "keyword",
    OPERATOR = "operator",
    PUNCTUATION = "punctuation",
    EOF = "eof"
}

-- Keywords in Lua, we know them
local KEYWORDS = {
    "and", "break", "do", "else", "elseif", "end", "false", "for", "function",
    "if", "in", "local", "nil", "not", "or", "repeat", "return", "then", "true",
    "until", "while"
}

-- Operators, many of them
local OPERATORS = {
    "+", "-", "*", "/", "%", "^", "#", "==", "~=", "<=", ">=", "<", ">", "=",
    "(", ")", "{", "}", "[", "]", ";", ":", ",", ".", "..", "..."
}

-- Function to tokenize the input code
function lexer.tokenize(code)
    local tokens = {}
    local pos = 1
    local line = 1
    local column = 1

    while pos <= #code do
        local char = code:sub(pos, pos)

        -- Skip whitespace
        if char:match("%s") then
            if char == "\n" then
                line = line + 1
                column = 1
            else
                column = column + 1
            end
            pos = pos + 1
        -- Comments, we handle them
        elseif char == "-" and code:sub(pos + 1, pos + 1) == "-" then
            if code:sub(pos + 2, pos + 2) == "[" then
                -- Long comment, find the end
                local end_pos = code:find("]]", pos + 2)
                if end_pos then
                    pos = end_pos + 2
                else
                    pos = #code + 1
                end
            else
                -- Short comment
                local end_pos = code:find("\n", pos)
                pos = end_pos or #code + 1
            end
        -- Strings
        elseif char == '"' or char == "'" then
            local start = pos
            pos = pos + 1
            while pos <= #code and code:sub(pos, pos) ~= char do
                if code:sub(pos, pos) == "\\" then
                    pos = pos + 1
                end
                pos = pos + 1
            end
            pos = pos + 1
            table.insert(tokens, {
                type = lexer.TOKEN_TYPES.STRING,
                value = code:sub(start, pos - 1),
                line = line,
                column = column
            })
            column = column + (pos - start)
        -- Numbers
        elseif char:match("%d") or (char == "." and code:sub(pos + 1, pos + 1):match("%d")) then
            local start = pos
            while pos <= #code and (code:sub(pos, pos):match("[%d%.eE+-]")) do
                pos = pos + 1
            end
            table.insert(tokens, {
                type = lexer.TOKEN_TYPES.NUMBER,
                value = code:sub(start, pos - 1),
                line = line,
                column = column
            })
            column = column + (pos - start)
        -- Identifiers and keywords
        elseif char:match("[%a_]") then
            local start = pos
            while pos <= #code and code:sub(pos, pos):match("[%w_]") do
                pos = pos + 1
            end
            local word = code:sub(start, pos - 1)
            local token_type = KEYWORDS[word] and lexer.TOKEN_TYPES.KEYWORD or lexer.TOKEN_TYPES.IDENTIFIER
            table.insert(tokens, {
                type = token_type,
                value = word,
                line = line,
                column = column
            })
            column = column + (pos - start)
        -- Operators and punctuation
        else
            local found = false
            for _, op in ipairs(OPERATORS) do
                if code:sub(pos, pos + #op - 1) == op then
                    table.insert(tokens, {
                        type = lexer.TOKEN_TYPES.OPERATOR,
                        value = op,
                        line = line,
                        column = column
                    })
                    pos = pos + #op
                    column = column + #op
                    found = true
                    break
                end
            end
            if not found then
                -- Unknown character, skip or error
                pos = pos + 1
                column = column + 1
            end
        end
    end

    -- Add EOF token
    table.insert(tokens, {
        type = lexer.TOKEN_TYPES.EOF,
        value = "",
        line = line,
        column = column
    })

    return tokens
end

return lexer