We do not provide more code features than mkdocs-material does out of the box
at this point.
For more information, please refer to the
[mkdocs-material code blocks documentation](https://squidfunk.github.io/mkdocs-material/reference/code-blocks/).

## Configuration

In general, you want to enable the following configuration lines:

```yaml
markdown_extensions:
  - pymdownx.highlight:
      anchor_linenums: true
      line_spans: __span
      pygments_lang_class: true
  - pymdownx.inlinehilite
  - pymdownx.snippets
  - pymdownx.superfences

theme:
  features:
    - content.code.copy
    - content.code.select
    - content.code.annotate
```

## Usage

Click here to see the [list of supported programming languages for code highlighting](https://pygments.org/docs/lexers/).

This code creates a code snippet with line numbers and annotations:

````markdown title="Code Example with Line Numbers and Annotation"
```py title="bubble_sort.py" linenums="1"
def bubble_sort(items):
    for i in range(len(items)):
        for j in range(len(items) - 1 - i): # (1)
            if items[j] > items[j + 1]:
                items[j], items[j + 1] = items[j + 1], items[j]
```

1.  :man_raising_hand: I'm a code annotation! I can contain `code`, **formatted
    text**, images, ... basically anything that can be written in Markdown.
````

Result:

```py title="bubble_sort.py" linenums="1"
def bubble_sort(items):
    for i in range(len(items)):
        for j in range(len(items) - 1 - i): # (1)
            if items[j] > items[j + 1]:
                items[j], items[j + 1] = items[j + 1], items[j]
```

1.  :man_raising_hand: I'm a code annotation! I can contain `code`, **formatted
    text**, images, ... basically anything that can be written in Markdown.
