function expression_token_name(type) {
    if (type == "end") {
        return "end of expression"
    }
    if (expression_token_value != "") {
        return expression_token_value
    }
    return type
}

function expression_is_word_char(char) {
    return char ~ /^[A-Za-z0-9_-]$/
}

function expression_token_is_key() {
    return expression_token_type == "identifier" || expression_token_type == "and" ||
        expression_token_type == "or" || expression_token_type == "not" ||
        expression_token_type == "literal_true" || expression_token_type == "literal_false" ||
        expression_token_type == "literal_null"
}

function expression_lex_next(    char, next_char, start, quote, escaped, word, lowered, raw) {
    while (expression_position <= length(expression_source) && substr(expression_source, expression_position, 1) ~ /[[:space:]]/) {
        expression_position++
    }
    expression_token_value = ""
    if (expression_position > length(expression_source)) {
        expression_token_type = "end"
        return
    }

    char = substr(expression_source, expression_position, 1)
    next_char = substr(expression_source, expression_position + 1, 1)
    if (char next_char == "//") {
        expression_token_type = "alternative"
        expression_token_value = "//"
        expression_position += 2
        return
    }
    if (char next_char == "..") {
        expression_token_type = "recursive"
        expression_token_value = ".."
        expression_position += 2
        return
    }
    if (char next_char == "|=") {
        expression_token_type = "update"
        expression_token_value = "|="
        expression_position += 2
        return
    }
    if ((char == "+" || char == "-" || char == "*" || char == "/" || char == "%") && next_char == "=") {
        expression_token_type = "compound"
        expression_token_value = char next_char
        expression_position += 2
        return
    }
    if (char next_char == "==" || char next_char == "!=" || char next_char == ">=" || char next_char == "<=") {
        expression_token_type = "compare"
        expression_token_value = char next_char
        expression_position += 2
        return
    }
    if (char == ">" || char == "<") {
        expression_token_type = "compare"
        expression_token_value = char
        expression_position++
        return
    }
    if (char == "=") {
        expression_token_type = "assign"
        expression_token_value = char
        expression_position++
        return
    }
    if (char == ".") {
        expression_token_type = "dot"
        expression_token_value = char
        expression_position++
        return
    }
    if (char == "|") {
        expression_token_type = "pipe"
        expression_token_value = char
        expression_position++
        return
    }
    if (char == "(") {
        expression_token_type = "left_parenthesis"
        expression_token_value = char
        expression_position++
        return
    }
    if (char == ")") {
        expression_token_type = "right_parenthesis"
        expression_token_value = char
        expression_position++
        return
    }
    if (char == "[") {
        expression_token_type = "left_bracket"
        expression_token_value = char
        expression_position++
        return
    }
    if (char == "]") {
        expression_token_type = "right_bracket"
        expression_token_value = char
        expression_position++
        return
    }
    if (char == ",") {
        expression_token_type = "comma"
        expression_token_value = char
        expression_position++
        return
    }
    if (char == "{") {
        expression_token_type = "left_brace"
        expression_token_value = char
        expression_position++
        return
    }
    if (char == "}") {
        expression_token_type = "right_brace"
        expression_token_value = char
        expression_position++
        return
    }
    if (char == ":") {
        expression_token_type = "colon"
        expression_token_value = char
        expression_position++
        return
    }
    if (char == "?") {
        expression_token_type = "question"
        expression_token_value = char
        expression_position++
        return
    }
    if (char == ";") {
        expression_token_type = "semicolon"
        expression_token_value = char
        expression_position++
        return
    }
    if (char == "$") {
        start = expression_position + 1
        expression_position++
        while (expression_position <= length(expression_source) && expression_is_word_char(substr(expression_source, expression_position, 1))) {
            expression_position++
        }
        if (expression_position == start) {
            fail("variable names require characters after $")
        }
        expression_token_type = "variable"
        expression_token_value = substr(expression_source, start, expression_position - start)
        return
    }
    if (char == "@") {
        start = expression_position
        expression_position++
        while (expression_position <= length(expression_source) && expression_is_word_char(substr(expression_source, expression_position, 1))) {
            expression_position++
        }
        if (expression_position == start + 1) {
            fail("codec names require characters after @")
        }
        expression_token_type = "identifier"
        expression_token_value = substr(expression_source, start, expression_position - start)
        return
    }
    if (char == "*") {
        start = expression_position
        expression_position++
        while (expression_position <= length(expression_source) && substr(expression_source, expression_position, 1) ~ /^[+d?n]$/) {
            expression_position++
        }
        expression_token_type = "arithmetic"
        expression_token_value = substr(expression_source, start, expression_position - start)
        return
    }
    if (char == "+" || char == "-" || char == "/" || char == "%") {
        expression_token_type = "arithmetic"
        expression_token_value = char
        expression_position++
        return
    }

    quote = sprintf("%c", 39)
    if (char == "\"" || char == quote) {
        start = expression_position
        quote = char
        escaped = 0
        expression_position++
        while (expression_position <= length(expression_source)) {
            char = substr(expression_source, expression_position, 1)
            if (escaped) {
                escaped = 0
            } else if (quote == "\"" && char == "\\") {
                escaped = 1
            } else if (char == quote) {
                expression_position++
                raw = substr(expression_source, start, expression_position - start)
                if (quote == "\"" && index(raw, "\\(")) {
                    expression_token_type = "interpolated"
                    expression_token_value = substr(raw, 2, length(raw) - 2)
                } else {
                    expression_token_type = "string"
                    expression_token_value = scalar_value(raw)
                }
                return
            }
            expression_position++
        }
        fail("unterminated string in expression")
    }

    if (char ~ /^[0-9]$/) {
        start = expression_position
        while (expression_position <= length(expression_source) && substr(expression_source, expression_position, 1) ~ /^[0-9_]$/) {
            expression_position++
        }
        if (substr(expression_source, expression_position, 1) == "." && substr(expression_source, expression_position + 1, 1) ~ /^[0-9]$/) {
            expression_position++
            while (expression_position <= length(expression_source) && substr(expression_source, expression_position, 1) ~ /^[0-9_]$/) {
                expression_position++
            }
        }
        if (tolower(substr(expression_source, expression_position, 1)) == "e") {
            expression_position++
            if (substr(expression_source, expression_position, 1) == "+" || substr(expression_source, expression_position, 1) == "-") {
                expression_position++
            }
            while (expression_position <= length(expression_source) && substr(expression_source, expression_position, 1) ~ /^[0-9_]$/) {
                expression_position++
            }
        }
        expression_token_type = "number"
        expression_token_value = substr(expression_source, start, expression_position - start)
        return
    }

    if (expression_is_word_char(char)) {
        start = expression_position
        while (expression_position <= length(expression_source) && expression_is_word_char(substr(expression_source, expression_position, 1))) {
            expression_position++
        }
        word = substr(expression_source, start, expression_position - start)
        lowered = tolower(word)
        if (lowered == "and" || lowered == "or" || lowered == "not" || lowered == "as" || lowered == "ref") {
            expression_token_type = lowered
        } else if (lowered == "true" || lowered == "false" || lowered == "null") {
            expression_token_type = "literal_" lowered
        } else {
            expression_token_type = "identifier"
        }
        expression_token_value = word
        return
    }
    fail("unexpected character in expression: " char)
}

function expression_new(kind, left, right, value,    expression) {
    expression = ++expression_count
    if (max_nodes > 0 && expression > max_nodes) fail("expression node limit exceeded (max " max_nodes ")")
    expression_kind[expression] = kind
    expression_left[expression] = left
    expression_right[expression] = right
    expression_value[expression] = value
    return expression
}

function expression_expect(type,    actual) {
    if (expression_token_type != type) {
        actual = expression_token_name(expression_token_type)
        fail("expected " type " but found " actual)
    }
    expression_lex_next()
}

function expression_parse_fragment(source,    saved_source, saved_position, saved_type, saved_value, expression) {
    saved_source = expression_source
    saved_position = expression_position
    saved_type = expression_token_type
    saved_value = expression_token_value
    expression_source = source
    expression_position = 1
    expression_lex_next()
    expression = expression_parse_stream()
    if (expression_token_type != "end") {
        fail("unexpected token in interpolation: " expression_token_name(expression_token_type))
    }
    expression_source = saved_source
    expression_position = saved_position
    expression_token_type = saved_type
    expression_token_value = saved_value
    return expression
}

function expression_compile_interpolation(raw,    expression, segment_start, i, j, slash_count, marker, depth, quote, escaped, char, inner_start, literal, child, count) {
    expression = expression_new("interpolate", 0, 0, "")
    segment_start = 1
    i = 1
    while (i <= length(raw)) {
        if (substr(raw, i, 1) != "\\") {
            i++
            continue
        }
        slash_count = 0
        j = i
        while (substr(raw, j, 1) == "\\") {
            slash_count++
            j++
        }
        if (substr(raw, j, 1) != "(" || slash_count % 2 == 0) {
            i = j
            continue
        }
        marker = j - 1
        literal = substr(raw, segment_start, marker - segment_start)
        expression_interpolation_literal[expression, count + 1] = decode_double_quoted(literal)
        inner_start = j + 1
        depth = 1
        quote = ""
        escaped = 0
        for (j = inner_start; j <= length(raw); j++) {
            char = substr(raw, j, 1)
            if (quote != "") {
                if (escaped) {
                    escaped = 0
                } else if (char == "\\") {
                    escaped = 1
                } else if (char == quote) {
                    quote = ""
                }
                continue
            }
            if (char == "\"" || char == sprintf("%c", 39)) {
                quote = char
            } else if (char == "(") {
                depth++
            } else if (char == ")") {
                depth--
                if (!depth) {
                    break
                }
            }
        }
        if (depth) {
            fail("unterminated interpolation in expression")
        }
        child = expression_parse_fragment(substr(raw, inner_start, j - inner_start))
        expression_child[expression, ++count] = child
        expression_child_count[expression] = count
        segment_start = j + 1
        i = segment_start
    }
    expression_interpolation_literal[expression, count + 1] = decode_double_quoted(substr(raw, segment_start))
    return expression
}

function expression_finish_slice(slice,    end_expression) {
    expression_lex_next()
    if (expression_token_type != "right_bracket") {
        end_expression = expression_parse_stream()
        expression_child[slice, 2] = end_expression
        expression_slice_has_end[slice] = 1
    }
    expression_expect("right_bracket")
    return slice
}

function expression_parse_primary(    expression, name, step, argument, value, value_type, child, key, key_expression, source, initial, update, variable, slice, start_expression) {
    if (expression_token_type == "dot") {
        expression = expression_new("identity", 0, 0, "")
        expression_lex_next()
        if (expression_token_is_key()) {
            expression = expression_new("key", expression, 0, expression_token_value)
            expression_lex_next()
        }
    } else if (expression_token_type == "recursive") {
        expression = expression_new("recursive", 0, 0, "")
        expression_lex_next()
    } else if (expression_token_type == "string") {
        expression = expression_new("literal", 0, 0, expression_token_value)
        expression_literal_type[expression] = "string"
        expression_lex_next()
    } else if (expression_token_type == "interpolated") {
        value = expression_token_value
        expression_lex_next()
        expression = expression_compile_interpolation(value)
    } else if (expression_token_type == "number") {
        value = expression_token_value
        value_type = scalar_type(value, "", value)
        if (value_type != "int" && value_type != "float") {
            fail("invalid numeric literal: " value)
        }
        expression = expression_new("literal", 0, 0, value)
        expression_literal_type[expression] = value_type
        expression_lex_next()
    } else if (expression_token_type == "literal_true" || expression_token_type == "literal_false") {
        expression = expression_new("literal", 0, 0, tolower(expression_token_value))
        expression_literal_type[expression] = "bool"
        expression_lex_next()
    } else if (expression_token_type == "literal_null") {
        expression = expression_new("literal", 0, 0, "")
        expression_literal_type[expression] = "null"
        expression_lex_next()
    } else if (expression_token_type == "variable") {
        expression = expression_new("variable", 0, 0, expression_token_value)
        expression_lex_next()
    } else if (expression_token_type == "left_parenthesis") {
        expression_lex_next()
        expression = expression_parse_stream()
        expression_expect("right_parenthesis")
    } else if (expression_token_type == "left_bracket") {
        expression = expression_new("array", 0, 0, "")
        expression_lex_next()
        if (expression_token_type != "right_bracket") {
            while (1) {
                child = expression_parse_pipe()
                expression_child[expression, ++expression_child_count[expression]] = child
                if (expression_token_type != "comma") {
                    break
                }
                expression_lex_next()
            }
        }
        expression_expect("right_bracket")
    } else if (expression_token_type == "left_brace") {
        expression = expression_new("object", 0, 0, "")
        expression_lex_next()
        if (expression_token_type != "right_brace") {
            while (1) {
                key_expression = 0
                if (expression_token_type == "left_parenthesis") {
                    expression_lex_next()
                    key_expression = expression_parse_stream()
                    expression_expect("right_parenthesis")
                    key = ""
                } else {
                    if (expression_token_type != "identifier" && expression_token_type != "string") {
                        fail("object keys must be identifiers, strings, or parenthesized expressions")
                    }
                    key = expression_token_value
                    expression_lex_next()
                }
                expression_expect("colon")
                child = expression_parse_pipe()
                expression_object_key[expression, ++expression_child_count[expression]] = key
                expression_object_key_expression[expression, expression_child_count[expression]] = key_expression
                expression_child[expression, expression_child_count[expression]] = child
                if (expression_token_type != "comma") {
                    break
                }
                expression_lex_next()
            }
        }
        expression_expect("right_brace")
    } else if (expression_token_type == "identifier") {
        name = tolower(expression_token_value)
        expression_lex_next()
        if (name == "reduce") {
            source = expression_parse_assignment()
            expression_expect("as")
            if (expression_token_type != "variable") {
                fail("reduce requires a variable after as")
            }
            variable = expression_token_value
            expression_lex_next()
            expression_expect("left_parenthesis")
            initial = expression_parse_pipe()
            expression_expect("semicolon")
            update = expression_parse_pipe()
            expression_expect("right_parenthesis")
            expression = expression_new("reduce", source, initial, variable)
            expression_child[expression, 1] = update
        } else if (name == "env" || name == "strenv") {
            expression_expect("left_parenthesis")
            if (expression_token_type != "identifier" && expression_token_type != "string") {
                fail(name " requires an environment variable name")
            }
            value = expression_token_value
            expression_lex_next()
            expression_expect("right_parenthesis")
            expression = expression_new(name, 0, 0, value)
        } else if (name == "envsubst") {
            value = ""
            if (expression_token_type == "left_parenthesis") {
                expression_lex_next()
                while (expression_token_type != "right_parenthesis") {
                    if (expression_token_type != "identifier" ||
                        (tolower(expression_token_value) != "nu" && tolower(expression_token_value) != "ne" && tolower(expression_token_value) != "ff")) {
                        fail("envsubst options are nu, ne, or ff")
                    }
                    value = value " " tolower(expression_token_value) " "
                    expression_lex_next()
                    if (expression_token_type != "comma") {
                        break
                    }
                    expression_lex_next()
                }
                expression_expect("right_parenthesis")
            }
            expression = expression_new("envsubst", 0, 0, value)
        } else if (name == "first") {
            if (expression_token_type == "left_parenthesis") {
                expression_lex_next()
                argument = expression_parse_stream()
                expression_expect("right_parenthesis")
                expression = expression_new("first", argument, 0, "filtered")
            } else {
                expression = expression_new("first", 0, 0, "")
            }
        } else if (name == "with") {
            expression_expect("left_parenthesis")
            argument = expression_parse_stream()
            expression_expect("semicolon")
            child = expression_parse_stream()
            expression_expect("right_parenthesis")
            expression = expression_new("with", argument, child, "")
        } else if (name == "setpath") {
            expression_expect("left_parenthesis")
            argument = expression_parse_stream()
            expression_expect("semicolon")
            child = expression_parse_stream()
            expression_expect("right_parenthesis")
            expression = expression_new("setpath", argument, child, "")
        } else if (name == "delpaths" || name == "explode" || name == "error" || name == "eval" ||
            name == "load" || name == "load_str" || name == "load_base64" || name == "load_props" ||
            name == "pointer" || name == "apply_patch" || name == "merge_patch" || name == "diff_patch" ||
            name == "validate" || name == "schema_valid" || name == "schema_errors") {
            expression_expect("left_parenthesis")
            argument = expression_parse_stream()
            expression_expect("right_parenthesis")
            expression = expression_new(name, argument, 0, "")
        } else if (name == "to_json" || name == "to_yaml") {
            argument = 0
            if (expression_token_type == "left_parenthesis") {
                expression_lex_next()
                if (expression_token_type != "right_parenthesis") {
                    argument = expression_parse_stream()
                }
                expression_expect("right_parenthesis")
            }
            expression = expression_new(name, argument, 0, "")
        } else if (name == "from_json" || name == "from_yaml" || name == "from_props" || name == "from_csv" || name == "from_tsv" ||
            name == "from_toml" || name == "from_ini" || name == "from_xml" || name == "to_props" || name == "to_csv" || name == "to_tsv" ||
            name == "to_toml" || name == "to_ini" || name == "to_xml") {
            if (expression_token_type == "left_parenthesis") {
                expression_lex_next()
                expression_expect("right_parenthesis")
            }
            expression = expression_new(name, 0, 0, "")
        } else if (name == "@json" || name == "@jsond" || name == "@yaml" || name == "@yamld" ||
            name == "@props" || name == "@propsd" || name == "@csv" || name == "@csvd" || name == "@tsv" || name == "@tsvd" ||
            name == "@toml" || name == "@tomld" || name == "@ini" || name == "@inid" || name == "@xml" || name == "@xmld" ||
            name == "@base64" || name == "@base64d" ||
            name == "@uri" || name == "@urid" || name == "@sh") {
            if (name == "@json") expression = expression_new("to_json", 0, 0, "compact")
            else if (name == "@jsond") expression = expression_new("from_json", 0, 0, "")
            else if (name == "@yaml") expression = expression_new("to_yaml", 0, 0, "")
            else if (name == "@yamld") expression = expression_new("from_yaml", 0, 0, "")
            else if (name == "@props") expression = expression_new("to_props", 0, 0, "")
            else if (name == "@propsd") expression = expression_new("from_props", 0, 0, "")
            else if (name == "@csv") expression = expression_new("to_csv", 0, 0, "")
            else if (name == "@csvd") expression = expression_new("from_csv", 0, 0, "")
            else if (name == "@tsv") expression = expression_new("to_tsv", 0, 0, "")
            else if (name == "@tsvd") expression = expression_new("from_tsv", 0, 0, "")
            else if (name == "@toml") expression = expression_new("to_toml", 0, 0, "")
            else if (name == "@tomld") expression = expression_new("from_toml", 0, 0, "")
            else if (name == "@ini") expression = expression_new("to_ini", 0, 0, "")
            else if (name == "@inid") expression = expression_new("from_ini", 0, 0, "")
            else if (name == "@xml") expression = expression_new("to_xml", 0, 0, "")
            else if (name == "@xmld") expression = expression_new("from_xml", 0, 0, "")
            else expression = expression_new("codec_" substr(name, 2), 0, 0, "")
        } else if (name == "select" || name == "has" || name == "del" || name == "map" || name == "map_values" || name == "with_entries" ||
            name == "contains" || name == "startswith" || name == "endswith" || name == "split" || name == "join" ||
            name == "sort_by" || name == "group_by" || name == "unique_by" || name == "min_by" || name == "max_by" ||
            name == "any_c" || name == "all_c" || name == "test" || name == "sort_keys" || name == "filter" ||
            name == "pick" || name == "omit") {
            expression_expect("left_parenthesis")
            argument = expression_parse_stream()
            expression_expect("right_parenthesis")
            expression = expression_new(name == "test" ? "regex_test" : name, argument, 0, "")
        } else if (name == "sub") {
            expression_expect("left_parenthesis")
            argument = expression_parse_stream()
            expression_expect("semicolon")
            child = expression_parse_stream()
            expression_expect("right_parenthesis")
            expression = expression_new("regex_sub", argument, child, "")
        } else if (name == "length" || name == "keys" || name == "kind" || name == "type" || name == "to_entries" || name == "from_entries" ||
            name == "sort" || name == "unique" || name == "flatten" || name == "reverse" || name == "upcase" || name == "downcase" ||
            name == "trim" || name == "to_string" || name == "array_to_map" || name == "split_doc" || name == "shuffle" ||
            name == "min" || name == "max" || name == "any" || name == "all" || name == "add" || name == "path" ||
            name == "parent" || name == "root" || name == "to_number" || name == "documentindex" ||
            name == "fileindex" || name == "filename" || name == "empty" || name == "line" || name == "key" ||
            name == "column" || name == "tag" || name == "anchor" || name == "alias" || name == "style" || name == "line_comment" ||
            name == "head_comment" || name == "foot_comment" || name == "pivot") {
            if (expression_token_type == "left_parenthesis") {
                expression_lex_next()
                expression_expect("right_parenthesis")
            }
            if (name == "line") name = "node_line"
            else if (name == "column") name = "node_column"
            else if (name == "key") name = "node_key"
            else if (name == "tag") name = "node_tag"
            else if (name == "anchor") name = "node_anchor"
            else if (name == "alias") name = "node_alias"
            else if (name == "style") name = "node_style"
            else if (name == "line_comment") name = "node_line_comment"
            else if (name == "head_comment") name = "node_head_comment"
            else if (name == "foot_comment") name = "node_foot_comment"
            expression = expression_new(name, 0, 0, "")
        } else {
            fail("unknown expression operator: " name)
        }
    } else {
        fail("expected expression but found " expression_token_name(expression_token_type))
    }

    if (expression_token_type == "question") {
        expression_optional[expression] = 1
        expression_lex_next()
    }
    while (1) {
        if (expression_token_type == "dot") {
            expression_lex_next()
            if (!expression_token_is_key()) {
                fail("expected a key after .")
            }
            expression = expression_new("key", expression, 0, expression_token_value)
            expression_lex_next()
        } else if (expression_token_type == "left_bracket") {
            expression_lex_next()
            if (expression_token_type == "right_bracket") {
                expression = expression_new("each", expression, 0, "")
                expression_lex_next()
            } else if (expression_token_type == "colon") {
                expression = expression_finish_slice(expression_new("slice", expression, 0, ""))
            } else if (expression_token_type == "number") {
                value = expression_token_value
                if (value !~ /^[0-9]+$/) {
                    fail("sequence indexes must be integers")
                }
                expression_lex_next()
                if (expression_token_type == "colon") {
                    start_expression = expression_new("literal", 0, 0, value)
                    expression_literal_type[start_expression] = "int"
                    slice = expression_new("slice", expression, 0, "")
                    expression_child[slice, 1] = start_expression
                    expression_slice_has_start[slice] = 1
                    expression = expression_finish_slice(slice)
                } else {
                    expression_expect("right_bracket")
                    expression = expression_new("index", expression, 0, value + 0)
                }
            } else if (expression_token_type == "string") {
                value = expression_token_value
                expression_lex_next()
                if (expression_token_type == "colon") {
                    start_expression = expression_new("literal", 0, 0, value)
                    expression_literal_type[start_expression] = "string"
                    slice = expression_new("slice", expression, 0, "")
                    expression_child[slice, 1] = start_expression
                    expression_slice_has_start[slice] = 1
                    expression = expression_finish_slice(slice)
                } else {
                    expression_expect("right_bracket")
                    expression = expression_new("key", expression, 0, value)
                }
            } else {
                step = expression_parse_stream()
                if (expression_token_type == "colon") {
                    slice = expression_new("slice", expression, 0, "")
                    expression_child[slice, 1] = step
                    expression_slice_has_start[slice] = 1
                    expression = expression_finish_slice(slice)
                } else {
                    expression_expect("right_bracket")
                    expression = expression_new("dynamic", expression, step, "")
                }
            }
        } else if (expression_token_type == "identifier" &&
            (tolower(expression_token_value) == "style" || tolower(expression_token_value) == "line_comment" ||
            tolower(expression_token_value) == "head_comment" || tolower(expression_token_value) == "foot_comment" ||
            tolower(expression_token_value) == "tag" || tolower(expression_token_value) == "anchor" ||
            tolower(expression_token_value) == "alias")) {
            value = tolower(expression_token_value)
            expression_lex_next()
            expression = expression_new("node_property", expression, 0, value)
        } else {
            break
        }
        if (expression_token_type == "question") {
            expression_optional[expression] = 1
            expression_lex_next()
        }
    }
    return expression
}

function expression_path(node,    result, depth, current, edge, i) {
    result = new_node("sequence", 0, "", "", "")
    depth = 0
    current = node
    while (current in node_parent) {
        expression_path_edge[++depth] = node_parent_edge[current]
        current = node_parent[current]
    }
    for (i = depth; i >= 1; i--) {
        edge = expression_path_edge[i]
        if (substr(edge, 1, 6) == "index ") {
            add_sequence(result, expression_scalar(substr(edge, 7), "int"), 0)
        } else {
            add_sequence(result, expression_scalar(substr(edge, 5), "string"), 0)
        }
        delete expression_path_edge[i]
    }
    return result
}

function expression_root(node,    current) {
    current = node
    while (current in node_parent) current = node_parent[current]
    return current
}

