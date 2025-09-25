defmodule Superls do
  @moduledoc "README.md"
             |> File.read!()
             |> String.split("<!-- MDOC !-->")
             |> Enum.fetch!(1)

  @type store() :: String.t()

  @secret System.get_env("SLS_SECRET") ||
            "bqpBY/700YM3ns8e6fSAUtA4fx3/I+w/Xeoma6kn9xCS9XZc6KzWx54yl7XLHMIf"

  @doc false
  if Mix.env() == :test do
    def puts(_msg), do: :ok
    def gets(_msg, default), do: default
  else
    def puts(msg), do: IO.puts(msg)
    def gets(msg, _default), do: IO.gets(msg) |> to_string()
  end

  @doc false
  # read tokens from private files 
  def read_banned(file) do
    Stream.resource(
      fn -> File.open!(Application.app_dir(:superls, "priv/#{file}")) end,
      fn file ->
        case IO.read(file, :line) do
          data when is_binary(data) -> {[String.trim_trailing(data) |> String.downcase()], file}
          _ -> {:halt, file}
        end
      end,
      fn file -> File.close(file) end
    )
    |> Enum.to_list()
    |> Map.from_keys(nil)
  end

  @doc "interrupt flow with the stores_pathmessage `mg`"
  @spec halt(String.t()) :: no_return()
  def halt(msg) do
    throw(msg)
  end

  @doc "Returns `encrypted` from `term` with `passwd`"
  def encrypt(index, ""),
    do: index

  def encrypt(index, password) do
    @secret
    |> Plug.Crypto.encrypt(password, index, max_age: :infinity)
  end

  @doc "Returns `decrypted` from `term` with `passwd`"
  def decrypt(index, ""),
    do: {:ok, index}

  def decrypt(index, password) do
    @secret
    |> Plug.Crypto.decrypt(password, index)
  end

  @doc false
  @spec build_indexed_list([]) :: {length :: integer(), indexed_list :: []}
  def build_indexed_list(list) do
    len = length(list)
    {len, do_build_indexed_list(list, {len, []})}
  end

  # https://stackoverflow.com/questions/22576658/convert-elixir-string-to-integer-or-float
  @spec string_to_numeric(binary()) :: float() | number() | nil
  def string_to_numeric(val) when is_binary(val),
    do: _string_to_numeric(Regex.replace(~r{[^\d\.]}, val, ""))

  defp _string_to_numeric(val) when is_binary(val),
    do: _string_to_numeric(Integer.parse(val), val)

  defp _string_to_numeric(:error, _val), do: nil
  defp _string_to_numeric({num, ""}, _val), do: num
  defp _string_to_numeric({num, ".0"}, _val), do: num
  defp _string_to_numeric({_num, _str}, val), do: elem(Float.parse(val), 0)

  defp do_build_indexed_list([], {_, list}), do: list

  defp do_build_indexed_list([f | rest], {cnt, acc}),
    do: do_build_indexed_list(rest, {cnt - 1, [{f, cnt} | acc]})

  defmacro __using__(_) do
    quote do
      @type store() :: String.t()

      @default_store Application.compile_env!(:superls, :default_store_name)
      defp default_store, do: @default_store
    end
  end
end
