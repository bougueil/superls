defmodule Superls.Store do
  # alias Superls.{Prompt, Tag}
  # use Superls

  # @moduledoc false
  # @sep_path "-"

  # def archive(media_path, store_name, password, confirm? \\ false) do
  #   if Prompt.prompt("Do archive in store '#{store_name}' ? [Y/n]", confirm?) do
  #     confirm? && IO.write("updating #{store_name} ...")

  #     store_cache_path = maybe_create_dir(store_name, confirm?)
  #     media_path = String.trim_trailing(media_path, "/")

  #     index =
  #       get_indexes_from_resource(media_path, password)
  #       |> :erlang.term_to_binary()
  #       |> :zlib.gzip()
  #       |> Superls.encode(password)

  #     encoded_path =
  #       "#{store_cache_path}/#{Superls.encode(encode_index_uri(media_path), password)}"

  #     dbg(
  #       {store_cache_path, media_path, Superls.encode(encode_index_uri(media_path), encoded_path)}
  #     )

  #     :ok = File.write(encoded_path, index)
  #     confirm? && IO.puts("\rstore '#{store_name}' updated.")
  #     :ok
  #   else
  #     :aborted
  #   end
  # end

  # # returns indexes from the store
  # def list_indexes(store_name) do
  #   path = cache_store_path(store_name)
  #   files = File.ls(path)

  #   case files do
  #     {:error, :enoent} ->
  #       []

  #     {:ok, files} ->
  #       Enum.map(files, fn fp ->
  #         stat = File.stat!(Path.join([path, fp]), time: :posix)
  #         {fp, datetime_human_str(stat.mtime), stat.size}
  #       end)
  #   end
  # end

  # def cache_path(),
  #   do: Application.fetch_env!(:superls, :stores_path)

  # def maybe_create_cache_path(),
  #   do: maybe_create_dir("", false)

  # def decode_index_uri(index_uri) when is_binary(index_uri) do
  #   String.split(index_uri, "-")
  #   |> hd()
  #   |> Base.decode32!()
  # end

  # def encode_index_uri(vol_path) when is_binary(vol_path),
  #   do: "#{Base.encode32(vol_path)}#{@sep_path}#{Path.basename(vol_path)}"

  # # do not care return value when only_passwd_check = true (archive)
  # def get_indexes_path(store, password, only_passwd_check \\ false) do
  #   store_path = cache_store_path(store)

  #   case File.ls!(store_path) do
  #     [] ->
  #       []

  #     [first | _] = list ->
  #       try do
  #         _ = Superls.decode(first, password) |> dbg()

  #         if only_passwd_check do
  #           []
  #         else
  #           # for fname <- list, do: "#{store_path}/#{fname}"
  #           list
  #         end
  #       rescue
  #         err ->
  #           Superls.halt("pb decoding the store with password = #{password} (#{inspect(err)})")
  #       end
  #   end
  # end

  # defp cache_store_path(store),
  #   do: Path.expand("#{store}", cache_path())

  # def list_stores() do
  #   cache_path = cache_path()
  #   for fname <- File.ls!(cache_path), do: fname
  # end

  # defp load_index(enc32_path, password) do
  #   [
  #     path: enc32_path,
  #     tokens:
  #       File.read!(enc32_path)
  #       |> Superls.decode(password)
  #       |> :zlib.gunzip()
  #       |> :erlang.binary_to_term()
  #   ]
  # end

  # # return a merged index
  # # either from existing indexes from store_name or from tokenizing the path
  # def get_indexes_from_resource(store_name_or_path, password) do
  #   dbg(:entering_get_indexes_from_resource)
  #   store_name_or_path = String.replace(store_name_or_path, "\\ ", "\ ")
  #   dbg({store_name_or_path, password})

  #   if File.dir?(store_name_or_path) do
  #     case String.split(store_name_or_path, cache_path()) do
  #       ["", index_path] ->
  #         [path, _] = String.split(index_path, "-")
  #         index_uri = Path.basename(path)
  #         _ = Base.decode32!(index_uri)
  #         load_index(store_name_or_path, password)[:tokens]

  #       [^store_name_or_path] ->
  #         # not an index path, create index from a volume path
  #         # tokenize the files names
  #         Tag.index_media_path(store_name_or_path)
  #     end
  #   else
  #     case String.split(store_name_or_path, cache_path()) do
  #       ["", index_path] ->
  #         [path, _] = String.split(index_path, "-")
  #         index_uri = Path.basename(path)
  #         _ = Base.decode32!(index_uri)
  #         load_index(store_name_or_path, password)[:tokens]

  #       [^store_name_or_path] ->
  #         # search
  #         dbg(store_name_or_path)
  #         get_indexes_from_store(store_name_or_path, password)
  #     end
  #   end
  # end

  # def get_index_content(uri, password) do
  #   dbg(uri)
  #   uri = Superls.decode(uri, password)
  #   dbg(uri)
  #   ["", index_path] = String.split(uri, cache_path())
  #   [path, _] = String.split(index_path, "-")
  #   index_uri = Path.basename(path)
  #   _ = Base.decode32!(index_uri)
  #   dbg(uri)
  #   load_index(uri, password)[:tokens]
  # end

  # def get_indexes_from_store(store_name, password) do
  #   # decrypt the store indexes
  #   dbg({:entering_get_indexes_from_store, store_name, password})

  #   get_indexes_path(store_name, password)
  #   |> load_tags(store_name, password)
  #   |> Tag.merge_indexes()
  # end

  # def load_tags(uri_paths, store_name, password) when is_list(uri_paths) do
  #   store_cache_path = cache_path()

  #   Enum.reduce(uri_paths, [], fn fname, acc ->
  #     tags = get_index_content(fname, password)
  #     vol_path = get_vol_path_from_cache_path(fname)
  #     [{vol_path, tags} | acc]
  #   end)
  # end

  # defp get_vol_path_from_cache_path(fname) do
  #   case String.split(fname, "-") do
  #     [index22, _] ->
  #       index_name = Path.basename(index22)

  #       case Base.decode32(index_name) do
  #         :error ->
  #           # index_name is a regular file name
  #           throw("invalid filename #{fname}")

  #         {:ok, vol_path} ->
  #           vol_path
  #       end

  #     _ ->
  #       throw("invalid filename #{fname}")
  #   end
  # end

  # # def is_encrypted?(<<31, 139, 8, 0, 0, 0, 0, 0, 0, 3, _::binary>>),
  # #   do: false

  # def is_encrypted?(_index),
  #   do: false
end
