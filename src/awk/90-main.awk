BEGIN {
    SQ = sprintf("%c", 39)
    document_index = 0
    codec_initialize()
    expression_dispatch_initialize()
    expression_single_token["."] = "dot"
    expression_single_token["|"] = "pipe"
    expression_single_token["("] = "left_parenthesis"
    expression_single_token[")"] = "right_parenthesis"
    expression_single_token["["] = "left_bracket"
    expression_single_token["]"] = "right_bracket"
    expression_single_token[","] = "comma"
    expression_single_token["{"] = "left_brace"
    expression_single_token["}"] = "right_brace"
    expression_single_token[":"] = "colon"
    expression_single_token["?"] = "question"
    expression_single_token[";"] = "semicolon"
    expression_single_token[">"] = "compare"
    expression_single_token["<"] = "compare"
    expression_single_token["="] = "assign"
    for (single_token_char in expression_single_token) {
        if (expression_single_token[single_token_char] != "compare") {
            expression_token_literal[expression_single_token[single_token_char]] = single_token_char
        }
    }
    expression_codec_kind["@json"] = "to_json"
    expression_codec_kind["@jsond"] = "from_json"
    expression_codec_kind["@yaml"] = "to_yaml"
    expression_codec_kind["@yamld"] = "from_yaml"
    expression_codec_kind["@props"] = "to_props"
    expression_codec_kind["@propsd"] = "from_props"
    expression_codec_kind["@csv"] = "to_csv"
    expression_codec_kind["@csvd"] = "from_csv"
    expression_codec_kind["@tsv"] = "to_tsv"
    expression_codec_kind["@tsvd"] = "from_tsv"
    expression_codec_kind["@toml"] = "to_toml"
    expression_codec_kind["@tomld"] = "from_toml"
    expression_codec_kind["@ini"] = "to_ini"
    expression_codec_kind["@inid"] = "from_ini"
    expression_codec_kind["@xml"] = "to_xml"
    expression_codec_kind["@xmld"] = "from_xml"
    expression_codec_kind["@base64"] = "codec_base64"
    expression_codec_kind["@base64d"] = "codec_base64d"
    expression_codec_kind["@uri"] = "codec_uri"
    expression_codec_kind["@urid"] = "codec_urid"
    expression_codec_kind["@sh"] = "codec_sh"
    parser_table_count = split("length keys kind type to_entries from_entries sort unique flatten reverse " \
        "upcase downcase trim to_string array_to_map split_doc shuffle min max any all add path " \
        "parent root to_number documentindex fileindex filename empty pivot", parser_table_names, " ")
    for (parser_table_index = 1; parser_table_index <= parser_table_count; parser_table_index++) {
        expression_context_kind[parser_table_names[parser_table_index]] = parser_table_names[parser_table_index]
    }
    parser_table_count = split("line column key tag anchor alias style line_comment head_comment foot_comment", parser_table_names, " ")
    for (parser_table_index = 1; parser_table_index <= parser_table_count; parser_table_index++) {
        expression_context_kind[parser_table_names[parser_table_index]] = "node_" parser_table_names[parser_table_index]
    }
    query = ENVIRON["YSH_QUERY_TEXT"]
    if (query == "") {
        query = "."
    }
    if (output_mode == "") {
        output_mode = "value"
    }
    if (input_format == "" || input_format == "auto") input_format = "yaml"
    if (selected_document == "") {
        selected_document = 0
    }
    if (yaml_indent == "") {
        yaml_indent = 2
    }
    if (unwrap_scalar_mode == "") {
        unwrap_scalar_mode = 1
    }
    presentation_possible = 1
    current_input_file_index = input_file_index + 0
    current_input_filename = input_filename
    file_document_offset = 0
    if (combined_files_mode) {
        for (argument_index = 1; argument_index < ARGC; argument_index++) {
            if (ARGV[argument_index] == "") {
                continue
            }
            declared_file_index = input_file_index + declared_input_file_count
            input_physical_name[declared_file_index] = ARGV[argument_index]
            if (logical_input_list != "") {
                if ((getline logical_input_name < logical_input_list) <= 0) {
                    fail("logical input list is missing an entry")
                }
                input_file_name[declared_file_index] = logical_input_name
            } else {
                input_file_name[declared_file_index] = ARGV[argument_index]
            }
            declared_input_file_count++
        }
        if (logical_input_list != "") {
            close(logical_input_list)
        }
        declared_last_input_file_index = input_file_index + declared_input_file_count - 1
    }
}

{
    if (input_format != "yaml") {
        input_byte_count += length($0) + 1
        if (max_input_bytes > 0 && input_byte_count > max_input_bytes) fail("input size limit exceeded (max " max_input_bytes " bytes)")
        codec_input_buffer = codec_input_buffer $0 "\n"
        next
    }
    if (combined_files_mode && FNR == 1) {
        next_input_file_index = combined_seen_file ? current_input_file_index + 1 : input_file_index + 0
        while (next_input_file_index <= declared_last_input_file_index && input_physical_name[next_input_file_index] != FILENAME) {
            next_input_file_index++
        }
        if (next_input_file_index > declared_last_input_file_index) {
            fail("could not map combined input file: " FILENAME)
        }
        if (!combined_seen_file) {
            current_input_file_index = next_input_file_index
            current_input_filename = input_file_name[current_input_file_index]
            input_file_start_line[current_input_file_index] = NR
            input_file_has_lines[current_input_file_index] = 1
            combined_seen_file = 1
        } else {
            input_file_end_line[current_input_file_index] = NR - 1
            if (multiline_scalar_active || multiline_flow_active) {
                fail("a YAML scalar or flow collection cannot span input files")
            }
            if (block_active) {
                flush_block()
            }
            fail_pending_explicit_keys(NR)
            if (!document_has_content[document_index] && document_explicit[document_index]) {
                create_empty_document(NR)
            }
            if ((document_index in document_root) || document_explicit[document_index] || document_has_content[document_index]) {
                document_index++
            }
            document_ended = 0
            clear_structure()
            current_input_file_index = next_input_file_index
            current_input_filename = input_file_name[current_input_file_index]
            input_file_start_line[current_input_file_index] = NR
            input_file_has_lines[current_input_file_index] = 1
            file_document_offset = document_index
        }
    }
    input_byte_count += length($0) + 1
    if (max_input_bytes > 0 && input_byte_count > max_input_bytes) {
        fail("input size limit exceeded (max " max_input_bytes " bytes)")
    }
    if (inplace_mode) {
        raw_input_line[NR] = $0
    }
    if (block_active) {
        process_line($0, NR)
        next
    }
    if (multiline_scalar_active) {
        if ($0 ~ /^(---|\.\.\.)([[:space:]]|$)/) {
            fail("document markers cannot appear inside quoted scalars on line " NR)
        }
        multiline_scalar_prefix = $0
        sub(/[^ ].*$/, "", multiline_scalar_prefix)
        if ($0 !~ /^[[:space:]]*$/ && length(multiline_scalar_prefix) < multiline_scalar_min_indent) {
            fail("invalid quoted scalar indentation on line " NR)
        }
        multiline_scalar_text = multiline_scalar_text "\n" $0
        if (!multiline_quote_is_open(multiline_scalar_text, multiline_scalar_delimiter)) {
            source_multiline_scalar_end[multiline_scalar_line] = NR
            process_line(multiline_scalar_text, multiline_scalar_line)
            multiline_scalar_active = 0
            multiline_scalar_text = ""
        }
        next
    }
    if (multiline_flow_active) {
        flow_line_prefix = $0
        sub(/[^ ].*$/, "", flow_line_prefix)
        flow_line_trimmed = trim($0)
        flow_line_first = substr(flow_line_trimmed, 1, 1)
        if (flow_line_trimmed != "" && flow_line_trimmed !~ /^#/ &&
            flow_line_first != "}" && flow_line_first != "]" &&
            length(flow_line_prefix) < multiline_flow_min_indent) {
            fail("invalid flow collection indentation on line " NR)
        }
        if (flow_line_trimmed == "---" || flow_line_trimmed == "...") {
            fail("document markers cannot appear inside flow collections on line " NR)
        }
        if (multiline_flow_root == "[" && flow_line_trimmed ~ /^:/) {
            fail("flow mapping values must follow their keys on line " NR)
        }
        if ($0 ~ /,#[^[:space:]]/) {
            fail("comments in flow collections require separation on line " NR)
        }
        if ($0 ~ /^[[:space:]]*#/) {
            multiline_flow_comment_break = 1
            flow_pending_comment_add($0, NR)
            next
        }
        if (multiline_flow_comment_break) {
            flow_previous = trim(multiline_flow_text)
            flow_previous = substr(flow_previous, length(flow_previous), 1)
            if (flow_previous != "," && flow_line_first != "," &&
                flow_line_first != "}" && flow_line_first != "]") {
                fail("flow entries separated by a comment require a comma on line " NR)
            }
            multiline_flow_comment_break = 0
        }
        flow_line_clean = strip_flow_line_comment($0)
        if (trim(flow_line_clean) == "") {
            next
        }
        flow_position_bind_pending(length(multiline_flow_text) + 2)
        flow_position_append($0, flow_line_clean, NR)
        multiline_flow_text = multiline_flow_text " " flow_line_clean
        if (flow_balance(multiline_flow_text) <= 0) {
            source_multiline_flow_end[multiline_flow_line] = NR
            process_line(multiline_flow_text, multiline_flow_line)
            flow_position_clear()
            multiline_flow_active = 0
            multiline_flow_text = ""
        }
        next
    }
    if ($0 ~ /^[[:space:]]*$/ || $0 ~ /^[[:space:]]*#/) {
        process_line($0, NR)
        next
    }
    multiline_scalar_delimiter = $0 ~ /["']/ ? multiline_scalar_quote($0) : ""
    if (multiline_scalar_delimiter != "") {
        multiline_scalar_active = 1
        multiline_scalar_line = NR
        multiline_scalar_text = $0
        multiline_scalar_prefix = $0
        sub(/[^ ].*$/, "", multiline_scalar_prefix)
        multiline_scalar_min_indent = length(multiline_scalar_prefix)
        multiline_scalar_first = substr($0, multiline_scalar_min_indent + 1)
        if (multiline_scalar_first ~ /^-[[:space:]]/ || find_mapping_separator(multiline_scalar_first, 1)) {
            multiline_scalar_min_indent++
        }
        next
    }
    process_line($0, NR)
}

END {
    if (!exit_status && multiline_scalar_active) {
        print "Error: unclosed quoted scalar on line " multiline_scalar_line > "/dev/stderr"
        exit_status = 1
    }
    if (!exit_status && multiline_flow_active) {
        print "Error: unclosed multiline flow collection on line " multiline_flow_line > "/dev/stderr"
        exit_status = 1
    }
    if (!exit_status && input_format != "yaml") {
        document_index = 0
        if (input_format == "json") document_root[0] = codec_json_decode(codec_input_buffer)
        else if (input_format == "toml") document_root[0] = codec_toml_decode(codec_input_buffer)
        else if (input_format == "ini") document_root[0] = codec_ini_decode(codec_input_buffer)
        else if (input_format == "xml") document_root[0] = codec_xml_decode(codec_input_buffer)
        else fail("unsupported input format: " input_format)
        document_has_content[0] = 1
    } else if (!exit_status) {
        if (combined_files_mode && combined_seen_file) {
            input_file_end_line[current_input_file_index] = NR
        }
        flush_block()
        parser_flush_pending_foot()
        for (pending_indent = 0; pending_indent <= max_indent; pending_indent++) {
            if (explicit_key_valid[pending_indent]) {
                add_explicit_null(pending_indent, NR + 1)
            }
        }
    }
    if (!exit_status && document_directive_pending[document_index]) {
        print "Error: directive requires a following document" > "/dev/stderr"
        exit_status = 1
    }
    if (!exit_status) {
        if (null_input_mode && !(0 in document_root) && node_count == 0) {
            document_index = 0
            create_empty_document(1)
        } else if (document_explicit[document_index] && !document_has_content[document_index]) {
            create_empty_document(NR + 1)
        }
        finalize_nodes()
        validate_aliases()
        validate_merges()
        parsed_node_count = node_count
        if (inplace_mode && transaction_batch_mode) {
            output_transaction_files(query)
        } else if (inplace_mode) {
            transform_all_documents(query, "")
            source_edit_compile(1, NR, 0)
            if (preserve_only_mode && !presentation_possible) {
                fail("preserve-only edit would produce overlapping source edits")
            }
            if (presentation_possible) {
                emit_preserved_input(1, NR)
            } else {
                emit_all_yaml_documents("")
            }
        } else if (eval_all_mode) {
            output_eval_all(query, output_mode)
        } else if (batch_files_mode) {
            output_batch_files(query, output_mode)
        } else if (all_documents_mode) {
            for (selected_document_cursor = 0; selected_document_cursor <= document_index; selected_document_cursor++) {
                if (selected_document_cursor in document_root) {
                    output_result(selected_document_cursor, query, output_mode)
                }
            }
        } else {
            output_result(selected_document + 0, query, output_mode)
        }
        if (explain_mode && !transaction_batch_mode) {
            output_explain()
        }
        if (exit_status_mode && (batch_files_mode ? batch_files_exit_status : (!final_result_count || !final_result_truthy))) {
            exit_status = 1
        }
    }
    exit exit_status
}
