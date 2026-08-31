#!/usr/bin/env bash
# assert_surviving_tests tool for test-rules MCP server
# Reports what a test class contains once a set of deletions is applied.

# Fully qualified parent classes whose own test set is empty, so a subclass's
# runnable tests are exactly the ones declared in its own file: PHPUnit's
# TestCase and Shopware's ShopwareTestCase (an abstract TestCase subclass
# declaring only static assertion helpers). Any other parent may contribute
# inherited test methods this file cannot show, which is UNRESOLVED rather than
# a count.
declare -ga _SURVIVAL_BASE_FQCNS=('PHPUnit\Framework\TestCase' 'Shopware\Core\Test\ShopwareTestCase')

# The unqualified names the bases above are written under. A short name outside
# this set is never resolved through the file's imports, so an aliased import of
# a known base is UNRESOLVED rather than a count.
declare -ga _SURVIVAL_BASE_SHORT_NAMES=(TestCase ShopwareTestCase)

# Decide whether a fully qualified name is one of the known empty-test-set bases.
# Globals:
#   _SURVIVAL_BASE_FQCNS - read.
# Arguments:
#   $1 - a class name, with or without a leading namespace separator.
# Returns:
#   0 when the name is a known base; 1 otherwise.
_survival_is_base_fqcn() {
    local candidate="${1#\\}"
    local known
    for known in "${_SURVIVAL_BASE_FQCNS[@]}"; do
        if [[ "${candidate}" == "${known}" ]]; then
            return 0
        fi
    done
    return 1
}

# Decide whether a parent class is one of the known empty-test-set bases.
#
# A qualified target names a class on its own and must be exactly one of the
# known bases. An unqualified target names a class only together with the file's
# imports, so it must both be one of the bases' short names and be imported
# under a name resolving to a known base — a bare `TestCase` with no matching
# import is some other TestCase, not PHPUnit's.
# Globals:
#   _SURVIVAL_BASE_SHORT_NAMES - read.
# Arguments:
#   $1 - the extends target as written; $2 - the fully qualified name the file
#        imports under that short name, empty when the file imports no such name.
# Returns:
#   0 when the parent is a known base; 1 otherwise.
_survival_is_known_base() {
    local parent="$1" imported="${2:-}"
    if _survival_is_base_fqcn "${parent}"; then
        return 0
    fi
    if [[ "${parent}" == *\\* ]]; then
        return 1
    fi
    local short
    for short in "${_SURVIVAL_BASE_SHORT_NAMES[@]}"; do
        if [[ "${parent}" == "${short}" ]]; then
            if [[ -n "${imported}" ]] && _survival_is_base_fqcn "${imported}"; then
                return 0
            fi
            return 1
        fi
    done
    return 1
}

# Scan a PHP test file and report the shape of the class named by its basename.
#
# Emits one record per line: `TARGET` when that class is declared, `ABSTRACT`,
# `EXTENDS <parent>`, `IMPORT <short name> <fully qualified name>` for every
# namespace-level `use` import, `TRAIT` for a trait `use` in its body,
# `METHOD <name>` for every method it declares, `TEST <name>` for every method
# that counts as a test (public, non-static, non-abstract, named test* or
# carrying `#[Test]`), and `AMBIGUOUS <reason>` when the scan cannot decide what
# a line is.
#
# The scan is line-based but string-aware: comment stripping, attribute-group
# delimiting, heredoc detection and brace counting all track quote state, so a
# `//` or a `#` inside a quoted attribute argument is not read as a comment, a
# `<<<` inside a string does not open a heredoc, and a `{` inside an interpolated
# string is not read as a block opener. Heredoc and nowdoc bodies are skipped
# entirely, so PHP source quoted inside one is neither counted as a declaration
# nor counted as a brace.
#
# Methods are attributed to the target class only at depth 1 of its own body:
# a declaration nested deeper belongs to an anonymous class in a method body,
# and one at the depth the class was opened at belongs to whatever follows the
# class. Both are excluded rather than credited to the target.
#
# A line whose state cannot be decided — a string literal left open at end of
# line, an unterminated heredoc or block comment at end of file, a closing brace
# with no opener the scan can follow or braces left open at end of file — yields
# `AMBIGUOUS` rather than a count, which the caller reports as a refusal, not
# UNRESOLVED: that status is reserved for an abstract class, an unresolvable
# parent, or a trait use.
# Arguments:
#   $1 - path to the file, $2 - the expected class name.
# Outputs:
#   The records above on stdout.
# Returns:
#   awk's status.
_survival_scan() {
    awk -v target="$2" '
        # The program is embedded in a single-quoted shell string, so a literal
        # apostrophe cannot appear in it.
        BEGIN { SQ = "\047" }

        # Strip comments from one line, leaving string literals intact so a
        # `//` inside a quoted argument is not read as a comment.
        # Globals: inblock, unterminated, hd_open, hd_id - all written.
        function strip_comments(s,   out, i, n, c, two, q, esc, rest, first) {
            out = ""
            i = 1
            n = length(s)
            while (i <= n) {
                c = substr(s, i, 1)
                if (inblock) {
                    if (c == "*" && substr(s, i + 1, 1) == "/") {
                        inblock = 0
                        i = i + 2
                    } else {
                        i++
                    }
                    continue
                }
                two = substr(s, i, 2)
                if (two == "/*") { inblock = 1; i = i + 2; continue }
                if (two == "//") { break }
                if (c == "#") {
                    # `#` opens a comment except as `#[`, which opens an
                    # attribute.
                    if (substr(s, i + 1, 1) == "[") { out = out "#["; i = i + 2; continue }
                    break
                }
                if (substr(s, i, 3) == "<<<") {
                    # PHP allows nothing but a comment after a heredoc opener,
                    # so the rest of the line carries no code either way.
                    rest = substr(s, i + 3)
                    sub(/^[ \t]+/, "", rest)
                    first = substr(rest, 1, 1)
                    if (first == SQ || first == "\"") { rest = substr(rest, 2) }
                    if (match(rest, /^[A-Za-z_][A-Za-z0-9_]*/)) {
                        hd_open = 1
                        hd_id = substr(rest, RSTART, RLENGTH)
                    }
                    break
                }
                if (c == SQ || c == "\"") {
                    q = c
                    out = out c
                    i++
                    esc = 0
                    while (i <= n) {
                        c = substr(s, i, 1)
                        out = out c
                        i++
                        if (esc) { esc = 0; continue }
                        if (c == "\\") { esc = 1; continue }
                        if (c == q) { q = ""; break }
                    }
                    if (q != "") { unterminated = 1; return out }
                    continue
                }
                out = out c
                i++
            }
            return out
        }

        # Walk an attribute group over `s` from index `from`, with `depth`
        # brackets already open, skipping bracket characters inside strings.
        # Globals: attr_end, attr_depth - written.
        function scan_attr(s, from, depth,   i, n, c, q, esc) {
            n = length(s)
            for (i = from; i <= n; i++) {
                c = substr(s, i, 1)
                if (q != "") {
                    if (esc) { esc = 0; continue }
                    if (c == "\\") { esc = 1; continue }
                    if (c == q) { q = "" }
                    continue
                }
                if (c == SQ || c == "\"") { q = c; esc = 0; continue }
                if (c == "[") { depth++; continue }
                if (c == "]") {
                    depth--
                    if (depth == 0) {
                        attr_end = i
                        attr_depth = 0
                        return
                    }
                }
            }
            attr_end = 0
            attr_depth = depth
        }

        # Record one attribute-group member under its bare attribute name.
        # Globals: attrnames - appended to.
        function add_attr_name(member,   name) {
            gsub(/^[ \t]+|[ \t]+$/, "", member)
            if (!match(member, /^\\?[A-Za-z_][A-Za-z0-9_\\]*/)) { return }
            name = substr(member, RSTART, RLENGTH)
            sub(/^.*\\/, "", name)
            attrnames = attrnames "|" name
        }

        # Record every attribute name declared in one balanced `#[...]` group,
        # so `#[Test, TestDox(...)]` registers Test as a group member and
        # `#[TestWith(...)]` does not.
        function add_attr_names(group,   body, i, n, c, depth, q, esc, member) {
            body = group
            sub(/^#\[/, "", body)
            sub(/\][ \t]*$/, "", body)
            depth = 0
            member = ""
            n = length(body)
            for (i = 1; i <= n; i++) {
                c = substr(body, i, 1)
                if (q != "") {
                    member = member c
                    if (esc) { esc = 0; continue }
                    if (c == "\\") { esc = 1; continue }
                    if (c == q) { q = "" }
                    continue
                }
                if (c == SQ || c == "\"") { q = c; esc = 0; member = member c; continue }
                if (c == "(" || c == "[") { depth++; member = member c; continue }
                if (c == ")" || c == "]") { depth--; member = member c; continue }
                if (c == "," && depth == 0) {
                    add_attr_name(member)
                    member = ""
                    continue
                }
                member = member c
            }
            add_attr_name(member)
        }

        # Net brace delta of one line, skipping braces inside string literals.
        # Comments are stripped and attribute groups consumed before this runs,
        # so every remaining brace outside a string opens or closes a block.
        function brace_delta(s,   i, n, c, q, esc, d) {
            n = length(s)
            d = 0
            for (i = 1; i <= n; i++) {
                c = substr(s, i, 1)
                if (q != "") {
                    if (esc) { esc = 0; continue }
                    if (c == "\\") { esc = 1; continue }
                    if (c == q) { q = "" }
                    continue
                }
                if (c == SQ || c == "\"") { q = c; esc = 0; continue }
                if (c == "{") { d++; continue }
                if (c == "}") { d-- }
            }
            return d
        }

        # Record a namespace-level `use` import as the short name it introduces
        # and the name that short name resolves to. A grouped import, a
        # `use function` and a `use const` match nothing here and stay
        # unrecorded, which leaves a parent written under one unresolvable
        # rather than resolved to the wrong class.
        function emit_import(s,   body, alias, fqcn, short) {
            if (s !~ /^use[ \t]+\\?[A-Za-z_][A-Za-z0-9_\\]*([ \t]+as[ \t]+[A-Za-z_][A-Za-z0-9_]*)?[ \t]*;$/) { return }
            body = s
            sub(/^use[ \t]+/, "", body)
            sub(/[ \t]*;$/, "", body)
            alias = ""
            if (match(body, /[ \t]+as[ \t]+[A-Za-z_][A-Za-z0-9_]*$/)) {
                alias = substr(body, RSTART, RLENGTH)
                sub(/^[ \t]+as[ \t]+/, "", alias)
                body = substr(body, 1, RSTART - 1)
            }
            sub(/^\\/, "", body)
            fqcn = body
            short = fqcn
            sub(/^.*\\/, "", short)
            if (alias != "") { short = alias }
            print "IMPORT " short " " fqcn
        }

        # Strip string-literal contents (quotes included) from one line, the
        # same quote-tracking `brace_delta` uses for braces, so a `class` token
        # quoted inside a message string is never read as a declaration.
        function strip_strings(s,   i, n, c, q, esc, out) {
            out = ""
            n = length(s)
            for (i = 1; i <= n; i++) {
                c = substr(s, i, 1)
                if (q != "") {
                    if (esc) { esc = 0; continue }
                    if (c == "\\") { esc = 1; continue }
                    if (c == q) { q = "" }
                    continue
                }
                if (c == SQ || c == "\"") { q = c; esc = 0; continue }
                out = out c
            }
            return out
        }

        function class_name(s,   n, stripped) {
            stripped = strip_strings(s)
            if (!match(stripped, /(^|[ \t])class[ \t]+[A-Za-z_][A-Za-z0-9_]*/)) { return "" }
            n = substr(stripped, RSTART, RLENGTH)
            sub(/^.*class[ \t]+/, "", n)
            # `new class extends Foo` has no name; the word after the keyword is
            # the next keyword, not a class this file declares.
            if (n == "extends" || n == "implements") { return "" }
            return n
        }

        function emit_class(decl, opened_at,   base) {
            current = class_name(decl)
            if (current != target) { return }
            in_target = 1
            base_depth = opened_at
            print "TARGET"
            if (decl ~ /(^|[ \t])abstract[ \t]/) { print "ABSTRACT" }
            if (match(decl, /[ \t]extends[ \t]+\\?[A-Za-z_][A-Za-z0-9_\\]*/)) {
                base = substr(decl, RSTART, RLENGTH)
                sub(/^[ \t]*extends[ \t]+/, "", base)
                print "EXTENDS " base
            }
        }

        function emit_method(pre, mname,   n, w, i, vis, is_static, is_abstract) {
            vis = "public"
            is_static = 0
            is_abstract = 0
            n = split(pre, w, /[ \t]+/)
            for (i = 1; i <= n; i++) {
                if (w[i] == "private" || w[i] == "protected") { vis = w[i] }
                else if (w[i] == "static") { is_static = 1 }
                else if (w[i] == "abstract") { is_abstract = 1 }
            }
            print "METHOD " mname
            if (vis != "public" || is_static || is_abstract) { return }
            # #[DataProvider] and #[DataProviderExternal] decorate the consuming
            # test, so they neither mark nor exclude one; only the name prefix
            # and #[Test] mark a test.
            if (mname ~ /^test/) { print "TEST " mname; return }
            if (index(attrnames "|", "|Test|") > 0) { print "TEST " mname }
        }

        function refuse(reason) {
            print "AMBIGUOUS " reason
            ambiguous = 1
            exit
        }

        {
            line = $0
            sub(/\r$/, "", line)

            # A heredoc or nowdoc body is opaque: PHP source quoted inside one
            # declares nothing. The closer may be indented (PHP 7.3+) and may be
            # followed by `;`, `,` or `)`.
            if (inheredoc) {
                if (match(line, "^[ \t]*" hdid "([^A-Za-z0-9_]|$)")) { inheredoc = 0 }
                next
            }

            hd_open = 0
            unterminated = 0
            line = strip_comments(line)
            if (unterminated) {
                refuse("a string literal is not closed on line " NR)
            }
            if (hd_open) {
                inheredoc = 1
                hdid = hd_id
            }
            gsub(/^[ \t]+|[ \t]+$/, "", line)

            if (attr_pending) {
                scan_attr(line, 1, attr_depth)
                if (attr_end == 0) {
                    attrbuf = attrbuf " " line
                    next
                }
                add_attr_names(attrbuf " " substr(line, 1, attr_end))
                attr_pending = 0
                line = substr(line, attr_end + 1)
                gsub(/^[ \t]+|[ \t]+$/, "", line)
            }
            while (substr(line, 1, 2) == "#[") {
                scan_attr(line, 1, 0)
                if (attr_end == 0) {
                    attrbuf = line
                    attr_pending = 1
                    break
                }
                add_attr_names(substr(line, 1, attr_end))
                line = substr(line, attr_end + 1)
                gsub(/^[ \t]+|[ \t]+$/, "", line)
            }
            if (attr_pending) { next }
            if (line == "") { next }

            # Declarations are placed by the depth the line opens at, so a line
            # that both opens and closes a block still reads as a declaration at
            # its own depth.
            linedepth = depth
            depth = depth + brace_delta(line)
            if (depth < 0) {
                refuse("a closing brace on line " NR " has no opener the scan can follow")
            }

            # An import sits at namespace level; a `use` inside a class body is
            # a trait draw, which the class-body branch below reports instead.
            if (linedepth == 0 && line ~ /^use[ \t]/) {
                emit_import(line)
                attrnames = ""
                next
            }

            if (classbuf == "") {
                if (class_name(line) != "") { classbuf = line }
            } else {
                classbuf = classbuf " " line
            }
            if (classbuf != "") {
                if (index(classbuf, "{") > 0) {
                    emit_class(classbuf, linedepth)
                    classbuf = ""
                }
                attrnames = ""
                next
            }

            if (current == target && in_target && linedepth == base_depth + 1) {
                if (line ~ /^use[ \t]+\\?[A-Za-z_]/) {
                    print "TRAIT"
                    attrnames = ""
                    next
                }
                if (match(line, /function[ \t]+[A-Za-z_][A-Za-z0-9_]*[ \t]*\(/)) {
                    pre = substr(line, 1, RSTART - 1)
                    mname = substr(line, RSTART, RLENGTH)
                    sub(/^function[ \t]+/, "", mname)
                    sub(/[ \t]*\(.*$/, "", mname)
                    # Anything but modifier words before `function` means this is
                    # an expression, not a method declaration.
                    if (pre ~ /^[A-Za-z \t]*$/) { emit_method(pre, mname) }
                }
            }
            attrnames = ""
        }

        END {
            if (!ambiguous) {
                if (inheredoc) { print "AMBIGUOUS heredoc " hdid " is not closed at end of file" }
                else if (inblock) { print "AMBIGUOUS a block comment is not closed at end of file" }
                else if (depth != 0) { print "AMBIGUOUS " depth " brace(s) are left open at end of file" }
            }
        }
    ' "$1"
}

# Report what a test class contains once a set of deletions is applied.
#
# The shared argument validator checks required fields, unknown fields and
# enums, not types, so the type checks below are the tool's own.
# Globals:
#   PROJECT_ROOT - read; a relative test_path resolves against it.
# Arguments:
#   JSON arguments object with `test_path` (string) and `deleted_methods`
#   (array of string, possibly empty).
# Outputs:
#   On success a one-line JSON object {test_path, total, deleted, surviving,
#   status} on stdout; on refusal an `Error: ...` message on stdout. Nothing is
#   written to stderr — the dispatcher merges it into the client's result.
# Returns:
#   0 on a reported result; 1 on any refusal.
tool_assert_surviving_tests() {
    local args="${1:-}"
    if [[ -z "${args}" ]]; then args='{}'; fi

    local validation rc=0
    validation=$(printf '%s' "${args}" | jq -r '
        if (has("test_path") | not) then
            "Missing required parameter: test_path."
        elif (.test_path | type) != "string" then
            "Invalid test_path: expected a string, got \(.test_path | type) (\(.test_path | tojson))."
        elif (.test_path == "") then
            "Invalid test_path: expected a non-empty string, got an empty string."
        elif (has("deleted_methods") | not) then
            "Missing required parameter: deleted_methods."
        elif (.deleted_methods | type) != "array" then
            "Invalid deleted_methods: expected an array of strings, got \(.deleted_methods | type) (\(.deleted_methods | tojson))."
        else
            ([.deleted_methods | to_entries[] | select((.value | type) != "string")]) as $nonstring
          | ([.deleted_methods | to_entries[] | select(.value == "")]) as $blank
          | ([.deleted_methods | to_entries[]
                | select((.value | type) == "string" and .value != "")
                | select((.value | test("\\A[A-Za-z_][A-Za-z0-9_]*\\z")) | not)]) as $invalid
          | ([.deleted_methods | group_by(.)[] | select(length > 1) | .[0]]) as $dupes
          | if ($nonstring | length) > 0 then
                "Invalid deleted_methods: every entry must be a string; got "
                + ($nonstring | map("index \(.key)=\(.value | tojson)") | join(", ")) + "."
            elif ($blank | length) > 0 then
                "Invalid deleted_methods: entries must be non-empty strings; got an empty string at "
                + ($blank | map("index \(.key)") | join(", ")) + "."
            elif ($invalid | length) > 0 then
                "Invalid deleted_methods: entries must be PHP method names (a letter or underscore, then letters, digits and underscores); got "
                + ($invalid | map("index \(.key)=\(.value | tojson)") | join(", ")) + "."
            elif ($dupes | length) > 0 then
                "Invalid deleted_methods: duplicate entry "
                + ($dupes | map(tojson) | join(", ")) + "."
            else "" end
        end
    ' 2>/dev/null) || rc=$?
    if [[ ${rc} -ne 0 ]]; then
        log "ERROR" "assert_surviving_tests: arguments could not be evaluated: ${args}"
        printf 'Error: assert_surviving_tests could not evaluate its arguments against the input schema.\n'
        return 1
    fi
    if [[ -n "${validation}" ]]; then
        log "ERROR" "assert_surviving_tests: ${validation}"
        printf 'Error: %s\n' "${validation}"
        return 1
    fi

    local test_path
    rc=0
    test_path=$(printf '%s' "${args}" | jq -r '.test_path' 2>/dev/null) || rc=$?
    if [[ ${rc} -ne 0 ]]; then
        log "ERROR" "assert_surviving_tests: test_path could not be read"
        printf 'Error: assert_surviving_tests could not read test_path.\n'
        return 1
    fi

    # A relative path is resolved against the project root. No fallback to the
    # process working directory: the server's cwd is whatever launched it, and
    # resolving there would silently read a different file.
    local resolved="${test_path}"
    if [[ "${test_path}" != /* ]]; then
        if [[ -z "${PROJECT_ROOT:-}" ]]; then
            log "ERROR" "assert_surviving_tests: PROJECT_ROOT unset, cannot resolve ${test_path}"
            printf 'Error: assert_surviving_tests cannot resolve the relative test_path %s: PROJECT_ROOT is not set.\n' "${test_path}"
            return 1
        fi
        resolved="${PROJECT_ROOT}/${test_path}"
    fi

    if [[ ! -f "${resolved}" ]] || [[ ! -r "${resolved}" ]]; then
        log "ERROR" "assert_surviving_tests: unreadable test_path ${resolved}"
        printf 'Error: assert_surviving_tests cannot read test_path %s (resolved to %s); it does not exist or is not readable.\n' "${test_path}" "${resolved}"
        return 1
    fi

    # PSR-4: the test class is the one named after the file. A file declaring no
    # such class does not identify its test class — a refusal below, not
    # UNRESOLVED: UNRESOLVED means a class was found but its runnable set is not
    # derivable from this file (abstract, unresolvable parent, trait use).
    local base_name="${resolved##*/}"
    local class_name="${base_name%.php}"

    local scan
    # awk's own diagnostics would land in the client's result (the dispatcher
    # merges stderr); the explicit status check below reports the refusal.
    rc=0
    scan=$(_survival_scan "${resolved}" "${class_name}" 2>/dev/null) || rc=$?
    if [[ ${rc} -ne 0 ]]; then
        log "ERROR" "assert_surviving_tests: scan failed for ${resolved}"
        printf 'Error: assert_surviving_tests could not scan %s.\n' "${test_path}"
        return 1
    fi

    local target_found=0 is_abstract=0 uses_trait=0 parent="" ambiguous=""
    local -a methods=() tests=()
    local -A imports=()
    local record import
    while IFS= read -r record; do
        case "${record}" in
            TARGET) target_found=1 ;;
            ABSTRACT) is_abstract=1 ;;
            TRAIT) uses_trait=1 ;;
            AMBIGUOUS\ *) ambiguous="${record#AMBIGUOUS }" ;;
            EXTENDS\ *) parent="${record#EXTENDS }" ;;
            IMPORT\ *)
                import="${record#IMPORT }"
                imports["${import%% *}"]="${import#* }"
                ;;
            METHOD\ *) methods+=("${record#METHOD }") ;;
            TEST\ *) tests+=("${record#TEST }") ;;
        esac
    done <<< "${scan}"

    # A scan the awk program itself could not classify is not UNRESOLVED: the
    # spec reserves that status for a class the file positively identifies as
    # abstract, trait-drawing, or based on an unresolvable parent. A line the
    # scanner cannot read is a refusal, naming what could not be parsed and
    # where — a check that cannot evaluate its input reports a refusal, never
    # a pass.
    if [[ -n "${ambiguous}" ]]; then
        log "ERROR" "assert_surviving_tests: scan of ${resolved} is ambiguous: ${ambiguous}"
        printf 'Error: assert_surviving_tests could not scan %s: %s.\n' "${test_path}" "${ambiguous}"
        return 1
    fi

    # A file declaring no class named after its basename identifies no test
    # class at all — a refusal naming what was expected, not UNRESOLVED (which
    # requires a found class whose runnable set this file cannot determine).
    if [[ ${target_found} -eq 0 ]]; then
        log "ERROR" "assert_surviving_tests: ${resolved} declares no class named ${class_name}"
        printf 'Error: assert_surviving_tests: %s declares no class named %s.\n' "${test_path}" "${class_name}"
        return 1
    fi

    local -a deleted_methods=()
    local expected_count entries entry
    rc=0
    expected_count=$(printf '%s' "${args}" | jq -r '.deleted_methods | length' 2>/dev/null) || rc=$?
    if [[ ${rc} -ne 0 ]] || [[ ! "${expected_count}" =~ ^[0-9]+$ ]]; then
        log "ERROR" "assert_surviving_tests: deleted_methods length could not be read"
        printf 'Error: assert_surviving_tests could not read deleted_methods.\n'
        return 1
    fi
    rc=0
    entries=$(printf '%s' "${args}" | jq -r '.deleted_methods[]' 2>/dev/null) || rc=$?
    if [[ ${rc} -ne 0 ]]; then
        log "ERROR" "assert_surviving_tests: deleted_methods entries could not be read"
        printf 'Error: assert_surviving_tests could not read the deleted_methods entries.\n'
        return 1
    fi
    if [[ ${expected_count} -gt 0 ]]; then
        while IFS= read -r entry; do
            deleted_methods+=("${entry}")
        done <<< "${entries}"
    fi
    # The schema validation above already refuses any entry outside
    # [A-Za-z0-9_], so a newline could not have reached this read and fragmented
    # into two lines. This count check catches any other read discrepancy.
    if [[ ${#deleted_methods[@]} -ne ${expected_count} ]]; then
        log "ERROR" "assert_surviving_tests: read ${#deleted_methods[@]} of ${expected_count} deleted_methods entries"
        printf 'Error: assert_surviving_tests could not read all %s deleted_methods entries.\n' "${expected_count}"
        return 1
    fi

    local status="" reason=""
    if [[ ${is_abstract} -eq 1 ]]; then
        status="UNRESOLVED"
        reason="${class_name} is abstract, so its runnable tests are its subclasses'"
    elif [[ ${uses_trait} -eq 1 ]]; then
        status="UNRESOLVED"
        reason="${class_name} uses a trait, which may contribute test methods this file does not show"
    elif [[ -n "${parent}" ]] && ! _survival_is_known_base "${parent}" "${imports["${parent}"]:-}"; then
        status="UNRESOLVED"
        reason="${class_name} extends ${parent}, which cannot be established as a PHPUnit or Shopware base"
    fi

    local payload
    # UNRESOLVED blocks the safety calculation, so it asserts no count: a number
    # here would read as a verified survivor count for a class whose runnable set
    # this file does not determine. It also accuses no finding, so an unmatched
    # deleted_methods entry is not reported. `reason` names the condition,
    # which is the whole content of the informational entry the caller renders.
    if [[ -n "${status}" ]]; then
        log "INFO" "assert_surviving_tests: ${test_path} UNRESOLVED — ${reason}"
        rc=0
        payload=$(jq -n -c --arg test_path "${test_path}" --arg status "${status}" --arg reason "${reason}" \
            '{test_path: $test_path, total: null, deleted: null, surviving: null, status: $status, reason: $reason}' 2>/dev/null) || rc=$?
        if [[ ${rc} -ne 0 ]]; then
            log "ERROR" "assert_surviving_tests: UNRESOLVED result could not be built for ${test_path}"
            printf 'Error: assert_surviving_tests could not build its result for %s.\n' "${test_path}"
            return 1
        fi
        printf '%s\n' "${payload}"
        return 0
    fi

    local -A method_set=() test_set=()
    local name
    for name in "${methods[@]}"; do
        method_set["${name}"]=1
    done
    for name in "${tests[@]}"; do
        test_set["${name}"]=1
    done

    local -a unmatched=()
    for name in "${deleted_methods[@]}"; do
        if [[ -z "${method_set[${name}]+set}" ]]; then
            unmatched+=("${name}")
        fi
    done
    if [[ ${#unmatched[@]} -gt 0 ]]; then
        local unmatched_csv=""
        for name in "${unmatched[@]}"; do
            unmatched_csv="${unmatched_csv:+${unmatched_csv}, }${name}"
        done
        log "ERROR" "assert_surviving_tests: ${test_path} declares no method named ${unmatched_csv}"
        printf 'Error: assert_surviving_tests: %s declares no method named: %s.\n' "${test_path}" "${unmatched_csv}"
        return 1
    fi

    # Only a deleted test method changes the survivor count; deleting a data
    # provider or a private helper removes no test.
    local deleted_count=0
    for name in "${deleted_methods[@]}"; do
        if [[ -n "${test_set[${name}]+set}" ]]; then
            deleted_count=$(( deleted_count + 1 ))
        fi
    done

    local total=${#tests[@]}
    local surviving=$(( total - deleted_count ))
    local result_status="OK"
    if [[ ${surviving} -eq 0 ]]; then
        result_status="EMPTY"
    fi

    log "INFO" "assert_surviving_tests: ${test_path} total=${total} deleted=${deleted_count} surviving=${surviving} status=${result_status}"
    rc=0
    payload=$(jq -n -c \
        --arg test_path "${test_path}" \
        --argjson total "${total}" \
        --argjson deleted "${deleted_count}" \
        --argjson surviving "${surviving}" \
        --arg status "${result_status}" \
        '{test_path: $test_path, total: $total, deleted: $deleted, surviving: $surviving, status: $status}' 2>/dev/null) || rc=$?
    if [[ ${rc} -ne 0 ]]; then
        log "ERROR" "assert_surviving_tests: result could not be built for ${test_path}"
        printf 'Error: assert_surviving_tests could not build its result for %s.\n' "${test_path}"
        return 1
    fi
    printf '%s\n' "${payload}"
}
