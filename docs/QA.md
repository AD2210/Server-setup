# QA et linters

Le runner QA contrôle les scripts Bash et les formats présents dans le dépôt.

```bash
qa/lint.sh
```

Contrôles exécutés :

* `bash -n` sur tous les scripts Bash ;
* ShellCheck ;
* shfmt ;
* Markdownlint pour la documentation Markdown ;
* Taplo pour les fichiers TOML ;
* Yamllint pour les fichiers YAML ;
* `caddy validate` sur le template Caddy.

Sur un poste où les outils ne sont pas encore installés, le mode de diagnostic
suivant exécute les contrôles disponibles sans bloquer :

```bash
QA_ALLOW_MISSING_TOOLS=true qa/lint.sh
```

La CI doit utiliser le mode par défaut afin qu'un outil manquant ou une erreur
de lint bloque la validation.
