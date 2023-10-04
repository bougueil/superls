defmodule Superls.MatchSize do
  use Superls

  @moduledoc false
  # group files by size 

  # @size_threshold: size difference percentage threshold
  @size_threshold Application.compile_env!(:superls, :size_threshold) / 100

  def pretty_print_result(result) do
    for {sz, similar_files} <- result do
      IO.puts(
        IO.ANSI.light_magenta() <>
          IO.ANSI.reverse() <>
          "#{Superls.pp_sz(sz)}" <>
          IO.ANSI.reverse_off() <>
          "________________________________________________________________" <>
          IO.ANSI.reset()
      )

      [{file1, vol1} | rest] = similar_files

      IO.puts(
        IO.ANSI.bright() <>
          Path.basename(file1.name) <>
          IO.ANSI.reset() <>
          "\t" <>
          Superls.pp_sz(file1.size) <>
          "\t" <>
          vol1 <>
          "/" <>
          Path.dirname(file1.name) <>
          IO.ANSI.reset()
      )

      for {file2, vol2} <- rest do
        #  " - " <>
        #  " - " <>
        (IO.ANSI.bright() <>
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

  def best_size(files) do
    len = length(files)

    files =
      files
      |> Enum.sort(&(elem(elem(&1, 0), 0).size <= elem(elem(&2, 0), 0).size))
      |> Superls.build_indexed_list(len)

    files
    |> Flow.from_enumerable()
    |> Flow.flat_map(fn {{file_vol, _tags}, start_compare} ->
      by_file_size(Enum.slice(files, start_compare..len), file_vol, [])
    end)
    |> Flow.partition(key: {:elem, 0})
    |> Flow.reduce(fn -> %{} end, fn {sz, [f1, f2]}, acc ->
      case acc do
        %{^sz => list} ->
          %{acc | sz => [f2 | list]}

        %{} ->
          Map.put(acc, sz, [f1, f2])

        other ->
          :erlang.error({:badmap, other}, [acc, sz, [[f1, f2]]])
      end
    end)
    |> Enum.into(%{})
  end

  defp by_file_size([], _file_vol, acc),
    do: acc

  defp by_file_size(
         [{{file2_vol = {file2, _vol}, _tag}, _index} | rest],
         file_vol = {file, _},
         acc
       ) do
    if match_sz(file.size, file2.size) do
      by_file_size(rest, file_vol, [
        {file.size, [file_vol, file2_vol]} | acc
      ])
    else
      acc
    end
  end

  defp match_sz(_, 0),
    do: false

  # size1 > size2 thanks to sort
  defp match_sz(size1, size2) do
    (size1 - size2) / size2 < @size_threshold
  end
end
