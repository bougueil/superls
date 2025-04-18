defmodule Superls.MatchSize do
  use Superls

  @moduledoc false
  # group files by size

  @size_threshold Application.compile_env!(:superls, :size_threshold) / 100

  def size(result), do: length(result)

  def to_string(duplicates) do
    for {sz, [{fp1, f1_info, vol1} | rest]} <- duplicates,
        do:
          [
            {sz, :sizeb, [:light_magenta, :reverse]},
            {"____________________", :str, [:light_magenta]},
            "\n",
            {f1_info.size, :sizeb, []},
            " ",
            {Path.basename(fp1), {:scr, 60}, [:bright]},
            "  ",
            {Path.join(vol1, f1_info.dir), :scr, []},
            "\n",
            for {fp2, f2_info, vol2} <- rest do
              [
                {f2_info.size, :sizeb, []},
                " ",
                {Path.basename(fp2), :str, [:bright]},
                "  ",
                {Path.join(vol2, f2_info.dir), :scr, []},
                "\n"
              ]
            end
          ]
          |> StrFmt.to_string()
  end

  def best_size(files) do
    {len, files} =
      files
      |> Enum.sort(&(elem(&1, 1).size <= elem(&2, 1).size))

      # use Enum.with_index() ?
      |> Superls.build_indexed_list()

    files
    |> Flow.from_enumerable()
    |> Flow.flat_map(fn {file, start_compare} ->
      near_sz_files(Enum.slice(files, start_compare..len), file, [])
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
    |> Enum.sort(&(elem(&1, 0) >= elem(&2, 0)))
  end

  def near_sz_files([], _file_vol, acc),
    do: acc

  def near_sz_files(
        [{file2 = {_fp2, fp2_info, _vol2}, _index} | rest],
        file = {_fp, fp_info, _vol},
        acc
      ) do
    if near_sz?(fp_info.size, fp2_info.size) do
      near_sz_files(rest, file, [
        {fp_info.size, [file, file2]} | acc
      ])
    else
      acc
    end
  end

  defp near_sz?(_, 0), do: false

  defp near_sz?(size1, size2) do
    (size1 - size2) / size2 < @size_threshold
  end
end
