defmodule Superls do
  @moduledoc "README.md"
             |> File.read!()
             |> String.split("<!-- MDOC !-->")
             |> Enum.fetch!(1)

  alias Superls.Prompt

  @secret System.get_env("SLS_SECRET") ||
            "bqpBY/700YM3ns8e6fSAUtA4fx3/I+w/Xeoma6kn9xCS9XZc6KzWx54yl7XLHMIf"

  @doc false
  def load_keys(file) do
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

  def halt(msg) do
    throw(msg)
  end

  def cache_path,
    do: Application.fetch_env!(:superls, :stores_path)

  def encrypt(index, false),
    do: index

  def encrypt(index, password) do
    @secret
    |> Plug.Crypto.encrypt(password, index, max_age: :infinity)
  end

  def decrypt(index, false),
    do: {:ok, index}

  def decrypt(index, password) do
    @secret
    |> Plug.Crypto.decrypt(password, index)
  end

  def cache_store_path(store),
    do: Path.expand("#{store}", cache_path())

  def maybe_create_cache_path,
    do: maybe_create_dir("", false)

  def maybe_create_dir(store, confirm?) do
    store_path = cache_store_path(store)
    do_maybe_create_dir(File.exists?(store_path), store, store_path, confirm?)
  end

  defp do_maybe_create_dir(true, _store, store_path, _confirm?),
    do: store_path

  defp do_maybe_create_dir(false, store, store_path, confirm?) do
    if Prompt.prompt("Confirm create a new store `#{store}` [N/y] ?", confirm?) do
      :ok = File.mkdir_p!(store_path)
    end

    store_path
  end

  @doc false
  def pp_sz(size) when size > 10 * 1024 * 1024 * 1024 do
    "#{div(size, 1024 * 1024 * 102) / 10} gB."
  end

  def pp_sz(size) when size > 10 * 1024 * 1024 do
    "#{div(size, 1024 * 102) / 10} mB."
  end

  def pp_sz(size) when size > 10 * 1024 do
    "#{div(size, 102) / 10} kB."
  end

  def pp_sz(size) do
    "#{size} B."
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

  @doc false
  def build_indexed_list(list, len),
    do: do_build_indexed_list(list, {len, []})

  defp do_build_indexed_list([], {_, list}), do: list

  defp do_build_indexed_list([f | rest], {cnt, acc}),
    do: do_build_indexed_list(rest, {cnt - 1, [{f, cnt} | acc]})

  defmacro __using__(_) do
    quote do
      @default_store Application.compile_env!(:superls, :default_store_name)
      defp default_store, do: @default_store

      defp date_human_str(posix_time),
        do: posix_time |> DateTime.from_unix!() |> DateTime.to_date() |> Date.to_string()

      defp datetime_human_str(posix_time),
        do: posix_time |> DateTime.from_unix!() |> DateTime.to_string()
    end
  end
end
