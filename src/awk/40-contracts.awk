function patch_pointer_decode(token,    result, i, char, next_char) {
    result = ""
    for (i = 1; i <= length(token); i++) {
        char = substr(token, i, 1)
        if (char != "~") {
            result = result char
            continue
        }
        next_char = substr(token, ++i, 1)
        if (next_char == "0") result = result "~"
        else if (next_char == "1") result = result "/"
        else fail("invalid JSON Pointer escape")
    }
    return result
}

function patch_pointer_encode(token,    result) {
    result = token
    gsub(/~/, "~0", result)
    gsub(/\//, "~1", result)
    return result
}

function patch_pointer_find(root, pointer, allow_append,    remaining, slash, token, current, resolved, child, index_value) {
    patch_pointer_parent = 0
    patch_pointer_target = 0
    patch_pointer_token = ""
    patch_pointer_index = -1
    if (pointer == "") {
        patch_pointer_target = root
        return root
    }
    if (substr(pointer, 1, 1) != "/") fail("JSON Pointer must be empty or start with /")
    remaining = substr(pointer, 2)
    current = root
    while (1) {
        slash = index(remaining, "/")
        if (slash) {
            token = patch_pointer_decode(substr(remaining, 1, slash - 1))
            remaining = substr(remaining, slash + 1)
        } else {
            token = patch_pointer_decode(remaining)
        }
        resolved = resolve_alias(current)
        if (!slash) {
            patch_pointer_parent = resolved
            patch_pointer_token = token
            if (node_kind[resolved] == "mapping") {
                patch_pointer_target = mapping_lookup(resolved, token)
                return patch_pointer_target
            }
            if (node_kind[resolved] == "sequence") {
                if (token == "-" && allow_append) {
                    patch_pointer_index = sequence_count[resolved]
                    return 0
                }
                if (token !~ /^(0|[1-9][0-9]*)$/) fail("JSON Pointer array index must be an unsigned integer without leading zeros")
                index_value = token + 0
                if (index_value < sequence_count[resolved]) patch_pointer_target = sequence_child[resolved, index_value + 1]
                else if (!(allow_append && index_value == sequence_count[resolved])) fail("JSON Pointer array index is out of bounds: " token)
                patch_pointer_index = index_value
                return patch_pointer_target
            }
            fail("JSON Pointer cannot traverse " expression_type_name(resolved))
        }
        if (node_kind[resolved] == "mapping") {
            child = mapping_lookup(resolved, token)
        } else if (node_kind[resolved] == "sequence") {
            if (token !~ /^(0|[1-9][0-9]*)$/ || token + 0 >= sequence_count[resolved]) {
                fail("JSON Pointer array index is out of bounds: " token)
            }
            child = sequence_child[resolved, token + 1]
        } else {
            fail("JSON Pointer cannot traverse " expression_type_name(resolved))
        }
        if (!child) fail("JSON Pointer path does not exist at /" patch_pointer_encode(token))
        current = child
    }
}

function expression_semantic_equal(left, right,    left_node, right_node, i, collection, key, child) {
    left_node = resolve_alias(left)
    right_node = resolve_alias(right)
    if (node_kind[left_node] != node_kind[right_node]) return 0
    if (node_kind[left_node] == "scalar") return expression_nodes_equal(left_node, right_node)
    if (node_kind[left_node] == "sequence") {
        if (sequence_count[left_node] != sequence_count[right_node]) return 0
        for (i = 1; i <= sequence_count[left_node]; i++) {
            if (!expression_semantic_equal(sequence_child[left_node, i], sequence_child[right_node, i])) return 0
        }
        return 1
    }
    if (expression_mapping_length(left_node) != expression_mapping_length(right_node)) return 0
    collection = ++collection_serial
    collect_mapping_keys(left_node, collection)
    for (i = 1; i <= collection_count[collection]; i++) {
        key = collection_key[collection, i]
        child = mapping_lookup(right_node, key)
        if (!child || !expression_semantic_equal(mapping_lookup(left_node, key), child)) return 0
    }
    return 1
}

function patch_sequence_insert(parent, index_value, value,    replacement, i) {
    replacement = new_node("sequence", 0, "", "", "")
    for (i = 0; i <= sequence_count[parent]; i++) {
        if (i == index_value) add_sequence(replacement, expression_clone_node(value), 0)
        if (i < sequence_count[parent]) add_sequence(replacement, expression_clone_node(sequence_child[parent, i + 1]), 0)
    }
    expression_replace_node(parent, replacement)
    return expression_last_replace_changed
}

function patch_add(root, pointer, value,    target, parent, placeholder, changed) {
    target = patch_pointer_find(root, pointer, 1)
    parent = patch_pointer_parent
    if (!parent) {
        expression_replace_node(root, value)
        return expression_last_replace_changed
    }
    if (node_kind[parent] == "mapping") {
        if (target) {
            expression_replace_node(target, value)
            return expression_last_replace_changed
        }
        placeholder = expression_null()
        expression_missing_parent[placeholder] = parent
        expression_missing_key[placeholder] = patch_pointer_token
        expression_replace_node(placeholder, value)
        return expression_last_replace_changed
    }
    return patch_sequence_insert(parent, patch_pointer_index, value)
}

function patch_remove(root, pointer,    target) {
    target = patch_pointer_find(root, pointer, 0)
    if (!target) fail("JSON Patch remove path does not exist: " pointer)
    expression_delete_node(target)
    return expression_last_delete_changed
}

function patch_replace(root, pointer, value,    target) {
    target = patch_pointer_find(root, pointer, 0)
    if (!target) fail("JSON Patch replace path does not exist: " pointer)
    expression_replace_node(target, value)
    return expression_last_replace_changed
}

function patch_required_string(operation, name,    node) {
    node = mapping_lookup(operation, name)
    if (!node) fail("JSON Patch operation requires " name)
    node = resolve_alias(node)
    if (node_kind[node] != "scalar" || node_type[node] != "string") fail("JSON Patch " name " must be a string")
    return node_value[node]
}

function patch_apply(root, patch,    resolved_patch, i, operation, op, path, from, value, source, changed) {
    resolved_patch = resolve_alias(patch)
    if (node_kind[resolved_patch] != "sequence") fail("JSON Patch must be an array of operations")
    for (i = 1; i <= sequence_count[resolved_patch]; i++) {
        changed = 0
        operation = resolve_alias(sequence_child[resolved_patch, i])
        if (node_kind[operation] != "mapping") fail("JSON Patch operation must be an object")
        op = patch_required_string(operation, "op")
        path = patch_required_string(operation, "path")
        if (op == "add" || op == "replace" || op == "test") {
            value = mapping_lookup(operation, "value")
            if (!value) fail("JSON Patch " op " operation requires value")
        }
        if (op == "add") {
            changed = patch_add(root, path, value)
        } else if (op == "remove") {
            changed = patch_remove(root, path)
        } else if (op == "replace") {
            changed = patch_replace(root, path, value)
        } else if (op == "copy" || op == "move") {
            from = patch_required_string(operation, "from")
            source = patch_pointer_find(root, from, 0)
            if (!source) fail("JSON Patch " op " source does not exist: " from)
            if (op == "move" && path != from && index(path, from "/") == 1) fail("JSON Patch cannot move a value into its own descendant")
            value = expression_clone_node(source)
            if (op == "move" && path != from) changed = patch_remove(root, from) || changed
            if (path != from) changed = patch_add(root, path, value) || changed
        } else if (op == "test") {
            source = patch_pointer_find(root, path, 0)
            if (!source || !expression_semantic_equal(source, value)) fail("JSON Patch test failed at " path)
        } else {
            fail("unsupported JSON Patch operation: " op)
        }
        if (changed) expression_mark_changed(root)
    }
    return root
}

function merge_patch_apply(target, patch,    resolved_target, resolved_patch, collection, i, key, child, existing, placeholder) {
    resolved_target = resolve_alias(target)
    resolved_patch = resolve_alias(patch)
    if (node_kind[resolved_patch] != "mapping") {
        expression_replace_node(target, resolved_patch)
        if (expression_last_replace_changed) expression_mark_changed(target)
        return
    }
    if (node_kind[resolved_target] != "mapping") {
        expression_replace_node(target, new_node("mapping", 0, "", "", ""))
        if (expression_last_replace_changed) expression_mark_changed(target)
        resolved_target = resolve_alias(target)
    }
    collection = ++collection_serial
    collect_mapping_keys(resolved_patch, collection)
    for (i = 1; i <= collection_count[collection]; i++) {
        key = collection_key[collection, i]
        child = resolve_alias(mapping_lookup(resolved_patch, key))
        existing = mapping_lookup(resolved_target, key)
        if (node_kind[child] == "scalar" && node_type[child] == "null") {
            if (existing) {
                expression_delete_node(existing)
                if (expression_last_delete_changed) expression_mark_changed(resolved_target)
            }
        } else if (existing) {
            merge_patch_apply(existing, child)
        } else {
            placeholder = expression_null()
            expression_missing_parent[placeholder] = resolved_target
            expression_missing_key[placeholder] = key
            if (node_kind[child] == "mapping") {
                expression_replace_node(placeholder, new_node("mapping", 0, "", "", ""))
                merge_patch_apply(placeholder, child)
            } else {
                expression_replace_node(placeholder, child)
            }
            if (expression_last_replace_changed) expression_mark_changed(resolved_target)
        }
    }
}

function patch_operation(result, op, path, value,    operation) {
    operation = new_node("mapping", 0, "", "", "")
    add_mapping(operation, "op", expression_scalar(op, "string"), 0, 0)
    add_mapping(operation, "path", expression_scalar(path, "string"), 0, 0)
    if (value) add_mapping(operation, "value", expression_clone_node(value), 0, 0)
    add_sequence(result, operation, 0)
}

function patch_diff_into(before, after, path, result,    left, right, left_keys, right_keys, i, key, left_child, right_child) {
    left = resolve_alias(before)
    right = resolve_alias(after)
    if (expression_semantic_equal(left, right)) return
    if (node_kind[left] != "mapping" || node_kind[right] != "mapping") {
        patch_operation(result, "replace", path, right)
        return
    }
    left_keys = ++collection_serial
    right_keys = ++collection_serial
    collect_mapping_keys(left, left_keys)
    collect_mapping_keys(right, right_keys)
    for (i = 1; i <= collection_count[left_keys]; i++) {
        key = collection_key[left_keys, i]
        if (!mapping_lookup(right, key)) patch_operation(result, "remove", path "/" patch_pointer_encode(key), 0)
    }
    for (i = 1; i <= collection_count[left_keys]; i++) {
        key = collection_key[left_keys, i]
        left_child = mapping_lookup(left, key)
        right_child = mapping_lookup(right, key)
        if (right_child) patch_diff_into(left_child, right_child, path "/" patch_pointer_encode(key), result)
    }
    for (i = 1; i <= collection_count[right_keys]; i++) {
        key = collection_key[right_keys, i]
        if (!mapping_lookup(left, key)) patch_operation(result, "add", path "/" patch_pointer_encode(key), mapping_lookup(right, key))
    }
}

function schema_add_error(errors, instance_path, schema_path, keyword, message,    error) {
    error = new_node("mapping", 0, "", "", "")
    add_mapping(error, "instancePath", expression_scalar(instance_path, "string"), 0, 0)
    add_mapping(error, "schemaPath", expression_scalar(schema_path, "string"), 0, 0)
    add_mapping(error, "keyword", expression_scalar(keyword, "string"), 0, 0)
    add_mapping(error, "message", expression_scalar(message, "string"), 0, 0)
    add_sequence(errors, error, 0)
}

function schema_type_name(instance,    node) {
    node = resolve_alias(instance)
    if (node_kind[node] == "mapping") return "object"
    if (node_kind[node] == "sequence") return "array"
    if (node_type[node] == "bool") return "boolean"
    if (node_type[node] == "null") return "null"
    if (node_type[node] == "int") return "integer"
    if (node_type[node] == "float") return "number"
    return "string"
}

function schema_type_matches(instance, wanted,    node, number) {
    node = resolve_alias(instance)
    if (wanted == "object") return node_kind[node] == "mapping"
    if (wanted == "array") return node_kind[node] == "sequence"
    if (wanted == "string") return node_kind[node] == "scalar" && node_type[node] == "string"
    if (wanted == "boolean") return node_kind[node] == "scalar" && node_type[node] == "bool"
    if (wanted == "null") return node_kind[node] == "scalar" && node_type[node] == "null"
    if (wanted == "number") return node_kind[node] == "scalar" && (node_type[node] == "int" || node_type[node] == "float")
    if (wanted == "integer") {
        if (node_kind[node] != "scalar" || (node_type[node] != "int" && node_type[node] != "float")) return 0
        number = node_value[node] + 0
        return number == int(number)
    }
    return 0
}

function schema_type_contract(type_node,    node, i, child) {
    node = resolve_alias(type_node)
    if (node_kind[node] == "scalar" && node_type[node] == "string") return node_value[node]
    if (node_kind[node] == "sequence") {
        for (i = 1; i <= sequence_count[node]; i++) {
            child = resolve_alias(sequence_child[node, i])
            if (node_kind[child] != "scalar" || node_type[child] != "string") fail("JSON Schema type array must contain strings")
        }
        return "array"
    }
    fail("JSON Schema type must be a string or array of strings")
}

function schema_matches_type(instance, type_node,    node, i) {
    node = resolve_alias(type_node)
    if (node_kind[node] == "scalar") return schema_type_matches(instance, node_value[node])
    for (i = 1; i <= sequence_count[node]; i++) {
        if (schema_type_matches(instance, node_value[resolve_alias(sequence_child[node, i])])) return 1
    }
    return 0
}

function schema_utf8_length(value,    count, i, byte) {
    count = 0
    for (i = 1; i <= length(value); i++) {
        byte = codec_byte(substr(value, i, 1))
        if (byte < 128 || byte >= 192) count++
    }
    return count
}

function schema_number(node, keyword,    resolved) {
    resolved = resolve_alias(node)
    if (node_kind[resolved] != "scalar" || (node_type[resolved] != "int" && node_type[resolved] != "float")) {
        fail("JSON Schema " keyword " must be a number")
    }
    return node_value[resolved] + 0
}

function schema_nonnegative_integer(node, keyword,    resolved, value) {
    resolved = resolve_alias(node)
    value = node_value[resolved] + 0
    if (node_kind[resolved] != "scalar" || (node_type[resolved] != "int" && node_type[resolved] != "float") || value < 0 || value != int(value)) {
        fail("JSON Schema " keyword " must be a non-negative integer")
    }
    return value
}

function schema_boolean(node, keyword,    resolved) {
    resolved = resolve_alias(node)
    if (node_kind[resolved] != "scalar" || node_type[resolved] != "bool") fail("JSON Schema " keyword " must be a boolean")
    return tolower(node_value[resolved]) == "true"
}

function schema_trial(instance, schema, instance_path, schema_path, root,    errors) {
    errors = new_node("sequence", 0, "", "", "")
    schema_validate(instance, schema, errors, instance_path, schema_path, root)
    return sequence_count[errors] == 0
}

function schema_validate(instance, schema, errors, instance_path, schema_path, root,    resolved_schema, resolved_instance, valid, keyword, type_node, i, j, child, collection, key, property_schema, instance_child, required, matched, count, trial, minimum, maximum, number, size, pattern, properties, pattern_properties, additional, covered, item_start, contains_count, min_contains, max_contains, ref, referenced, active_key, dependent, dependency, name_node, name_schema, conditional, numeric_text) {
    if (++schema_validation_depth > max_depth) fail("JSON Schema validation depth limit exceeded (max " max_depth ")")
    resolved_schema = resolve_alias(schema)
    resolved_instance = resolve_alias(instance)
    valid = 1

    if (node_kind[resolved_schema] == "scalar" && node_type[resolved_schema] == "bool") {
        if (tolower(node_value[resolved_schema]) != "true") {
            schema_add_error(errors, instance_path, schema_path, "falseSchema", "value is rejected by the schema")
            valid = 0
        }
        schema_validation_depth--
        return valid
    }
    if (node_kind[resolved_schema] != "mapping") fail("JSON Schema must be an object or boolean")
    if (mapping_lookup(resolved_schema, "$dynamicRef")) fail("JSON Schema dynamic references are outside the focused profile")
    if (mapping_lookup(resolved_schema, "unevaluatedProperties") || mapping_lookup(resolved_schema, "unevaluatedItems")) {
        fail("JSON Schema unevaluated vocabularies are outside the focused profile")
    }

    child = mapping_lookup(resolved_schema, "$ref")
    if (child) {
        child = resolve_alias(child)
        if (node_kind[child] != "scalar" || node_type[child] != "string") fail("JSON Schema $ref must be a string")
        ref = node_value[child]
        if (ref == "#") referenced = root
        else if (substr(ref, 1, 2) == "#/") referenced = patch_pointer_find(root, substr(ref, 2), 0)
        else fail("JSON Schema supports local $ref values only")
        if (!referenced) fail("JSON Schema $ref does not resolve: " ref)
        active_key = referenced SUBSEP resolved_instance
        if (schema_ref_active[active_key]) fail("cyclic JSON Schema $ref")
        schema_ref_active[active_key] = 1
        if (!schema_validate(resolved_instance, referenced, errors, instance_path, ref, root)) valid = 0
        delete schema_ref_active[active_key]
    }

    type_node = mapping_lookup(resolved_schema, "type")
    if (type_node) {
        schema_type_contract(type_node)
        if (!schema_matches_type(resolved_instance, type_node)) {
            schema_add_error(errors, instance_path, schema_path "/type", "type", "expected " expression_to_string(type_node) ", got " schema_type_name(resolved_instance))
            valid = 0
        }
    }

    child = mapping_lookup(resolved_schema, "const")
    if (child && !expression_semantic_equal(resolved_instance, child)) {
        schema_add_error(errors, instance_path, schema_path "/const", "const", "value does not match const")
        valid = 0
    }
    child = mapping_lookup(resolved_schema, "enum")
    if (child) {
        child = resolve_alias(child)
        if (node_kind[child] != "sequence") fail("JSON Schema enum must be an array")
        matched = 0
        for (i = 1; i <= sequence_count[child]; i++) if (expression_semantic_equal(resolved_instance, sequence_child[child, i])) matched = 1
        if (!matched) {
            schema_add_error(errors, instance_path, schema_path "/enum", "enum", "value is not in enum")
            valid = 0
        }
    }

    for (j = 1; j <= 3; j++) {
        keyword = j == 1 ? "allOf" : (j == 2 ? "anyOf" : "oneOf")
        child = mapping_lookup(resolved_schema, keyword)
        if (!child) continue
        child = resolve_alias(child)
        if (node_kind[child] != "sequence" || !sequence_count[child]) fail("JSON Schema " keyword " must be a non-empty array")
        count = 0
        if (keyword == "allOf") {
            for (i = 1; i <= sequence_count[child]; i++) {
                if (!schema_validate(resolved_instance, sequence_child[child, i], errors, instance_path, schema_path "/" keyword "/" (i - 1), root)) valid = 0
            }
        } else {
            for (i = 1; i <= sequence_count[child]; i++) {
                if (schema_trial(resolved_instance, sequence_child[child, i], instance_path, schema_path "/" keyword "/" (i - 1), root)) count++
            }
            if ((keyword == "anyOf" && count == 0) || (keyword == "oneOf" && count != 1)) {
                schema_add_error(errors, instance_path, schema_path "/" keyword, keyword, keyword == "anyOf" ? "value matches no subschema" : "value must match exactly one subschema")
                valid = 0
            }
        }
    }
    child = mapping_lookup(resolved_schema, "not")
    if (child && schema_trial(resolved_instance, child, instance_path, schema_path "/not", root)) {
        schema_add_error(errors, instance_path, schema_path "/not", "not", "value matches the forbidden schema")
        valid = 0
    }
    conditional = mapping_lookup(resolved_schema, "if")
    if (conditional) {
        if (schema_trial(resolved_instance, conditional, instance_path, schema_path "/if", root)) {
            child = mapping_lookup(resolved_schema, "then")
            if (child && !schema_validate(resolved_instance, child, errors, instance_path, schema_path "/then", root)) valid = 0
        } else {
            child = mapping_lookup(resolved_schema, "else")
            if (child && !schema_validate(resolved_instance, child, errors, instance_path, schema_path "/else", root)) valid = 0
        }
    }

    if (node_kind[resolved_instance] == "mapping") {
        size = expression_mapping_length(resolved_instance)
        child = mapping_lookup(resolved_schema, "minProperties")
        if (child && size < schema_nonnegative_integer(child, "minProperties")) {
            schema_add_error(errors, instance_path, schema_path "/minProperties", "minProperties", "object has too few properties")
            valid = 0
        }
        child = mapping_lookup(resolved_schema, "maxProperties")
        if (child && size > schema_nonnegative_integer(child, "maxProperties")) {
            schema_add_error(errors, instance_path, schema_path "/maxProperties", "maxProperties", "object has too many properties")
            valid = 0
        }
        required = mapping_lookup(resolved_schema, "required")
        if (required) {
            required = resolve_alias(required)
            if (node_kind[required] != "sequence") fail("JSON Schema required must be an array")
            for (i = 1; i <= sequence_count[required]; i++) {
                name_node = resolve_alias(sequence_child[required, i])
                if (node_kind[name_node] != "scalar" || node_type[name_node] != "string") fail("JSON Schema required names must be strings")
                key = node_value[name_node]
                if (!mapping_lookup(resolved_instance, key)) {
                    schema_add_error(errors, instance_path, schema_path "/required", "required", "required property is missing: " key)
                    valid = 0
                }
            }
        }
        properties = mapping_lookup(resolved_schema, "properties")
        if (properties && node_kind[resolve_alias(properties)] != "mapping") fail("JSON Schema properties must be an object")
        pattern_properties = mapping_lookup(resolved_schema, "patternProperties")
        if (pattern_properties && node_kind[resolve_alias(pattern_properties)] != "mapping") fail("JSON Schema patternProperties must be an object")
        additional = mapping_lookup(resolved_schema, "additionalProperties")
        name_schema = mapping_lookup(resolved_schema, "propertyNames")
        collection = ++collection_serial
        collect_mapping_keys(resolved_instance, collection)
        for (i = 1; i <= collection_count[collection]; i++) {
            key = collection_key[collection, i]
            instance_child = mapping_lookup(resolved_instance, key)
            if (name_schema) {
                name_node = expression_scalar(key, "string")
                if (!schema_validate(name_node, name_schema, errors, instance_path "/" patch_pointer_encode(key), schema_path "/propertyNames", root)) valid = 0
            }
            covered = 0
            if (properties) {
                property_schema = mapping_lookup(resolve_alias(properties), key)
                if (property_schema) {
                    covered = 1
                    if (!schema_validate(instance_child, property_schema, errors, instance_path "/" patch_pointer_encode(key), schema_path "/properties/" patch_pointer_encode(key), root)) valid = 0
                }
            }
            if (pattern_properties) {
                trial = ++collection_serial
                collect_mapping_keys(resolve_alias(pattern_properties), trial)
                for (j = 1; j <= collection_count[trial]; j++) {
                    pattern = collection_key[trial, j]
                    if (key ~ pattern) {
                        covered = 1
                        if (!schema_validate(instance_child, mapping_lookup(resolve_alias(pattern_properties), pattern), errors, instance_path "/" patch_pointer_encode(key), schema_path "/patternProperties/" patch_pointer_encode(pattern), root)) valid = 0
                    }
                }
            }
            if (!covered && additional) {
                child = resolve_alias(additional)
                if (node_kind[child] == "scalar" && node_type[child] == "bool") {
                    if (!schema_boolean(child, "additionalProperties")) {
                        schema_add_error(errors, instance_path "/" patch_pointer_encode(key), schema_path "/additionalProperties", "additionalProperties", "additional property is not allowed")
                        valid = 0
                    }
                } else if (!schema_validate(instance_child, child, errors, instance_path "/" patch_pointer_encode(key), schema_path "/additionalProperties", root)) valid = 0
            }
        }
        dependent = mapping_lookup(resolved_schema, "dependentRequired")
        if (dependent) {
            dependent = resolve_alias(dependent)
            if (node_kind[dependent] != "mapping") fail("JSON Schema dependentRequired must be an object")
            trial = ++collection_serial
            collect_mapping_keys(dependent, trial)
            for (i = 1; i <= collection_count[trial]; i++) {
                key = collection_key[trial, i]
                if (!mapping_lookup(resolved_instance, key)) continue
                dependency = resolve_alias(mapping_lookup(dependent, key))
                if (node_kind[dependency] != "sequence") fail("JSON Schema dependentRequired entries must be arrays")
                for (j = 1; j <= sequence_count[dependency]; j++) {
                    name_node = resolve_alias(sequence_child[dependency, j])
                    if (node_kind[name_node] != "scalar" || node_type[name_node] != "string") fail("JSON Schema dependentRequired names must be strings")
                    if (!mapping_lookup(resolved_instance, node_value[name_node])) {
                        schema_add_error(errors, instance_path, schema_path "/dependentRequired/" patch_pointer_encode(key), "dependentRequired", "dependent property is missing: " node_value[name_node])
                        valid = 0
                    }
                }
            }
        }
        dependent = mapping_lookup(resolved_schema, "dependentSchemas")
        if (dependent) {
            dependent = resolve_alias(dependent)
            if (node_kind[dependent] != "mapping") fail("JSON Schema dependentSchemas must be an object")
            trial = ++collection_serial
            collect_mapping_keys(dependent, trial)
            for (i = 1; i <= collection_count[trial]; i++) {
                key = collection_key[trial, i]
                if (mapping_lookup(resolved_instance, key) &&
                    !schema_validate(resolved_instance, mapping_lookup(dependent, key), errors, instance_path, schema_path "/dependentSchemas/" patch_pointer_encode(key), root)) valid = 0
            }
        }
    }

    if (node_kind[resolved_instance] == "sequence") {
        size = sequence_count[resolved_instance]
        child = mapping_lookup(resolved_schema, "minItems")
        if (child && size < schema_nonnegative_integer(child, "minItems")) {
            schema_add_error(errors, instance_path, schema_path "/minItems", "minItems", "array has too few items")
            valid = 0
        }
        child = mapping_lookup(resolved_schema, "maxItems")
        if (child && size > schema_nonnegative_integer(child, "maxItems")) {
            schema_add_error(errors, instance_path, schema_path "/maxItems", "maxItems", "array has too many items")
            valid = 0
        }
        child = mapping_lookup(resolved_schema, "uniqueItems")
        if (child && schema_boolean(child, "uniqueItems")) {
            for (i = 1; i <= size; i++) for (j = i + 1; j <= size; j++) {
                if (expression_semantic_equal(sequence_child[resolved_instance, i], sequence_child[resolved_instance, j])) {
                    schema_add_error(errors, instance_path, schema_path "/uniqueItems", "uniqueItems", "array items are not unique")
                    valid = 0
                    i = size
                    break
                }
            }
        }
        child = mapping_lookup(resolved_schema, "prefixItems")
        item_start = 1
        if (child) {
            child = resolve_alias(child)
            if (node_kind[child] != "sequence") fail("JSON Schema prefixItems must be an array")
            for (i = 1; i <= sequence_count[child] && i <= size; i++) {
                if (!schema_validate(sequence_child[resolved_instance, i], sequence_child[child, i], errors, instance_path "/" (i - 1), schema_path "/prefixItems/" (i - 1), root)) valid = 0
            }
            item_start = sequence_count[child] + 1
        }
        child = mapping_lookup(resolved_schema, "items")
        if (child) for (i = item_start; i <= size; i++) {
            if (!schema_validate(sequence_child[resolved_instance, i], child, errors, instance_path "/" (i - 1), schema_path "/items", root)) valid = 0
        }
        child = mapping_lookup(resolved_schema, "contains")
        if (child) {
            contains_count = 0
            for (i = 1; i <= size; i++) if (schema_trial(sequence_child[resolved_instance, i], child, instance_path "/" (i - 1), schema_path "/contains", root)) contains_count++
            min_contains = mapping_lookup(resolved_schema, "minContains") ? schema_nonnegative_integer(mapping_lookup(resolved_schema, "minContains"), "minContains") : 1
            max_contains = mapping_lookup(resolved_schema, "maxContains") ? schema_nonnegative_integer(mapping_lookup(resolved_schema, "maxContains"), "maxContains") : -1
            if (contains_count < min_contains || (max_contains >= 0 && contains_count > max_contains)) {
                schema_add_error(errors, instance_path, schema_path "/contains", "contains", "array contains count is outside the allowed range")
                valid = 0
            }
        }
    }

    if (node_kind[resolved_instance] == "scalar" && node_type[resolved_instance] == "string") {
        size = schema_utf8_length(node_value[resolved_instance])
        child = mapping_lookup(resolved_schema, "minLength")
        if (child && size < schema_nonnegative_integer(child, "minLength")) {
            schema_add_error(errors, instance_path, schema_path "/minLength", "minLength", "string is too short")
            valid = 0
        }
        child = mapping_lookup(resolved_schema, "maxLength")
        if (child && size > schema_nonnegative_integer(child, "maxLength")) {
            schema_add_error(errors, instance_path, schema_path "/maxLength", "maxLength", "string is too long")
            valid = 0
        }
        child = mapping_lookup(resolved_schema, "pattern")
        if (child) {
            child = resolve_alias(child)
            if (node_kind[child] != "scalar" || node_type[child] != "string") fail("JSON Schema pattern must be a string")
            if (node_value[resolved_instance] !~ node_value[child]) {
                schema_add_error(errors, instance_path, schema_path "/pattern", "pattern", "string does not match the required pattern")
                valid = 0
            }
        }
    }

    if (node_kind[resolved_instance] == "scalar" && (node_type[resolved_instance] == "int" || node_type[resolved_instance] == "float")) {
        number = node_value[resolved_instance] + 0
        child = mapping_lookup(resolved_schema, "minimum")
        if (child && number < schema_number(child, "minimum")) {
            schema_add_error(errors, instance_path, schema_path "/minimum", "minimum", "number is below the minimum")
            valid = 0
        }
        child = mapping_lookup(resolved_schema, "maximum")
        if (child && number > schema_number(child, "maximum")) {
            schema_add_error(errors, instance_path, schema_path "/maximum", "maximum", "number is above the maximum")
            valid = 0
        }
        child = mapping_lookup(resolved_schema, "exclusiveMinimum")
        if (child && number <= schema_number(child, "exclusiveMinimum")) {
            schema_add_error(errors, instance_path, schema_path "/exclusiveMinimum", "exclusiveMinimum", "number is not above the exclusive minimum")
            valid = 0
        }
        child = mapping_lookup(resolved_schema, "exclusiveMaximum")
        if (child && number >= schema_number(child, "exclusiveMaximum")) {
            schema_add_error(errors, instance_path, schema_path "/exclusiveMaximum", "exclusiveMaximum", "number is not below the exclusive maximum")
            valid = 0
        }
        child = mapping_lookup(resolved_schema, "multipleOf")
        if (child) {
            minimum = schema_number(child, "multipleOf")
            if (minimum <= 0) fail("JSON Schema multipleOf must be greater than zero")
            maximum = number / minimum
            if (maximum < 0) maximum = -maximum
            numeric_text = tolower(sprintf("%.15g", maximum))
            if (numeric_text ~ /inf|nan/ || maximum - int(maximum + 0.000000000001) > 0.000000001) {
                schema_add_error(errors, instance_path, schema_path "/multipleOf", "multipleOf", "number is not a multiple of the required value")
                valid = 0
            }
        }
    }

    schema_validation_depth--
    return valid
}

function schema_errors(instance, schema,    errors) {
    errors = new_node("sequence", 0, "", "", "")
    schema_validation_depth = 0
    schema_validate(instance, schema, errors, "", "#", resolve_alias(schema))
    return errors
}

