defmodule Accent do
  @moduledoc false
  # transform a string in a plain ascii string
  # https://stackoverflow.com/a/37511463/1878180

  @diacritics Regex.compile!("[\u0300-\u036f]")
  def normalize(str) do
    String.normalize(str, :nfd)
    |> String.replace(@diacritics, "")
  end
end
