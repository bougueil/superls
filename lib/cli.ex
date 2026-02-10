defmodule Superls.CLI do
  @moduledoc false
  alias Superls.{CLI.Search, Store, Password, Store}

  use Superls

  @options [
    password: :boolean
  ]

  def main(argv) do
    _ = Store.maybe_create_cache_path()

    with {opts, args, []} <-
           OptionParser.parse(argv, aliases: [p: :password], strict: @options),
         is_password? <- Keyword.get(opts, :password, false),
         password <- if(is_password?, do: Password.io_get(), else: "") do
      main_args(args, password)
    else
      {_, _, wrong} ->
        IO.puts("invalid command, check #{inspect(wrong)}")
    end
  catch
    err -> IO.puts("#{err}")
  end

  defp main_args(["index", vol_path | store], password) do
    Store.archive(vol_path, store_name(store), password)
  end

  defp main_args(["help"], _passwd) do
    path = Store.cache_path()

    IO.puts("""
    Usage:

      superls [myindex]
        search for tags in index `myindex` (default index: `default`) 

      superls index /path/to/my/volume/files [index_name] [-p]
            build the index index_name and save it locally on disk
            -p requires to enter a password to encrypt the saved index
            Note: links prevent indexing, execute this before indexing: `find /path/to/my/files -type l -ls`

    Currently saved indexes:
      #{Enum.intersperse(Store.list_stores(), ", ")}
      in #{path}
    """)
  end

  # search
  defp main_args(store_name_or_path, password) do
    store_name = store_name(store_name_or_path)
    mi = Store.get_merged_index_from_store(store_name, password)

    :shell.start_interactive({Search, :start, [mi, [store: store_name, passwd: password]]})

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
  catch
    :enoent ->
      IO.puts("** index `#{store_name_or_path}` not found\n\ntry: superls help")

    err ->
      IO.puts("** #{err}")
      main_args(store_name_or_path, Password.io_get())
  end

  # defp main_args(cmd, _passwd) do
  #   throw(
  #     "** unknown command `#{Enum.intersperse(cmd, " ")}`\n" <>
  #       "type: `superls help` for available commands"
  #   )
  # end

  defp store_name([]), do: default_store()
  defp store_name([str]) when is_binary(str), do: str
end
