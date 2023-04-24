# Yaml.sh
[![Build Status](https://travis-ci.org/azohra/yaml.sh.svg?branch=master)](https://travis-ci.org/azohra/yaml.sh)

---

Yup. A YAML parser completely in bash. I can't believe it either.

> At the moment, we support [a subset of the yaml spec](https://docs.yaml.sh/#/supported_yml).

## Getting Started

Install it:
```bash
$ curl -s https://get.yaml.sh | sh
```

Then query with it:
```bash
$ ysh -f my.yml -q "path.to.awesomeness"
```

## Library use

If installed:
```bash
YSH_LIB=1;source /usr/local/bin/ysh
```

If you want the internet as your only dependency:
```bash
$ YSH_LIB=1;source /dev/stdin <<< "$(curl -s https://raw.githubusercontent.com/azohra/yaml.sh/v0.2.0/ysh)"
```

## Cook Book

```yaml
---
block_no: 0
level_one:
  level_two:
    key: value
    quoted: "value"
    simple_lists:
      - first
      - second item
      - "third item"
    object_lists:
      - {name: one, value: 1}
      - {name: "second thing", value: 2}
    expanded_lists:
      - name: one
        value: 1
      - name: two
        value: 2
      - name: "quoted thing"
        value: 9000
---
block_no: 1
```

### Read from a file:
```bash
ysh -f input.yaml -Q "block_no"
```

### Re-use an already transpiled file
```bash
file=$(ysh -f input.yaml)
ysh -T $file -Q "block_no"
```

### Query piped yaml
```bash
cat input.yaml | ysh -Q "block_no"
```

### Query for a value
```bash
ysh -f file.yaml -Q "block_no"
```

### Query from a stored sub structure
```bash
sub=$(ysh -f file.yaml -s "level_one")
ysh -T $sub -Q "level_two.key"
```

### Query i'th item from a simple list
```bash
ysh -f input.yaml -Q "level_one.level_two.simple_lists[1]"
```

### Query i'th item from a complex list
```bash
ysh -f input.yaml -Q "level_one.level_two.expanded_lists[1].name"
```

### Print value from each block
```bash
 #!/bin/bash
YSH_LIB=1; source /usr/local/bin/ysh

file=$(ysh -f input.yaml)
while [ -n "${file}" ]; do
  echo "Block Number:" $(ysh -T "${file}" -Q "block_no")
  file=$(ysh -T "${file}" -n)
done
```


## Flags

> **TIP:** 
> Most flags have an upper-case and lower case usage. Upper case
> flags denote the expectation of a value (empty otherwise),
> where lowercase flags are chainable queries that can also
> be passed back in with `-T`. In most cases queries will end
> with an uppercase flag.


`-f, --file        <file_name>`
> Read from a file.

`-T, --transpiled  <file_name>`
> Read from a pre-transpiled string.

`-q, --query       <query>`
> Generic query string. DOES NOT SUPPORT `[n]` NOTATION

`-Q, --query-val   <query>`
> Safe query. Guarentees the return is a value. DOES NOT SUPPORT `[n]` NOTATION

`-s, --sub         <query>`
> Query for a subtree of yaml. Guarentees results are a subtree and no values are returned.

`-l, --list        <query>`
> Query for a list.

`-L, --list        <query>`
> Query for a list of values. Guarentees results are all values.

`-c, --count       <query>`
> Query for a list and count the elements.

`-i, --index       <i>`
> Access i'th element from chained list query.

`-I, --index-val   <i>`
> Access i'th element from chained list query. Garentees result is a value.

`-t, --tops           `
> Return top level keys of structure.

`-n, --next           `
> Moves to next block

`-h, --help           `
> Show this help dialog.

For more complete usage and examples look at the [docs](https://docs.yaml.azohra.com).

---
Made with ❤️ by the developers at [azohra.com](https://azohra.com)
