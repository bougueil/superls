defmodule Superls.Tag do
  alias Superls.{ListerFile, MatchDate, MatchJaro, MatchSize}

  @moduledoc false

  @separators [",", " ", "_", "-", ".", "*", "/", "(", ")", ":", "\t", "\n"]

  @banned_tags Superls.load_keys("banned_tags")
  @banned_ext Superls.load_keys("banned_file_ext")

  # Tokenize `media_path` volume and returns the index.
  def index_media_path(media_path) do
    media_path = Path.absname(media_path)
    prefix_len = byte_size(media_path) + 1

    ls_r(media_path)
    |> Flow.from_enumerable()
    |> Flow.flat_map(&index_media_path_map(&1, media_path, prefix_len))
    |> Flow.partition(key: {:elem, 0})
    |> Flow.reduce(fn -> %{} end, &index_media_path_reduce(&1, &2))
    |> Enum.into(%{})
  end

  defp index_media_path_map(file, path, prefix_len) do
    if banned_ext?(Path.extname(file)) or File.dir?(file) do
      []
    else
      <<_prfx::binary-size(prefix_len), fp::binary>> = file

      try do
        stat = File.stat!(Path.join([path, fp]), time: :posix)

        fp
        |> String.downcase()
        |> Accent.normalize()
        |> extract_tokens()
        |> Enum.reject(&banned_tag?/1)
        |> Enum.map(
          &{&1, %ListerFile{name: fp, size: stat.size, mtime: stat.mtime, atime: stat.atime}}
        )
      rescue
        err ->
          IO.puts(:stderr, "error reading #{path}/#{fp}: #{inspect(err)} ... skip it.")
          []
      end
    end
  end

  defp index_media_path_reduce({tag, lister_file}, acc) do
    case acc do
      %{^tag => list} ->
        if :lists.member(lister_file, list) do
          acc
        else
          %{acc | tag => [lister_file | list]}
        end

      %{} ->
        Map.put(acc, tag, [lister_file])

      other ->
        :erlang.error({:badmap, other}, [acc, tag, [lister_file]])
    end
  end

  @doc """
  From the `merged_indexes` returns a map of files with their tags.
  """
  def files_index_from_tags(merged_index) when is_map(merged_index) do
    merged_index
    |> Flow.from_enumerable()
    |> Flow.flat_map(fn {_tag, files} -> files end)
    |> Flow.partition()
    |> Flow.reduce(fn -> %{} end, fn file_vol = {%ListerFile{name: name}, _vol}, acc ->
      tags =
        name
        |> String.downcase()
        |> extract_tokens()
        |> Enum.reject(&banned_tag?/1)

      if(tags != [], do: Map.put(acc, file_vol, tags), else: acc)
    end)
    |> Enum.to_list()
  end

  # extract all tokens including "10.16.16" tokens
  defp extract_tokens(file_path) do
    date_r =
      ~r/\b\d{2}.\d{2}.\d{2}|\b\d{4}-\d{2}-\d{2}/

    # extract date from file_path
    case Regex.run(date_r, file_path, capture: :first) do
      nil ->
        # no date in file_path
        String.split(file_path, @separators, trim: true)

      [date] ->
        case Regex.split(date_r, file_path) do
          list = [_ | _] ->
            [date | Enum.map(list, &String.split(&1, @separators, trim: true))]
            |> List.flatten()

          _unexpected ->
            IO.puts("** malformed filename #{inspect(file_path, printable_limit: :infinity)}")
            ["error"]
        end
    end
  end

  @doc """
  Search all tags in `merged_index` that match the `search_str`.
  """
  def search_matching_tags(merged_index, search_str) when is_binary(search_str) do
    search_str
    |> to_tags_list()
    |> Enum.map(&match_partial(&1, merged_index))
    |> Enum.reduce(&MapSet.intersection(&1, &2))
    |> MapSet.to_list()
  end

  defp ls_r(path),
    do: Path.wildcard(Path.join(path, "**"))

  defp banned_ext?(ext),
    do: Map.has_key?(@banned_ext, ext)

  defp banned_tag?(tag),
    do: Map.has_key?(@banned_tags, tag)

  defp to_tags_list(search_str) do
    search_str
    |> String.downcase()
    |> Accent.normalize()
    |> String.split(@separators, trim: true)
    |> Enum.reject(&(String.length(&1) == 1))
  end

  # a user_tag matches partially the dirs_tags index
  defp match_partial(search_tags, merged_index) do
    Enum.flat_map(merged_index, fn {tag, file_vol_list} ->
      if(String.contains?(tag, search_tags), do: [file_vol_list], else: [])
    end)
    |> List.flatten()
    |> MapSet.new()
  end

  @doc """
  sort tags with their appearance
  """
  def tag_freq(merged_index) do
    Enum.reduce(merged_index, %{}, fn {tag, files}, acc0 ->
      from_same_volume? = Enum.unzip(files) |> elem(1) |> all_equal?()
      Map.put(acc0, tag, {length(files), from_same_volume?})
    end)
    |> Enum.sort_by(fn {tag, {num_files, _samev?}} -> {num_files, tag} end, &>/2)
  end

  def all_equal?([_]),
    do: true

  def all_equal?([head | rest]) do
    Enum.reduce_while(rest, nil, fn
      ^head, _ -> {:cont, true}
      _, _ -> {:halt, false}
    end)
  end

  @doc """
  merge all indexes `volumes_tags` in one index.

  Add the volume path to each file
  """
  def merge_indexes(volumes_tags) when is_list(volumes_tags),
    do: Enum.reduce(volumes_tags, %{}, &aggregate_vol_tags(&1, &2))

  defp aggregate_vol_tags({vol_path, tags}, store) do
    Enum.reduce(tags, store, fn {tag, files}, acc ->
      files =
        for file <- files,
            do: {file, vol_path}

      Map.get_and_update(acc, tag, fn
        nil -> {nil, files}
        prevfiles -> {prevfiles, Enum.concat(prevfiles, files)}
      end)
      |> elem(1)
    end)
  end

  def search_duplicated_tags(merged_index) do
    files_index_from_tags(merged_index)
    |> MatchJaro.best_jaro()
  end

  def search_similar_size(merged_index) do
    files_index_from_tags(merged_index)
    |> MatchSize.best_size()
  end

  def search_oldness(merged_index, cmd, nentries) do
    files_index_from_tags(merged_index)
    |> MatchDate.search_oldness(cmd, nentries)
  end

  def search_bydate(merged_index, cmd, date, ndays) do
    files_index_from_tags(merged_index)
    |> MatchDate.search_bydate(cmd, date, ndays)
  end
end
