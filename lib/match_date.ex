defmodule Superls.MatchDate do
  @day_seconds 3600 * 24
  @moduledoc false
  use Superls
  alias Superls.{StrFmt}

  # list oldest / newest files according to mtime / atime

  def size(result), do: length(result)

  @doc ~S"""
  returns files between date from a list of files according to cmd:
  - `xd`: created / modified date
  - `rd`: accessed date
  """
  def search_bydate(files, cmd, date, ndays) when cmd in ~w(xd rd) do
    {_sorter, field} = sorter_field(cmd)

    # mtime : 1696153262 ~U[2023-10-01 09:41:02Z]
    date_unix = Date.diff(date, ~D[1970-01-01]) * @day_seconds
    date_min = date_unix - ndays * @day_seconds
    date_max = date_unix + ndays * @day_seconds

    Enum.filter(files, fn {_fp, fp_info, _vol} ->
      field.(fp_info) >= date_min and fp_info.mtime <= date_max
    end)
  end

  @doc ~S"""
  returns the oldest or newest files from a list of files according to:
  - `xo`: created / modified oldest
  - `xn`: created / modified newest
  - `ro`: accessed oldest
  - `rn`: accessed newest
  the default number of returned files is set by the config parameter `:num_files`
  """
  def search_oldness(files, cmd, nentries) do
    {sorter, _} = sorter_field(cmd)
    IO.puts("search newest/oldest (#{cmd}) files, max: (#{nentries} files): ")

    files
    |> Enum.sort(sorter)
    |> Enum.take(nentries)
  end

  @doc false
  def format(result, cmd) do
    {_, field} = sorter_field(cmd)

    for {fp, f_info, vol} <- result do
      [
        {field.(f_info), :date, []},
        " ",
        {f_info.size, :sizeb, []},
        " ",
        {Path.basename(fp), {:scr, 60}, [:bright]},
        "  ",
        {Path.join(vol, Path.dirname(fp)), :scr, []},
        "\n"
      ]
    end
    |> StrFmt.to_string()
  end

  defp sorter_field(cmd) do
    case cmd do
      "xo" -> {fn {_fpa, a, _vola}, {_fpb, b, _volb} -> a.mtime < b.mtime end, & &1.mtime}
      "xn" -> {fn {_fpa, a, _vola}, {_fpb, b, _volb} -> a.mtime >= b.mtime end, & &1.mtime}
      "ro" -> {fn {_fpa, a, _vola}, {_fpb, b, _volb} -> a.atime < b.atime end, & &1.atime}
      "rn" -> {fn {_fpa, a, _vola}, {_fpb, b, _volb} -> a.atime >= b.atime end, & &1.atime}
      "xd" -> {nil, & &1.mtime}
      "rd" -> {nil, & &1.atime}
    end
  end
end
