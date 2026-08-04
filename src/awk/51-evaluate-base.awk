function expression_evaluate_base(kind, expression, input,    output, middle, left_stream, right_stream, single, node, child, i, j, collection, key, argument_stream, argument, result_node, variable, previous, had, accumulator, update_stream, partial_count, next_count, partial, partials, nexts) {
    output = expression_stream_new()
    if (kind == "identity") {
        expression_stream_append(output, input)
        return output
    }
    if (kind == "split_doc") {
        # YAML.sh already separates every YAML stream result into a valid document.
        # Keep split_doc explicit and idempotent instead of weakening that contract.
        expression_stream_append(output, input)
        return output
    }
    if (kind == "empty") {
        return output
    }
    if (kind == "error") {
        key = "aborted"
        argument_stream = expression_evaluate(expression_left[expression], input)
        if (expression_stream_count[argument_stream]) {
            node = resolve_alias(expression_stream_node[argument_stream, 1])
            key = node_kind[node] == "scalar" ? node_value[node] : ""
        }
        fail(key)
    }
    if (kind == "env" || kind == "strenv") {
        if (disable_env_ops) {
            fail("environment operations are disabled")
        }
        key = expression_value[expression]
        if (kind == "env" && !(key in ENVIRON)) {
            fail("value for env variable '" key "' not provided in env()")
        }
        for (i = 1; i <= expression_stream_count[input]; i++) {
            if (kind == "strenv") {
                expression_stream_push(output, expression_scalar(ENVIRON[key], "string"))
            } else {
                expression_stream_push(output, parse_value(ENVIRON[key], 0, -1, 0))
            }
        }
        return output
    }
    if (kind == "to_number" || kind == "envsubst") {
        if (kind == "envsubst" && disable_env_ops) {
            fail("environment operations are disabled")
        }
        for (i = 1; i <= expression_stream_count[input]; i++) {
            node = resolve_alias(expression_stream_node[input, i])
            if (node_kind[node] != "scalar" || node_type[node] != "string") {
                fail(kind " requires a string")
            }
            if (kind == "envsubst") {
                expression_stream_push(output, expression_scalar(expression_envsubst(node_value[node], expression_value[expression]), "string"))
            } else {
                key = scalar_type(node_value[node], "", node_value[node])
                if (key != "int" && key != "float") {
                    fail("cannot convert value to number: " node_value[node])
                }
                expression_stream_push(output, expression_scalar(node_value[node], key))
            }
        }
        return output
    }
    if (kind == "literal") {
        for (i = 1; i <= expression_stream_count[input]; i++) {
            expression_stream_push(output, expression_scalar(expression_value[expression], expression_literal_type[expression]))
        }
        return output
    }
    if (kind == "interpolate") {
        for (i = 1; i <= expression_stream_count[input]; i++) {
            single = expression_stream_single(expression_stream_node[input, i])
            partial_count = 1
            partials[1] = expression_interpolation_literal[expression, 1]
            for (j = 1; j <= expression_child_count[expression]; j++) {
                argument_stream = expression_evaluate(expression_child[expression, j], single)
                next_count = 0
                if (expression_stream_count[argument_stream]) {
                    for (collection = 1; collection <= partial_count; collection++) {
                        partial = partials[collection]
                        nexts[++next_count] = partial expression_interpolation_text(expression_stream_node[argument_stream, 1]) expression_interpolation_literal[expression, j + 1]
                    }
                }
                partial_count = next_count
                for (collection = 1; collection <= partial_count; collection++) {
                    partials[collection] = nexts[collection]
                }
            }
            for (collection = 1; collection <= partial_count; collection++) {
                expression_stream_push(output, expression_scalar(partials[collection], "string"))
            }
        }
        return output
    }
    if (kind == "variable") {
        variable = expression_value[expression]
        if (!(variable in expression_variable_node)) {
            fail("undefined variable $" variable)
        }
        for (i = 1; i <= expression_stream_count[input]; i++) {
            expression_stream_push(output, expression_variable_node[variable])
        }
        return output
    }
    if (kind == "array" || kind == "object") {
        if (eval_all_mode && expression == eval_all_top_expression && kind == "array") {
            result_node = new_node("sequence", 0, "", "", "")
            for (i = 1; i <= expression_stream_count[input]; i++) {
                single = expression_stream_single(expression_stream_node[input, i])
                for (j = 1; j <= expression_child_count[expression]; j++) {
                    middle = expression_evaluate(expression_child[expression, j], single)
                    for (collection = 1; collection <= expression_stream_count[middle]; collection++) {
                        add_sequence(result_node, expression_clone_node(expression_stream_node[middle, collection]), 0)
                    }
                }
            }
            expression_stream_push(output, result_node)
            return output
        }
        for (i = 1; i <= expression_stream_count[input]; i++) {
            single = expression_stream_single(expression_stream_node[input, i])
            if (kind == "array") {
                result_node = new_node("sequence", 0, "", "", "")
                for (j = 1; j <= expression_child_count[expression]; j++) {
                    middle = expression_evaluate(expression_child[expression, j], single)
                    for (collection = 1; collection <= expression_stream_count[middle]; collection++) {
                        add_sequence(result_node, expression_clone_node(expression_stream_node[middle, collection]), 0)
                    }
                }
            } else {
                result_node = new_node("mapping", 0, "", "", "")
                for (j = 1; j <= expression_child_count[expression]; j++) {
                    middle = expression_evaluate(expression_child[expression, j], single)
                    child = expression_stream_first_or_null(middle)
                    key = expression_object_key[expression, j]
                    if (expression_object_key_expression[expression, j]) {
                        argument_stream = expression_evaluate(expression_object_key_expression[expression, j], single)
                        if (!expression_stream_count[argument_stream]) {
                            fail("computed object key produced no value")
                        }
                        argument = resolve_alias(expression_stream_node[argument_stream, 1])
                        if (node_kind[argument] != "scalar") {
                            fail("computed object keys must be scalars")
                        }
                        key = expression_interpolation_text(argument)
                    }
                    add_mapping(result_node, key, expression_clone_node(child), 0, 0)
                }
            }
            expression_stream_push(output, result_node)
        }
        return output
    }
    if (kind == "recursive") {
        for (i = 1; i <= expression_stream_count[input]; i++) {
            expression_collect_recursive_all(expression_stream_node[input, i], output)
        }
        return output
    }
    if (kind == "negate") {
        middle = expression_evaluate(expression_left[expression], input)
        for (i = 1; i <= expression_stream_count[middle]; i++) {
            node = resolve_alias(expression_stream_node[middle, i])
            if (node_type[node] != "int" && node_type[node] != "float") {
                fail("unary - requires a number")
            }
            expression_stream_push(output, expression_arithmetic_number(-expression_numeric(node), node_type[node]))
        }
        return output
    }
    if (kind == "arithmetic") {
        if (eval_all_mode && expression == eval_all_top_expression) {
            left_stream = expression_evaluate(expression_left[expression], input)
            right_stream = expression_evaluate(expression_right[expression], input)
            for (j = 1; j <= expression_stream_count[left_stream]; j++) {
                for (collection = 1; collection <= expression_stream_count[right_stream]; collection++) {
                    expression_stream_push(output, expression_arithmetic(expression_stream_node[left_stream, j], expression_stream_node[right_stream, collection], expression_value[expression]))
                }
            }
            return output
        }
        for (i = 1; i <= expression_stream_count[input]; i++) {
            single = expression_stream_single(expression_stream_node[input, i])
            left_stream = expression_evaluate(expression_left[expression], single)
            right_stream = expression_evaluate(expression_right[expression], single)
            for (j = 1; j <= expression_stream_count[left_stream]; j++) {
                for (collection = 1; collection <= expression_stream_count[right_stream]; collection++) {
                    expression_stream_push(output, expression_arithmetic(expression_stream_node[left_stream, j], expression_stream_node[right_stream, collection], expression_value[expression]))
                }
            }
        }
        return output
    }
    if (kind == "pipe") {
        middle = expression_evaluate(expression_left[expression], input)
        return expression_evaluate(expression_right[expression], middle)
    }
    if (kind == "bind") {
        variable = expression_value[expression]
        had = variable in expression_variable_node
        previous = expression_variable_node[variable]
        if (eval_all_mode && expression == eval_all_top_expression) {
            left_stream = expression_evaluate(expression_left[expression], input)
            for (j = 1; j <= expression_stream_count[left_stream]; j++) {
                expression_variable_node[variable] = expression_stream_node[left_stream, j]
                right_stream = expression_evaluate(expression_right[expression], input)
                expression_stream_append(output, right_stream)
            }
        } else {
            for (i = 1; i <= expression_stream_count[input]; i++) {
                single = expression_stream_single(expression_stream_node[input, i])
                left_stream = expression_evaluate(expression_left[expression], single)
                for (j = 1; j <= expression_stream_count[left_stream]; j++) {
                    expression_variable_node[variable] = expression_stream_node[left_stream, j]
                    right_stream = expression_evaluate(expression_right[expression], single)
                    expression_stream_append(output, right_stream)
                }
            }
        }
        if (had) {
            expression_variable_node[variable] = previous
        } else {
            delete expression_variable_node[variable]
        }
        return output
    }
    if (kind == "reduce") {
        variable = expression_value[expression]
        had = variable in expression_variable_node
        previous = expression_variable_node[variable]
        if (eval_all_mode && expression == eval_all_top_expression) {
            left_stream = expression_evaluate(expression_left[expression], input)
            right_stream = expression_evaluate(expression_right[expression], input)
            accumulator = expression_stream_first_or_null(right_stream)
            for (j = 1; j <= expression_stream_count[left_stream]; j++) {
                expression_variable_node[variable] = expression_stream_node[left_stream, j]
                single = expression_stream_single(accumulator)
                update_stream = expression_evaluate(expression_child[expression, 1], single)
                accumulator = expression_stream_first_or_null(update_stream)
            }
            expression_stream_push(output, accumulator)
            if (had) {
                expression_variable_node[variable] = previous
            } else {
                delete expression_variable_node[variable]
            }
            return output
        }
        for (i = 1; i <= expression_stream_count[input]; i++) {
            single = expression_stream_single(expression_stream_node[input, i])
            left_stream = expression_evaluate(expression_left[expression], single)
            right_stream = expression_evaluate(expression_right[expression], single)
            accumulator = expression_stream_first_or_null(right_stream)
            for (j = 1; j <= expression_stream_count[left_stream]; j++) {
                expression_variable_node[variable] = expression_stream_node[left_stream, j]
                single = expression_stream_single(accumulator)
                update_stream = expression_evaluate(expression_child[expression, 1], single)
                accumulator = expression_stream_first_or_null(update_stream)
            }
            expression_stream_push(output, accumulator)
        }
        if (had) {
            expression_variable_node[variable] = previous
        } else {
            delete expression_variable_node[variable]
        }
        return output
    }
    if (kind == "with") {
        for (i = 1; i <= expression_stream_count[input]; i++) {
            single = expression_stream_single(expression_stream_node[input, i])
            left_stream = expression_evaluate(expression_left[expression], single)
            for (j = 1; j <= expression_stream_count[left_stream]; j++) {
                middle = expression_stream_single(expression_stream_node[left_stream, j])
                expression_evaluate(expression_right[expression], middle)
            }
            expression_stream_push(output, expression_stream_node[input, i])
        }
        return output
    }
    if (kind == "explode") {
        for (i = 1; i <= expression_stream_count[input]; i++) {
            single = expression_stream_single(expression_stream_node[input, i])
            middle = expression_evaluate(expression_left[expression], single)
            for (j = 1; j <= expression_stream_count[middle]; j++) {
                expression_stream_push(output, expression_clone_node(expression_stream_node[middle, j]))
            }
        }
        return output
    }
    fail("expression kind reached the wrong evaluator family: " kind)
}

