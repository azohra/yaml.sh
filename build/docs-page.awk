#!/usr/bin/awk -f

function esc(value,    out) {
    out = value
    gsub(/&/, "\\&amp;", out)
    gsub(/</, "\\&lt;", out)
    gsub(/>/, "\\&gt;", out)
    gsub(/"/, "\\&quot;", out)
    return out
}

function trim(value) {
    sub(/^[[:space:]]+/, "", value)
    sub(/[[:space:]]+$/, "", value)
    return value
}

function slugify(value,    slug) {
    slug = tolower(value)
    gsub(/<[^>]+>/, "", slug)
    gsub(/`/, "", slug)
    gsub(/[^[:alnum:]_-]+/, "-", slug)
    gsub(/^-+|-+$/, "", slug)
    if (slug == "") slug = "section"
    base_slug = slug
    if (slug_seen[base_slug]++) slug = base_slug "-" slug_seen[base_slug]
    return slug
}

function doc_url(url,    name, anchor) {
    if (url ~ /^(https?:|mailto:|#|\/)/) return url
    if (url !~ /\.md(#[^ ]*)?$/) return url
    anchor = ""
    if (index(url, "#")) {
        anchor = substr(url, index(url, "#"))
        url = substr(url, 1, index(url, "#") - 1)
    }
    name = url
    sub(/^.*\//, "", name)
    sub(/\.md$/, "", name)
    if (name == "README") return "/docs/" anchor
    return "/docs/" name "/" anchor
}

function inline(value,    out, before, code, after, token, left, middle, right, end_at, url, label, n) {
    out = esc(value)
    delete inline_code
    inline_code_count = 0
    while (match(out, /`[^`]+`/)) {
        before = substr(out, 1, RSTART - 1)
        code = substr(out, RSTART + 1, RLENGTH - 2)
        after = substr(out, RSTART + RLENGTH)
        token = "@@YSHCODE" ++inline_code_count "@@"
        inline_code[inline_code_count] = "<code>" code "</code>"
        out = before token after
    }
    while (match(out, /\[[^]]+\]\([^)]+\)/)) {
        before = substr(out, 1, RSTART - 1)
        middle = substr(out, RSTART + 1, RLENGTH - 2)
        after = substr(out, RSTART + RLENGTH)
        end_at = index(middle, "](")
        label = substr(middle, 1, end_at - 1)
        url = substr(middle, end_at + 2)
        out = before "<a href=\"" doc_url(url) "\">" label "</a>" after
    }
    while (match(out, /\*\*[^*]+\*\*/)) {
        left = substr(out, 1, RSTART - 1)
        middle = substr(out, RSTART + 2, RLENGTH - 4)
        right = substr(out, RSTART + RLENGTH)
        out = left "<strong>" middle "</strong>" right
    }
    for (n = 1; n <= inline_code_count; n++) {
        token = "@@YSHCODE" n "@@"
        while ((left = index(out, token)) > 0) {
            out = substr(out, 1, left - 1) inline_code[n] substr(out, left + length(token))
        }
    }
    return out
}

function close_paragraph() {
    if (paragraph != "") {
        print "          <p>" inline(paragraph) "</p>"
        paragraph = ""
    }
}

function close_list() {
    if (list_type != "") {
        print "          </" list_type ">"
        list_type = ""
    }
}

function table_cells(row, cells,    count, cleaned, cell, ch, i, in_code, key) {
    cleaned = row
    sub(/^\|[[:space:]]*/, "", cleaned)
    sub(/[[:space:]]*\|$/, "", cleaned)
    for (key in cells) delete cells[key]
    count = 1
    cell = ""
    in_code = 0
    for (i = 1; i <= length(cleaned); i++) {
        ch = substr(cleaned, i, 1)
        if (ch == "`") {
            in_code = !in_code
            cell = cell ch
        } else if (ch == "\\" && substr(cleaned, i + 1, 1) == "|") {
            cell = cell "|"
            i++
        } else if (ch == "|" && !in_code) {
            cells[count++] = cell
            cell = ""
        } else {
            cell = cell ch
        }
    }
    cells[count] = cell
    return count
}

function render_table(    row_count, cell_count, cells, r, c, tag) {
    if (table_count < 2) return
    cell_count = table_cells(table_line[1], cells)
    print "          <div class=\"table-wrap" (cell_count >= 4 ? " table-wide" : "") "\"><table>"
    print "            <thead><tr>"
    for (c = 1; c <= cell_count; c++) print "              <th>" inline(trim(cells[c])) "</th>"
    print "            </tr></thead>"
    print "            <tbody>"
    for (r = 3; r <= table_count; r++) {
        cell_count = table_cells(table_line[r], cells)
        print "              <tr>"
        for (c = 1; c <= cell_count; c++) print "                <td>" inline(trim(cells[c])) "</td>"
        print "              </tr>"
    }
    print "            </tbody>"
    print "          </table></div>"
    delete table_line
    table_count = 0
}

function close_blocks() {
    close_paragraph()
    close_list()
    if (table_count) render_table()
}

function nav_link(slug, label,    url, current) {
    url = slug == "index" ? "/docs/" : "/docs/" slug "/"
    current = slug == page_slug ? " aria-current=\"page\"" : ""
    print "              <li><a href=\"" url "\"" current ">" label "</a></li>"
}

function nav_group(label, a, al, b, bl, c, cl, d, dl) {
    print "          <section class=\"nav-group\">"
    print "            <p class=\"nav-title\">" label "</p>"
    print "            <ul>"
    if (a != "") nav_link(a, al)
    if (b != "") nav_link(b, bl)
    if (c != "") nav_link(c, cl)
    if (d != "") nav_link(d, dl)
    print "            </ul>"
    print "          </section>"
}

function print_nav() {
    nav_group("Start", "index", "Overview", "getting-started", "Install & quick start", "recipes", "Recipes", "", "")
    nav_group("Use", "queries", "Query language", "operators", "Operator reference", "documents", "Files & documents", "output", "Output & metadata")
    nav_group("Reference", "contracts", "Validate, patch & convert", "supported_yml", "YAML support", "yq-compatibility", "yq compatibility", "security", "Security & limits")
    nav_group("Build", "internals", "How it works", "development", "Development", "migration", "Migration", "", "")
}

function print_header() {
    print "<!doctype html>"
    print "<html lang=\"en\">"
    print "<head>"
    print "  <meta charset=\"utf-8\">"
    print "  <meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">"
    print "  <meta name=\"description\" content=\"" esc(page_description) "\">"
    print "  <meta name=\"theme-color\" content=\"#101410\">"
    print "  <meta property=\"og:title\" content=\"" esc(page_title) " · YAML.sh\">"
    print "  <meta property=\"og:description\" content=\"" esc(page_description) "\">"
    print "  <meta property=\"og:image\" content=\"https://yaml.azohra.com/og.png\">"
    print "  <link rel=\"canonical\" href=\"https://yaml.azohra.com" (page_slug == "index" ? "/docs/" : "/docs/" page_slug "/") "\">"
    print "  <link rel=\"icon\" href=\"/favicon.ico\">"
    print "  <link rel=\"stylesheet\" href=\"/docs/docs.css\">"
    print "  <script src=\"/docs/docs.js\" defer></script>"
    print "  <title>" esc(page_title) " · YAML.sh docs</title>"
    print "</head>"
    print "<body>"
    print "  <a class=\"skip-link\" href=\"#content\">Skip to content</a>"
    print "  <header class=\"site-header\">"
    print "    <a class=\"wordmark\" href=\"/\" aria-label=\"YAML.sh home\"><span class=\"mark\" aria-hidden=\"true\">Y</span><span>YAML<em>.sh</em></span></a>"
    print "    <nav aria-label=\"Primary\">"
    print "      <button class=\"header-search\" type=\"button\" data-search-open aria-label=\"Search documentation\">Search</button>"
    print "      <a aria-current=\"page\" href=\"/docs/\">Docs</a>"
    print "      <a href=\"https://github.com/azohra/yaml.sh\">GitHub</a>"
    print "      <a class=\"install\" href=\"/docs/getting-started/\">Install <span>v" esc(version) "</span></a>"
    print "    </nav>"
    print "  </header>"
    print "  <details class=\"mobile-docs\"><summary>Browse documentation</summary><nav>"
    print_nav()
    print "  </nav></details>"
    print "  <div class=\"docs-shell\">"
    print "    <aside class=\"docs-nav\" aria-label=\"Documentation\">"
    print "      <button class=\"search-trigger\" type=\"button\" data-search-open><span>Search docs</span><kbd>/</kbd></button>"
    print "      <nav>"
    print_nav()
    print "      </nav>"
    print "      <p class=\"nav-foot\">One file. <code>/bin/sh</code> + AWK.</p>"
    print "    </aside>"
    print "    <main id=\"content\" class=\"doc-content\">"
    print "      <div class=\"eyebrow\"><span>Documentation</span><span>v" esc(version) "</span></div>"
    print "      <article>"
}

BEGIN {
    print_header()
}

{
    line = $0
    sub(/\r$/, "", line)

    if (in_code) {
        if (line ~ /^```/) {
            print "</code></pre>"
            print "          </div>"
            in_code = 0
        } else {
            print esc(line)
        }
        next
    }

    if (line ~ /^```/) {
        close_blocks()
        language = substr(line, 4)
        if (language == "") language = "text"
        print "          <div class=\"code-block\">"
        print "            <div class=\"code-head\"><span>" esc(language) "</span><button type=\"button\" data-copy>Copy</button></div>"
        printf "            <pre><code class=\"language-%s\">", esc(language)
        in_code = 1
        next
    }

    if (line ~ /^\|/) {
        close_paragraph()
        close_list()
        table_line[++table_count] = line
        next
    } else if (table_count) {
        render_table()
    }

    if (line == "") {
        close_paragraph()
        close_list()
        next
    }

    if (line ~ /^###? / || line ~ /^# /) {
        close_blocks()
        level = 1
        while (substr(line, level, 1) == "#") level++
        level--
        heading = substr(line, level + 2)
        id = slugify(heading)
        if (level == 1) {
            print "          <h1 id=\"" id "\">" inline(heading) "</h1>"
        } else {
            print "          <h" level " id=\"" id "\"><a href=\"#" id "\">" inline(heading) "<span class=\"anchor-mark\" aria-hidden=\"true\">#</span></a></h" level ">"
            if (level <= 3) {
                toc_level[++toc_count] = level
                toc_id[toc_count] = id
                toc_label[toc_count] = heading
            }
        }
        next
    }

    if (line ~ /^> /) {
        close_blocks()
        print "          <blockquote><p>" inline(substr(line, 3)) "</p></blockquote>"
        next
    }

    if (line ~ /^- /) {
        close_paragraph()
        if (list_type != "ul") {
            close_list()
            list_type = "ul"
            print "          <ul>"
        }
        print "            <li>" inline(substr(line, 3)) "</li>"
        next
    }

    if (line ~ /^[0-9]+\. /) {
        close_paragraph()
        if (list_type != "ol") {
            close_list()
            list_type = "ol"
            print "          <ol>"
        }
        item = line
        sub(/^[0-9]+\. /, "", item)
        print "            <li>" inline(item) "</li>"
        next
    }

    close_list()
    paragraph = paragraph == "" ? line : paragraph " " line
}

END {
    close_blocks()
    if (in_code) print "</code></pre></div>"
    print "      </article>"
    print "      <nav class=\"page-turn\" aria-label=\"More documentation\"><a href=\"/docs/recipes/\"><span>Try a real task</span><strong>Open the recipe book →</strong></a><a href=\"/docs/supported_yml/\"><span>Check YAML support</span><strong>See exactly what works →</strong></a></nav>"
    print "    </main>"
    if (toc_count) {
        print "    <aside class=\"page-nav\" aria-label=\"On this page\">"
        print "      <strong>On this page</strong>"
        print "      <ol>"
        for (i = 1; i <= toc_count; i++) print "        <li class=\"level-" toc_level[i] "\"><a href=\"#" toc_id[i] "\">" inline(toc_label[i]) "</a></li>"
        print "      </ol>"
        print "      <a class=\"edit-link\" href=\"https://github.com/azohra/yaml.sh/edit/main/_static/_www/docs/" (page_slug == "index" ? "README" : page_slug) ".md\">Edit this page</a>"
        print "    </aside>"
    }
    print "  </div>"
    print "  <dialog class=\"search-dialog\" data-search-dialog>"
    print "    <form method=\"dialog\" class=\"search-box\"><label for=\"docs-search\">Search the docs</label><button value=\"close\" aria-label=\"Close search\">×</button><input id=\"docs-search\" type=\"search\" autocomplete=\"off\" placeholder=\"Try “merge files” or “envsubst”\"><div class=\"search-results\" aria-live=\"polite\"></div><p><kbd>↑</kbd><kbd>↓</kbd> move <kbd>enter</kbd> open <kbd>esc</kbd> close</p></form>"
    print "  </dialog>"
    print "  <footer class=\"site-footer\"><p>YAML.sh · YAML in shell. No, really.</p><p><a href=\"https://github.com/azohra/yaml.sh\">Source</a> · <a href=\"/docs/development/\">Contribute</a></p></footer>"
    print "</body>"
    print "</html>"
}
