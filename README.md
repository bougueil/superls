# superls
[![CI](https://github.com/bougueil/superls/actions/workflows/ci.yml/badge.svg)](https://github.com/bougueil/superls/actions/workflows/ci.yml)

<!-- MDOC !-->

A multi volumes files indexer and search engine elixir CLI (Linux).

### Indexing
  `superls` analyzes the filenames of a volume, extracts the filename tags and other file attributes such as size, and builds an index for the volume.

  Unless a store name is given (-s), volume indexes are grouped together in the `default` store.

  Stores are saved compressed and optionally password encrypted.

  The following command creates an index of /path/to/my/files in the `default` store :

```bash
superls archive /path/to/my/files
```
or on store `mystore` with password encryption :

```bash
superls archive /path/to/my/files -s mystore -p
```

### Search

The command to search tags in the `default` store with the CLI is :

```bash
superls search
```
An interactive shell asks for commands like query by a list of tags separated by space, a tag can be incomplete.<br>
The result is a list of matched files.

### Other CLI commands
  For help, getting stores details ...  :

```bash
superls
```


### What is parsed ?

`superls` tokenizes filenames with the following delimiters :
```elixir
  ",", " ", "_", "-", ".", "*", "/", "(", ")", ":", "\t", "\n"
```

Collected tags are grouped with some files attributes like the file size.<br>
See `ListerFile{}`struct for more details about collected data.

Tags and file attributes constitute the index entry for the file.

### Discarding files and tags from indexing

Files with an extension present in `./priv/banned_file_ext` are not indexed.

Tags present in `./priv/banned_tags` are not indexed.

### Advanced search
#### jaro search
#### by size search

<!-- MDOC !-->

## build
sls is built with a secret key that can be customized with the `SLS_SECRET` environment variable.
```
mix deps.get
mix do escript.build + escript.install

or with a custom secret key:
mix deps.get
SLS_SECRET="myBuiltSecret" mix do escript.build + escript.install
```

## run
```
superls
```
