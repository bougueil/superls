defmodule Superls.Store do
  alias Superls.{Prompt, Tag}
  use Superls

  @moduledoc false
  @sep_path "-"

  def archive(media_path, store_name, confirm? \\ false) do
    if Prompt.prompt("Do archive in store '#{store_name}' ? [Y/n]", confirm?) do
      confirm? && IO.write("updating #{store_name} ...")

      store_cache_path = maybe_create_dir(store_name, confirm?)
      media_path = String.trim_trailing(media_path, "/")

      index =
        get_indexes_from_resource(media_path)
        |> :erlang.term_to_binary()
        |> :zlib.gzip()

      encoded_path = "#{store_cache_path}/#{encode_index_uri(media_path)}"
      :ok = File.write(encoded_path, index)
      confirm? && IO.puts("\rstore '#{store_name}' updated.")
      :ok
    else
      :aborted
    end
  end

  # returns indexes from the store
  def list_indexes(store_name) do
    path = cache_store_path(store_name)
    files = File.ls(path)

    case files do
      {:error, :enoent} ->
        []

      {:ok, files} ->
        Enum.map(files, fn fp ->
          stat = File.stat!(Path.join([path, fp]), time: :posix)
          {fp, datetime_human_str(stat.mtime), stat.size}
        end)
    end
  end

  def inspect_store(store_name) do
    tags = get_indexes_from_resource(store_name)
    files = Tag.files_index_from_tags(tags)

    %{
      num_tags: map_size(tags),
      num_files: length(files),
      files: files,
      most_frequent_100:
        Tag.tag_freq(tags)
        |> Enum.take(100)
        |> Enum.into(%{}, fn {tag, {freq, _}} -> {tag, freq} end),
      tags: tags
    }
  end

  def cache_path(),
    do: Application.fetch_env!(:superls, :stores_path)

  def maybe_create_cache_path(),
    do: maybe_create_dir("", false)

  def decode_index_uri(index_uri) when is_binary(index_uri) do
    String.split(index_uri, "-")
    |> hd()
    |> Base.decode32!()
  end

  def encode_index_uri(vol_path) when is_binary(vol_path),
    do: "#{Base.encode32(vol_path)}#{@sep_path}#{Path.basename(vol_path)}"

  defp get_indexes_path(store) do
    store_path = cache_store_path(store)
    for fname <- File.ls!(store_path), do: "#{store_path}/#{fname}"
  end

  defp cache_store_path(store),
    do: Path.expand("#{store}", cache_path())

  def list_stores() do
    cache_path = cache_path()
    for fname <- File.ls!(cache_path), do: fname
  end

  defp maybe_create_dir(store, confirm?) do
    store_path = cache_store_path(store)
    do_maybe_create_dir(File.exists?(store_path), store, store_path, confirm?)
  end

  defp do_maybe_create_dir(true, _store, store_path, _confirm?),
    do: store_path

  defp do_maybe_create_dir(false, store, store_path, confirm?) do
    if Prompt.prompt("Confirm create a new store '#{store}' [N/y] ?", confirm?) do
      :ok = File.mkdir_p!(store_path)
    end

    store_path
  end

  defp load_index(enc32_path) do
    [
      path: enc32_path,
      tokens:
        File.read!(enc32_path)
        |> :zlib.gunzip()
        |> :erlang.binary_to_term()
    ]
  end

  # return a merged index
  # either from existing indexes from store_name or from tokenizing the path
  def get_indexes_from_resource(store_name_or_path) do
    store_name_or_path = String.replace(store_name_or_path, "\\ ", "\ ")

    if File.dir?(store_name_or_path) do
      case String.split(store_name_or_path, cache_path()) do
        ["", index_path] ->
          [path, _] = String.split(index_path, "-")
          index_uri = Path.basename(path)
          _ = Base.decode32!(index_uri)
          load_index(store_name_or_path)[:tokens]

        [^store_name_or_path] ->
          # not an index path, create index from a volume path
          # tokenize the files names
          Tag.index_media_path(store_name_or_path)
      end
    else
      case String.split(store_name_or_path, cache_path()) do
        ["", index_path] ->
          [path, _] = String.split(index_path, "-")
          index_uri = Path.basename(path)
          _ = Base.decode32!(index_uri)
          load_index(store_name_or_path)[:tokens]

        [^store_name_or_path] ->
          get_indexes_from_store(store_name_or_path)
      end
    end
  end

  defp get_indexes_from_store(store_name) do
    get_indexes_path(store_name)
    |> load_tags()
    |> Tag.merge_indexes()
  end

  defp load_tags(stores) when is_list(stores) do
    Enum.reduce(stores, [], fn fname, acc ->
      tags = get_indexes_from_resource(fname)
      vol_path = get_vol_path_from_cache_path(fname)
      [{vol_path, tags} | acc]
    end)
  end

  defp get_vol_path_from_cache_path(fname) do
    case String.split(fname, "-") do
      [index22, _] ->
        index_name = Path.basename(index22)

        case Base.decode32(index_name) do
          :error ->
            # index_name is a regular file name
            throw("invalid filename #{fname}")

          {:ok, vol_path} ->
            vol_path
        end

      _ ->
        throw("invalid filename #{fname}")
    end
  end
end
