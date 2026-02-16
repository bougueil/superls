# superls
[![CI](https://github.com/bougueil/superls/actions/workflows/ci.yml/badge.svg)](https://github.com/bougueil/superls/actions/workflows/ci.yml)

<!-- MDOC !-->
A multi volumes files indexer and search engine CLI (elixir, Linux).

### Indexing
  `superls` analyzes the filenames of a volume, extracts the filename tags and other file attributes such as size, date and builds an index for the volume.

  Unless an index name is given, all volumes are stored in the `default` index.

  Indexes are saved compressed and optionally password encrypted.

  The following command creates an index of `/path/to/my/volume_files` in the `default` index :

```bash
superls index `/path/to/my/volume_files`
```
or on index `myindex` with stdin password encryption :

```bash
superls index `/path/to/my/volume_files` myindex -p
```

### Searching tags

Search tags with the `default` index :

```bash
superls
```

Search with index myindex :

```bash
superls myindex
```

An interactive shell asks for commands like query by a list of tags, a string separated by space. A tag can be incomplete.

The result is a list of matched files with associated size and path.

### Other CLI commands
  For help, getting superls commands ...  :

```bash
superls help
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
`superls` is built with a static secret key that can be customized with the `SLS_SECRET` environment variable.
The secret key combined with the `-p` password protect the index content.
```
mix setup
asdf reshim elixir # if using asdf

or with a custom secret key (passwords encrypted) :
SLS_SECRET="myBuiltSecret" mix setup
asdf reshim elixir # if using asdf
```

## run
```
superls
```
