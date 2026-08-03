function new_node(kind, source_line, value, value_type, tag,    node) {
    if (max_nodes > 0 && node_count >= max_nodes) {
        fail("node limit exceeded (max " max_nodes ")")
    }
    node = ++node_count
    node_kind[node] = kind
    node_line[node] = source_line
    if (value != "") {
        node_value[node] = value
    }
    if (value_type != "") {
        node_type[node] = value_type
    }
    if (tag != "") {
        node_tag[node] = tag
    }
    if (document_index != file_document_offset) {
        node_document[node] = document_index - file_document_offset
    }
    if (combined_files_mode) {
        node_file_index[node] = current_input_file_index
        node_filename[node] = current_input_filename
    }
    return node
}

function bind_anchor(name, node, source_line,    key, anchor_index) {
    if (name == "") {
        return
    }
    key = document_index SUBSEP name
    anchor_target[key] = node
    node_anchor[node] = name
    anchor_index = ++document_anchor_count[document_index]
    document_anchor_name[document_index, anchor_index] = name
    document_anchor_node[document_index, anchor_index] = node
}

function ensure_container(node, kind, source_line) {
    if (node_kind[node] == "pending") {
        node_kind[node] = kind
        node_type[node] = ""
        if (substr(node_parent_edge[node], 1, 4) == "key " && (node in node_line_comment)) {
            node_key_line_comment[node] = node_line_comment[node]
            delete node_line_comment[node]
        }
        return node
    }
    if (node_kind[node] != kind) {
        fail("cannot add " kind " content to " node_kind[node] " node on line " source_line)
    }
    return node
}

function ensure_root(kind, source_line,    root) {
    if (!(document_index in document_root)) {
        root = new_node(kind, source_line, "", "", "")
        document_root[document_index] = root
        document_file_index[document_index] = current_input_file_index
        document_filename[document_index] = current_input_filename
        document_has_content[document_index] = 1
        parser_record_content(root, 0)
        return root
    }
    root = (document_index in document_root) ? document_root[document_index] : 0
    return ensure_container(root, kind, source_line)
}

function create_empty_document(source_line,    root) {
    if (document_index in document_root) {
        return document_root[document_index]
    }
    root = new_node("scalar", source_line, "", "null", "")
    document_root[document_index] = root
    document_file_index[document_index] = current_input_file_index
    document_filename[document_index] = current_input_filename
    document_has_content[document_index] = 1
    parser_record_content(root, 0)
    return root
}

function add_mapping(parent, key, child, source_line, is_merge,    seen_key, entry, depth) {
    ensure_container(parent, "mapping", source_line)
    seen_key = parent SUBSEP key
    if (seen_key in mapping_seen) {
        fail("duplicate mapping key " key " on line " source_line)
    }
    mapping_seen[seen_key] = 1
    entry = ++mapping_count[parent]
    mapping_key[parent, entry] = key
    mapping_child[parent, entry] = child
    if (is_merge) {
        mapping_merge[parent, entry] = 1
    }
    node_parent[child] = parent
    node_parent_edge[child] = "key " key
    depth = node_depth[parent] + 1
    if (node_kind[child] == "mapping" || node_kind[child] == "sequence" || node_kind[child] == "pending") {
        node_depth[child] = depth
    }
    if (max_depth > 0 && depth > max_depth) {
        fail("collection depth limit exceeded (max " max_depth ")")
    }
}

function add_sequence(parent, child, source_line,    entry, depth) {
    ensure_container(parent, "sequence", source_line)
    entry = ++sequence_count[parent]
    sequence_child[parent, entry] = child
    node_parent[child] = parent
    node_parent_edge[child] = "index " (entry - 1)
    depth = node_depth[parent] + 1
    if (node_kind[child] == "mapping" || node_kind[child] == "sequence" || node_kind[child] == "pending") {
        node_depth[child] = depth
    }
    if (max_depth > 0 && depth > max_depth) {
        fail("collection depth limit exceeded (max " max_depth ")")
    }
}

function alias_node(name, source_line,    key, node) {
    key = document_index SUBSEP name
    if (!(key in anchor_target)) {
        fail("undefined or forward alias *" name " on line " source_line)
    }
    node = new_node("alias", source_line, name, "", "")
    alias_target[node] = anchor_target[key]
    return node
}

function parse_scalar_key(value, source_line,    remainder, tag, anchor, node, resolved) {
    remainder = parse_properties(strip_inline_comment(trim(value)), source_line)
    tag = parsed_tag
    anchor = parsed_anchor
    if (substr(remainder, 1, 1) == "[" || substr(remainder, 1, 1) == "{") {
        fail("collection-valued mapping keys are not supported on line " source_line)
    }
    node = parse_core(remainder, source_line, tag, anchor)
    resolved = resolve_alias(node)
    if (node_kind[resolved] != "scalar") {
        fail("collection-valued mapping keys are not supported on line " source_line)
    }
    if (index(remainder, "\n")) {
        fail("implicit mapping keys must fit on one line " source_line)
    }
    parsed_key_is_merge = remainder == "<<" && tag == ""
    return node_value[resolved]
}
