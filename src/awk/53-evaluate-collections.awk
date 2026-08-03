function expression_evaluate_collections(kind, expression, input,    output, middle, left_stream, right_stream, single, node, resolved, child, i, j, collection, key, predicate, matched, argument_stream, argument, result_node, variable, previous, had, accumulator, update_stream, start_index, end_index, size, interpolation, partial_count, next_count, partial, stage, mutation_path, mutation_kind, was_missing, input_target, path_stream, value_stream, path_node, path_serial, target_count, property_expression, property) {
    output = expression_stream_new()
    if (kind == "map" || kind == "map_values") {
        for (i = 1; i <= expression_stream_count[input]; i++) {
            node = expression_stream_node[input, i]
            resolved = resolve_alias(node)
            if (node_kind[resolved] != "sequence" && node_kind[resolved] != "mapping") {
                fail(kind " requires a sequence or mapping")
            }
            result_node = new_node(kind == "map" ? "sequence" : node_kind[resolved], 0, "", "", "")
            if (node_kind[resolved] == "sequence") {
                for (j = 1; j <= sequence_count[resolved]; j++) {
                    single = expression_stream_single(sequence_child[resolved, j])
                    argument_stream = expression_evaluate(expression_left[expression], single)
                    for (collection = 1; collection <= expression_stream_count[argument_stream]; collection++) {
                        add_sequence(result_node, expression_clone_node(expression_stream_node[argument_stream, collection]), 0)
                    }
                }
            } else {
                collection = ++collection_serial
                collect_mapping_keys(resolved, collection)
                for (j = 1; j <= collection_count[collection]; j++) {
                    key = collection_key[collection, j]
                    single = expression_stream_single(mapping_lookup(resolved, key))
                    argument_stream = expression_evaluate(expression_left[expression], single)
                    if (kind == "map") {
                        for (matched = 1; matched <= expression_stream_count[argument_stream]; matched++) {
                            add_sequence(result_node, expression_clone_node(expression_stream_node[argument_stream, matched]), 0)
                        }
                    } else if (expression_stream_count[argument_stream]) {
                        add_mapping(result_node, key, expression_clone_node(expression_stream_node[argument_stream, 1]), 0, 0)
                    }
                }
            }
            expression_stream_push(output, result_node)
        }
        return output
    }
    if (kind == "to_entries" || kind == "from_entries" || kind == "with_entries") {
        for (i = 1; i <= expression_stream_count[input]; i++) {
            node = resolve_alias(expression_stream_node[input, i])
            if (kind == "to_entries") {
                result_node = new_node("sequence", 0, "", "", "")
                if (node_kind[node] == "mapping") {
                    collection = ++collection_serial
                    collect_mapping_keys(node, collection)
                    for (j = 1; j <= collection_count[collection]; j++) {
                        key = collection_key[collection, j]
                        add_sequence(result_node, expression_entry(key, mapping_lookup(node, key), "string"), 0)
                    }
                } else if (node_kind[node] == "sequence") {
                    for (j = 1; j <= sequence_count[node]; j++) {
                        add_sequence(result_node, expression_entry((j - 1) "", sequence_child[node, j], "int"), 0)
                    }
                } else {
                    fail("to_entries requires a mapping or sequence")
                }
                expression_stream_push(output, result_node)
                continue
            }
            if (kind == "with_entries") {
                if (node_kind[node] != "mapping" && node_kind[node] != "sequence") {
                    fail("with_entries requires a mapping or sequence")
                }
                middle = expression_stream_new()
                if (node_kind[node] == "mapping") {
                    collection = ++collection_serial
                    collect_mapping_keys(node, collection)
                    for (j = 1; j <= collection_count[collection]; j++) {
                        key = collection_key[collection, j]
                        single = expression_stream_single(expression_entry(key, mapping_lookup(node, key), "string"))
                        argument_stream = expression_evaluate(expression_left[expression], single)
                        expression_stream_append(middle, argument_stream)
                    }
                } else {
                    for (j = 1; j <= sequence_count[node]; j++) {
                        single = expression_stream_single(expression_entry((j - 1) "", sequence_child[node, j], "int"))
                        argument_stream = expression_evaluate(expression_left[expression], single)
                        expression_stream_append(middle, argument_stream)
                    }
                }
            } else {
                if (node_kind[node] != "sequence") {
                    fail("from_entries requires a sequence")
                }
                middle = expression_stream_new()
                for (j = 1; j <= sequence_count[node]; j++) {
                    expression_stream_push(middle, sequence_child[node, j])
                }
            }
            result_node = new_node("mapping", 0, "", "", "")
            for (j = 1; j <= expression_stream_count[middle]; j++) {
                child = resolve_alias(expression_stream_node[middle, j])
                if (node_kind[child] != "mapping" || !mapping_lookup(child, "key") || !mapping_lookup(child, "value")) {
                    fail(kind " requires entries containing key and value")
                }
                key = expression_string_value(mapping_lookup(child, "key"))
                if (mapping_lookup(result_node, key)) {
                    expression_replace_node(mapping_lookup(result_node, key), mapping_lookup(child, "value"))
                } else {
                    add_mapping(result_node, key, expression_clone_node(mapping_lookup(child, "value")), 0, 0)
                }
            }
            expression_stream_push(output, result_node)
        }
        return output
    }
    if (kind == "array_to_map") {
        for (i = 1; i <= expression_stream_count[input]; i++) {
            node = resolve_alias(expression_stream_node[input, i])
            if (node_kind[node] != "sequence") {
                fail("array_to_map requires a sequence")
            }
            result_node = new_node("mapping", 0, "", "", "")
            for (j = 1; j <= sequence_count[node]; j++) {
                add_mapping(result_node, (j - 1) "", expression_clone_node(sequence_child[node, j]), 0, 0)
            }
            expression_stream_push(output, result_node)
        }
        return output
    }
    if (kind == "sort" || kind == "unique" || kind == "reverse" || kind == "flatten") {
        for (i = 1; i <= expression_stream_count[input]; i++) {
            node = resolve_alias(expression_stream_node[input, i])
            if (node_kind[node] != "sequence") {
                fail(kind " requires a sequence")
            }
            result_node = new_node("sequence", 0, "", "", "")
            if (kind == "flatten") {
                expression_flatten_into(node, result_node)
            } else if (kind == "reverse") {
                for (j = sequence_count[node]; j >= 1; j--) {
                    add_sequence(result_node, expression_clone_node(sequence_child[node, j]), 0)
                }
            } else if (kind == "unique") {
                middle = ++expression_sort_serial
                for (j = 1; j <= sequence_count[node]; j++) {
                    child = sequence_child[node, j]
                    key = middle SUBSEP expression_fingerprint(child)
                    if (!(key in expression_unique_seen)) {
                        expression_unique_seen[key] = 1
                        add_sequence(result_node, expression_clone_node(child), 0)
                    }
                }
            } else {
                middle = ++expression_sort_serial
                matched = 0
                for (j = 1; j <= sequence_count[node]; j++) {
                    child = sequence_child[node, j]
                    collection = ++matched
                    while (collection > 1 && expression_sort_less(child, expression_sort_node[middle, collection - 1])) {
                        expression_sort_node[middle, collection] = expression_sort_node[middle, collection - 1]
                        collection--
                    }
                    expression_sort_node[middle, collection] = child
                }
                for (j = 1; j <= matched; j++) {
                    add_sequence(result_node, expression_clone_node(expression_sort_node[middle, j]), 0)
                }
            }
            expression_stream_push(output, result_node)
        }
        return output
    }
    if (kind == "sort_keys") {
        middle = expression_evaluate(expression_left[expression], input)
        matched = expression_kind[expression_left[expression]] == "recursive"
        if (matched) {
            if (expression_stream_count[middle]) {
                if (inplace_mode) {
                    presentation_possible = 0
                }
                expression_stream_push(output, expression_sort_keys_clone(expression_stream_node[middle, 1], 1))
            }
            return output
        }
        for (i = 1; i <= expression_stream_count[middle]; i++) {
            expression_stream_push(output, expression_sort_keys_clone(expression_stream_node[middle, i], 0))
        }
        return output
    }
    if (kind == "min_by" || kind == "max_by") {
        for (i = 1; i <= expression_stream_count[input]; i++) {
            node = resolve_alias(expression_stream_node[input, i])
            if (node_kind[node] != "sequence") {
                fail(kind " requires a sequence")
            }
            child = 0
            argument = 0
            for (j = 1; j <= sequence_count[node]; j++) {
                result_node = sequence_child[node, j]
                single = expression_stream_single(result_node)
                argument_stream = expression_evaluate(expression_left[expression], single)
                key = expression_stream_count[argument_stream] ? expression_stream_node[argument_stream, 1] : expression_null()
                if (!child || (kind == "min_by" && expression_sort_less(key, argument)) ||
                    (kind == "max_by" && expression_sort_less(argument, key))) {
                    child = result_node
                    argument = key
                }
            }
            if (child) {
                expression_stream_push(output, expression_clone_node(child))
            }
        }
        return output
    }
    if (kind == "sort_by" || kind == "group_by" || kind == "unique_by") {
        for (i = 1; i <= expression_stream_count[input]; i++) {
            node = resolve_alias(expression_stream_node[input, i])
            if (node_kind[node] != "sequence") {
                fail(kind " requires a sequence")
            }
            result_node = new_node("sequence", 0, "", "", "")
            middle = ++expression_sort_serial
            matched = 0
            for (j = 1; j <= sequence_count[node]; j++) {
                child = sequence_child[node, j]
                single = expression_stream_single(child)
                argument_stream = expression_evaluate(expression_left[expression], single)
                argument = expression_stream_count[argument_stream] ? expression_stream_node[argument_stream, 1] : expression_null()
                if (kind == "unique_by") {
                    key = middle SUBSEP expression_fingerprint(argument)
                    if (!(key in expression_unique_seen)) {
                        expression_unique_seen[key] = 1
                        add_sequence(result_node, expression_clone_node(child), 0)
                    }
                } else if (kind == "group_by") {
                    key = middle SUBSEP expression_fingerprint(argument)
                    collection = expression_group_index[key]
                    if (!collection) {
                        collection = ++matched
                        expression_group_index[key] = collection
                        expression_sort_node[middle, collection] = new_node("sequence", 0, "", "", "")
                        add_sequence(result_node, expression_sort_node[middle, collection], 0)
                    }
                    add_sequence(expression_sort_node[middle, collection], expression_clone_node(child), 0)
                } else {
                    collection = ++matched
                    while (collection > 1 && expression_sort_less(argument, expression_sort_key[middle, collection - 1])) {
                        expression_sort_key[middle, collection] = expression_sort_key[middle, collection - 1]
                        expression_sort_node[middle, collection] = expression_sort_node[middle, collection - 1]
                        collection--
                    }
                    expression_sort_key[middle, collection] = argument
                    expression_sort_node[middle, collection] = child
                }
            }
            if (kind == "sort_by") {
                for (j = 1; j <= matched; j++) {
                    add_sequence(result_node, expression_clone_node(expression_sort_node[middle, j]), 0)
                }
            }
            expression_stream_push(output, result_node)
        }
        return output
    }
    if (kind == "add") {
        for (i = 1; i <= expression_stream_count[input]; i++) {
            node = resolve_alias(expression_stream_node[input, i])
            if (node_kind[node] != "sequence") {
                fail("add requires a sequence")
            }
            if (!sequence_count[node]) {
                expression_stream_push(output, expression_null())
                continue
            }
            child = expression_clone_node(sequence_child[node, 1])
            for (j = 2; j <= sequence_count[node]; j++) {
                child = expression_arithmetic(child, sequence_child[node, j], "+")
            }
            expression_stream_push(output, child)
        }
        return output
    }
    if (kind == "min" || kind == "max" || kind == "any" || kind == "all" || kind == "any_c" || kind == "all_c") {
        for (i = 1; i <= expression_stream_count[input]; i++) {
            node = resolve_alias(expression_stream_node[input, i])
            if (node_kind[node] != "sequence") {
                fail(kind " requires a sequence")
            }
            if (kind == "min" || kind == "max") {
                if (!sequence_count[node]) {
                    continue
                }
                child = sequence_child[node, 1]
                for (j = 2; j <= sequence_count[node]; j++) {
                    argument = sequence_child[node, j]
                    if ((kind == "min" && expression_sort_less(argument, child)) ||
                        (kind == "max" && expression_sort_less(child, argument))) {
                        child = argument
                    }
                }
                expression_stream_push(output, expression_clone_node(child))
                continue
            }
            matched = kind == "all" || kind == "all_c"
            for (j = 1; j <= sequence_count[node]; j++) {
                child = sequence_child[node, j]
                if (kind == "any_c" || kind == "all_c") {
                    single = expression_stream_single(child)
                    argument_stream = expression_evaluate(expression_left[expression], single)
                    predicate = 0
                    for (collection = 1; collection <= expression_stream_count[argument_stream]; collection++) {
                        if (expression_truthy(expression_stream_node[argument_stream, collection])) {
                            predicate = 1
                        }
                    }
                } else {
                    predicate = expression_truthy(child)
                }
                if ((kind == "any" || kind == "any_c") && predicate) {
                    matched = 1
                    break
                }
                if ((kind == "all" || kind == "all_c") && !predicate) {
                    matched = 0
                    break
                }
            }
            expression_stream_push(output, expression_boolean(matched))
        }
        return output
    }
    if (kind == "upcase" || kind == "downcase" || kind == "trim" || kind == "to_string" ||
        kind == "regex_test" || kind == "regex_sub" || kind == "contains" || kind == "startswith" ||
        kind == "endswith" || kind == "split" || kind == "join") {
        return expression_evaluate_string(kind, expression, input)
    }
    if (kind == "length" || kind == "keys" || kind == "kind" || kind == "type" || kind == "has") {
        for (i = 1; i <= expression_stream_count[input]; i++) {
            node = expression_stream_node[input, i]
            resolved = resolve_alias(node)
            if (kind == "length") {
                if (node_kind[resolved] == "mapping") {
                    matched = expression_mapping_length(resolved)
                } else if (node_kind[resolved] == "sequence") {
                    matched = sequence_count[resolved] + 0
                } else if (node_type[resolved] == "null") {
                    matched = 0
                } else {
                    matched = length(node_value[resolved])
                }
                expression_stream_push(output, expression_scalar(matched "", "int"))
            } else if (kind == "kind") {
                expression_stream_push(output, expression_scalar(expression_kind_name(resolved), "string"))
            } else if (kind == "type") {
                expression_stream_push(output, expression_scalar(expression_type_name(resolved), "string"))
            } else if (kind == "keys") {
                result_node = new_node("sequence", 0, "", "", "")
                if (node_kind[resolved] == "mapping") {
                    collection = ++collection_serial
                    collect_mapping_keys(resolved, collection)
                    for (j = 1; j <= collection_count[collection]; j++) {
                        add_sequence(result_node, expression_scalar(collection_key[collection, j], "string"), 0)
                    }
                } else if (node_kind[resolved] == "sequence") {
                    for (j = 0; j < sequence_count[resolved]; j++) {
                        add_sequence(result_node, expression_scalar(j "", "int"), 0)
                    }
                } else {
                    fail("keys requires a mapping or sequence")
                }
                expression_stream_push(output, result_node)
            } else {
                single = expression_stream_single(node)
                argument_stream = expression_evaluate(expression_left[expression], single)
                if (expression_stream_count[argument_stream] < 1) {
                    expression_stream_push(output, expression_boolean(0))
                    continue
                }
                argument = resolve_alias(expression_stream_node[argument_stream, 1])
                if (node_kind[argument] != "scalar") {
                    fail("has requires a scalar key or index")
                }
                if (node_kind[resolved] == "mapping") {
                    matched = mapping_lookup(resolved, node_value[argument]) != 0
                } else if (node_kind[resolved] == "sequence" && node_type[argument] == "int") {
                    collection = node_value[argument] + 0
                    if (collection < 0) {
                        collection = sequence_count[resolved] + collection
                    }
                    matched = collection >= 0 && collection < sequence_count[resolved]
                } else {
                    matched = 0
                }
                expression_stream_push(output, expression_boolean(matched))
            }
        }
        return output
    }
    fail("expression kind reached the wrong evaluator family: " kind)
}

