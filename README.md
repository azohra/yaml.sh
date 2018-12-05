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
$ YSH_LIB=1;source /dev/stdin <<< "$(curl -s https://raw.githubusercontent.com/azohra/yaml.sh/master/y.sh)"
```

## Flags

`-f, --file        <file_name>`
> Read from a file.

`-T, --transpiled  <file_name>`
> Read from a pre-transpiled string.

`-q, --query       <query>`
> Generic query string.

`-Q, --query-val   <query>`
> Safe query. Guarentees the return is a value.

`-s, --sub         <query>`
> Query for a subtree of yaml. Guarentees results are a subtree and no values are returned.

`-l, --list        <query>`
> Query for a list.

`-c, --count       <query>`
> Query for a list and count the elements.

`-i, --index       <i>`
> Access i'th element from chained list query.

`-I, --index-val   <i>`
> Access i'th element from chained list query. Garentees result is a value.

`-t, --tops           `
> Return top level keys of structure.

`-h, --help           `
> Show this help dialog.

For more complete usage and examples look at the [docs](https://docs.yaml.sh).

---
Made with ❤️ by the developers at [azohra.com](https://azohra.com)
