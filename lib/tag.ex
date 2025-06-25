defmodule Superls.Tag do
  @moduledoc "Tokenize a media path."
  alias Superls.{MergedIndex}

  @separators ~w(, _ - . * / ( \) : | " [ ] { }) ++ ["\t", "\n", " "]
  @banned_tags Superls.read_banned("banned_tags")
  @banned_ext Superls.read_banned("banned_file_ext")

  @doc "Tokenize `media_dir` volume and returns its `index`."
  @spec index_media_dir(media_dir :: Path.t()) :: index :: MergedIndex.tags()
  def index_media_dir(media_dir) do
    media_dir = Path.absname(media_dir)

    ls_r(media_dir)
    |> Flow.from_enumerable()
    |> Flow.flat_map(&index_media_dir_map(&1, media_dir))
    |> Flow.partition(key: {:elem, 0})
    |> Flow.reduce(fn -> %{} end, &index_media_dir_reduce(&1, &2))
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

  defp index_media_dir_map(fp, media_dir) do
    if banned_ext?(Path.extname(fp)) or File.dir?(fp) do
      []
    else
      rel_fp = Path.relative_to(fp, media_dir)
      # CHECK cache rel_fp_split entry
      [_ | rel_fp_split] = String.split(rel_fp, "/") |> Enum.reverse()

      rel_path_tokens =
        Enum.reduce(rel_fp_split, [], fn sub_path, acc ->
          tokenize_path(sub_path) ++ acc
        end)

      file = Path.basename(rel_fp)

      try do
        stat = File.stat!(fp, time: :posix)
        file_tokens = file |> tokenize_path()

        # remove token already taken by file_tokens
        rel_path_tokens = rel_path_tokens -- file_tokens

        (file_tokens ++ rel_path_tokens)
        |> List.flatten()
        |> Enum.map(
          &{&1,
           {rel_fp,
            %{
              size: stat.size,
              mtime: stat.mtime,
              atime: stat.atime,
              prefix_tag?: Enum.member?(rel_path_tokens, &1)
            }}}
        )
      rescue
        err in File.Error ->
          IO.puts("error reading #{fp}: #{inspect(err)} ... skip it.")
          []
      end
    end
  end

  defp tokenize_path(path) do
    path
    |> String.downcase()
    |> Accent.normalize()
    |> extract_tokens()
    |> Enum.reject(&banned_tag?/1)
  end

  defp index_media_dir_reduce({tag, {file, file_info}}, acc) do
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
end
