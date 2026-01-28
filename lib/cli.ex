defmodule Superls.CLI do
  @moduledoc false
  alias Superls.{CLI.Search, Store, Password, Store}

  use Superls

  @options [
    store: :string,
    password: :boolean
  ]

  def main(argv) do
    _ = Store.maybe_create_cache_path()

    with {opts, args, []} <-
           OptionParser.parse(argv, aliases: [p: :password, i: :store], strict: @options),
         is_password? <- Keyword.get(opts, :password, false),
         password <- if(is_password?, do: Password.io_get(), else: ""),
         store <- Keyword.get(opts, :store, default_store()),
         password <- Store.check_password(store, password) do
      main_args(args, store, password)
    else
      {_, _, wrong} ->
        IO.puts("invalid command, check #{inspect(wrong)}")
    end
  catch
    err -> IO.puts("#{err}")
  end

  defp main_args(["index", media_path], store_name, password) do
    Store.archive(media_path, store_name, password)
  end

  defp main_args(["search"], store_name_or_path, password) do
    mi = Store.get_merged_index_from_store(store_name_or_path, password)

    :shell.start_interactive(
      {Search, :start, [mi, [store: store_name_or_path, passwd: password]]}
    )

    :timer.sleep(:infinity)
  rescue
    _e in File.Error ->
      default = default_store()

      store =
        case store_name_or_path do
          ^default -> ""
          any -> any
        end

      IO.puts("""
      ** store `#{store_name_or_path}` is missing.
      first create it with: superls index /path/to/my/volume_files -i #{store} [- p]
      """)
  end

  defp main_args(["help"], _store, _passwd) do
    path = Store.cache_path()

    IO.puts("""
    Usage: superls command [params] [-p -i my_index]
      -i specifies an index name, no -i defaults to the index `default`
      -p requires to enter a password, no -p defaults to no password 
    Available commands are:
      index:\n\t  superls index /path/to/my/files\n\t  note: links prevent indexing, executes this before indexing: `find /path/to/my/files -type l -ls`
      search:\n\t  superls search
    Stores:
      #{Enum.intersperse(Store.list_stores(), ", ")}

    Cache information:
      cache_path: #{path}
    """)
  end

  defp main_args([], store_name, passwd),
    do: main_args(["help"], store_name, passwd)

  defp main_args(cmd, _store, _passwd) do
    throw(
      "** unknown command `#{Enum.intersperse(cmd, " ")}`\n" <>
        "type: `superls help` for available commands"
    )
  end
end
