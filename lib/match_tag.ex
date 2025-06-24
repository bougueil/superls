defmodule Superls.MatchTag do
  use Superls
  alias Superls.{StrFmt}

  @moduledoc false

  def size(result), do: Enum.reduce(result, 0, fn {_vol, fps}, acc -> acc + length(fps) end)

  def to_string(vol_fps) when is_list(vol_fps) do
    Enum.map(vol_fps, fn {vol, fps} ->
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
end
