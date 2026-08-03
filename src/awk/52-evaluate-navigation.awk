function expression_evaluate_navigation(kind, expression, input,    output, middle, left_stream, right_stream, single, node, resolved, child, i, j, collection, key, predicate, matched, argument_stream, argument, result_node, variable, previous, had, accumulator, update_stream, start_index, end_index, size, interpolation, partial_count, next_count, partial, stage, mutation_path, mutation_kind, was_missing, input_target, path_stream, value_stream, path_node, path_serial, target_count, property_expression, property) {
    output = expression_stream_new()
    if (kind == "first" || kind == "filter") {
        for (i = 1; i <= expression_stream_count[input]; i++) {
            node = resolve_alias(expression_stream_node[input, i])
            if (node_kind[node] != "sequence" && node_kind[node] != "mapping") {
                continue
            }
            if (kind == "filter") {
                result_node = new_node("sequence", 0, "", "", "")
            }
            collection = ++collection_serial
            if (node_kind[node] == "mapping") {
                collect_mapping_keys(node, collection)
                size = collection_count[collection]
            } else {
                size = sequence_count[node]
            }
            for (j = 1; j <= size; j++) {
                child = node_kind[node] == "mapping" ? mapping_lookup(node, collection_key[collection, j]) : sequence_child[node, j]
                matched = kind == "first" && expression_value[expression] == "" ? 1 : expression_predicate_matches(expression_left[expression], child)
                if (matched && kind == "first") {
                    expression_stream_push(output, child)
                    break
                }
                if (matched) {
                    add_sequence(result_node, expression_clone_node(child), 0)
                }
            }
            if (kind == "filter") {
                expression_stream_push(output, result_node)
            }
        }
        return output
    }
    if (kind == "pick" || kind == "omit") {
        for (i = 1; i <= expression_stream_count[input]; i++) {
            node = resolve_alias(expression_stream_node[input, i])
            single = expression_stream_single(node)
            argument_stream = expression_evaluate(expression_left[expression], single)
            if (!expression_stream_count[argument_stream]) {
                fail(kind " requires a sequence of keys or indexes")
            }
            argument = resolve_alias(expression_stream_node[argument_stream, 1])
            if (node_kind[argument] != "sequence") {
                fail(kind " requires a sequence of keys or indexes")
            }
            expression_stream_push(output, expression_pick_or_omit(node, argument, kind == "omit"))
        }
        return output
    }
    if (kind == "pivot") {
        for (i = 1; i <= expression_stream_count[input]; i++) {
            expression_stream_push(output, expression_pivot(resolve_alias(expression_stream_node[input, i])))
        }
        return output
    }
    if (kind == "comma") {
        middle = expression_evaluate(expression_left[expression], input)
        expression_stream_append(output, middle)
        middle = expression_evaluate(expression_right[expression], input)
        expression_stream_append(output, middle)
        return output
    }
    if (kind == "slice") {
        middle = expression_evaluate(expression_left[expression], input)
        for (i = 1; i <= expression_stream_count[middle]; i++) {
            node = expression_stream_node[middle, i]
            resolved = resolve_alias(node)
            if (node_kind[resolved] == "sequence") {
                size = sequence_count[resolved]
            } else if (node_kind[resolved] == "scalar" && node_type[resolved] == "string") {
                size = length(node_value[resolved])
            } else if (expression_optional[expression]) {
                continue
            } else {
                fail("slices require a sequence or string")
            }
            start_index = 0
            end_index = size
            single = expression_stream_single(resolved)
            if (expression_slice_has_start[expression]) {
                argument_stream = expression_evaluate(expression_child[expression, 1], single)
                if (!expression_stream_count[argument_stream]) {
                    fail("slice start requires an integer")
                }
                argument = resolve_alias(expression_stream_node[argument_stream, 1])
                if (node_type[argument] != "int") {
                    fail("slice start requires an integer")
                }
                start_index = node_value[argument] + 0
            }
            if (expression_slice_has_end[expression]) {
                argument_stream = expression_evaluate(expression_child[expression, 2], single)
                if (!expression_stream_count[argument_stream]) {
                    fail("slice end requires an integer")
                }
                argument = resolve_alias(expression_stream_node[argument_stream, 1])
                if (node_type[argument] != "int") {
                    fail("slice end requires an integer")
                }
                end_index = node_value[argument] + 0
            }
            if (start_index < 0) {
                start_index = size + start_index
            }
            if (end_index < 0) {
                end_index = size + end_index
            }
            if (start_index < 0) {
                start_index = 0
            } else if (start_index > size) {
                start_index = size
            }
            if (end_index < 0) {
                end_index = 0
            } else if (end_index > size) {
                end_index = size
            }
            if (end_index < start_index) {
                end_index = start_index
            }
            if (node_kind[resolved] == "sequence") {
                result_node = new_node("sequence", 0, "", "", "")
                for (j = start_index + 1; j <= end_index; j++) {
                    add_sequence(result_node, expression_clone_node(sequence_child[resolved, j]), 0)
                }
                expression_stream_push(output, result_node)
            } else {
                expression_stream_push(output, expression_scalar(substr(node_value[resolved], start_index + 1, end_index - start_index), "string"))
            }
        }
        return output
    }
    if (kind == "key" || kind == "index" || kind == "each") {
        middle = expression_evaluate(expression_left[expression], input)
        for (i = 1; i <= expression_stream_count[middle]; i++) {
            node = expression_stream_node[middle, i]
            resolved = resolve_alias(node)
            if (kind == "key") {
                if (node_kind[resolved] == "mapping") {
                    child = mapping_lookup(resolved, expression_value[expression])
                } else {
                    child = 0
                }
                if (child) {
                    expression_stream_push(output, child)
                } else if (node_kind[resolved] == "mapping" || !expression_optional[expression]) {
                    child = expression_null()
                    expression_missing_parent[child] = resolved
                    expression_missing_key[child] = expression_value[expression]
                    expression_stream_push(output, child)
                }
            } else if (kind == "index") {
                collection = expression_value[expression] + 0
                if (node_kind[resolved] == "sequence" && collection < 0) {
                    collection = sequence_count[resolved] + collection
                }
                if (node_kind[resolved] == "sequence" && collection >= 0 && collection < sequence_count[resolved]) {
                    child = sequence_child[resolved, collection + 1]
                } else {
                    child = 0
                }
                if (child) {
                    expression_stream_push(output, child)
                } else if (node_kind[resolved] == "sequence" || !expression_optional[expression]) {
                    expression_stream_push(output, expression_null())
                }
            } else if (node_kind[resolved] == "sequence") {
                for (j = 1; j <= sequence_count[resolved]; j++) {
                    expression_stream_push(output, sequence_child[resolved, j])
                }
            } else if (node_kind[resolved] == "mapping") {
                collection = ++collection_serial
                collect_mapping_keys(resolved, collection)
                for (j = 1; j <= collection_count[collection]; j++) {
                    key = collection_key[collection, j]
                    expression_stream_push(output, mapping_lookup(resolved, key))
                }
            } else {
                if (expression_optional[expression]) {
                    continue
                }
                if (node_kind[resolved] == "scalar") {
                    fail("cannot iterate over " node_type[resolved])
                }
                fail("cannot iterate over " node_kind[resolved])
            }
        }
        return output
    }
    if (kind == "dynamic") {
        middle = expression_evaluate(expression_left[expression], input)
        for (i = 1; i <= expression_stream_count[middle]; i++) {
            node = expression_stream_node[middle, i]
            resolved = resolve_alias(node)
            single = expression_stream_single(resolved)
            argument_stream = expression_evaluate(expression_right[expression], single)
            for (j = 1; j <= expression_stream_count[argument_stream]; j++) {
                argument = resolve_alias(expression_stream_node[argument_stream, j])
                if (node_kind[argument] != "scalar") {
                    fail("dynamic indexes require a scalar key or index")
                }
                if (node_kind[resolved] == "sequence" && node_type[argument] == "int") {
                    collection = node_value[argument] + 0
                    if (collection < 0) {
                        collection = sequence_count[resolved] + collection
                    }
                    if (collection >= 0 && collection < sequence_count[resolved]) {
                        expression_stream_push(output, sequence_child[resolved, collection + 1])
                    } else {
                        expression_stream_push(output, expression_null())
                    }
                } else if (node_kind[resolved] == "mapping") {
                    key = node_value[argument]
                    child = mapping_lookup(resolved, key)
                    if (child) {
                        expression_stream_push(output, child)
                    } else {
                        child = expression_null()
                        expression_missing_parent[child] = resolved
                        expression_missing_key[child] = key
                        expression_stream_push(output, child)
                    }
                } else if (!expression_optional[expression]) {
                    fail("dynamic indexing requires a mapping or sequence")
                }
            }
        }
        return output
    }
    if ((kind == "assign" || kind == "update") && expression_kind[expression_left[expression]] == "node_property") {
        property_expression = expression_left[expression]
        property = expression_value[property_expression]
        for (i = 1; i <= expression_stream_count[input]; i++) {
            node = expression_stream_node[input, i]
            single = expression_stream_single(node)
            left_stream = expression_evaluate(expression_left[property_expression], single)
            if (kind == "assign") {
                right_stream = expression_evaluate(expression_right[expression], single)
                if (!expression_stream_count[right_stream]) {
                    expression_stream_push(right_stream, expression_null())
                }
            }
            for (j = 1; j <= expression_stream_count[left_stream]; j++) {
                child = expression_stream_node[left_stream, j]
                if (kind == "update") {
                    middle = expression_stream_single(expression_scalar(expression_node_property_value(child, property), "string"))
                    right_stream = expression_evaluate(expression_right[expression], middle)
                    if (!expression_stream_count[right_stream]) {
                        expression_stream_push(right_stream, expression_scalar("", "string"))
                    }
                    argument = expression_stream_node[right_stream, 1]
                } else {
                    collection = expression_stream_count[right_stream] == expression_stream_count[left_stream] ? j : 1
                    argument = expression_stream_node[right_stream, collection]
                }
                if (explain_mode) {
                    input_target = explain_input_target(child)
                    mutation_path = explain_path(child) " " property
                }
                expression_set_node_property(child, property, argument)
                if (expression_last_property_changed) {
                    expression_mark_changed(child)
                }
                if (explain_mode && input_target && expression_last_property_changed) {
                    explain_record_mutation("replace", mutation_path, child)
                }
            }
            expression_stream_push(output, node)
        }
        return output
    }
    if (kind == "setpath") {
        for (i = 1; i <= expression_stream_count[input]; i++) {
            node = expression_stream_node[input, i]
            single = expression_stream_single(node)
            path_stream = expression_evaluate(expression_left[expression], single)
            value_stream = expression_evaluate(expression_right[expression], single)
            if (!expression_stream_count[path_stream]) {
                fail("setpath path produced no value")
            }
            child = expression_stream_count[value_stream] ? expression_stream_node[value_stream, 1] : expression_null()
            result_node = expression_follow_path(node, expression_stream_node[path_stream, 1], 1)
            was_missing = expression_path_was_missing
            if (explain_mode) {
                input_target = explain_input_target(result_node)
                mutation_path = explain_path(result_node)
            }
            expression_replace_node(result_node, child)
            if (expression_last_replace_changed) {
                expression_mark_changed(result_node)
            }
            if (explain_mode && input_target && expression_last_replace_changed) {
                explain_record_mutation(was_missing ? "insert" : "replace", mutation_path, result_node)
            }
            expression_stream_push(output, node)
        }
        return output
    }
    if (kind == "delpaths") {
        path_serial = ++expression_path_serial
        for (i = 1; i <= expression_stream_count[input]; i++) {
            target_count = 0
            node = expression_stream_node[input, i]
            single = expression_stream_single(node)
            path_stream = expression_evaluate(expression_left[expression], single)
            if (!expression_stream_count[path_stream]) {
                expression_stream_push(output, node)
                continue
            }
            path_node = resolve_alias(expression_stream_node[path_stream, 1])
            if (node_kind[path_node] != "sequence") {
                fail("delpaths requires an array of paths")
            }
            for (j = 1; j <= sequence_count[path_node]; j++) {
                child = expression_follow_path(node, sequence_child[path_node, j], 0)
                if (child) {
                    expression_path_target[path_serial, ++target_count] = child
                }
            }
            for (j = target_count; j >= 1; j--) {
                child = expression_path_target[path_serial, j]
                if (explain_mode) {
                    input_target = explain_input_target(child)
                    mutation_path = explain_path(child)
                }
                expression_delete_node(child)
                if (expression_last_delete_changed) {
                    expression_mark_changed(child)
                }
                if (explain_mode && input_target && expression_last_delete_changed) {
                    explain_record_mutation("delete", mutation_path, child)
                }
                delete expression_path_target[path_serial, j]
            }
            expression_stream_push(output, node)
        }
        return output
    }
    if (kind == "assign" || kind == "update") {
        left_stream = expression_evaluate(expression_left[expression], input)
        if (kind == "assign") {
            right_stream = expression_evaluate(expression_right[expression], input)
            if (!expression_stream_count[right_stream]) {
                expression_stream_push(right_stream, expression_null())
            }
            for (i = 1; i <= expression_stream_count[left_stream]; i++) {
                j = expression_stream_count[right_stream] == expression_stream_count[left_stream] ? i : 1
                node = expression_stream_node[left_stream, i]
                if (explain_mode) {
                    input_target = explain_input_target(node)
                    mutation_path = explain_path(node)
                    was_missing = (node in expression_missing_parent) && !expression_placeholder_attached[node]
                }
                expression_replace_node(node, expression_stream_node[right_stream, j])
                if (expression_last_replace_changed) {
                    expression_mark_changed(node)
                }
                if (explain_mode && input_target && expression_last_replace_changed) {
                    explain_record_mutation(was_missing ? "insert" : "replace", mutation_path, node)
                }
            }
        } else {
            for (i = 1; i <= expression_stream_count[left_stream]; i++) {
                node = expression_stream_node[left_stream, i]
                single = expression_stream_single(node)
                right_stream = expression_evaluate(expression_right[expression], single)
                child = expression_stream_count[right_stream] ? expression_stream_node[right_stream, 1] : expression_null()
                if (explain_mode) {
                    input_target = explain_input_target(node)
                    mutation_path = explain_path(node)
                    was_missing = (node in expression_missing_parent) && !expression_placeholder_attached[node]
                }
                expression_replace_node(node, child)
                if (expression_last_replace_changed) {
                    expression_mark_changed(node)
                }
                if (explain_mode && input_target && expression_last_replace_changed) {
                    explain_record_mutation(was_missing ? "insert" : "replace", mutation_path, node)
                }
            }
        }
        expression_stream_append(output, input)
        return output
    }
    if (kind == "del") {
        middle = expression_evaluate(expression_left[expression], input)
        for (i = expression_stream_count[middle]; i >= 1; i--) {
            node = expression_stream_node[middle, i]
            if (explain_mode) {
                input_target = explain_input_target(node)
                mutation_path = explain_path(node)
            }
            expression_delete_node(node)
            if (expression_last_delete_changed) {
                expression_mark_changed(node)
            }
            if (explain_mode && input_target && expression_last_delete_changed) {
                explain_record_mutation("delete", mutation_path, node)
            }
        }
        expression_stream_append(output, input)
        return output
    }
    if (kind == "select") {
        for (i = 1; i <= expression_stream_count[input]; i++) {
            node = expression_stream_node[input, i]
            single = expression_stream_single(node)
            predicate = expression_evaluate(expression_left[expression], single)
            matched = 0
            for (j = 1; j <= expression_stream_count[predicate]; j++) {
                if (expression_truthy(expression_stream_node[predicate, j])) {
                    matched = 1
                    break
                }
            }
            if (matched) {
                expression_stream_push(output, node)
            }
        }
        return output
    }
    if (kind == "compare") {
        for (i = 1; i <= expression_stream_count[input]; i++) {
            single = expression_stream_single(expression_stream_node[input, i])
            left_stream = expression_evaluate(expression_left[expression], single)
            right_stream = expression_evaluate(expression_right[expression], single)
            for (j = 1; j <= expression_stream_count[left_stream]; j++) {
                for (collection = 1; collection <= expression_stream_count[right_stream]; collection++) {
                    node = expression_stream_node[left_stream, j]
                    child = expression_stream_node[right_stream, collection]
                    matched = expression_compare(node, child, expression_value[expression])
                    expression_stream_push(output, expression_boolean(matched))
                }
            }
        }
        return output
    }
    if (kind == "and" || kind == "or") {
        for (i = 1; i <= expression_stream_count[input]; i++) {
            single = expression_stream_single(expression_stream_node[input, i])
            left_stream = expression_evaluate(expression_left[expression], single)
            if (!expression_stream_count[left_stream]) {
                if (kind == "and") {
                    expression_stream_push(output, expression_boolean(0))
                } else {
                    right_stream = expression_evaluate(expression_right[expression], single)
                    for (collection = 1; collection <= expression_stream_count[right_stream]; collection++) {
                        expression_stream_push(output, expression_boolean(expression_truthy(expression_stream_node[right_stream, collection])))
                    }
                }
                continue
            }
            for (j = 1; j <= expression_stream_count[left_stream]; j++) {
                node = expression_stream_node[left_stream, j]
                matched = expression_truthy(node)
                if ((kind == "or" && matched) || (kind == "and" && !matched)) {
                    expression_stream_push(output, expression_boolean(matched))
                    continue
                }
                right_stream = expression_evaluate(expression_right[expression], single)
                for (collection = 1; collection <= expression_stream_count[right_stream]; collection++) {
                    child = expression_stream_node[right_stream, collection]
                    expression_stream_push(output, expression_boolean(expression_truthy(child)))
                }
            }
        }
        return output
    }
    if (kind == "not") {
        middle = expression_evaluate(expression_left[expression], input)
        for (i = 1; i <= expression_stream_count[middle]; i++) {
            expression_stream_push(output, expression_boolean(!expression_truthy(expression_stream_node[middle, i])))
        }
        return output
    }
    if (kind == "alternative") {
        for (i = 1; i <= expression_stream_count[input]; i++) {
            single = expression_stream_single(expression_stream_node[input, i])
            left_stream = expression_evaluate(expression_left[expression], single)
            matched = 0
            for (j = 1; j <= expression_stream_count[left_stream]; j++) {
                node = expression_stream_node[left_stream, j]
                if (expression_truthy(node)) {
                    expression_stream_push(output, node)
                    matched = 1
                }
            }
            if (!matched) {
                right_stream = expression_evaluate(expression_right[expression], single)
                expression_stream_append(output, right_stream)
            }
        }
        return output
    }
    fail("expression kind reached the wrong evaluator family: " kind)
}

