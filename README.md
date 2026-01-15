# superls
[![CI](https://github.com/bougueil/superls/actions/workflows/ci.yml/badge.svg)](https://github.com/bougueil/superls/actions/workflows/ci.yml)

<!-- MDOC !-->
A multi volumes files indexer and search engine CLI (elixir, Linux).

### Indexing
  `superls` analyzes the filenames of a volume, extracts the filename tags and other file attributes such as size, date and builds an index for the volume.

  Unless a store name is given (-s), all volume indexes are stored in the `default` store folder.

  Stores are saved compressed and optionally password encrypted.

  The following command creates an index of /path/to/my/volume_files in the `default` store :

```bash
superls archive /path/to/my/volume_files
```
or on store `mystore` with stdin password encryption :

```bash
superls archive /path/to/my/volume_files -s mystore -p
```

### Search

The command to search tags in the `default` store with the CLI is :

```bash
superls search
```
An interactive shell asks for commands like query by a list of tags, a string separated by space. A tag can be incomplete.<br>
The result is a list of matched files.

### Other CLI commands
  For help, getting stores commands ...  :

```bash
superls
```


### What is parsed ?

`superls` tokenizes the filenames with the following delimiters :
```elixir
  ",",  "_",  "-",  ".",  "*",  "/",
  "(",  ")",  ":",  "|",  "\"",  "[",  "]",
  "{",  "}",  "\t",  "\n",  " 
  ```

Collected tags are grouped with some files attributes, currently: size, mtime, atime.<br>

Tags and file attributes constitute the index entry for the file.

### Discarding files and tags from indexing

Files with an extension present in `./priv/banned_file_ext` are not indexed.

Tags present in `./priv/banned_tags` are not indexed.

### Advanced search
#### jaro search
#### by size search

<!-- MDOC !-->

## build
sls is built with a static secret key that can be customized with the `SLS_SECRET` environment variable.
The secret key combined with the `-p` password protect the index content.
```
mix deps.get
mix do escript.build + escript.install
asdf reshim elixir # if using asdf

or with a custom secret key:
mix deps.get
SLS_SECRET="myBuiltSecret" mix do escript.build + escript.install
asdf reshim elixir # if using asdf
```

## run
```
superls
```
