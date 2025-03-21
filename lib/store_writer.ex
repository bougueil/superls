defmodule Superls.Store.Writer do
  alias Superls.{Prompt, Store, Tag}
  use Superls
  @moduledoc false
  @sep_path "-"
  def archive(media_path, store_name, passwd, prompted? \\ false) do
    if Prompt.prompt("Do archive in store `#{store_name}` ? [Y/n]", prompted?) do
      prompted? && IO.write("updating store `#{store_name}` ...")

      !File.dir?(media_path) &&
        Superls.halt("error: media_path: #{media_path} must point to a directory")

      store_cache_path = Superls.maybe_create_dir(store_name, prompted?)
      media_path = String.trim_trailing(media_path, "/")

      digest =
        Tag.index_media_path(media_path)
        |> :erlang.term_to_binary()
        |> :zlib.gzip()
        |> Superls.encrypt(passwd)

      try do
        Store.Reader.clean_old_digests(media_path, store_name, passwd)

        encoded_path =
          "#{store_cache_path}/#{Superls.encrypt(encode_digest_uri(media_path), passwd)}"

        :ok = File.write(encoded_path, digest)
        prompted? && IO.puts("\rstore `#{store_name}` updated.")
        :ok
      rescue
        e in ArgumentError ->
          Superls.halt(
            "** invalid password: '#{passwd}' for store: '#{store_name}'.\nerror: #{inspect(e)}"
          )
      end
    else
      Superls.halt("Aborting.")
    end
  end

  def encode_digest_uri(vol_path) when is_binary(vol_path),
    do: "#{Base.encode32(vol_path)}#{@sep_path}#{Path.basename(vol_path)}"
end
