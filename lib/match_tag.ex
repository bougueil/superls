defmodule Superls.MatchTag do
  use Superls
  alias Superls.{StrFmt, Tag}

  @moduledoc false

  def size(result), do: Enum.sum_by(result, fn {_vol, fps} -> length(fps) end)

  def format(vol_fps) when is_list(vol_fps) do
    Enum.map(vol_fps, fn
      {_vol, []} ->
        []

      {vol, fps} ->
        [
          {"#{vol} (#{length(fps)} entries)", :str, [:light_magenta, :reverse]},
          {"_", :padr, [:light_magenta]},
          "\n",
          for {fp, f_info} <- fps do
            [
              {f_info.size, :sizeb, []},
              " ",
              {Path.basename(fp), {:scr, 60}, [:bright]},
              "  ",
              {Path.dirname(fp), :scr, []},
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
