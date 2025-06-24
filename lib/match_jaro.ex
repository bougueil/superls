defmodule Superls.MatchJaro do
  use Superls

  alias Superls.{StrFmt}
  @moduledoc false
  # group files by similar tags

  @jaro_threshold Application.compile_env!(:superls, :jaro_threshold)
  def size(result), do: map_size(result)

  def to_string(result) do
    for {dist, similar_files} <- result do
      [
        {"distance: #{dist}", :str, [:light_magenta, :reverse]},
        {"_", :padl, [:light_magenta]},
        "\n",
        for {{file1, vol1}, {file2, vol2}} <- similar_files do
          [
            {Path.basename(file1), :str, [:bright]},
            "  ",
            {Path.join(vol1, Path.dirname(file1)), :scr, []},
            "\n",
            {Path.basename(file2), :str, [:bright]},
            "  ",
            {Path.join(vol2, Path.dirname(file2)), :scr, []},
            "\n",
            "\n"
          ]
        end
      ]
      |> StrFmt.to_string()
    end
  end

  @spec best_jaro([tuple()]) :: %{float() => [{tuple(), tuple()}]}
  def best_jaro(files) do
    {len, files} =
      files
      |> build_f_mapset([])
      |> Superls.build_indexed_list()

    files
    |> Flow.from_enumerable()
    |> Flow.flat_map(fn {{file_vol, tags}, start_compare} ->
      jaro_per_file_mapset(Enum.slice(files, start_compare..len), file_vol, tags, [])
    end)
    |> Flow.partition(key: {:elem, 0})
    |> Flow.reduce(fn -> %{} end, &best_jaro_reduce/2)
    |> Enum.into(%{})
  end

  defp best_jaro_reduce({d, similar_files_tuple}, acc) do
    case acc do
      %{^d => list} ->
        if :lists.member(similar_files_tuple, list) do
          acc
        else
          %{acc | d => [similar_files_tuple | list]}
        end

      %{} ->
        Map.put(acc, d, [similar_files_tuple])

      other ->
        :erlang.error({:badmap, other}, [acc, d, [similar_files_tuple]])
    end
  end

  defp build_f_mapset([], list), do: list

  defp build_f_mapset([{fp, fp_info, vol} | rest], acc) do
    # build_f_mapset(rest, [{{fp, vol, fp_info.dir}, MapSet.new(fp_info.tags)} | acc])
    build_f_mapset(rest, [{{fp, vol}, MapSet.new(fp_info.tags)} | acc])
  end

  defp jaro_per_file_mapset([], _file_vol, _tags, acc),
    do: acc

  defp jaro_per_file_mapset([{{file2_vol, set2}, _} | rest], file_vol, set1, acc) do
    d = MapSet.size(MapSet.intersection(set1, set2)) / MapSet.size(MapSet.union(set1, set2))

    if d >= @jaro_threshold do
      jaro_per_file_mapset(rest, file_vol, set1, [
        {d, List.to_tuple(Enum.sort([file_vol, file2_vol]))} | acc
      ])
    else
      jaro_per_file_mapset(rest, file_vol, set1, acc)
    end
  end
end
