#! /usr/bin/env python

import sys
from pathlib import Path
from tree_sitter import Language, Parser, Query, QueryCursor
import argparse
import mkdocs_gen_files
import os
import re
import textwrap
import tree_sitter_nix as tsnix

NIX_LANGUAGE = Language(tsnix.language())
parser = Parser(NIX_LANGUAGE)

class NixFile:
    def __init__(self, path):
        self.path = path

    def to_markdown(self):
        document = Document(self.path)
        matches = document.query(
            Query(NIX_LANGUAGE, """
                (
                    (comment) @comment
                    .
                    (_) @element
                )
                """)
               )
        outs = []
        is_first = True
        for (_, match) in matches:
            outs = outs + [ TreeSitterNode(document, match).to_markdown(is_first = is_first) ]
            is_first = False

        return "\n\n".join(outs)

class Document:
    def __init__(self, path):
        self.path = path
        self.content = open(path, "rb").read()
        self.tree = parser.parse(self.content)
        self.lines = self.content.decode("utf-8").splitlines()

    def query(self, tree_sitter_query):
        query_cursor = QueryCursor(tree_sitter_query)
        return query_cursor.matches(self.tree.root_node)

    def extract(self, tree_sitter_node):
        start_point = tree_sitter_node.start_point
        end_point = tree_sitter_node.end_point
        first_line = self.lines[start_point.row][start_point.column:]
        lines_between = self.lines[start_point.row+1:end_point.row]
        last_line = self.lines[end_point.row][:end_point.column]
        joined_head = first_line
        joined_tail = "\n".join(lines_between + [last_line])
        joined_lines = "\n".join([joined_head, textwrap.dedent(joined_tail)])
        return textwrap.dedent(joined_lines)

class TreeSitterNode:
    def __init__(self, document, match):
        self.document = document
        self.match = match

    def strip_comment_markers(self, s):
        return re.sub(
                r'/\*(.*)\*/', r'\1',
                s,
                flags=re.MULTILINE | re.DOTALL
                ).strip()

    def to_markdown(self, is_first = False):
        if is_first:
               return "\n".join([
                    self.strip_comment_markers(
                        self.document.extract(self.match["comment"][0]))
                   ])
        else:
               return "\n".join([
                    self.strip_comment_markers(
                        self.document.extract(self.match["comment"][0])),
                    "```nix",
                    self.document.extract(self.match["element"][0]),
                    "```"])

def main():
    parser = argparse.ArgumentParser(
            prog="generate-references",
            description="Generate Markdown documents from Nix files",
            )
    parser.add_argument("path", default=".")
    parser.add_argument("-f", "--file", action="store_true")
    args = parser.parse_args()
    if args.file:
        print(NixFile(args.path).to_markdown())

if __name__ == "__main__":
    main()

if __name__ == "generate_references":
    root = Path("../")
    nav = mkdocs_gen_files.Nav()
    for path in sorted(root.rglob("*.nix")):
        module_path = path.relative_to(root).with_suffix("")
        doc_path = path.relative_to(root).with_suffix(".md")
        full_doc_path = Path("references", doc_path)

        parts = tuple(module_path.parts)
        nav[parts] = full_doc_path.as_posix()

        mkdocs_gen_files.open(full_doc_path, "w").write(NixFile(path).to_markdown())

        mkdocs_gen_files.set_edit_path(full_doc_path, path.relative_to(root))

    mkdocs_gen_files.open("SUMMARY.md", "w").writelines(nav.build_literate_nav())
