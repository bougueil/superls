defmodule Superls.Tag do
  @moduledoc "Tokenize a media path."
  alias Superls.{MergedIndex}

  @separators ~w(, _ - . * / ( \) : | " [ ] { }) ++ ["\t", "\n", " "]
  @banned_tags Superls.read_banned("banned_tags")
  @banned_ext Superls.read_banned("banned_file_ext")

  @doc "Tokenize `media_path` volume and returns its `index`."
  @spec index_media_path(media_path :: Path.t()) :: index :: MergedIndex.tags()
  def index_media_path(media_path) do
    media_path = Path.absname(media_path)

    ls_r(media_path)
    |> Flow.from_enumerable()
    |> Flow.flat_map(&index_media_path_map(&1, media_path))
    |> Flow.partition(key: {:elem, 0})
    |> Flow.reduce(fn -> %{} end, &index_media_path_reduce(&1, &2))
    |> Enum.into(%{})
  end

  @doc "extract all tokens including dates `10.16.16` and times `16:57` tokens."
  @spec extract_tokens(file_path :: Path.t()) :: tokens :: list(String.t())

  def extract_tokens(file_path) do
    elem_r = ~r/\d{2}\.\d{2}\.\d{2}|\d{4}-\d{2}-\d{2}|\d{1,2}:\d{1,2}:\d{1,2}|\d{1,2}:\d{1,2}/
    elem_date = ~r/\d{2}\.\d{2}\.\d{2}|\d{4}-\d{2}-\d{2}/

    # extract dates from file_path to form a token date
    elems = Regex.scan(elem_date, file_path)

    case Regex.split(elem_r, file_path) do
      list = [_ | _] ->
        [elems | Enum.map(list, &String.split(&1, @separators, trim: true))]
        |> List.flatten()

      _unexpected ->
        IO.puts("** malformed filename #{inspect(file_path, printable_limit: :infinity)}")
        ["error"]
    end
  end

  @doc """
  Search all tags in `merged_index` that match the `search_str`,

  Returns {`matches`, `query_tags`}.
  """
  @spec search_matching_tags(merged_index :: MergedIndex.t(), search_str :: String.t()) ::
          {matches ::
             list(
               {MergedIndex.volume(), list({MergedIndex.file_name(), MergedIndex.file_entry()})}
             ), query_tags :: list(MergedIndex.tag())}
  def search_matching_tags(merged_index, search_str) when is_binary(search_str) do
    keywords = to_keywords(search_str)

    {Enum.map(merged_index, fn {vol, tags} ->
       {
         vol,
         keywords
         |> Enum.reduce(nil, &match_partial(&1, &2, tags))
         |> MapSet.to_list()
       }
     end)
     |> Enum.reject(fn {_vol, fps} -> fps == [] end), keywords}
  end

  defp index_media_path_map(fp, path) do
    if banned_ext?(Path.extname(fp)) or File.dir?(fp) do
      []
    else
      rel_fp = Path.relative_to(fp, path)
      file = Path.basename(rel_fp)

      try do
        stat = File.stat!(fp, time: :posix)

        file
        |> String.downcase()
        |> Accent.normalize()
        |> extract_tokens()
        |> Enum.reject(&banned_tag?/1)
        |> Enum.map(
          &{&1,
           {file,
            %{size: stat.size, mtime: stat.mtime, dir: Path.dirname(rel_fp), atime: stat.atime}}}
        )
      rescue
        err in File.Error ->
          IO.puts("error reading #{fp}: #{inspect(err)} ... skip it.")
          []
      end
    end
  end

  defp index_media_path_reduce({tag, {file, file_info}}, acc) do
    case acc do
      %{^tag => files} ->
        if Map.has_key?(files, file) do
          acc
        else
          %{acc | tag => Map.put(files, file, file_info)}
        end

      %{} ->
        Map.put(acc, tag, %{file => file_info})

      other ->
        :erlang.error({:badmap, other}, [acc, tag, [file_info]])
    end
  end

  defp ls_r(path), do: Path.wildcard(Path.join(path, "**"))

  defp banned_ext?(ext), do: Map.has_key?(@banned_ext, ext)

  defp banned_tag?(tag), do: Map.has_key?(@banned_tags, tag)

  defp to_keywords(search_str) do
    search_str
    |> String.downcase()
    |> Accent.normalize()
    |> extract_tokens()
    |> Enum.reject(&(String.length(&1) == 1))
    |> Enum.uniq()
  end

  defp match_partial(keywd, acc0, tags) do
    keywd_files =
      Enum.filter(tags, &String.contains?(elem(&1, 0), keywd))
      |> Enum.flat_map(&Map.to_list(elem(&1, 1)))
      |> MapSet.new()

    if acc0 do
      MapSet.intersection(acc0, keywd_files)
    else
      keywd_files
    end
  end
end
