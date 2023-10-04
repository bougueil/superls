defmodule Superls do
  @moduledoc ~S"""
  A locally filenames parser and search engine CLI.

  ## Parsing
  `Superls` scans all filenames of a volume, extracts the tags from the filenames along other file attributes like size and builds an index for this volume.

  Volumes indexes are grouped, unless specified, in the `default` store.

  Stores are saved compressed in the user cache environment.

  The following command creates an index of /path/to/my/files in the `default` store :

  ```bash
  superls archive /path/to/my/files
  ```

  ## Search

  The command to search tags in the default store with the CLI is :

  ```bash
  superls search 
  ```
  `search` is a command line interpreter where tags can be typed even incomplete and a list of matched files is displayed.

  ## Other CLI commands
  Typing the following command will display help and stores information for `Superls` :

  ```bash
  superls 
  ```


  ## What is parsed ?

  `Superls` tokenizes filenames with the following delimiters :
  ```elixir
  ",", " ", "_", "-", ".", "*", "/", "(", ")", ":", "\t", "\n"
  ```
      
  Each collected file is grouped with its tags and its file attributes,
  see `ListerFile{}`struct for more details about file attributes.

  Tags and file attributes constitute the index keys.
  """

  @doc false
  def load_keys(file) do
    Stream.resource(
      fn -> File.open!(Application.app_dir(:superls, "priv/#{file}")) end,
      fn file ->
        case IO.read(file, :line) do
          data when is_binary(data) -> {[String.trim_trailing(data) |> String.downcase()], file}
          _ -> {:halt, file}
        end
      end,
      fn file -> File.close(file) end
    )
    |> Enum.to_list()
    |> Map.from_keys(nil)
  end

  @doc false
  def pp_sz(size) when size > 10 * 1024 * 1024 * 1024 do
    "#{div(size, 1024 * 1024 * 102) / 10} gB."
  end

  def pp_sz(size) when size > 10 * 1024 * 1024 do
    "#{div(size, 1024 * 102) / 10} mB."
  end

  def pp_sz(size) when size > 10 * 1024 do
    "#{div(size, 102) / 10} kB."
  end

  def pp_sz(size) do
    "#{size} B."
  end

  def build_indexed_list(list, len),
    do: do_build_indexed_list(list, {len, []})

  defp do_build_indexed_list([], {_, list}), do: list

  defp do_build_indexed_list([f | rest], {cnt, acc}),
    do: do_build_indexed_list(rest, {cnt - 1, [{f, cnt} | acc]})

  defmacro __using__(_) do
    quote do
      @default_store Application.compile_env!(:superls, :default_store_name)
      defp default_store(), do: @default_store

      defp date_human_str(posix_time),
        do: posix_time |> DateTime.from_unix!() |> DateTime.to_date() |> Date.to_string()

      defp datetime_human_str(posix_time),
        do: posix_time |> DateTime.from_unix!() |> DateTime.to_string()
    end
  end
end
