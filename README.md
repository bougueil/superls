# superls
[![CI](https://github.com/bougueil/superls/actions/workflows/ci.yml/badge.svg)](https://github.com/bougueil/superls/actions/workflows/ci.yml)

<!-- MDOC !-->

A multi volumes files indexer and search engine elixir CLI (Linux).

### Indexing
  `Superls` scans all filenames of a volume, extracts the tags from the filenames along other file attributes like size and builds an index for this volume.

  Volumes indexes are grouped, unless specified, in the `default` store.

  Stores are saved compressed in the user cache environment.

  The following command creates an index of /path/to/my/files in the `default` store :

```bash
superls archive /path/to/my/files
```

### Search

The command to search tags in the default store with the CLI is :

```bash
superls search
```
Tags are entered separated by space, tags can be incomplete.
The result is a list of matched files.

### Other CLI commands
  For help, getting stores details ...  :

```bash
superls
```


### What is parsed ?

`Superls` tokenizes filenames with the following delimiters :
```elixir
  ",", " ", "_", "-", ".", "*", "/", "(", ")", ":", "\t", "\n"
```

Each collected file is grouped with its tags and its file attributes,
see `ListerFile{}`struct for more details about file attributes.

Tags and file attributes constitute the index entry.

### Advanced search
#### jaro search
#### by size search

<!-- MDOC !-->

## build
```
mix deps.get
mix do escript.build + escript.install
```

## run
```
superls
```
