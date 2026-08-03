# Documents & file edits

YAML.sh reads YAML streams, edits files without losing unrelated source text, and can prepare several file changes before writing any of them.

## YAML document streams

Documents in one stream may be separated by `---` and terminated by `...`. YAML.sh selects the first document by default. Select another with its zero-based index:

```sh
ysh --document 1 '.environment' stream.yml
# production
```

The short form is `-d`. Use `--all-documents` to evaluate the expression independently against every document:

```sh
ysh --all-documents '[documentIndex, .metadata.name]' stream.yml
```

Anchors and tag handles are scoped to one document. Empty explicit documents are represented as null rather than disappearing.

`split_doc` marks every selected result as a separate YAML document:

```sh
ysh -o=yaml '.services[] | split_doc' config.yml
```

Multiple YAML results are always separated safely, so applying `split_doc` more than once does not change the output.

## Preview and write an edit

Use the same expression to inspect, check, or write a change:

```sh
ysh --diff '.image.tag = "stable"' deploy.yml
ysh --check '.image.tag = "stable"' deploy.yml
ysh -i '.image.tag = "stable"' deploy.yml
```

`--diff` prints the exact candidate without writing. `--check` stays quiet and exits `0` when no change is needed, `1` when the file would change, and `2` for invalid input or an invalid query. `-i` writes the candidate.

Evaluation finishes before YAML.sh prepares an edit. For supported changes, it rewrites only the source spans it owns:

| Edit | What stays intact |
| --- | --- |
| Scalar replacement | Surrounding spacing, quote style, properties, and line comment |
| Flow mapping or sequence | Source outside the changed collection |
| Literal or folded scalar | Block style, indentation, and header comment |
| Head or foot comment | Source outside the owned full-line comment block |
| Block insert, append, delete, or reorder | Unchanged records and their attached comments |
| Alias or merged value | Alias and merge occurrences; the owned anchor source is updated |

Changed flow collections use stable formatting inside their span. A change without a safe source plan falls back to stable semantic YAML.

Make preservation mandatory with `--preserve-only`:

```sh
ysh --preserve-only --diff '.items += ["release"]' config.yml
ysh --preserve-only -i '.items += ["release"]' config.yml
```

If the edit would require regeneration, YAML.sh exits with an error before producing or writing a candidate.

## Edit several files

One command can prepare the same change for several files:

```sh
ysh --check '.image.tag = "stable"' services/*.yml
ysh --diff '.image.tag = "stable"' services/*.yml
ysh -i '.image.tag = "stable"' services/*.yml
```

The query is compiled once. Every file is parsed from a snapshot, and every changed candidate is prepared before the first replacement. Files with no changes are left untouched.

Before writing, YAML.sh verifies that live files still match the snapshots it evaluated. If a file changed during the run, the operation stops instead of overwriting it. Symlinks, duplicate paths, and names containing newlines are refused. Permissions are preserved.

Each file replacement is an atomic same-directory rename. A multi-file batch is not one globally atomic filesystem operation: if a later replacement fails or the process is interrupted, YAML.sh restores files already changed from the snapshots it read. Normal backups and version control still matter.

## Share data across files

Use `eval-all` when documents need to exchange values. `filename`, `fileIndex`, and `documentIndex` identify each input:

```sh
query='select(fileIndex == 0).version as $version | select(fileIndex > 0).release.version = $version'
ysh eval-all --check "$query" release.yml services/*.yml
ysh eval-all -i "$query" release.yml services/*.yml
```

Every source participates in the snapshot check; only mutated sources are replaced.

To fold the complete input stream into one document:

```sh
ysh eval-all '. as $document ireduce ({}; . * $document)' defaults.yml region.yml secrets.yml
```
