function explain_path(node,    depth, current, parent, edge, i, result, key) {
    depth = 0
    current = node
    while (current) {
        if ((current in expression_missing_parent) && !expression_placeholder_attached[current]) {
            parent = expression_missing_parent[current]
            edge = "key " expression_missing_key[current]
        } else if (current in node_parent) {
            parent = node_parent[current]
            edge = node_parent_edge[current]
        } else {
            break
        }
        explain_path_edge[++depth] = edge
        current = parent
    }
    result = ""
    for (i = depth; i >= 1; i--) {
        edge = explain_path_edge[i]
        if (substr(edge, 1, 6) == "index ") {
            result = result "[" substr(edge, 7) "]"
        } else {
            key = substr(edge, 5)
            if (key ~ /^[A-Za-z_][A-Za-z0-9_-]*$/) {
                result = result "." key
            } else {
                result = result "[" json_quote(key) "]"
            }
        }
        delete explain_path_edge[i]
    }
    return result == "" ? "." : result
}

function explain_record_mutation(kind, path, node,    file) {
    explain_mutation_count++
    file = expression_input_file(node)
    explain_mutation_file[explain_mutation_count] = file
    if (kind == "insert") {
        explain_insertion_count++
    } else if (kind == "delete") {
        explain_deletion_count++
    } else {
        explain_replacement_count++
    }
    if (explain_mode == 2 || explain_mutation_count <= 20) {
        explain_mutation_kind[explain_mutation_count] = kind
        explain_mutation_path[explain_mutation_count] = path
    }
}

function expression_effective_root(node,    current) {
    current = node
    while (current) {
        if ((current in expression_missing_parent) && !expression_placeholder_attached[current]) {
            current = expression_missing_parent[current]
        } else if (current in node_parent) {
            current = node_parent[current]
        } else {
            break
        }
    }
    return current
}

function explain_input_target(node,    current, document) {
    current = expression_effective_root(node)
    for (document = 0; document <= document_index; document++) {
        if ((document in document_root) && document_root[document] == current) {
            return 1
        }
    }
    return 0
}

function expression_input_file(node,    current) {
    current = expression_effective_root(node)
    return (current in node_file_index) ? node_file_index[current] : input_file_index + 0
}

function expression_mark_changed(node,    file) {
    expression_any_change = 1
    file = expression_input_file(node)
    expression_file_changed[file] = 1
}

# Explain bookkeeping must capture the path before the mutation rewrites the
# node's ancestry, so these helpers own the mutation call itself.
function expression_apply_replace(target, source, was_missing,    input_target, mutation_path) {
    if (explain_mode) {
        input_target = explain_input_target(target)
        mutation_path = explain_path(target)
    }
    expression_replace_node(target, source)
    if (expression_last_replace_changed) {
        expression_mark_changed(target)
        if (explain_mode && input_target) {
            explain_record_mutation(was_missing ? "insert" : "replace", mutation_path, target)
        }
    }
}

function expression_apply_delete(target,    input_target, mutation_path) {
    if (explain_mode) {
        input_target = explain_input_target(target)
        mutation_path = explain_path(target)
    }
    expression_delete_node(target)
    if (expression_last_delete_changed) {
        expression_mark_changed(target)
        if (explain_mode && input_target) {
            explain_record_mutation("delete", mutation_path, target)
        }
    }
}

function expression_envsubst(value, options,    result, i, char, closing, name, start, body, suffix, replacement, is_set) {
    result = ""
    i = 1
    while (i <= length(value)) {
        char = substr(value, i, 1)
        if (char != "$") {
            result = result char
            i++
            continue
        }
        if (substr(value, i + 1, 1) == "{") {
            closing = index(substr(value, i + 2), "}")
            if (!closing) {
                result = result char
                i++
                continue
            }
            body = substr(value, i + 2, closing - 1)
            name = ""
            start = 1
            if (substr(body, start, 1) ~ /^[A-Za-z_]$/) {
                while (substr(body, start, 1) ~ /^[A-Za-z0-9_]$/) {
                    name = name substr(body, start, 1)
                    start++
                }
            }
            suffix = substr(body, start)
            is_set = name in ENVIRON
            if (name == "") {
                result = result substr(value, i, closing + 2)
            } else if (substr(suffix, 1, 2) == ":-") {
                replacement = substr(suffix, 3)
                if (!is_set || ENVIRON[name] == "") {
                    result = result replacement
                } else {
                    result = result ENVIRON[name]
                }
            } else if (substr(suffix, 1, 1) == "-") {
                replacement = substr(suffix, 2)
                if (is_set) {
                    result = result ENVIRON[name]
                } else {
                    result = result replacement
                }
            } else if (suffix != "") {
                result = result substr(value, i, closing + 2)
            } else {
                if (index(options, " nu ") && !is_set) {
                    fail("environment variable " name " is not set")
                }
                if (index(options, " ne ") && is_set && ENVIRON[name] == "") {
                    fail("environment variable " name " is empty")
                }
                result = result ENVIRON[name]
            }
            i += closing + 2
            continue
        }
        start = i + 1
        name = ""
        if (substr(value, start, 1) ~ /^[A-Za-z_]$/) {
            while (substr(value, start, 1) ~ /^[A-Za-z0-9_]$/) {
                name = name substr(value, start, 1)
                start++
            }
        }
        if (name == "") {
            result = result char
            i++
        } else {
            if (index(options, " nu ") && !(name in ENVIRON)) {
                fail("environment variable " name " is not set")
            }
            if (index(options, " ne ") && (name in ENVIRON) && ENVIRON[name] == "") {
                fail("environment variable " name " is empty")
            }
            result = result ENVIRON[name]
            i = start
        }
    }
    return result
}

function expression_sort_mapping(node,    result, collection, count, i, j, key) {
    result = new_node("mapping", 0, "", "", "")
    collection = ++collection_serial
    collect_mapping_keys(node, collection)
    count = collection_count[collection]
    for (i = 1; i <= count; i++) {
        key = collection_key[collection, i]
        j = i
        while (j > 1 && key < expression_sorted_key[j - 1]) {
            expression_sorted_key[j] = expression_sorted_key[j - 1]
            j--
        }
        expression_sorted_key[j] = key
    }
    for (i = 1; i <= count; i++) {
        key = expression_sorted_key[i]
        add_mapping(result, key, expression_clone_node(mapping_lookup(node, key)), 0, 0)
        delete expression_sorted_key[i]
    }
    return result
}

function expression_sort_keys_clone(node, recursive,    resolved, result, i, replacement) {
    resolved = resolve_alias(node)
    if (node_kind[resolved] == "mapping") {
        result = expression_sort_mapping(resolved)
        if (recursive) {
            for (i = 1; i <= mapping_count[result]; i++) {
                replacement = expression_sort_keys_clone(mapping_child[result, i], 1)
                mapping_child[result, i] = replacement
                node_parent[replacement] = result
                node_parent_edge[replacement] = "key " mapping_key[result, i]
            }
        }
        return result
    }
    result = expression_clone_node(node)
    if (recursive && node_kind[resolved] == "sequence") {
        for (i = 1; i <= sequence_count[result]; i++) {
            replacement = expression_sort_keys_clone(sequence_child[result, i], 1)
            sequence_child[result, i] = replacement
            node_parent[replacement] = result
            node_parent_edge[replacement] = "index " (i - 1)
        }
    }
    return result
}

function expression_predicate_matches(expression, node,    stream, result, i) {
    stream = expression_stream_single(node)
    result = expression_evaluate(expression, stream)
    for (i = 1; i <= expression_stream_count[result]; i++) {
        if (expression_truthy(expression_stream_node[result, i])) {
            return 1
        }
    }
    return 0
}

function expression_pick_or_omit(node, choices, omit_mode,    result, selected, i, j, choice, key, child, collection) {
    if (node_kind[node] != "mapping" && node_kind[node] != "sequence") {
        fail((omit_mode ? "omit" : "pick") " requires a mapping or sequence")
    }
    result = new_node(node_kind[node], 0, "", "", "")
    selected = ++expression_selection_serial
    for (i = 1; i <= sequence_count[choices]; i++) {
        choice = resolve_alias(sequence_child[choices, i])
        if (node_kind[choice] != "scalar") {
            fail((omit_mode ? "omit" : "pick") " choices must be scalar keys or indexes")
        }
        if (node_kind[node] == "mapping") {
            key = node_value[choice]
            child = mapping_lookup(node, key)
            if (child && !(selected SUBSEP key in expression_selected)) {
                expression_selected[selected, key] = 1
                if (!omit_mode) {
                    add_mapping(result, key, expression_clone_node(child), 0, 0)
                }
            }
        } else if (node_type[choice] == "int") {
            j = node_value[choice] + 0
            if (j >= 0 && j < sequence_count[node]) {
                expression_selected[selected, j] = 1
                if (!omit_mode) {
                    add_sequence(result, expression_clone_node(sequence_child[node, j + 1]), 0)
                }
            }
        }
    }
    if (omit_mode && node_kind[node] == "mapping") {
        collection = ++collection_serial
        collect_mapping_keys(node, collection)
        for (i = 1; i <= collection_count[collection]; i++) {
            key = collection_key[collection, i]
            if (!(selected SUBSEP key in expression_selected)) {
                add_mapping(result, key, expression_clone_node(mapping_lookup(node, key)), 0, 0)
            }
        }
    } else if (omit_mode) {
        for (i = 0; i < sequence_count[node]; i++) {
            if (!(selected SUBSEP i in expression_selected)) {
                add_sequence(result, expression_clone_node(sequence_child[node, i + 1]), 0)
            }
        }
    }
    return result
}

function expression_pivot(node,    result, first, mode, max_count, i, j, child, row, collection, key, seen) {
    if (node_kind[node] != "sequence") {
        fail("pivot requires a sequence")
    }
    if (!sequence_count[node]) {
        return new_node("sequence", 0, "", "", "")
    }
    first = resolve_alias(sequence_child[node, 1])
    mode = node_kind[first]
    if (mode != "sequence" && mode != "mapping") {
        fail("pivot requires a sequence of sequences or mappings")
    }
    for (i = 1; i <= sequence_count[node]; i++) {
        child = resolve_alias(sequence_child[node, i])
        if (node_kind[child] != mode) {
            fail("pivot requires homogeneous collection kinds")
        }
        if (mode == "sequence" && sequence_count[child] > max_count) {
            max_count = sequence_count[child]
        }
    }
    if (mode == "sequence") {
        result = new_node("sequence", 0, "", "", "")
        for (j = 1; j <= max_count; j++) {
            row = new_node("sequence", 0, "", "", "")
            for (i = 1; i <= sequence_count[node]; i++) {
                child = resolve_alias(sequence_child[node, i])
                add_sequence(row, j <= sequence_count[child] ? expression_clone_node(sequence_child[child, j]) : expression_null(), 0)
            }
            add_sequence(result, row, 0)
        }
        return result
    }
    result = new_node("mapping", 0, "", "", "")
    seen = ++expression_selection_serial
    for (i = 1; i <= sequence_count[node]; i++) {
        child = resolve_alias(sequence_child[node, i])
        collection = ++collection_serial
        collect_mapping_keys(child, collection)
        for (j = 1; j <= collection_count[collection]; j++) {
            key = collection_key[collection, j]
            if (!(seen SUBSEP key in expression_selected)) {
                expression_selected[seen, key] = 1
                row = new_node("sequence", 0, "", "", "")
                add_mapping(result, key, row, 0, 0)
            }
        }
    }
    collection = ++collection_serial
    collect_mapping_keys(result, collection)
    for (j = 1; j <= collection_count[collection]; j++) {
        key = collection_key[collection, j]
        row = mapping_lookup(result, key)
        for (i = 1; i <= sequence_count[node]; i++) {
            child = resolve_alias(sequence_child[node, i])
            add_sequence(row, mapping_lookup(child, key) ? expression_clone_node(mapping_lookup(child, key)) : expression_null(), 0)
        }
    }
    return result
}

function expression_parse_unary(    operand) {
    if (expression_token_type == "not") {
        expression_lex_next()
        operand = expression_new("identity", 0, 0, "")
        return expression_new("not", operand, 0, "")
    }
    if (expression_token_type == "arithmetic" && expression_token_value == "-") {
        expression_lex_next()
        operand = expression_parse_unary()
        return expression_new("negate", operand, 0, "")
    }
    return expression_parse_primary()
}

function expression_parse_product(    left, operator, right) {
    left = expression_parse_unary()
    while (expression_token_type == "arithmetic" && (substr(expression_token_value, 1, 1) == "*" || expression_token_value == "/" || expression_token_value == "%")) {
        operator = expression_token_value
        expression_lex_next()
        right = expression_parse_unary()
        left = expression_new("arithmetic", left, right, operator)
    }
    return left
}

function expression_parse_sum(    left, operator, right) {
    left = expression_parse_product()
    while (expression_token_type == "arithmetic" && (expression_token_value == "+" || expression_token_value == "-")) {
        operator = expression_token_value
        expression_lex_next()
        right = expression_parse_product()
        left = expression_new("arithmetic", left, right, operator)
    }
    return left
}

function expression_parse_compare(    left, operator, right) {
    left = expression_parse_sum()
    while (expression_token_type == "compare") {
        operator = expression_token_value
        expression_lex_next()
        right = expression_parse_sum()
        left = expression_new("compare", left, right, operator)
    }
    return left
}

function expression_parse_and(    left, right) {
    left = expression_parse_compare()
    while (expression_token_type == "and") {
        expression_lex_next()
        right = expression_parse_compare()
        left = expression_new("and", left, right, "")
    }
    return left
}

function expression_parse_or(    left, right) {
    left = expression_parse_and()
    while (expression_token_type == "or") {
        expression_lex_next()
        right = expression_parse_and()
        left = expression_new("or", left, right, "")
    }
    return left
}

function expression_parse_alternative(    left, right) {
    left = expression_parse_or()
    while (expression_token_type == "alternative") {
        expression_lex_next()
        right = expression_parse_or()
        left = expression_new("alternative", left, right, "")
    }
    return left
}

function expression_parse_assignment(    left, right, kind, operator, identity, arithmetic) {
    left = expression_parse_alternative()
    if (expression_token_type == "assign" || expression_token_type == "update" || expression_token_type == "compound") {
        kind = expression_token_type
        operator = expression_token_value
        expression_lex_next()
        right = expression_parse_assignment()
        if (kind == "compound") {
            identity = expression_new("identity", 0, 0, "")
            arithmetic = expression_new("arithmetic", identity, right, substr(operator, 1, 1))
            return expression_new("update", left, arithmetic, "")
        }
        return expression_new(kind, left, right, "")
    }
    return left
}

function expression_parse_pipe(    left, right, variable, initial, update, reduction) {
    left = expression_parse_assignment()
    if (expression_token_type == "ref") {
        expression_lex_next()
        if (expression_token_type != "variable") fail("ref requires a variable")
        variable = expression_token_value
        expression_lex_next()
        expression_expect("pipe")
        right = expression_parse_pipe()
        return expression_new("bind", left, right, variable)
    }
    if (expression_token_type == "as") {
        expression_lex_next()
        if (expression_token_type != "variable") {
            fail("as requires a variable")
        }
        variable = expression_token_value
        expression_lex_next()
        if (expression_token_type == "identifier" && tolower(expression_token_value) == "ireduce") {
            expression_lex_next()
            expression_expect("left_parenthesis")
            initial = expression_parse_pipe()
            expression_expect("semicolon")
            update = expression_parse_pipe()
            expression_expect("right_parenthesis")
            reduction = expression_new("reduce", left, initial, variable)
            expression_child[reduction, 1] = update
            if (expression_token_type == "pipe") {
                expression_lex_next()
                right = expression_parse_pipe()
                return expression_new("pipe", reduction, right, "")
            }
            return reduction
        }
        expression_expect("pipe")
        right = expression_parse_pipe()
        return expression_new("bind", left, right, variable)
    }
    if (expression_token_type == "pipe") {
        expression_lex_next()
        right = expression_parse_pipe()
        return expression_new("pipe", left, right, "")
    }
    return left
}

function expression_parse_stream(    left, right) {
    left = expression_parse_pipe()
    while (expression_token_type == "comma") {
        expression_lex_next()
        right = expression_parse_pipe()
        left = expression_new("comma", left, right, "")
    }
    return left
}

function expression_parse(source,    expression) {
    expression_source = source
    expression_position = 1
    expression_count = 0
    expression_lex_next()
    expression = expression_parse_stream()
    if (expression_token_type != "end") {
        fail("unexpected token after expression: " expression_token_name(expression_token_type))
    }
    return expression
}

function collect_keys_from_source(source, collection,    resolved, i) {
    resolved = resolve_alias(source)
    if (node_kind[resolved] == "mapping") {
        collect_mapping_keys(resolved, collection)
    } else if (node_kind[resolved] == "sequence") {
        for (i = 1; i <= sequence_count[resolved]; i++) {
            collect_keys_from_source(sequence_child[resolved, i], collection)
        }
    }
}

function collect_mapping_keys(mapping, collection,    stack_key, seen_key, i, key) {
    mapping = resolve_alias(mapping)
    stack_key = collection SUBSEP mapping
    if (stack_key in collection_stack) {
        fail("recursive merge while collecting mapping keys")
    }
    collection_stack[stack_key] = 1

    for (i = 1; i <= mapping_count[mapping]; i++) {
        if (mapping_merge[mapping, i]) {
            collect_keys_from_source(mapping_child[mapping, i], collection)
        }
    }
    for (i = 1; i <= mapping_count[mapping]; i++) {
        if (!mapping_merge[mapping, i]) {
            key = mapping_key[mapping, i]
            seen_key = collection SUBSEP key
            if (!(seen_key in collection_seen)) {
                collection_seen[seen_key] = 1
                collection_key[collection, ++collection_count[collection]] = key
            }
        }
    }
    delete collection_stack[stack_key]
}

function expression_stream_new() {
    return ++expression_stream_serial
}

function expression_stream_push(stream, node) {
    expression_stream_node[stream, ++expression_stream_count[stream]] = node
}

function expression_stream_single(node,    stream) {
    stream = expression_stream_new()
    expression_stream_push(stream, node)
    return stream
}

function expression_stream_append(target, source,    i) {
    for (i = 1; i <= expression_stream_count[source]; i++) {
        expression_stream_push(target, expression_stream_node[source, i])
    }
}

function expression_scalar(value, value_type) {
    return new_node("scalar", 0, value, value_type, "")
}

function expression_boolean(value) {
    if (value) {
        return expression_scalar("true", "bool")
    }
    return expression_scalar("false", "bool")
}

function expression_null() {
    return expression_scalar("", "null")
}

function expression_truthy(node,    resolved, lowered) {
    resolved = resolve_alias(node)
    if (node_kind[resolved] != "scalar") {
        return 1
    }
    if (node_type[resolved] == "null") {
        return 0
    }
    if (node_type[resolved] == "bool") {
        lowered = tolower(node_value[resolved])
        return lowered != "false"
    }
    return 1
}

function expression_numeric(node,    resolved, value) {
    resolved = resolve_alias(node)
    if (node_type[resolved] == "int") {
        return json_integer(node_value[resolved]) + 0
    }
    value = node_value[resolved]
    gsub(/_/, "", value)
    if (tolower(value) ~ /\.(inf|nan)$/) {
        fail("non-finite numbers cannot be compared")
    }
    return value + 0
}

function expression_nodes_equal(left, right,    left_node, right_node) {
    left_node = resolve_alias(left)
    right_node = resolve_alias(right)
    if (node_kind[left_node] != "scalar" || node_kind[right_node] != "scalar") {
        return 0
    }
    if (node_type[left_node] == "null" || node_type[right_node] == "null") {
        return node_type[left_node] == "null" && node_type[right_node] == "null"
    }
    if ((node_type[left_node] == "int" || node_type[left_node] == "float") &&
        (node_type[right_node] == "int" || node_type[right_node] == "float")) {
        return expression_numeric(left_node) == expression_numeric(right_node)
    }
    if (node_type[left_node] == "bool" && node_type[right_node] == "bool") {
        return tolower(node_value[left_node]) == tolower(node_value[right_node])
    }
    return node_type[left_node] == node_type[right_node] && node_value[left_node] == node_value[right_node]
}

function expression_compare(left, right, operator,    left_node, right_node, left_value, right_value, equal) {
    equal = expression_nodes_equal(left, right)
    if (operator == "==") {
        return equal
    }
    if (operator == "!=") {
        return !equal
    }
    left_node = resolve_alias(left)
    right_node = resolve_alias(right)
    if (node_kind[left_node] != "scalar" || node_kind[right_node] != "scalar") {
        fail("ordering comparisons require scalar values")
    }
    if ((node_type[left_node] == "int" || node_type[left_node] == "float") &&
        (node_type[right_node] == "int" || node_type[right_node] == "float")) {
        left_value = expression_numeric(left_node)
        right_value = expression_numeric(right_node)
    } else if (node_type[left_node] == "string" && node_type[right_node] == "string") {
        left_value = node_value[left_node]
        right_value = node_value[right_node]
    } else {
        fail("ordering comparisons require two numbers or two strings")
    }
    if (operator == ">") {
        return left_value > right_value
    }
    if (operator == ">=") {
        return left_value >= right_value
    }
    if (operator == "<") {
        return left_value < right_value
    }
    return left_value <= right_value
}

function expression_mapping_length(node,    collection) {
    collection = ++collection_serial
    collect_mapping_keys(node, collection)
    return collection_count[collection]
}

function expression_kind_name(node,    resolved) {
    resolved = resolve_alias(node)
    if (node_kind[resolved] == "mapping") {
        return "map"
    }
    if (node_kind[resolved] == "sequence") {
        return "seq"
    }
    return "scalar"
}

function expression_type_name(node,    resolved) {
    resolved = resolve_alias(node)
    if (node_tag[resolved] != "") {
        if (node_tag[resolved] ~ /^tag:yaml.org,2002:/) {
            return "!!" substr(node_tag[resolved], length("tag:yaml.org,2002:") + 1)
        }
        return node_tag[resolved]
    }
    if (node_kind[resolved] == "mapping") {
        return "!!map"
    }
    if (node_kind[resolved] == "sequence") {
        return "!!seq"
    }
    if (node_type[resolved] == "string") {
        return "!!str"
    }
    if (node_type[resolved] == "tagged") {
        return "!"
    }
    return "!!" node_type[resolved]
}

function expression_clone_node(source,    resolved, clone, i, collection, key, child) {
    resolved = resolve_alias(source)
    clone = new_node(node_kind[resolved], 0, node_value[resolved], node_type[resolved], node_tag[resolved])
    node_origin[clone] = (resolved in node_origin) ? node_origin[resolved] : resolved
    if (resolved in node_style) {
        node_style[clone] = node_style[resolved]
    }
    if (resolved in node_line_comment) {
        node_line_comment[clone] = node_line_comment[resolved]
    }
    if (resolved in node_head_comment) node_head_comment[clone] = node_head_comment[resolved]
    if (resolved in node_foot_comment) node_foot_comment[clone] = node_foot_comment[resolved]
    if (resolved in node_key_head_comment) node_key_head_comment[clone] = node_key_head_comment[resolved]
    if (resolved in node_key_foot_comment) node_key_foot_comment[clone] = node_key_foot_comment[resolved]
    if (resolved in node_key_line_comment) node_key_line_comment[clone] = node_key_line_comment[resolved]
    if (node_line_comment_modified[resolved]) {
        node_line_comment_modified[clone] = 1
    }
    if (node_head_comment_modified[resolved]) node_head_comment_modified[clone] = 1
    if (node_foot_comment_modified[resolved]) node_foot_comment_modified[clone] = 1
    if (node_key_head_comment_modified[resolved]) node_key_head_comment_modified[clone] = 1
    if (node_key_foot_comment_modified[resolved]) node_key_foot_comment_modified[clone] = 1
    if (node_key_line_comment_modified[resolved]) node_key_line_comment_modified[clone] = 1
    delete node_document[clone]
    delete node_file_index[clone]
    delete node_filename[clone]
    if (resolved in node_document) {
        node_document[clone] = node_document[resolved]
    }
    if (resolved in node_file_index) {
        node_file_index[clone] = node_file_index[resolved]
    }
    if (resolved in node_filename) {
        node_filename[clone] = node_filename[resolved]
    }
    if (node_kind[resolved] == "sequence") {
        for (i = 1; i <= sequence_count[resolved]; i++) {
            add_sequence(clone, expression_clone_node(sequence_child[resolved, i]), 0)
        }
    } else if (node_kind[resolved] == "mapping") {
        collection = ++collection_serial
        collect_mapping_keys(resolved, collection)
        for (i = 1; i <= collection_count[collection]; i++) {
            key = collection_key[collection, i]
            child = mapping_lookup(resolved, key)
            add_mapping(clone, key, expression_clone_node(child), 0, 0)
        }
    }
    return clone
}

function expression_clear_node(node,    i, key) {
    if (node_kind[node] == "mapping") {
        for (i = 1; i <= mapping_count[node]; i++) {
            key = mapping_key[node, i]
            delete mapping_seen[node SUBSEP key]
            delete mapping_key[node, i]
            delete mapping_child[node, i]
            delete mapping_merge[node, i]
        }
        mapping_count[node] = 0
    } else if (node_kind[node] == "sequence") {
        for (i = 1; i <= sequence_count[node]; i++) {
            delete sequence_child[node, i]
        }
        sequence_count[node] = 0
    }
    delete alias_target[node]
    delete node_anchor[node]
}

function expression_attach_missing(node,    parent, key) {
    if (!(node in expression_missing_parent) || expression_placeholder_attached[node]) {
        return
    }
    parent = expression_missing_parent[node]
    key = expression_missing_key[node]
    if (parent in expression_missing_parent) {
        if (node_kind[parent] == "scalar" && node_type[parent] == "null") {
            node_kind[parent] = "mapping"
            node_type[parent] = ""
            node_value[parent] = ""
        }
        expression_attach_missing(parent)
    }
    if (node_kind[parent] != "mapping") {
        fail("cannot create key " key " below " expression_type_name(parent))
    }
    add_mapping(parent, key, node, 0, 0)
    expression_placeholder_attached[node] = 1
}

function expression_node_state_equal(left, right,    i) {
    if (node_kind[left] != node_kind[right] || node_type[left] != node_type[right] ||
        node_value[left] != node_value[right] || node_tag[left] != node_tag[right] ||
        node_anchor[left] != node_anchor[right]) {
        return 0
    }
    if (node_kind[left] == "alias") {
        return node_value[left] == node_value[right]
    }
    if (node_kind[left] == "sequence") {
        if (sequence_count[left] != sequence_count[right]) {
            return 0
        }
        for (i = 1; i <= sequence_count[left]; i++) {
            if (!expression_node_state_equal(sequence_child[left, i], sequence_child[right, i])) {
                return 0
            }
        }
    } else if (node_kind[left] == "mapping") {
        if (mapping_count[left] != mapping_count[right]) {
            return 0
        }
        for (i = 1; i <= mapping_count[left]; i++) {
            if (mapping_key[left, i] != mapping_key[right, i] || mapping_merge[left, i] != mapping_merge[right, i] ||
                !expression_node_state_equal(mapping_child[left, i], mapping_child[right, i])) {
                return 0
            }
        }
    }
    return 1
}

function expression_replace_node(target, source,    clone, saved_parent, saved_edge, saved_line, saved_document, i, key, child) {
    expression_last_replace_changed = 0
    if (resolve_alias(target) == resolve_alias(source) && !(target in expression_missing_parent)) {
        return target
    }
    if (!(target in expression_missing_parent) && expression_node_state_equal(target, resolve_alias(source))) {
        return target
    }
    clone = expression_clone_node(source)
    presentation_track_replace(target, clone)
    saved_parent = node_parent[target]
    saved_edge = node_parent_edge[target]
    saved_line = node_line[target]
    saved_document = node_document[target]
    expression_clear_node(target)
    node_kind[target] = node_kind[clone]
    node_value[target] = node_value[clone]
    node_type[target] = node_type[clone]
    node_tag[target] = node_tag[clone]
    node_line[target] = saved_line
    node_document[target] = saved_document
    node_parent[target] = saved_parent
    node_parent_edge[target] = saved_edge
    if (node_kind[clone] == "sequence") {
        for (i = 1; i <= sequence_count[clone]; i++) {
            child = sequence_child[clone, i]
            add_sequence(target, child, 0)
        }
    } else if (node_kind[clone] == "mapping") {
        for (i = 1; i <= mapping_count[clone]; i++) {
            key = mapping_key[clone, i]
            child = mapping_child[clone, i]
            add_mapping(target, key, child, 0, mapping_merge[clone, i])
        }
    }
    expression_attach_missing(target)
    expression_last_replace_changed = 1
    return target
}

function expression_delete_node(target,    parent, i, j, key, child) {
    expression_last_delete_changed = 0
    if (target in expression_missing_parent && !expression_placeholder_attached[target]) {
        return
    }
    if (inplace_mode) {
        presentation_track_delete(target)
    }
    parent = (target in node_parent) ? node_parent[target] : 0
    if (!parent) {
        expression_clear_node(target)
        node_kind[target] = "scalar"
        node_value[target] = ""
        node_type[target] = "null"
        node_tag[target] = ""
        expression_last_delete_changed = 1
        return
    }
    if (node_kind[parent] == "mapping") {
        for (i = 1; i <= mapping_count[parent]; i++) {
            if (mapping_child[parent, i] != target) {
                continue
            }
            key = mapping_key[parent, i]
            delete mapping_seen[parent SUBSEP key]
            for (j = i; j < mapping_count[parent]; j++) {
                mapping_key[parent, j] = mapping_key[parent, j + 1]
                mapping_child[parent, j] = mapping_child[parent, j + 1]
                if (mapping_merge[parent, j + 1]) {
                    mapping_merge[parent, j] = 1
                } else {
                    delete mapping_merge[parent, j]
                }
                child = mapping_child[parent, j]
                node_parent_edge[child] = "key " mapping_key[parent, j]
            }
            delete mapping_key[parent, mapping_count[parent]]
            delete mapping_child[parent, mapping_count[parent]]
            delete mapping_merge[parent, mapping_count[parent]]
            mapping_count[parent]--
            expression_last_delete_changed = 1
            return
        }
    } else if (node_kind[parent] == "sequence") {
        for (i = 1; i <= sequence_count[parent]; i++) {
            if (sequence_child[parent, i] != target) {
                continue
            }
            for (j = i; j < sequence_count[parent]; j++) {
                sequence_child[parent, j] = sequence_child[parent, j + 1]
                child = sequence_child[parent, j]
                node_parent_edge[child] = "index " (j - 1)
            }
            delete sequence_child[parent, sequence_count[parent]]
            sequence_count[parent]--
            expression_last_delete_changed = 1
            return
        }
    }
}

function expression_prepare_path_container(node, kind) {
    node = resolve_alias(node)
    if (node_kind[node] == kind) {
        return node
    }
    if (node_kind[node] != "scalar" || node_type[node] != "null") {
        fail("cannot traverse " expression_type_name(node) " as a " kind)
    }
    expression_clear_node(node)
    node_kind[node] = kind
    node_value[node] = ""
    node_type[node] = ""
    node_tag[node] = ""
    return node
}

function expression_follow_path(root, path_node, create,    path, current, segment, child, key, path_index, i) {
    expression_path_was_missing = 0
    path = resolve_alias(path_node)
    if (node_kind[path] != "sequence") {
        fail("path must be an array")
    }
    current = root
    for (i = 1; i <= sequence_count[path]; i++) {
        segment = resolve_alias(sequence_child[path, i])
        current = resolve_alias(current)
        if (node_kind[segment] != "scalar" || (node_type[segment] != "string" && node_type[segment] != "int")) {
            fail("path components must be strings or integers")
        }
        if (node_type[segment] == "string") {
            key = node_value[segment]
            if (node_kind[current] != "mapping") {
                if (!create) {
                    return 0
                }
                current = expression_prepare_path_container(current, "mapping")
            }
            child = mapping_lookup(current, key)
            if (!child) {
                if (!create) {
                    return 0
                }
                child = expression_null()
                add_mapping(current, key, child, 0, 0)
                expression_path_was_missing = 1
            }
        } else {
            path_index = node_value[segment] + 0
            if (path_index < 0) {
                fail("path indexes must be non-negative")
            }
            if (node_kind[current] != "sequence") {
                if (!create) {
                    return 0
                }
                current = expression_prepare_path_container(current, "sequence")
            }
            if (path_index >= sequence_count[current]) {
                if (!create) {
                    return 0
                }
                while (sequence_count[current] <= path_index) {
                    add_sequence(current, expression_null(), 0)
                }
                expression_path_was_missing = 1
            }
            child = sequence_child[current, path_index + 1]
        }
        current = child
    }
    return current
}

function expression_node_property_value(node, property,    value) {
    if (property == "style") {
        value = node_style[node]
        return value == "plain" ? "" : value
    }
    if (property == "line_comment") {
        return node_line_comment[node]
    }
    if (property == "head_comment") return node_head_comment[node]
    if (property == "foot_comment") return node_foot_comment[node]
    if (property == "tag") {
        return expression_type_name(node)
    }
    if (property == "anchor") {
        return node_anchor[node]
    }
    return node_kind[node] == "alias" ? node_value[node] : ""
}

function expression_normalize_tag(value) {
    if (value == "") {
        return ""
    }
    if (substr(value, 1, 2) == "!!") {
        return "tag:yaml.org,2002:" substr(value, 3)
    }
    if (substr(value, 1, 2) == "!<" && substr(value, length(value), 1) == ">") {
        return substr(value, 3, length(value) - 3)
    }
    if (substr(value, 1, 1) == "!" || value ~ /^tag:/) {
        return value
    }
    fail("tag must be empty, a YAML tag such as !!str, or an absolute tag URI")
}

function expression_node_document(node,    current, document) {
    current = node
    while (current in node_parent) {
        current = node_parent[current]
    }
    for (document = 0; document <= document_index; document++) {
        if ((document in document_root) && document_root[document] == current) {
            return document
        }
    }
    return -1
}

function expression_anchor_references(node,    candidate, count) {
    count = 0
    for (candidate = 1; candidate <= node_count; candidate++) {
        if (node_kind[candidate] == "alias" && alias_target[candidate] == node) {
            count++
        }
    }
    return count
}

function expression_refresh_anchor_target(document, name,    candidate, best) {
    if (name == "") {
        return
    }
    delete anchor_target[document SUBSEP name]
    best = 0
    for (candidate = 1; candidate <= node_count; candidate++) {
        if (node_anchor[candidate] == name && expression_node_document(candidate) == document && candidate > best) {
            best = candidate
        }
    }
    if (best) {
        anchor_target[document SUBSEP name] = best
    }
}

function expression_set_anchor(node, value,    candidate, document, old_value) {
    if (node_kind[node] == "alias") {
        fail("anchor cannot be set on an alias")
    }
    if (value != "" && !valid_anchor_name(value)) {
        fail("invalid anchor name: " value)
    }
    if (value == "" && expression_anchor_references(node)) {
        fail("cannot remove an anchor while aliases still reference it")
    }
    document = expression_node_document(node)
    for (candidate = 1; candidate <= node_count; candidate++) {
        if (candidate != node && node_anchor[candidate] == value && value != "" &&
            expression_node_document(candidate) == document) {
            fail("duplicate anchor name: " value)
        }
    }
    old_value = node_anchor[node]
    node_anchor[node] = value
    if (old_value != value) {
        for (candidate = 1; candidate <= node_count; candidate++) {
            if (node_kind[candidate] == "alias" && alias_target[candidate] == node) {
                node_value[candidate] = value
            }
        }
        expression_refresh_anchor_target(document, old_value)
        expression_refresh_anchor_target(document, value)
    }
}

function expression_set_alias(node, value,    document, target, parent) {
    if (value == "") {
        fail("alias must name an anchor")
    }
    if (!valid_anchor_name(value)) {
        fail("invalid alias name: " value)
    }
    if (expression_anchor_references(node)) {
        fail("cannot replace an anchor while aliases still reference it")
    }
    document = expression_node_document(node)
    target = anchor_target[document SUBSEP value]
    if (!target) {
        fail("unknown anchor for alias: " value)
    }
    if (target >= node) {
        fail("forward alias is not supported: " value)
    }
    parent = node_parent[node]
    while (parent) {
        if (parent == target) {
            fail("recursive alias: " value)
        }
        parent = node_parent[parent]
    }
    expression_clear_node(node)
    node_kind[node] = "alias"
    node_value[node] = value
    node_type[node] = ""
    node_tag[node] = ""
    delete node_style[node]
    alias_target[node] = target
}

function expression_set_node_property(node, property, value_node,    resolved, value, old_value, new_value, tag) {
    expression_last_property_changed = 0
    resolved = resolve_alias(value_node)
    if (node_kind[resolved] != "scalar" || node_type[resolved] != "string") {
        fail(property " must be set to a string")
    }
    value = node_value[resolved]
    if (node_key_reference[node] && (property == "line_comment" || property == "head_comment" || property == "foot_comment")) {
        node = node_origin[node]
        old_value = property == "line_comment" ? node_key_line_comment[node] : (property == "head_comment" ? node_key_head_comment[node] : node_key_foot_comment[node])
        if (value == old_value) return
        if (property == "line_comment") {
            node_key_line_comment[node] = value
            node_key_line_comment_modified[node] = 1
        } else if (property == "head_comment") {
            node_key_head_comment[node] = value
            node_key_head_comment_modified[node] = 1
        } else {
            node_key_foot_comment[node] = value
            node_key_foot_comment_modified[node] = 1
        }
        if (inplace_mode && !presentation_track_comment(node, property, 1, value)) presentation_possible = 0
        expression_last_property_changed = 1
        return
    }
    old_value = expression_node_property_value(node, property)
    new_value = property == "style" && value == "plain" ? "" : value
    if (new_value == old_value) {
        return
    }
    if (property == "style") {
        if (node_kind[node] == "scalar") {
            if (value != "" && value != "plain" && value != "single" && value != "double" &&
                value != "literal" && value != "folded") {
                fail("scalar style must be plain, single, double, literal, or folded")
            }
            if (value == "plain" && node_type[node] == "string" && !presentation_plain_safe(node_value[node])) {
                fail("value cannot be represented safely in plain style")
            }
            if ((value == "literal" || value == "folded") && node_type[node] != "string") {
                fail(value " style requires a string scalar")
            }
            if (value == "") {
                delete node_style[node]
            } else {
                node_style[node] = value
            }
        } else if (node_kind[node] == "mapping" || node_kind[node] == "sequence") {
            if (value != "" && value != "flow") {
                fail("collection style must be flow or empty")
            }
            if (value == "") {
                delete node_style[node]
            } else {
                node_style[node] = value
            }
        } else {
            fail("style cannot be set on an alias")
        }
    } else if (property == "line_comment") {
        node_line_comment[node] = value
        node_line_comment_modified[node] = 1
    } else if (property == "head_comment") {
        node_head_comment[node] = value
        node_head_comment_modified[node] = 1
    } else if (property == "foot_comment") {
        node_foot_comment[node] = value
        node_foot_comment_modified[node] = 1
    } else if (property == "tag") {
        if (node_kind[node] == "alias") {
            fail("tag cannot be set on an alias")
        }
        tag = expression_normalize_tag(value)
        node_tag[node] = tag
        if (node_kind[node] == "scalar") {
            node_type[node] = scalar_type(node_value[node], tag, node_value[node])
        }
    } else if (property == "anchor") {
        expression_set_anchor(node, value)
    } else if (property == "alias") {
        expression_set_alias(node, value)
    }
    if (inplace_mode) {
        if (presentation_flow_owner(node) &&
            !(property == "style" && (node_kind[node] == "mapping" || node_kind[node] == "sequence") && old_value != "flow")) {
            presentation_track_replace(node, node)
        } else if ((property == "style" || property == "line_comment") && node_kind[node] == "scalar" &&
            node_style[node] != "literal" && node_style[node] != "folded") {
            presentation_track_replace(node, node)
        } else if (property == "line_comment" && node_kind[node] == "scalar" &&
            (node_style[node] == "literal" || node_style[node] == "folded")) {
            presentation_track_owned_span(node)
        } else if (property == "head_comment" || property == "foot_comment") {
            if (!presentation_track_comment(node, property, 0, value)) presentation_possible = 0
        } else {
            presentation_possible = 0
        }
    }
    expression_last_property_changed = 1
}

function expression_collect_recursive(node, stream, serial,    resolved, seen_key, i, collection, key) {
    resolved = resolve_alias(node)
    seen_key = serial SUBSEP resolved
    if (seen_key in expression_recursive_seen) {
        return
    }
    expression_recursive_seen[seen_key] = 1
    expression_stream_push(stream, resolved)
    if (node_kind[resolved] == "sequence") {
        for (i = 1; i <= sequence_count[resolved]; i++) {
            expression_collect_recursive(sequence_child[resolved, i], stream, serial)
        }
    } else if (node_kind[resolved] == "mapping") {
        collection = ++collection_serial
        collect_mapping_keys(resolved, collection)
        for (i = 1; i <= collection_count[collection]; i++) {
            key = collection_key[collection, i]
            expression_collect_recursive(mapping_lookup(resolved, key), stream, serial)
        }
    }
}

function expression_arithmetic_number(value, value_type,    rendered) {
    rendered = sprintf("%.15g", value)
    if (value_type == "float" && rendered !~ /[.eE]/) {
        rendered = rendered ".0"
    }
    return expression_scalar(rendered, value_type)
}

function expression_deep_merge(left, right, flags,    left_node, right_node, result, collection, i, key, child, existing, merged, only_existing, only_new, append_arrays, deep_arrays) {
    left_node = resolve_alias(left)
    right_node = resolve_alias(right)
    only_existing = index(flags, "?") > 0
    only_new = index(flags, "n") > 0
    append_arrays = index(flags, "+") > 0
    deep_arrays = index(flags, "d") > 0
    if (node_kind[left_node] == "sequence" && node_kind[right_node] == "sequence") {
        result = expression_clone_node(left_node)
        if (append_arrays) {
            if (only_new) {
                return result
            }
            for (i = 1; i <= sequence_count[right_node]; i++) {
                add_sequence(result, expression_clone_node(sequence_child[right_node, i]), 0)
            }
            return result
        }
        if (deep_arrays) {
            for (i = 1; i <= sequence_count[right_node]; i++) {
                child = sequence_child[right_node, i]
                if (i <= sequence_count[result]) {
                    existing = sequence_child[result, i]
                    if (only_new &&
                        !((node_kind[resolve_alias(existing)] == "mapping" && node_kind[resolve_alias(child)] == "mapping") ||
                          (node_kind[resolve_alias(existing)] == "sequence" && node_kind[resolve_alias(child)] == "sequence"))) {
                        continue
                    }
                    merged = expression_deep_merge(existing, child, flags)
                    expression_replace_node(existing, merged)
                } else if (!only_existing) {
                    add_sequence(result, expression_clone_node(child), 0)
                }
            }
            return result
        }
        return only_new ? result : expression_clone_node(right_node)
    }
    if (node_kind[left_node] != "mapping" || node_kind[right_node] != "mapping") {
        return only_new ? expression_clone_node(left_node) : expression_clone_node(right_node)
    }
    result = expression_clone_node(left_node)
    collection = ++collection_serial
    collect_mapping_keys(right_node, collection)
    for (i = 1; i <= collection_count[collection]; i++) {
        key = collection_key[collection, i]
        child = mapping_lookup(right_node, key)
        existing = mapping_lookup(result, key)
        if (!existing) {
            if (!only_existing) {
                add_mapping(result, key, expression_clone_node(child), 0, 0)
            }
        } else if (node_kind[resolve_alias(existing)] == "mapping" && node_kind[resolve_alias(child)] == "mapping") {
            merged = expression_deep_merge(existing, child, flags)
            expression_replace_node(existing, merged)
        } else if (node_kind[resolve_alias(existing)] == "sequence" && node_kind[resolve_alias(child)] == "sequence" &&
            (deep_arrays || (append_arrays && !only_new))) {
            merged = expression_deep_merge(existing, child, flags)
            expression_replace_node(existing, merged)
        } else if (only_new) {
            continue
        } else {
            expression_replace_node(existing, child)
        }
    }
    return result
}

function expression_arithmetic(left, right, operator,    left_node, right_node, left_type, right_type, result_type, value, result, i, collection, key, child) {
    left_node = resolve_alias(left)
    right_node = resolve_alias(right)
    left_type = node_type[left_node]
    right_type = node_type[right_node]

    if (operator == "+" && left_type == "null") {
        return expression_clone_node(right_node)
    }
    if (operator == "+" && right_type == "null") {
        return expression_clone_node(left_node)
    }
    if ((left_type == "int" || left_type == "float") && (right_type == "int" || right_type == "float")) {
        if (operator == "/" && expression_numeric(right_node) == 0) {
            fail("division by zero")
        }
        if (operator == "%" && expression_numeric(right_node) == 0) {
            fail("modulo by zero")
        }
        if (operator == "+") {
            value = expression_numeric(left_node) + expression_numeric(right_node)
        } else if (operator == "-") {
            value = expression_numeric(left_node) - expression_numeric(right_node)
        } else if (operator == "*") {
            value = expression_numeric(left_node) * expression_numeric(right_node)
        } else if (operator == "/") {
            value = expression_numeric(left_node) / expression_numeric(right_node)
        } else {
            value = expression_numeric(left_node) % expression_numeric(right_node)
        }
        result_type = (operator == "/" || left_type == "float" || right_type == "float") ? "float" : "int"
        return expression_arithmetic_number(value, result_type)
    }
    if (operator == "+" && left_type == "string" && right_type == "string") {
        return expression_scalar(node_value[left_node] node_value[right_node], "string")
    }
    if (operator == "+" && node_kind[left_node] == "sequence" && node_kind[right_node] == "sequence") {
        result = new_node("sequence", 0, "", "", "")
        for (i = 1; i <= sequence_count[left_node]; i++) {
            add_sequence(result, expression_clone_node(sequence_child[left_node, i]), 0)
        }
        for (i = 1; i <= sequence_count[right_node]; i++) {
            add_sequence(result, expression_clone_node(sequence_child[right_node, i]), 0)
        }
        return result
    }
    if (operator == "+" && node_kind[left_node] == "mapping" && node_kind[right_node] == "mapping") {
        result = expression_clone_node(left_node)
        collection = ++collection_serial
        collect_mapping_keys(right_node, collection)
        for (i = 1; i <= collection_count[collection]; i++) {
            key = collection_key[collection, i]
            child = mapping_lookup(right_node, key)
            if (mapping_lookup(result, key)) {
                expression_replace_node(mapping_lookup(result, key), child)
            } else {
                add_mapping(result, key, expression_clone_node(child), 0, 0)
            }
        }
        return result
    }
    if (substr(operator, 1, 1) == "*" &&
        ((node_kind[left_node] == "mapping" && node_kind[right_node] == "mapping") ||
         (node_kind[left_node] == "sequence" && node_kind[right_node] == "sequence"))) {
        return expression_deep_merge(left_node, right_node, substr(operator, 2))
    }
    fail("operator " operator " does not support " expression_type_name(left_node) " and " expression_type_name(right_node))
}

function expression_fingerprint(node,    resolved, result, i, collection, key, child, value) {
    resolved = resolve_alias(node)
    if (node_kind[resolved] == "scalar") {
        value = node_value[resolved]
        return "s" length(node_type[resolved]) ":" node_type[resolved] length(value) ":" value
    }
    if (node_kind[resolved] == "sequence") {
        result = "q" sequence_count[resolved] ":"
        for (i = 1; i <= sequence_count[resolved]; i++) {
            value = expression_fingerprint(sequence_child[resolved, i])
            result = result length(value) ":" value
        }
        return result
    }
    collection = ++collection_serial
    collect_mapping_keys(resolved, collection)
    result = "m" collection_count[collection] ":"
    for (i = 1; i <= collection_count[collection]; i++) {
        key = collection_key[collection, i]
        child = mapping_lookup(resolved, key)
        value = expression_fingerprint(child)
        result = result length(key) ":" key length(value) ":" value
    }
    return result
}

function expression_sort_rank(node) {
    if (node_type[node] == "null") {
        return 0
    }
    if (node_type[node] == "bool") {
        return 1
    }
    if (node_type[node] == "int" || node_type[node] == "float") {
        return 2
    }
    if (node_kind[node] == "scalar") {
        return 3
    }
    if (node_kind[node] == "sequence") {
        return 4
    }
    return 5
}

function expression_sort_less(left, right,    left_node, right_node, left_rank, right_rank, left_value, right_value) {
    left_node = resolve_alias(left)
    right_node = resolve_alias(right)
    left_rank = expression_sort_rank(left_node)
    right_rank = expression_sort_rank(right_node)
    if (left_rank != right_rank) {
        return left_rank < right_rank
    }
    if (left_rank == 2) {
        return expression_numeric(left_node) < expression_numeric(right_node)
    }
    if (left_rank <= 3) {
        left_value = tolower(node_value[left_node])
        right_value = tolower(node_value[right_node])
        return left_value < right_value
    }
    return expression_fingerprint(left_node) < expression_fingerprint(right_node)
}

function expression_flatten_into(node, target,    resolved, i) {
    resolved = resolve_alias(node)
    if (node_kind[resolved] != "sequence") {
        add_sequence(target, expression_clone_node(resolved), 0)
        return
    }
    for (i = 1; i <= sequence_count[resolved]; i++) {
        expression_flatten_into(sequence_child[resolved, i], target)
    }
}

function expression_string_value(node,    resolved) {
    resolved = resolve_alias(node)
    if (node_kind[resolved] != "scalar") {
        fail("string operation requires scalar values")
    }
    if (node_type[resolved] == "null") {
        return ""
    }
    return node_value[resolved]
}

function expression_json_text(node,    resolved, result, i, collection, key) {
    resolved = resolve_alias(node)
    if (node_kind[resolved] == "scalar") {
        if (node_type[resolved] == "null") {
            return "null"
        }
        if (node_type[resolved] == "bool" || node_type[resolved] == "int" || node_type[resolved] == "float") {
            return node_value[resolved]
        }
        return json_quote(node_value[resolved])
    }
    if (node_kind[resolved] == "sequence") {
        result = "["
        for (i = 1; i <= sequence_count[resolved]; i++) {
            if (i > 1) {
                result = result ","
            }
            result = result expression_json_text(sequence_child[resolved, i])
        }
        return result "]"
    }
    collection = ++collection_serial
    collect_mapping_keys(resolved, collection)
    result = "{"
    for (i = 1; i <= collection_count[collection]; i++) {
        key = collection_key[collection, i]
        if (i > 1) {
            result = result ","
        }
        result = result json_quote(key) ":" expression_json_text(mapping_lookup(resolved, key))
    }
    return result "}"
}

function expression_json_pretty_text(node, step, level,    resolved, result, i, collection, key, child_indent, prefix) {
    if (step <= 0) return expression_json_text(node)
    resolved = resolve_alias(node)
    if (node_kind[resolved] == "scalar") return expression_json_text(resolved)
    child_indent = yaml_spaces((level + 1) * step)
    prefix = yaml_spaces(level * step)
    if (node_kind[resolved] == "sequence") {
        if (!sequence_count[resolved]) return "[]"
        result = "[\n"
        for (i = 1; i <= sequence_count[resolved]; i++) {
            if (i > 1) result = result ",\n"
            result = result child_indent expression_json_pretty_text(sequence_child[resolved, i], step, level + 1)
        }
        return result "\n" prefix "]"
    }
    collection = ++collection_serial
    collect_mapping_keys(resolved, collection)
    if (!collection_count[collection]) return "{}"
    result = "{\n"
    for (i = 1; i <= collection_count[collection]; i++) {
        key = collection_key[collection, i]
        if (i > 1) result = result ",\n"
        result = result child_indent json_quote(key) ": " expression_json_pretty_text(mapping_lookup(resolved, key), step, level + 1)
    }
    return result "\n" prefix "}"
}

function expression_yaml_scalar_text(node,    resolved, value) {
    if (node_kind[node] == "alias") {
        return "*" node_value[node]
    }
    resolved = resolve_alias(node)
    value = node_value[resolved]
    if (node_type[resolved] == "null" && value == "") {
        return "null"
    }
    if (node_type[resolved] != "string" || presentation_plain_safe(value)) {
        return value
    }
    return json_quote(value)
}

function expression_yaml_inline_text(node,    resolved) {
    if (node_kind[node] == "alias" || node_kind[resolve_alias(node)] == "scalar") {
        return expression_yaml_scalar_text(node)
    }
    resolved = resolve_alias(node)
    if ((node_kind[resolved] == "mapping" && !mapping_count[resolved]) ||
        (node_kind[resolved] == "sequence" && !sequence_count[resolved])) {
        return node_kind[resolved] == "mapping" ? "{}" : "[]"
    }
    if (node_style[resolved] == "flow") {
        return expression_yaml_flow_text(resolved)
    }
    return ""
}

function expression_yaml_flow_text(node,    resolved, result, i, key) {
    resolved = resolve_alias(node)
    if (node_kind[resolved] == "scalar" || node_kind[node] == "alias") {
        return expression_yaml_scalar_text(node)
    }
    result = node_kind[resolved] == "sequence" ? "[" : "{"
    if (node_kind[resolved] == "sequence") {
        for (i = 1; i <= sequence_count[resolved]; i++) {
            if (i > 1) result = result ", "
            result = result expression_yaml_flow_text(sequence_child[resolved, i])
        }
        return result "]"
    }
    for (i = 1; i <= mapping_count[resolved]; i++) {
        if (i > 1) result = result ", "
        key = mapping_key[resolved, i]
        key = presentation_plain_safe(key) ? key : json_quote(key)
        result = result key ": " expression_yaml_flow_text(mapping_child[resolved, i])
    }
    return result "}"
}

function expression_yaml_text(node, indent, step,    resolved, result, i, key, child, inline, prefix) {
    if (step == "") step = yaml_indent
    if (node_kind[node] == "alias") {
        return expression_yaml_scalar_text(node)
    }
    resolved = resolve_alias(node)
    if (node_kind[resolved] == "scalar") {
        return expression_yaml_scalar_text(resolved)
    }
    if (node_style[resolved] == "flow") {
        return expression_yaml_flow_text(resolved)
    }
    prefix = yaml_spaces(indent)
    result = ""
    if (node_kind[resolved] == "sequence") {
        if (!sequence_count[resolved]) {
            return "[]"
        }
        for (i = 1; i <= sequence_count[resolved]; i++) {
            child = sequence_child[resolved, i]
            inline = expression_yaml_inline_text(child)
            if (result != "") result = result "\n"
            if (inline != "") {
                result = result prefix "- " inline
            } else {
                result = result prefix "-\n" expression_yaml_text(child, indent + step, step)
            }
        }
        return result
    }
    if (!mapping_count[resolved]) {
        return "{}"
    }
    for (i = 1; i <= mapping_count[resolved]; i++) {
        key = mapping_key[resolved, i]
        child = mapping_child[resolved, i]
        inline = expression_yaml_inline_text(child)
        if (result != "") result = result "\n"
        key = presentation_plain_safe(key) ? key : json_quote(key)
        if (inline != "") {
            result = result prefix key ": " inline
        } else {
            result = result prefix key ":\n" expression_yaml_text(child, indent + step, step)
        }
    }
    return result
}

function expression_to_string(node,    resolved) {
    resolved = resolve_alias(node)
    if (node_kind[resolved] == "scalar") {
        return node_type[resolved] == "null" && node_value[resolved] == "" ? "null" : node_value[resolved]
    }
    return expression_yaml_text(node, 0)
}

function expression_interpolation_text(node,    resolved) {
    resolved = resolve_alias(node)
    if (node_kind[resolved] != "scalar") {
        return expression_json_text(resolved)
    }
    if (node_type[resolved] == "null") {
        return "null"
    }
    return node_value[resolved]
}

function expression_split_string(value, delimiter, result,    position, found) {
    if (delimiter == "") {
        for (position = 1; position <= length(value); position++) {
            add_sequence(result, expression_scalar(substr(value, position, 1), "string"), 0)
        }
        return
    }
    while ((found = index(value, delimiter))) {
        add_sequence(result, expression_scalar(substr(value, 1, found - 1), "string"), 0)
        value = substr(value, found + length(delimiter))
    }
    add_sequence(result, expression_scalar(value, "string"), 0)
}

function expression_regex_replace_all(value, pattern, replacement,    result, prefix, previous_nonempty) {
    result = ""
    while (match(value, pattern)) {
        prefix = substr(value, 1, RSTART - 1)
        result = result prefix
        if (RLENGTH > 0) {
            result = result replacement
            value = substr(value, RSTART + RLENGTH)
            previous_nonempty = 1
        } else {
            if (!previous_nonempty || RSTART > 1) {
                result = result replacement
            }
            previous_nonempty = 0
            if (RSTART <= length(value)) {
                result = result substr(value, RSTART, 1)
                value = substr(value, RSTART + 1)
            } else {
                return result
            }
        }
    }
    return result value
}

function expression_entry(key, value, key_type,    entry) {
    entry = new_node("mapping", 0, "", "", "")
    add_mapping(entry, "key", expression_scalar(key, key_type), 0, 0)
    add_mapping(entry, "value", expression_clone_node(value), 0, 0)
    return entry
}

function expression_evaluate_context(kind, expression, input,    output, middle, i, node, resolved, key, result_node) {
    output = expression_stream_new()
    if (kind == "filename" || kind == "fileindex" || kind == "documentindex") {
        for (i = 1; i <= expression_stream_count[input]; i++) {
            node = resolve_alias(expression_stream_node[input, i])
            if (kind == "filename") {
                key = (node in node_filename) ? node_filename[node] : input_filename
                expression_stream_push(output, expression_scalar(key, "string"))
            } else if (kind == "fileindex") {
                key = (node in node_file_index) ? node_file_index[node] : input_file_index + 0
                expression_stream_push(output, expression_scalar(key "", "int"))
            } else {
                expression_stream_push(output, expression_scalar((node_document[node] + 0) "", "int"))
            }
        }
        return output
    }
    if (kind == "path" || kind == "parent" || kind == "root") {
        for (i = 1; i <= expression_stream_count[input]; i++) {
            node = expression_stream_node[input, i]
            if (kind == "path") {
                expression_stream_push(output, expression_path(node))
            } else if (kind == "root") {
                expression_stream_push(output, expression_root(node))
            } else if (node in node_parent) {
                expression_stream_push(output, node_parent[node])
            }
        }
        return output
    }
    if (kind == "node_property") {
        middle = expression_evaluate(expression_left[expression], input)
        for (i = 1; i <= expression_stream_count[middle]; i++) {
            node = expression_stream_node[middle, i]
            expression_stream_push(output, expression_scalar(expression_node_property_value(node, expression_value[expression]), "string"))
        }
        return output
    }
    for (i = 1; i <= expression_stream_count[input]; i++) {
        node = expression_stream_node[input, i]
        resolved = resolve_alias(node)
        if (kind == "node_line") {
            expression_stream_push(output, expression_scalar(node_line[node] "", "int"))
        } else if (kind == "node_column") {
            expression_stream_push(output, expression_scalar(node_column[node] + 0 "", "int"))
        } else if (kind == "node_tag") {
            expression_stream_push(output, expression_scalar(expression_type_name(resolved), "string"))
        } else if (kind == "node_anchor") {
            expression_stream_push(output, expression_scalar(node_anchor[node], "string"))
        } else if (kind == "node_alias") {
            expression_stream_push(output, expression_scalar(node_kind[node] == "alias" ? node_value[node] : "", "string"))
        } else if (kind == "node_style") {
            key = node_style[node]
            expression_stream_push(output, expression_scalar(key == "plain" ? "" : key, "string"))
        } else if (kind == "node_line_comment") {
            expression_stream_push(output, expression_scalar(node_line_comment[node], "string"))
        } else if (kind == "node_head_comment") {
            expression_stream_push(output, expression_scalar(node_head_comment[node], "string"))
        } else if (kind == "node_foot_comment") {
            expression_stream_push(output, expression_scalar(node_foot_comment[node], "string"))
        } else if (kind == "node_key" && (node in node_parent)) {
            key = node_parent_edge[node]
            result_node = substr(key, 1, 6) == "index " ? expression_scalar(substr(key, 7), "int") : expression_scalar(substr(key, 5), "string")
            node_origin[result_node] = node
            if (substr(key, 1, 4) == "key ") node_key_reference[result_node] = 1
            node_line[result_node] = substr(key, 1, 4) == "key " && (node in node_key_line) ? node_key_line[node] : node_line[node]
            node_column[result_node] = substr(key, 1, 4) == "key " ? ((node in node_key_column) ? node_key_column[node] : node_indent[node] + 1) : node_column[node]
            if (substr(key, 1, 4) == "key ") {
                if (node in node_key_head_comment) node_head_comment[result_node] = node_key_head_comment[node]
                if (node in node_key_foot_comment) node_foot_comment[result_node] = node_key_foot_comment[node]
                if (node in node_key_line_comment) node_line_comment[result_node] = node_key_line_comment[node]
            } else {
                if (node in node_head_comment) node_head_comment[result_node] = node_head_comment[node]
                if (node in node_foot_comment) node_foot_comment[result_node] = node_foot_comment[node]
                if (node in node_line_comment) node_line_comment[result_node] = node_line_comment[node]
            }
            expression_stream_push(output, result_node)
        }
    }
    return output
}

function expression_evaluate_string(kind, expression, input,    output, i, j, node, key, single, argument_stream, argument, right_stream, child, result_node) {
    output = expression_stream_new()
    if (kind == "upcase" || kind == "downcase" || kind == "trim" || kind == "to_string") {
        for (i = 1; i <= expression_stream_count[input]; i++) {
            node = resolve_alias(expression_stream_node[input, i])
            if (kind == "to_string") {
                expression_stream_push(output, expression_scalar(expression_to_string(node), "string"))
                continue
            }
            if (node_kind[node] != "scalar" || node_type[node] != "string") fail(kind " requires a string")
            key = node_value[node]
            if (kind == "trim") {
                sub(/^[[:space:]]+/, "", key)
                sub(/[[:space:]]+$/, "", key)
            } else {
                key = kind == "upcase" ? toupper(key) : tolower(key)
            }
            expression_stream_push(output, expression_scalar(key, "string"))
        }
        return output
    }
    if (kind == "regex_test" || kind == "regex_sub") {
        for (i = 1; i <= expression_stream_count[input]; i++) {
            node = resolve_alias(expression_stream_node[input, i])
            if (node_kind[node] != "scalar" || node_type[node] != "string") fail((kind == "regex_test" ? "test" : "sub") " requires a string")
            single = expression_stream_single(node)
            argument_stream = expression_evaluate(expression_left[expression], single)
            if (!expression_stream_count[argument_stream]) fail("regular expression requires a pattern")
            argument = expression_string_value(expression_stream_node[argument_stream, 1])
            key = node_value[node]
            if (kind == "regex_test") {
                expression_stream_push(output, expression_boolean(key ~ argument))
                continue
            }
            right_stream = expression_evaluate(expression_right[expression], single)
            if (!expression_stream_count[right_stream]) fail("regular expression replacement requires a string")
            child = expression_string_value(expression_stream_node[right_stream, 1])
            expression_stream_push(output, expression_scalar(expression_regex_replace_all(key, argument, child), "string"))
        }
        return output
    }
    for (i = 1; i <= expression_stream_count[input]; i++) {
        node = resolve_alias(expression_stream_node[input, i])
        single = expression_stream_single(node)
        argument_stream = expression_evaluate(expression_left[expression], single)
        if (!expression_stream_count[argument_stream]) fail(kind " requires an argument")
        argument = expression_string_value(expression_stream_node[argument_stream, 1])
        if (kind == "join") {
            if (node_kind[node] != "sequence") fail("join requires a sequence")
            key = ""
            for (j = 1; j <= sequence_count[node]; j++) key = key (j > 1 ? argument : "") expression_string_value(sequence_child[node, j])
            expression_stream_push(output, expression_scalar(key, "string"))
            continue
        }
        if (node_kind[node] != "scalar" || node_type[node] != "string") fail(kind " requires a string")
        key = node_value[node]
        if (kind == "contains") expression_stream_push(output, expression_boolean(index(key, argument) > 0))
        else if (kind == "startswith") expression_stream_push(output, expression_boolean(substr(key, 1, length(argument)) == argument))
        else if (kind == "endswith") expression_stream_push(output, expression_boolean(substr(key, length(key) - length(argument) + 1) == argument))
        else {
            result_node = new_node("sequence", 0, "", "", "")
            expression_split_string(key, argument, result_node)
            expression_stream_push(output, result_node)
        }
    }
    return output
}

function expression_utility_indent(expression, single, fallback, allow_zero,    stream, node, value) {
    if (!expression_left[expression]) return fallback
    stream = expression_evaluate(expression_left[expression], single)
    if (expression_stream_count[stream] != 1) fail(expression_kind[expression] " requires one indentation value")
    node = resolve_alias(expression_stream_node[stream, 1])
    if (node_kind[node] != "scalar" || node_type[node] != "int") fail(expression_kind[expression] " indentation must be an integer")
    value = node_value[node] + 0
    if (value < (allow_zero ? 0 : 1) || value > 9) fail(expression_kind[expression] " indentation must be " (allow_zero ? "0 through 9" : "1 through 9"))
    return value
}

function expression_shuffle(node,    resolved, result, serial, count, i, j, swap) {
    resolved = resolve_alias(node)
    if (node_kind[resolved] != "sequence") fail("shuffle requires a sequence")
    result = new_node("sequence", 0, "", "", "")
    serial = ++codec_shuffle_serial
    count = sequence_count[resolved]
    for (i = 1; i <= count; i++) codec_shuffle_index[serial, i] = i
    for (i = count; i > 1; i--) {
        j = (codec_random_next() % i) + 1
        swap = codec_shuffle_index[serial, i]
        codec_shuffle_index[serial, i] = codec_shuffle_index[serial, j]
        codec_shuffle_index[serial, j] = swap
    }
    for (i = 1; i <= count; i++) {
        add_sequence(result, expression_clone_node(sequence_child[resolved, codec_shuffle_index[serial, i]]), 0)
        delete codec_shuffle_index[serial, i]
    }
    return result
}

function expression_evaluate_patch(kind, expression, input,    output, i, node, single, argument_stream, argument, value, result) {
    output = expression_stream_new()
    for (i = 1; i <= expression_stream_count[input]; i++) {
        node = expression_stream_node[input, i]
        single = expression_stream_single(node)
        argument_stream = expression_evaluate(expression_left[expression], single)
        if (expression_stream_count[argument_stream] != 1) fail(kind " requires exactly one argument value")
        argument = expression_stream_node[argument_stream, 1]
        if (kind == "pointer") {
            value = expression_string_value(argument)
            result = patch_pointer_find(node, value, 0)
            if (!result) fail("JSON Pointer path does not exist: " value)
            expression_stream_push(output, result)
        } else if (kind == "apply_patch") {
            patch_apply(node, argument)
            expression_stream_push(output, node)
        } else if (kind == "merge_patch") {
            merge_patch_apply(node, argument)
            expression_stream_push(output, node)
        } else {
            result = new_node("sequence", 0, "", "", "")
            patch_diff_into(node, argument, "", result)
            expression_stream_push(output, result)
        }
    }
    return output
}

function expression_evaluate_schema(kind, expression, input,    output, i, node, single, argument_stream, schema, errors, first, path, message) {
    output = expression_stream_new()
    for (i = 1; i <= expression_stream_count[input]; i++) {
        node = expression_stream_node[input, i]
        single = expression_stream_single(node)
        argument_stream = expression_evaluate(expression_left[expression], single)
        if (expression_stream_count[argument_stream] != 1) fail(kind " requires exactly one schema")
        schema = expression_stream_node[argument_stream, 1]
        errors = schema_errors(node, schema)
        if (kind == "schema_errors") {
            expression_stream_push(output, errors)
        } else if (kind == "schema_valid") {
            expression_stream_push(output, expression_boolean(sequence_count[errors] == 0))
        } else if (!sequence_count[errors]) {
            expression_stream_push(output, node)
        } else {
            first = sequence_child[errors, 1]
            path = node_value[resolve_alias(mapping_lookup(first, "instancePath"))]
            message = node_value[resolve_alias(mapping_lookup(first, "message"))]
            fail("schema validation failed at " (path == "" ? "/" : path) ": " message)
        }
    }
    return output
}

function expression_evaluate_utility(kind, expression, input,    output, i, j, node, resolved, single, argument_stream, value, result_node, dynamic_expression, dynamic_results, step) {
    output = expression_stream_new()
    if (kind == "eval") {
        if (disable_eval) fail("dynamic eval is disabled")
        if (++dynamic_eval_depth > 32) fail("dynamic eval depth limit exceeded")
        for (i = 1; i <= expression_stream_count[input]; i++) {
            node = expression_stream_node[input, i]
            single = expression_stream_single(node)
            argument_stream = expression_evaluate(expression_left[expression], single)
            for (j = 1; j <= expression_stream_count[argument_stream]; j++) {
                value = expression_string_value(expression_stream_node[argument_stream, j])
                if (value in dynamic_expression_cache) dynamic_expression = dynamic_expression_cache[value]
                else {
                    dynamic_expression = expression_parse_fragment(value)
                    dynamic_expression_cache[value] = dynamic_expression
                }
                dynamic_results = expression_evaluate(dynamic_expression, single)
                expression_stream_append(output, dynamic_results)
            }
        }
        dynamic_eval_depth--
        return output
    }
    if (kind == "load" || kind == "load_str" || kind == "load_base64" || kind == "load_props") {
        for (i = 1; i <= expression_stream_count[input]; i++) {
            single = expression_stream_single(expression_stream_node[input, i])
            argument_stream = expression_evaluate(expression_left[expression], single)
            for (j = 1; j <= expression_stream_count[argument_stream]; j++) {
                value = codec_read_file(expression_string_value(expression_stream_node[argument_stream, j]))
                if (kind == "load") result_node = codec_yaml_decode(value)
                else if (kind == "load_base64") result_node = expression_scalar(codec_base64_decode(value), "string")
                else if (kind == "load_props") result_node = codec_props_decode(value)
                else result_node = expression_scalar(value, "string")
                expression_stream_push(output, result_node)
            }
        }
        return output
    }
    for (i = 1; i <= expression_stream_count[input]; i++) {
        node = expression_stream_node[input, i]
        resolved = resolve_alias(node)
        single = expression_stream_single(node)
        if (kind == "to_json") {
            step = expression_value[expression] == "compact" ? 0 : expression_utility_indent(expression, single, 2, 1)
            value = expression_json_pretty_text(node, step, 0)
            if (step > 0) value = value "\n"
            result_node = expression_scalar(value, "string")
        } else if (kind == "to_yaml") {
            step = expression_utility_indent(expression, single, 2, 0)
            result_node = expression_scalar(expression_yaml_text(node, 0, step) "\n", "string")
        } else if (kind == "from_json" || kind == "from_yaml") {
            value = expression_string_value(node)
            result_node = kind == "from_json" ? codec_json_decode(value) : codec_yaml_decode(value)
        } else if (kind == "to_props") {
            result_node = expression_scalar(codec_props_walk(node, ""), "string")
        } else if (kind == "from_props") {
            result_node = codec_props_decode(expression_string_value(node))
        } else if (kind == "to_csv" || kind == "to_tsv") {
            result_node = expression_scalar(codec_delimited_encode(node, kind == "to_csv" ? "," : "\t"), "string")
        } else if (kind == "from_csv" || kind == "from_tsv") {
            result_node = codec_delimited_decode(expression_string_value(node), kind == "from_csv" ? "," : "\t")
        } else if (kind == "to_toml") {
            result_node = expression_scalar(codec_toml_encode(node), "string")
        } else if (kind == "from_toml") {
            result_node = codec_toml_decode(expression_string_value(node))
        } else if (kind == "to_ini") {
            result_node = expression_scalar(codec_ini_encode(node), "string")
        } else if (kind == "from_ini") {
            result_node = codec_ini_decode(expression_string_value(node))
        } else if (kind == "to_xml") {
            result_node = expression_scalar(codec_xml_encode(node), "string")
        } else if (kind == "from_xml") {
            result_node = codec_xml_decode(expression_string_value(node))
        } else if (kind == "codec_base64" || kind == "codec_base64d" || kind == "codec_uri" || kind == "codec_urid" || kind == "codec_sh") {
            if (node_kind[resolved] != "scalar" || node_type[resolved] != "string") fail(substr(kind, 7) " codec requires a string")
            value = node_value[resolved]
            if (kind == "codec_base64") value = codec_base64_encode(value)
            else if (kind == "codec_base64d") value = codec_base64_decode(value)
            else if (kind == "codec_uri") value = codec_uri_encode(value)
            else if (kind == "codec_urid") value = codec_uri_decode(value)
            else value = codec_shell_encode(value)
            result_node = expression_scalar(value, "string")
        } else if (kind == "shuffle") {
            result_node = expression_shuffle(node)
        }
        expression_stream_push(output, result_node)
    }
    return output
}

function expression_dispatch_register(family, kinds,    item, count, i) {
    count = split(kinds, item, /[[:space:]]+/)
    for (i = 1; i <= count; i++) expression_dispatch_family[item[i]] = family
}

function expression_dispatch_initialize() {
    expression_dispatch_register("patch", "pointer apply_patch merge_patch diff_patch")
    expression_dispatch_register("schema", "validate schema_valid schema_errors")
    expression_dispatch_register("utility",
        "eval load load_str load_base64 load_props to_json from_json to_yaml from_yaml " \
        "to_props from_props to_csv from_csv to_tsv from_tsv to_toml from_toml " \
        "to_ini from_ini to_xml from_xml codec_base64 codec_base64d codec_uri codec_urid codec_sh shuffle")
    expression_dispatch_register("context",
        "filename fileindex documentindex path parent root node_property node_line node_column node_key " \
        "node_tag node_anchor node_alias node_style node_line_comment node_head_comment node_foot_comment")
    expression_dispatch_register("base",
        "identity split_doc empty error env strenv to_number envsubst literal interpolate variable array object " \
        "recursive negate arithmetic pipe bind reduce with explode")
    expression_dispatch_register("navigation",
        "first filter pick omit pivot comma slice key index each dynamic setpath delpaths assign update del " \
        "select compare and or not alternative")
    expression_dispatch_register("collections",
        "map map_values to_entries from_entries with_entries array_to_map sort unique reverse flatten sort_keys " \
        "min_by max_by sort_by group_by unique_by add min max any all any_c all_c length keys kind type has")
    expression_dispatch_register("string",
        "upcase downcase trim to_string regex_test regex_sub contains startswith endswith split join")
}

function expression_evaluate(expression, input,    kind, family) {
    kind = expression_kind[expression]
    family = expression_dispatch_family[kind]

    if (family == "patch") return expression_evaluate_patch(kind, expression, input)
    if (family == "schema") return expression_evaluate_schema(kind, expression, input)
    if (family == "utility") return expression_evaluate_utility(kind, expression, input)
    if (family == "context") return expression_evaluate_context(kind, expression, input)
    if (family == "base") return expression_evaluate_base(kind, expression, input)
    if (family == "navigation") return expression_evaluate_navigation(kind, expression, input)
    if (family == "collections") return expression_evaluate_collections(kind, expression, input)
    if (family == "string") return expression_evaluate_string(kind, expression, input)

    fail("cannot evaluate expression kind " kind)
}
