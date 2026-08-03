# Operator manifest

This is the audited YAML-oriented surface for the current release. “Supported” means the listed forms are expected to agree with yq for documented inputs. “Focused” names a smaller portable contract. “Excluded” is a tested boundary—not a guess.

The evidence column names the focused test or release gate that owns each claim. The differential gate compares supported programs with mikefarah/yq v4.53.3; the parser-boundary gate makes exclusions fail closed.

| yq area | Status | YAML.sh forms or boundary | Evidence |
|---|---|---|---|
| Add | Supported | numbers, strings, arrays, maps, null; `+=` | `testExpressionArithmetic` |
| Alternative | Supported | `//` with lazy right-hand evaluation | `testExpressionAlternativeDefaults` |
| Anchor and alias | Focused | inspect, rename, assign, `explode`; graph identity retained | `testExpressionWritableYamlGraphMetadata` |
| Array to map | Supported | `array_to_map` with zero-based string keys | `testExpressionCapabilityClosure` |
| Assign and update | Supported | absolute, relative, and compound assignment across multiple paths | `testExpressionRelativeAndCompoundUpdates` |
| Boolean | Supported | `and`, `or`, `not`, `any`, `all`, `any_c`, `all_c` | `testExpressionBooleanFilters` |
| Collect into array | Supported | `[]`, `[expr]`, stream collection | `testExpressionArrayAndObjectConstruction` |
| Column | Supported | exact value and key columns in block and multiline flow YAML; generated nodes return 0 | `testExpressionNodeMetadata` |
| Comments | Supported | read/write head, line, and foot comments on values and keys; strict block-source edits | `testInplaceEditsPresentationMetadata` |
| Compare | Supported | `>`, `>=`, `<`, `<=` across scalar values | `testExpressionSelectAndComparisons` |
| Contains | Supported | portable string containment | `testExpressionSequenceAndStringHelpers` |
| Create object | Supported | literal and computed keys; stream values | `testExpressionArrayAndObjectConstruction` |
| Date and time | Excluded | no portable cross-platform date runtime | `testExpressionErrors` |
| Delete | Supported | `del`, `delpaths`, mapping and sequence targets | `testExpressionPathBasedUpdates` |
| Divide | Supported | numeric `/` and `/=`; zero is rejected | `testExpressionArithmetic` |
| Document index | Supported | `documentIndex` across streams and files | `testEvalAllAcrossFiles` |
| Encode and decode | Focused | `from_json`, `from_yaml`, `from_toml`, `from_ini`, `from_xml`, `from_props`, `from_csv`, `from_tsv`; matching `to_*` and shorthand forms; Base64, URI, shell | `testConfigurationFormatCodecs`, `testExpressionPortableUtilities` |
| Entries | Supported | `to_entries`, `from_entries`, `with_entries` | `testExpressionEntries` |
| Environment | Supported | `env`, `strenv`, `envsubst` options; disable switch | `testExpressionEnvironmentComposition` |
| Equals | Supported | structural `==` and `!=` | `testExpressionSelectAndComparisons` |
| Error | Supported | `error(message)` with short-circuiting guards | `testExpressionErrorGuards` |
| Eval | Focused | `eval(EXPR)` compiles YAML.sh expressions dynamically with node and depth ceilings | `testExpressionPortableUtilities` |
| File context | Supported | `filename`, `fileIndex`, multi-file and writable `eval-all` context | `testMultipleInputEvaluationAndMetadata` |
| Filter | Supported | arrays and mapping values | `testExpressionFocusedCollectionOperators` |
| First | Supported | first value and `first(condition)` | `testExpressionFocusedCollectionOperators` |
| Flatten | Focused | complete recursive flatten | `testExpressionProjectedCollectionsAndQuantifiers` |
| Group by | Supported | scalar grouping keys | `testExpressionProjectedCollectionsAndQuantifiers` |
| Has | Supported | mapping keys and positive/negative sequence indexes | `testExpressionCollectionHelpers` |
| Keys | Supported | mapping keys and sequence indexes | `testExpressionCollectionHelpers` |
| Kind | Supported | `scalar`, `map`, `seq` | `testExpressionKindAndType` |
| Length | Supported | strings, collections, null | `testExpressionCollectionHelpers` |
| Line | Supported | one-based source line, 0 for generated nodes | `testSourceLines` |
| Load | Focused | `load`, `load_str`, `load_base64`, `load_props`; byte ceiling and disable switch | `testExpressionPortableUtilities` |
| Min | Supported | `min`, `min_by` | `testExpressionProjectedCollectionsAndQuantifiers` |
| Map | Supported | `map`, `map_values`, mapping and sequence inputs | `testExpressionMapAndCommaStreams` |
| Max | Supported | `max`, `max_by` | `testExpressionProjectedCollectionsAndQuantifiers` |
| Modulo | Supported | numeric `%` and `%=` | `testExpressionArithmetic` |
| Multiply and merge | Supported | arithmetic, deep merge, `*+`, `*d`, `*?`, `*n` policies | `testExpressionMergeModifiers` |
| Omit | Supported | selected mapping keys or sequence indexes | `testExpressionFocusedCollectionOperators` |
| Parent | Supported | structural parent lookup | `testExpressionStructuralContextAndScopedUpdates` |
| Path | Supported | path lookup plus `setpath` and `delpaths` | `testExpressionPathBasedUpdates` |
| Pick | Supported | selected mapping keys or sequence indexes | `testExpressionFocusedCollectionOperators` |
| Pipe | Supported | streams, empty streams, precedence | `testExpressionIterationAndPipes` |
| Pivot | Focused | rectangular and ragged sequences; map rows | `testExpressionFocusedCollectionOperators` |
| Recursive descent | Supported | `..`, optional traversal, recursive selection and updates | `testExpressionRecursiveAndOptionalTraversal` |
| Reduce | Supported | `reduce`, `ireduce`, whole-stream eval-all folding | `testExpressionReduceAndDeepMerge` |
| Reverse | Supported | sequences | `testExpressionSequenceAndStringHelpers` |
| Root | Supported | graph/document root from any selected descendant | `testConfigurationPointersAndPatches` |
| Select | Supported | scalar and structural predicates | `testExpressionSelectAndComparisons` |
| Shuffle | Focused | portable Fisher–Yates shuffle; `--shuffle-seed` supplies reproducible runs | `testExpressionPortableUtilities` |
| Slice array | Supported | positive, negative, and open sequence slices | `testExpressionSlicesInterpolationAndRegex` |
| Sort | Supported | `sort`, `sort_by`, scalar ordering | `testExpressionProjectedCollectionsAndQuantifiers` |
| Sort keys | Supported | targeted and recursive `sort_keys(..)` | `testExpressionCapabilityClosure` |
| Split into documents | Focused | `split_doc` is explicit and idempotent; YAML streams are always document-separated | `testExpressionCapabilityClosure` |
| Strings | Focused | interpolation, string slices, case, `trim`, `to_string`, split/join, contains/prefix/suffix, POSIX `test`/`sub` | `testExpressionCapabilityClosure`, `testConfigurationPointersAndPatches` |
| Style | Focused | scalar and collection style read/write; source compiler decides preservation | `testExpressionBlockStylesAndOutputControls` |
| Subtract | Supported | numeric `-` and `-=` | `testExpressionArithmetic` |
| Tag | Supported | read/write core and custom tags | `testExpressionWritableYamlGraphMetadata` |
| To number | Supported | decimal integer and float strings | `testExpressionConversionAndKeyOrdering` |
| Traverse | Supported | keys, dynamic keys, indexes, splats, optional traversal | `testExpressionIterationAndPipes` |
| Union | Supported | comma streams | `testExpressionMapAndCommaStreams` |
| Unique | Supported | `unique`, `unique_by` | `testExpressionProjectedCollectionsAndQuantifiers` |
| Variables | Supported | value bindings, `ref`, dynamic lookup, reducer bindings | `testExpressionVariablesAndDynamicIndexes` |
| With | Supported | scoped updates over one or many matches | `testExpressionStructuralContextAndScopedUpdates` |

## CLI boundaries

YAML.sh reads YAML, JSON, TOML, INI, and XML and emits values or those semantic formats. Non-YAML input handles one semantic document at a time; source-aware `-i`, multi-file transactions, and presentation metadata remain YAML contracts. Date arithmetic, system execution, regex capture objects, and yq’s complete format-specific flag surface remain outside the contract.

## Configuration contracts

These are YAML.sh capabilities rather than yq operator-catalog rows.

| Contract | Status | Forms | Evidence |
|---|---|---|---|
| JSON Pointer | Supported | RFC 6901 lookup and escaping | `testConfigurationPointersAndPatches` |
| JSON Patch | Supported | RFC 6902 add/remove/replace/move/copy/test; deterministic diff generation | 108 pinned external assertions, source-edit and CLI tests |
| Merge Patch | Supported | RFC 7396 object merge and replacement semantics | `testConfigurationPointersAndPatches`, CLI tests |
| JSON Schema | Focused | documented 2020-12 validation vocabulary, local `$ref`, value-free path diagnostics | 701 pinned official assertions, `testConfigurationSchemaContracts` |
| TOML | Focused | decoder and encoder each pass the complete official valid 1.0 corpus; 462/474 invalid rejections | pinned `toml-test` v2.2.0 |
| INI | Focused | global scalars and nested dotted sections | `testConfigurationFormatCodecs` |
| XML | Focused | `+@attribute` / `+content` data profile; repeated elements; no DTD/custom entities | `testConfigurationFormatCodecs` |

For parser syntax rather than query operators, see [YAML support](supported_yml.md). For the practical comparison, see [yq compatibility](yq-compatibility.md).
