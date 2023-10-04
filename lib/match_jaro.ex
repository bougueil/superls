defmodule Superls.MatchJaro do
  use Superls

  @moduledoc false
  # group files by similar tags 

  @jaro_threshold Application.compile_env!(:superls, :jaro_threshold)
  def pretty_print_result(result) do
    for {d, similar_files} <- result do
      IO.write(
        IO.ANSI.light_magenta() <>
          IO.ANSI.reverse() <>
          "distance: #{d}" <>
          IO.ANSI.reverse_off() <>
          "________________________________________________________________" <>
          IO.ANSI.reset()
      )

      for {{file1, vol1}, {file2, vol2}} <- similar_files do
        #  " - " <>
        #  " - " <>
        ("\n" <>
           IO.ANSI.bright() <>
           Path.basename(file1.name) <>
           IO.ANSI.reset() <>
           "\t" <>
           Superls.pp_sz(file1.size) <>
           "\t" <>
           vol1 <>
           "/" <>
           Path.dirname(file1.name) <>
           IO.ANSI.reset() <>
           "\n" <>
           IO.ANSI.bright() <>
           Path.basename(file2.name) <>
           IO.ANSI.reset() <>
           "\t" <>
           Superls.pp_sz(file2.size) <>
           "\t" <>
           vol2 <> "/" <> Path.dirname(file2.name) <> IO.ANSI.reset())
        |> IO.puts()
      end
    end
  end

  def best_jaro(files) do
    len = length(files)

    files =
      files
      |> build_f_mapset([])
      |> Superls.build_indexed_list(len)

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

  defp build_f_mapset([{fv, tags} | rest], acc) do
    build_f_mapset(rest, [{fv, MapSet.new(tags)} | acc])
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
