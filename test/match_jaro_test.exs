defmodule Superls.MatchJaroTest do
  use ExUnit.Case

  alias Superls.{Api, Store}
  # defines default_store
  use Superls

  @root_dir Application.compile_env!(:superls, :stores_path) |> Path.dirname()

  # this test uses 2 volumes_paths containing 3 files 
  volumes_paths = for e <- ["vol1", "vol2"], do: Path.join(@root_dir, e)
  @volumes Enum.zip(Enum.map(volumes_paths, &Store.encode_index_uri/1), volumes_paths)

  @f1_bbb "file1.2022.FRENCH.aaa.bbb.ccc.ogv"
  @f2_bbb "file2.2022.FRENCH.AAA.bbb.ddd.ogv"
  @f3 "file3.2022.FRENCH.aaa.eee.ggg.ogv"
  @files [@f1_bbb, @f2_bbb]

  defp create_some_files() do
    for {_, path} <- @volumes do
      max_files = 100
      # max_files =
      # 100: 2.7s, 140: 11.7s, 160: 22.7s, 180: 42s
      for i <- 10..max_files do
        HelperTest.create_file(path, "#{@f3}.#{i}")
      end
    end
  end

  # create the media files to build indexes on
  setup do
    HelperTest.empty_store()

    for {_, path} <- @volumes do
      for fi <- @files, do: HelperTest.create_file(path, fi)
    end

    # create @f3 in one of the @volumes paths
    HelperTest.create_file(elem(hd(@volumes), 1), @f3)

    :ok
  end

  test "jaro" do
    create_some_files()
    HelperTest.create_indexes(@volumes, default_store())

    duplicated_tags = Api.search_duplicated_tags(default_store())
    assert Map.keys(duplicated_tags) |> Enum.member?(1.0)
  end
end
