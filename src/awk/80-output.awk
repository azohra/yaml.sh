function expression_compiled(query) {
    if (!compiled_expression) {
        compiled_expression = expression_parse(query)
    }
    return compiled_expression
}

function expression_all_roots_stream(    input, document) {
    input = expression_stream_new()
    for (document = 0; document <= document_index; document++) {
        if (document in document_root) {
            expression_stream_push(input, document_root[document])
        }
    }
    return input
}

function transform_all_documents(query, file_filter,    document, root, expression, input, results) {
    expression = expression_compiled(query)
    for (document = 0; document <= document_index; document++) {
        if (!(document in document_root) || (file_filter != "" && document_file_index[document] != file_filter)) {
            continue
        }
        root = document_root[document]
        input = expression_stream_single(root)
        results = configuration_apply_contracts(expression_evaluate(expression, input))
        explain_result_count += expression_stream_count[results]
    }
}

function transform_eval_all_documents(query,    expression, input, results, i, file) {
    expression = expression_compiled(query)
    eval_all_top_expression = expression
    input = expression_all_roots_stream()
    results = configuration_apply_contracts(expression_evaluate(expression, input))
    explain_result_count += expression_stream_count[results]
    for (i = 1; i <= expression_stream_count[results]; i++) {
        file = expression_input_file(expression_stream_node[results, i])
        explain_file_result_count[file]++
    }
}

function emit_all_yaml_documents(file_filter,    document, emitted) {
    emitted = 0
    for (document = 0; document <= document_index; document++) {
        if (!(document in document_root) || (file_filter != "" && document_file_index[document] != file_filter)) {
            continue
        }
        if (emitted++) {
            print "---"
        }
        emit_yaml(document_root[document])
    }
}

function clear_explain_state(    i) {
    for (i = 1; i <= explain_mutation_count; i++) {
        delete explain_mutation_kind[i]
        delete explain_mutation_path[i]
        delete explain_mutation_file[i]
    }
    explain_result_count = 0
    explain_mutation_count = 0
    explain_replacement_count = 0
    explain_insertion_count = 0
    explain_deletion_count = 0
    final_result_count = 0
    final_result_truthy = 0
}

function output_transaction_files(query,    file, last_file, start_nodes, marker, transaction_start_nodes) {
    last_file = declared_input_file_count ? declared_last_input_file_index : current_input_file_index
    marker = sprintf("%c", 30) "YSHFILE "
    if (eval_all_mode) {
        presentation_possible = 1
        clear_explain_state()
        transaction_start_nodes = node_count
        transform_eval_all_documents(query)
    }
    for (file = input_file_index + 0; file <= last_file; file++) {
        current_input_file_index = file
        current_input_filename = input_file_name[file]
        if (!eval_all_mode) {
            presentation_possible = 1
            clear_explain_state()
            start_nodes = node_count
            transform_all_documents(query, file)
        } else {
            start_nodes = transaction_start_nodes
        }
        if (preserve_only_mode && expression_file_changed[file] && !presentation_possible) {
            fail("preserve-only edit would regenerate YAML presentation: " input_file_name[file])
        }
        source_edit_compile(input_file_start_line[file], input_file_end_line[file], file)
        if (preserve_only_mode && expression_file_changed[file] && !presentation_possible) {
            fail("preserve-only edit would produce overlapping source edits: " input_file_name[file])
        }
        print marker file " " (expression_file_changed[file] ? 1 : 0)
        if (presentation_possible && input_file_has_lines[file]) {
            emit_preserved_input(input_file_start_line[file], input_file_end_line[file])
        } else if (!presentation_possible) {
            emit_all_yaml_documents(file)
        }
        if (explain_mode) {
            explain_file_mode = 1
            explain_file_index = file
            explain_file_generated_nodes = node_count - start_nodes
            output_explain()
            explain_file_mode = 0
        }
    }
}

function output_ast(document,    node, i) {
    for (node = 1; node <= node_count; node++) {
        if (node_document[node] != document) {
            continue
        }
        printf "node\t%d\t%s\tline=%d", node, node_kind[node], node_line[node]
        if (node_anchor[node] != "") {
            printf "\tanchor=%s", json_quote(node_anchor[node])
        }
        if (node_tag[node] != "") {
            printf "\ttag=%s", json_quote(node_tag[node])
        }
        if (node_kind[node] == "scalar") {
            printf "\ttype=%s\tvalue=%s", node_type[node], json_quote(node_value[node])
        } else if (node_kind[node] == "alias") {
            printf "\tname=%s\ttarget=%d", json_quote(node_value[node]), alias_target[node]
        }
        printf "\n"

        if (node_kind[node] == "mapping") {
            for (i = 1; i <= mapping_count[node]; i++) {
                printf "edge\t%d\tkey=%s\tchild=%d\tmerge=%d\n", node, json_quote(mapping_key[node, i]), mapping_child[node, i], mapping_merge[node, i]
            }
        } else if (node_kind[node] == "sequence") {
            for (i = 1; i <= sequence_count[node]; i++) {
                printf "edge\t%d\tindex=%d\tchild=%d\n", node, i - 1, sequence_child[node, i]
            }
        }
    }
}

function event_indent(depth,    prefix, i) {
    prefix = ""
    for (i = 0; i < depth; i++) {
        prefix = prefix "  "
    }
    return prefix
}

function configuration_file_node(path,    value, lower) {
    # Contract paths are explicit CLI inputs, like the primary document. The
    # file-ops policy only prevents expressions from selecting paths at runtime.
    value = local_file_read(path)
    lower = tolower(path)
    if (lower ~ /\.json$/) return codec_json_decode(value)
    if (lower ~ /\.toml$/) return codec_toml_decode(value)
    if (lower ~ /\.ini$/) return codec_ini_decode(value)
    if (lower ~ /\.xml$/) return codec_xml_decode(value)
    return codec_yaml_decode(value)
}

function configuration_apply_contracts(results,    output, i, node, errors, first, path, message) {
    if (schema_file != "" && !configuration_schema_node) configuration_schema_node = configuration_file_node(schema_file)
    if (patch_file != "" && !configuration_patch_node) configuration_patch_node = configuration_file_node(patch_file)
    if (merge_patch_file != "" && !configuration_merge_patch_node) configuration_merge_patch_node = configuration_file_node(merge_patch_file)
    if (patch_target_file != "" && !configuration_patch_target_node) configuration_patch_target_node = configuration_file_node(patch_target_file)
    output = expression_stream_new()
    for (i = 1; i <= expression_stream_count[results]; i++) {
        node = expression_stream_node[results, i]
        if (patch_file != "") patch_apply(node, configuration_patch_node)
        if (merge_patch_file != "") merge_patch_apply(node, configuration_merge_patch_node)
        if (schema_file != "") {
            errors = schema_errors(node, configuration_schema_node)
            if (sequence_count[errors]) {
                first = sequence_child[errors, 1]
                path = node_value[resolve_alias(mapping_lookup(first, "instancePath"))]
                message = node_value[resolve_alias(mapping_lookup(first, "message"))]
                fail("schema validation failed at " (path == "" ? "/" : path) ": " message)
            }
        }
        if (patch_target_file != "") {
            first = new_node("sequence", 0, "", "", "")
            patch_diff_into(node, configuration_patch_target_node, "", first)
            expression_stream_push(output, first)
        } else expression_stream_push(output, node)
    }
    return output
}

function output_node_events(node, depth,    i, prefix) {
    prefix = event_indent(depth)
    if (node_kind[node] == "alias") {
        print prefix "ALIAS name=" json_quote(node_value[node]) " line=" node_line[node]
        return
    }
    if (node_kind[node] == "scalar") {
        print prefix "SCALAR type=" node_type[node] " value=" json_quote(node_value[node]) " line=" node_line[node]
        return
    }
    if (node_kind[node] == "mapping") {
        print prefix "MAPPING_START line=" node_line[node]
        for (i = 1; i <= mapping_count[node]; i++) {
            print prefix "  KEY value=" json_quote(mapping_key[node, i]) " merge=" mapping_merge[node, i]
            output_node_events(mapping_child[node, i], depth + 1)
        }
        print prefix "MAPPING_END"
        return
    }
    if (node_kind[node] == "sequence") {
        print prefix "SEQUENCE_START line=" node_line[node]
        for (i = 1; i <= sequence_count[node]; i++) {
            output_node_events(sequence_child[node, i], depth + 1)
        }
        print prefix "SEQUENCE_END"
    }
}

function output_events(document) {
    print "STREAM_START"
    print "DOCUMENT_START index=" document
    output_node_events(document_root[document], 1)
    print "DOCUMENT_END index=" document
    print "STREAM_END"
}

function output_expression_node(target, output_mode,    resolved) {
    resolved = resolve_alias(target)
    if (output_mode == "line") {
        print node_line[target]
    } else if (output_mode == "type") {
        if (node_kind[resolved] == "scalar") {
            print node_type[resolved]
        } else {
            print node_kind[resolved]
        }
    } else if (output_mode == "tag") {
        print node_tag[resolved]
    } else if (output_mode == "json") {
        emit_json(target)
        printf "\n"
    } else if (output_mode == "yaml") {
        emit_yaml(target)
    } else if (output_mode == "toml") {
        printf "%s", codec_toml_encode(target)
    } else if (output_mode == "ini") {
        printf "%s", codec_ini_encode(target)
    } else if (output_mode == "xml") {
        printf "%s", codec_xml_encode(target)
    } else if (output_mode == "toml-test-json") {
        print codec_toml_test_json(target)
    } else if (output_mode == "toml-test-encode") {
        printf "%s", codec_toml_encode(codec_toml_test_decode(target))
    } else if (node_kind[resolved] == "scalar") {
        if (unwrap_scalar_mode) {
            print node_value[resolved]
        } else {
            emit_yaml(target)
        }
    } else {
        emit_json(target)
        printf "\n"
    }
}

function output_expression_results(results, output_mode,    i) {
    final_result_count = expression_stream_count[results]
    explain_result_count += final_result_count
    if (final_result_count) {
        final_result_truthy = expression_truthy(expression_stream_node[results, final_result_count])
    }
    for (i = 1; i <= expression_stream_count[results]; i++) {
        if (output_mode == "yaml" && emitted_output_count > 0) {
            print "---"
        }
        output_expression_node(expression_stream_node[results, i], output_mode)
        emitted_output_count++
    }
}

function output_explain(    documents, document, generated, presentation, shown, i, source, results, mutations, replacements, insertions, deletions, emitted_changes, parsed, source_edits) {
    documents = 0
    for (document = 0; document <= document_index; document++) {
        if ((document in document_root) && (!explain_file_mode || document_file_index[document] == explain_file_index)) {
            documents++
        }
    }
    parsed = parsed_node_count
    generated = explain_file_mode ? explain_file_generated_nodes : node_count - parsed_node_count
    results = explain_result_count + 0
    mutations = explain_mutation_count + 0
    replacements = explain_replacement_count + 0
    insertions = explain_insertion_count + 0
    deletions = explain_deletion_count + 0
    source_edits = inplace_mode ? source_edit_file_count[explain_file_mode ? explain_file_index : 0] + 0 : 0
    if (explain_file_mode && eval_all_mode) {
        parsed = 0
        results = explain_file_result_count[explain_file_index] + 0
        mutations = 0
        replacements = 0
        insertions = 0
        deletions = 0
        for (i = 1; i <= parsed_node_count; i++) {
            if (node_file_index[i] == explain_file_index) {
                parsed++
            }
        }
        for (i = 1; i <= explain_mutation_count; i++) {
            if (explain_mutation_file[i] != explain_file_index) {
                continue
            }
            mutations++
            if (explain_mutation_kind[i] == "insert") {
                insertions++
            } else if (explain_mutation_kind[i] == "delete") {
                deletions++
            } else {
                replacements++
            }
        }
    }
    source = explain_file_mode ? input_file_name[explain_file_index] : (combined_files_mode ? "multiple files" : input_filename)
    if (source == "") {
        source = "-"
    }
    if (!inplace_mode) {
        presentation = "not-requested"
    } else if (presentation_possible) {
        presentation = "preserved"
    } else {
        presentation = "regenerated"
    }
    if (explain_mode == 2) {
        printf "{\"input\":%s,\"documents\":%d,\"parsed_nodes\":%d,\"generated_nodes\":%d,", json_quote(source), documents, parsed, generated > "/dev/stderr"
        printf "\"results\":%d,\"mutations\":%d,\"replacements\":%d,\"insertions\":%d,\"deletions\":%d,", results, mutations, replacements, insertions, deletions > "/dev/stderr"
        printf "\"presentation\":%s,\"source_edits\":%d,\"changes\":[", json_quote(presentation), source_edits > "/dev/stderr"
        emitted_changes = 0
        for (i = 1; i <= explain_mutation_count; i++) {
            if (explain_file_mode && eval_all_mode && explain_mutation_file[i] != explain_file_index) {
                continue
            }
            if (emitted_changes++) {
                printf "," > "/dev/stderr"
            }
            printf "{\"kind\":%s,\"path\":%s}", json_quote(explain_mutation_kind[i]), json_quote(explain_mutation_path[i]) > "/dev/stderr"
        }
        print "]}" > "/dev/stderr"
        return
    }
    print "Explain: input=" json_quote(source) " documents=" documents " parsed_nodes=" parsed " generated_nodes=" generated > "/dev/stderr"
    print "Explain: results=" results " mutations=" mutations \
        " replacements=" replacements " insertions=" insertions \
        " deletions=" deletions " presentation=" presentation " source_edits=" source_edits > "/dev/stderr"
    shown = 0
    for (i = 1; i <= explain_mutation_count && shown < 20; i++) {
        if (explain_file_mode && eval_all_mode && explain_mutation_file[i] != explain_file_index) {
            continue
        }
        print "Explain: " explain_mutation_kind[i] " " explain_mutation_path[i] > "/dev/stderr"
        shown++
    }
    if (mutations > shown) {
        print "Explain: ... " (mutations - shown) " more mutations" > "/dev/stderr"
    }
}

function output_result(document, query, output_mode,    root, expression, input, results) {
    if (!(document in document_root)) {
        if (document == 0 && node_count == 0) {
            return
        }
        fail("document index not found: " document)
    }
    if (output_mode == "ast") {
        output_ast(document)
        return
    }
    if (output_mode == "events") {
        output_events(document)
        return
    }

    root = document_root[document]
    expression = expression_compiled(query)
    input = expression_stream_single(root)
    results = configuration_apply_contracts(expression_evaluate(expression, input))
    output_expression_results(results, output_mode)
}

function output_eval_all(query, output_mode,    expression, input, results) {
    expression = expression_compiled(query)
    eval_all_top_expression = expression
    input = expression_all_roots_stream()
    results = configuration_apply_contracts(expression_evaluate(expression, input))
    output_expression_results(results, output_mode)
}

function output_batch_files(query, output_mode,    file, last_file, document, found, file_truthy, file_has_document) {
    if (output_mode != "ast" && output_mode != "events") {
        expression_compiled(query)
    }
    last_file = declared_input_file_count ? declared_last_input_file_index : current_input_file_index
    for (file = input_file_index + 0; file <= last_file; file++) {
        found = 0
        file_has_document = 0
        file_truthy = 0
        current_input_file_index = file
        current_input_filename = input_file_name[file]
        for (document = 0; document <= document_index; document++) {
            if (!(document in document_root) || document_file_index[document] != file) {
                continue
            }
            file_has_document = 1
            current_input_filename = document_filename[document]
            if (!all_documents_mode && (node_document[document_root[document]] + 0) != selected_document + 0) {
                continue
            }
            found = 1
            output_result(document, query, output_mode)
            file_truthy = final_result_count && final_result_truthy
            if (!all_documents_mode) {
                break
            }
        }
        if (!found) {
            if (!file_has_document) {
                continue
            }
            fail("document index not found: " (selected_document + 0) " in " current_input_filename)
        }
        if (exit_status_mode && !file_truthy) {
            batch_files_exit_status = 1
        }
    }
}

