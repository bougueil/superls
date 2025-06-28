defmodule Superls.MatchJaroTest do
  use ExUnit.Case
  alias Superls.{MergedIndex, Store}
  import ExUnit.CaptureIO

  # defines default_store
  use Superls

  @root_dir Application.compile_env!(:superls, :stores_path) |> Path.dirname()

  # this test uses 2 volumes_paths containing 3 files
  volumes_paths = for e <- ["vol1", "vol2"], do: Path.join(@root_dir, e)
  @volumes Enum.zip(Enum.map(volumes_paths, &Store.encode_digest_uri/1), volumes_paths)

  @f1_bbb "file1.2022.FRENCH.aaa.bbb.ccc.ogv"
  @f2_bbb "file2.2022.FRENCH.AAA.bbb.ddd.ogv"
  @f3 "file3.2022.FRENCH.aaa.eee.ggg.ogv"
  @files [@f1_bbb, @f2_bbb]

  @max_files 100
  defp create_some_files do
    for {_, path} <- @volumes,
        i <- 10..@max_files,
        do: HelperTest.create_file(path, "#{@f3}.#{i}")
  end

  # create the media files to build indexes on
  setup do
    HelperTest.empty_store()
    for {_, path} <- @volumes, fi <- @files, do: HelperTest.create_file(path, fi)

    # create @f3 in one of the @volumes paths
    HelperTest.create_file(elem(hd(@volumes), 1), @f3)

    create_some_files()
    HelperTest.create_indexes(@volumes)
    :ok
  end

  test "jaro" do
    duplicates =
      HelperTest.get_merged_index(default_store())
      |> MergedIndex.search_duplicated_tags()

    assert Map.keys(duplicates) |> Enum.member?(1.0)
  end

  test "pretty_print" do
    {result, _output} =
      with_io(fn ->
        HelperTest.get_merged_index(default_store())
        |> MergedIndex.search_duplicated_tags()
        |> Superls.MatchJaro.format()
      end)

    assert true == String.contains?("#{result}", "distance: 1.0")
  end
end
