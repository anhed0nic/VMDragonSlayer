-- Parser for Lua, recursive descent like Italian family trees
-- /r/Italy would appreciate the simplicity

local parser = {}

-- AST node types
parser.NODE_TYPES = {
    PROGRAM = "program",
    FUNCTION_DECL = "function_decl",
    VARIABLE_DECL = "variable_decl",
    ASSIGNMENT = "assignment",
    IF_STATEMENT = "if_statement",
    WHILE_STATEMENT = "while_statement",
    FOR_STATEMENT = "for_statement",
    RETURN_STATEMENT = "return_statement",
    EXPRESSION = "expression",
    BINARY_OP = "binary_op",
    UNARY_OP = "unary_op",
    CALL = "call",
    IDENTIFIER = "identifier",
    NUMBER = "number",
    STRING = "string"
}

function parser.new(tokens)
    local self = {
        tokens = tokens,
        pos = 1,
        current_token = tokens[1]
    }

    function self.advance()
        self.pos = self.pos + 1
        self.current_token = self.tokens[self.pos]
    end

    function self.peek(offset)
        offset = offset or 1
        return self.tokens[self.pos + offset - 1]
    end

    function self.expect(type, value)
        if self.current_token.type == type and (not value or self.current_token.value == value) then
            local token = self.current_token
            self.advance()
            return token
        else
            error("Expected " .. type .. (value and " '" .. value .. "'" or "") .. " but got " .. self.current_token.type .. " '" .. self.current_token.value .. "'")
        end
    end

    function self.parse_program()
        local statements = {}
        while self.current_token.type ~= "eof" do
            table.insert(statements, self.parse_statement())
            if self.current_token.value == ";" then
                self.advance()
            end
        end
        return { type = parser.NODE_TYPES.PROGRAM, statements = statements }
    end

    function self.parse_statement()
        if self.current_token.type == "keyword" then
            if self.current_token.value == "local" then
                return self.parse_variable_decl()
            elseif self.current_token.value == "function" then
                return self.parse_function_decl()
            elseif self.current_token.value == "if" then
                return self.parse_if_statement()
            elseif self.current_token.value == "while" then
                return self.parse_while_statement()
            elseif self.current_token.value == "for" then
                return self.parse_for_statement()
            elseif self.current_token.value == "return" then
                return self.parse_return_statement()
            end
        elseif self.current_token.type == "identifier" then
            return self.parse_assignment_or_call()
        end
        return self.parse_expression()
    end

    function self.parse_variable_decl()
        self.expect("keyword", "local")
        local name = self.expect("identifier").value
        local init = nil
        if self.current_token.value == "=" then
            self.advance()
            init = self.parse_expression()
        end
        return { type = parser.NODE_TYPES.VARIABLE_DECL, name = name, init = init }
    end

    function self.parse_function_decl()
        self.expect("keyword", "function")
        local name = self.expect("identifier").value
        self.expect("operator", "(")
        local params = {}
        while self.current_token.type ~= "operator" or self.current_token.value ~= ")" do
            if self.current_token.type == "identifier" then
                table.insert(params, self.expect("identifier").value)
            end
            if self.current_token.value == "," then
                self.advance()
            end
        end
        self.expect("operator", ")")
        local body = self.parse_block()
        self.expect("keyword", "end")
        return { type = parser.NODE_TYPES.FUNCTION_DECL, name = name, params = params, body = body }
    end

    function self.parse_if_statement()
        self.expect("keyword", "if")
        local condition = self.parse_expression()
        self.expect("keyword", "then")
        local then_block = self.parse_block()
        local else_block = nil
        if self.current_token.value == "else" then
            self.advance()
            else_block = self.parse_block()
        elseif self.current_token.value == "elseif" then
            -- For simplicity, treat elseif as nested if
            else_block = { self.parse_if_statement() }
        end
        self.expect("keyword", "end")
        return { type = parser.NODE_TYPES.IF_STATEMENT, condition = condition, then_block = then_block, else_block = else_block }
    end

    function self.parse_while_statement()
        self.expect("keyword", "while")
        local condition = self.parse_expression()
        self.expect("keyword", "do")
        local body = self.parse_block()
        self.expect("keyword", "end")
        return { type = parser.NODE_TYPES.WHILE_STATEMENT, condition = condition, body = body }
    end

    function self.parse_for_statement()
        self.expect("keyword", "for")
        local var = self.expect("identifier").value
        self.expect("operator", "=")
        local start = self.parse_expression()
        self.expect("operator", ",")
        local stop = self.parse_expression()
        local step = nil
        if self.current_token.value == "," then
            self.advance()
            step = self.parse_expression()
        end
        self.expect("keyword", "do")
        local body = self.parse_block()
        self.expect("keyword", "end")
        return { type = parser.NODE_TYPES.FOR_STATEMENT, var = var, start = start, stop = stop, step = step, body = body }
    end

    function self.parse_return_statement()
        self.expect("keyword", "return")
        local expr = self.parse_expression()
        return { type = parser.NODE_TYPES.RETURN_STATEMENT, expression = expr }
    end

    function self.parse_assignment_or_call()
        local name = self.expect("identifier").value
        if self.current_token.value == "=" then
            self.advance()
            local expr = self.parse_expression()
            return { type = parser.NODE_TYPES.ASSIGNMENT, name = name, expression = expr }
        elseif self.current_token.value == "(" then
            local args = self.parse_call_args()
            return { type = parser.NODE_TYPES.CALL, name = name, args = args }
        end
        return { type = parser.NODE_TYPES.IDENTIFIER, name = name }
    end

    function self.parse_call_args()
        self.expect("operator", "(")
        local args = {}
        while self.current_token.type ~= "operator" or self.current_token.value ~= ")" do
            table.insert(args, self.parse_expression())
            if self.current_token.value == "," then
                self.advance()
            end
        end
        self.expect("operator", ")")
        return args
    end

    function self.parse_expression()
        return self.parse_binary_op()
    end

    function self.parse_binary_op()
        local left = self.parse_unary_op()
        while self.current_token.type == "operator" and (self.current_token.value == "+" or self.current_token.value == "-" or self.current_token.value == "*" or self.current_token.value == "/" or self.current_token.value == "==" or self.current_token.value == "<" or self.current_token.value == ">" or self.current_token.value == "and" or self.current_token.value == "or") do
            local op = self.current_token.value
            self.advance()
            local right = self.parse_unary_op()
            left = { type = parser.NODE_TYPES.BINARY_OP, left = left, op = op, right = right }
        end
        return left
    end

    function self.parse_unary_op()
        if self.current_token.type == "operator" and (self.current_token.value == "-" or self.current_token.value == "not") then
            local op = self.current_token.value
            self.advance()
            local expr = self.parse_unary_op()
            return { type = parser.NODE_TYPES.UNARY_OP, op = op, expression = expr }
        end
        return self.parse_primary()
    end

    function self.parse_primary()
        if self.current_token.type == "identifier" then
            local name = self.current_token.value
            self.advance()
            if self.current_token.value == "(" then
                local args = self.parse_call_args()
                return { type = parser.NODE_TYPES.CALL, name = name, args = args }
            else
                return { type = parser.NODE_TYPES.IDENTIFIER, name = name }
            end
        elseif self.current_token.type == "number" then
            local value = self.current_token.value
            self.advance()
            return { type = parser.NODE_TYPES.NUMBER, value = value }
        elseif self.current_token.type == "string" then
            local value = self.current_token.value
            self.advance()
            return { type = parser.NODE_TYPES.STRING, value = value }
        elseif self.current_token.value == "(" then
            self.advance()
            local expr = self.parse_expression()
            self.expect("operator", ")")
            return expr
        end
        error("Unexpected token: " .. self.current_token.type .. " '" .. self.current_token.value .. "'")
    end

    function self.parse_block()
        local statements = {}
        while self.current_token.type ~= "keyword" or (self.current_token.value ~= "end" and self.current_token.value ~= "else" and self.current_token.value ~= "elseif") do
            if self.current_token.type == "eof" then break end
            table.insert(statements, self.parse_statement())
            if self.current_token.value == ";" then
                self.advance()
            end
        end
        return statements
    end

    return self
end

function parser.parse(tokens)
    local p = parser.new(tokens)
    return p.parse_program()
end

return parser