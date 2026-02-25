defmodule Superls.MatchTag do
  use Superls
  alias Superls.{StrFmt, Tag}

  @moduledoc false

  def size(result), do: Enum.sum_by(result, fn {_vol, fps} -> length(fps) end)

  def format_files(vol_fps, opts) when is_list(vol_fps) do
    Enum.map(vol_fps, fn
      {_vol, []} ->
        []

      {vol, fps} ->
        [
          {"#{vol} (#{length(fps)} entries)", :str, [:light_magenta, :reverse]},
          {"_", :padr, [:light_magenta]},
          "\n",
          Enum.map(fps, &format_file(&1, Keyword.fetch!(opts, :show_flag_pos)))
        ]
    end)
    |> StrFmt.to_string()
  end

  @display_default 0
  @display_size 1
  @display_last_write_yymm 2
  @display_last_write 3
  @display_last_read 4

  def format_file({fp, f_info}, @display_size) do
    [
      {f_info.size, :sizeb, []},
      " "
    ] ++ format_file({fp, f_info}, @display_default)
  end

  def format_file({fp, f_info}, @display_last_write_yymm) do
    yms = f_info.mtime |> DateTime.from_unix!() |> Calendar.strftime("%y%m")

    [
      {f_info.size, :sizeb, []},
      " #{yms} "
    ] ++ format_file({fp, f_info}, @display_default)
  end

  def format_file({fp, f_info}, @display_last_write) do
    yms = f_info.mtime |> DateTime.from_unix!() |> Calendar.strftime("%y-%m-%d")

    [
      {f_info.size, :sizeb, []},
      " #{yms} "
    ] ++ format_file({fp, f_info}, @display_default)
  end

  def format_file({fp, f_info}, @display_last_read) do
    duration_s = f_info.atime - f_info.mtime
    weeks = div(duration_s, 3600 * 24 * 7)

    remain_s =
      if weeks == 0 do
        duration_s
      else
        duration_s - weeks * 3600 * 24 * 7
      end

    yms = "#{weeks}W-#{div(remain_s, 3600 * 24)}D "

    [
      {f_info.size, :sizeb, []},
      {{9, yms}, :str, []}
    ] ++ format_file({fp, f_info}, @display_default)
  end

  # @display_default
  def format_file({fp, _f_info}, @display_default) do
    [
      {Path.basename(fp), {:scr, 60}, [:bright]},
      "  ",
      {Path.dirname(fp), :scr, []},
      "\n"
    ]
  end

  def format_tags(vol_fps, exclude_tags) when is_list(vol_fps) do
    Enum.map(vol_fps, fn
      {_vol, []} ->
        []

      {vol, fps} ->
        [
          {"#{vol} (#{length(fps)} entries)", :str, [:light_magenta, :reverse]},
          {"_", :padr, [:light_magenta]},
          "\n",
          for {_fp, f_info} <- fps do
            [
              for tag <- f_info.tags -- exclude_tags do
                [tag, " "]
              end,
              "\n"
            ]
          end
        ]
    end)
    |> StrFmt.to_string()
  end

  def compute(vol_files, search_tags_string) do
    to_keywords(search_tags_string)
    |> do_search_matching_tags(vol_files)
  end

  defp do_search_matching_tags([] = keywords, vol_files) do
    {Enum.map(vol_files, fn {vol, _} -> {vol, []} end), keywords}
  end

  defp do_search_matching_tags(keywords, vol_files) do
    {Task.async_stream(
       vol_files,
       fn {vol, files} ->
         {vol,
          Enum.filter(files, fn {_file, file_info} ->
            Enum.all?(keywords, fn keyw ->
              Enum.any?(file_info.tags, &String.contains?(&1, keyw))
            end)
          end)}
       end,
       timeout: :infinity
     )
     |> Enum.map(fn {:ok, res} -> res end), keywords}
  end

  defp to_keywords(search_str) do
    search_str
    |> String.downcase()
    |> Accent.normalize()
    |> Tag.extract_tokens()
    |> Enum.reject(&(String.length(&1) == 1))
    |> Enum.uniq()
  end
end
