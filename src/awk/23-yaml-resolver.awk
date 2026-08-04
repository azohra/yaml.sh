function finalize_nodes(    node) {
    for (node = 1; node <= node_count; node++) {
        if (node_kind[node] == "pending") {
            node_kind[node] = "scalar"
            node_value[node] = ""
            node_type[node] = node_tag[node] == "tag:yaml.org,2002:str" ? "string" : "null"
        }
    }
}

function resolve_alias(node,    hops) {
    while (node_kind[node] == "alias") {
        if (++hops > node_count) {
            fail("recursive alias chain at node " node)
        }
        node = alias_target[node]
    }
    return node
}

function validate_aliases(    node, parent) {
    for (node = 1; node <= node_count; node++) {
        if (node_kind[node] != "alias") {
            continue
        }
        parent = node_parent[node]
        while (parent) {
            if (parent == alias_target[node]) {
                fail("recursive alias *" node_value[node] " on line " node_line[node])
            }
            parent = node_parent[parent]
        }
    }
}

function validate_merge_source(node, source_line,    resolved, i) {
    resolved = resolve_alias(node)
    if (node_kind[resolved] == "mapping") {
        return
    }
    if (node_kind[resolved] == "sequence") {
        for (i = 1; i <= sequence_count[resolved]; i++) {
            if (node_kind[resolve_alias(sequence_child[resolved, i])] != "mapping") {
                fail("merge sequence contains a non-mapping source on line " source_line)
            }
        }
        return
    }
    fail("merge source is not a mapping or sequence of mappings on line " source_line)
}

function validate_merges(    node, i) {
    for (node = 1; node <= node_count; node++) {
        if (node_kind[node] != "mapping") {
            continue
        }
        for (i = 1; i <= mapping_count[node]; i++) {
            if (mapping_merge[node, i]) {
                validate_merge_source(mapping_child[node, i], node_line[mapping_child[node, i]])
            }
        }
    }
}

function mapping_lookup_from_source(source, key, serial,    resolved, i, result) {
    resolved = resolve_alias(source)
    if (node_kind[resolved] == "mapping") {
        return mapping_lookup_internal(resolved, key, serial)
    }
    if (node_kind[resolved] == "sequence") {
        for (i = 1; i <= sequence_count[resolved]; i++) {
            result = mapping_lookup_from_source(sequence_child[resolved, i], key, serial)
            if (result) {
                return result
            }
        }
    }
    return 0
}

function mapping_lookup_internal(mapping, key, serial,    visit_key, i, result) {
    mapping = resolve_alias(mapping)
    visit_key = serial SUBSEP mapping SUBSEP key
    if (visit_key in lookup_seen) {
        fail("recursive merge while resolving key " key)
    }
    lookup_seen[visit_key] = 1

    for (i = 1; i <= mapping_count[mapping]; i++) {
        if (!mapping_merge[mapping, i] && mapping_key[mapping, i] == key) {
            delete lookup_seen[visit_key]
            return mapping_child[mapping, i]
        }
    }
    for (i = 1; i <= mapping_count[mapping]; i++) {
        if (mapping_merge[mapping, i]) {
            result = mapping_lookup_from_source(mapping_child[mapping, i], key, serial)
            if (result) {
                delete lookup_seen[visit_key]
                return result
            }
        }
    }
    delete lookup_seen[visit_key]
    return 0
}

function mapping_lookup(mapping, key) {
    return mapping_lookup_internal(mapping, key, ++lookup_serial)
}

