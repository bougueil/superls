ExUnit.start()

alias Superls.{Store}

defmodule HelperTest do
  @root_dir Application.compile_env!(:superls, :stores_path) |> Path.dirname()
  use Superls

  def create_indexes(volumes, password \\ "") do
    for {_, media_path} <- volumes,
        do: :ok = Store.archive(media_path, default_store(), password)

    :ok
  end

  def create_file(vol_path, fname, opts \\ []) do
    size = Keyword.get(opts, :size, 0)
    content = List.duplicate("_", size)
    File.mkdir_p!(vol_path)

    Path.join([vol_path, fname])
    |> File.write!(content)
  end

  def empty_store,
    do: File.rm_rf(@root_dir)

  def get_merged_index(store_name, password \\ ""),
    do: Store.get_merged_index_from_store(store_name, password)

  def extract_filenames_from_search(search_result) do
    search_result
    |> Superls.MergedIndex.flatten_files_vol()
    |> Enum.map(fn {fp, _f_info, _vol} -> fp end)
  end

  @ncols StrFmt.ncols()

  def fit_in_ncols?(str) do
    String.split(str, "\n", trim: true)
    |> Enum.all?(&(elem(StrFmt.text_length(&1), 1) <= @ncols))
  end
end
