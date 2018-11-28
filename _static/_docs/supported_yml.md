Right now YAML.sh only supports a subset of the yaml spec. Below is a reference on what is currently supported:

```yaml
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
```