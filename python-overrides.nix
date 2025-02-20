self: super: {
  # TODO: upstream
  mkdocs-get-deps = super.mkdocs-get-deps.overridePythonAttrs (old: {
    buildInputs = (old.buildInputs or [ ]) ++ [ self.hatchling ];
  });
  mkdocs-glightbox = super.mkdocs-glightbox.overridePythonAttrs (old: {
    buildInputs = (old.buildInputs or [ ]) ++ [ self.setuptools ];
  });
  mkdocs-drawio-exporter = super.mkdocs-drawio-exporter.overridePythonAttrs (old: {
    buildInputs = (old.buildInputs or [ ]) ++ [ self.poetry-core ];
  });
  mkdocs-redirects = super.mkdocs-redirects.overridePythonAttrs (old: {
    buildInputs = (old.buildInputs or [ ]) ++ [ self.hatchling ];
  });
  plantuml-markdown = super.plantuml-markdown.overridePythonAttrs (old: {
    buildInputs = (old.buildInputs or [ ]) ++ [ self.setuptools ];
    postPatch = ''
      touch test-requirements.txt
    '';
  });
}
