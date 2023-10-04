ExUnit.start()

alias Superls.{Api}

defmodule HelperTest do
  @root_dir Application.compile_env!(:superls, :stores_path) |> Path.dirname()

  def create_indexes(volumes, store_name) do
    for {_, media_path} <- volumes, do: Api.archive(media_path, store_name)
  end

  def create_file(vol_path, fname, opts \\ []) do
    size = Keyword.get(opts, :size, 0)
    content = List.duplicate("_", size)
    File.mkdir_p!(vol_path)

    Path.join([vol_path, fname])
    |> File.write!(content)
  end

  def empty_store(),
    do: File.rm_rf(@root_dir)
end
