# Operator manifest

This is the audited YAML-oriented surface for v1.14. “Supported” means the listed forms are expected to agree with yq for documented inputs. “Focused” names a smaller portable contract. “Excluded” is deliberate, tested rejection—not a maybe.

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
| Column | Focused | value and key columns for block nodes; generated nodes return 0 | `testExpressionCapabilityClosure` |
| Comments | Focused | read/write line comments; head and foot comments are retained but not addressable | `testExpressionPresentationMetadata` |
| Compare | Supported | `>`, `>=`, `<`, `<=` across scalar values | `testExpressionSelectAndComparisons` |
| Contains | Supported | portable string containment | `testExpressionSequenceAndStringHelpers` |
| Create object | Supported | literal and computed keys; stream values | `testExpressionArrayAndObjectConstruction` |
| Date and time | Excluded | no portable cross-platform date runtime | `testExpressionErrors` |
| Delete | Supported | `del`, `delpaths`, mapping and sequence targets | `testExpressionPathBasedUpdates` |
| Divide | Supported | numeric `/` and `/=`; zero is rejected | `testExpressionArithmetic` |
| Document index | Supported | `documentIndex` across streams and files | `testEvalAllAcrossFiles` |
| Encode and decode | Excluded | no JSON/Base64/URI/YAML string codecs | `testExpressionErrors` |
| Entries | Supported | `to_entries`, `from_entries`, `with_entries` | `testExpressionEntries` |
| Environment | Supported | `env`, `strenv`, `envsubst` options; disable switch | `testExpressionEnvironmentComposition` |
| Equals | Supported | structural `==` and `!=` | `testExpressionSelectAndComparisons` |
| Error | Supported | `error(message)` with short-circuiting guards | `testExpressionErrorGuards` |
| Eval | Excluded | no dynamic code evaluation | `testExpressionErrors` |
| File context | Focused | `filename`, `fileIndex`; no file-loading operators | `testMultipleInputEvaluationAndMetadata` |
| Filter | Supported | arrays and mapping values | `testExpressionFocusedCollectionOperators` |
| First | Supported | first value and `first(condition)` | `testExpressionFocusedCollectionOperators` |
| Flatten | Focused | complete recursive flatten | `testExpressionProjectedCollectionsAndQuantifiers` |
| Group by | Supported | scalar grouping keys | `testExpressionProjectedCollectionsAndQuantifiers` |
| Has | Supported | mapping keys and positive/negative sequence indexes | `testExpressionCollectionHelpers` |
| Keys | Supported | mapping keys and sequence indexes | `testExpressionCollectionHelpers` |
| Kind | Supported | `scalar`, `map`, `seq` | `testExpressionKindAndType` |
| Length | Supported | strings, collections, null | `testExpressionCollectionHelpers` |
| Line | Supported | one-based source line, 0 for generated nodes | `testSourceLines` |
| Load | Excluded | queries cannot read neighboring files | `testExpressionErrors` |
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
| Select | Supported | scalar and structural predicates | `testExpressionSelectAndComparisons` |
| Shuffle | Excluded | randomized output has no portable deterministic contract | `testExpressionErrors` |
| Slice array | Supported | positive, negative, and open sequence slices | `testExpressionSlicesInterpolationAndRegex` |
| Sort | Supported | `sort`, `sort_by`, scalar ordering | `testExpressionProjectedCollectionsAndQuantifiers` |
| Sort keys | Supported | targeted and recursive `sort_keys(..)` | `testExpressionCapabilityClosure` |
| Split into documents | Focused | `split_doc` is explicit and idempotent; YAML streams are always document-separated | `testExpressionCapabilityClosure` |
| Strings | Focused | interpolation, case, `trim`, `to_string`, split/join, contains/prefix/suffix, POSIX `test`/`sub` | `testExpressionCapabilityClosure` |
| Style | Focused | scalar and collection style read/write; source compiler decides preservation | `testExpressionBlockStylesAndOutputControls` |
| Subtract | Supported | numeric `-` and `-=` | `testExpressionArithmetic` |
| Tag | Supported | read/write core and custom tags | `testExpressionWritableYamlGraphMetadata` |
| To number | Supported | decimal integer and float strings | `testExpressionConversionAndKeyOrdering` |
| Traverse | Supported | keys, dynamic keys, indexes, splats, optional traversal | `testExpressionIterationAndPipes` |
| Union | Supported | comma streams | `testExpressionMapAndCommaStreams` |
| Unique | Supported | `unique`, `unique_by` | `testExpressionProjectedCollectionsAndQuantifiers` |
| Variables | Supported | value bindings, dynamic lookup, reducer bindings | `testExpressionVariablesAndDynamicIndexes` |
| With | Supported | scoped updates over one or many matches | `testExpressionStructuralContextAndScopedUpdates` |

## CLI boundaries

YAML.sh accepts YAML input and emits values, JSON, or YAML. Non-YAML codecs, dynamic evaluation, external loads, system execution, date arithmetic, regex capture objects, random shuffle, and yq’s format-specific flags remain outside the product. Those exclusions keep one auditable POSIX shell/AWK file honest.

For parser syntax rather than query operators, see [YAML support](supported_yml.md). For the practical comparison, see [yq compatibility](yq-compatibility.md).
