defmodule Superls.MatchSizeTest do
  use ExUnit.Case
  import ExUnit.CaptureIO

  alias Superls.{Store, MergedIndex, MatchSize}

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

  #   /tmp/test_superls
  # ├── stores
  # │   └── test_superls
  # │       ├── F52G24BPORSXG5C7ON2XAZLSNRZS65TPNQYQ====-vol1
  # │       └── F52G24BPORSXG5C7ON2XAZLSNRZS65TPNQZA====-vol2
  # ├── vol1
  # │   ├── file1.2022.FRENCH.aaa.bbb.ccc.ogv
  # │   ├── file2.2022.FRENCH.AAA.bbb.ddd.ogv
  # │   ├── file3.2022.FRENCH.aaa.eee.ggg.ogv
  # │   └── file3.2022.FRENCH.aaa.eee.ggg.ogv.10
  # └── vol2
  #     ├── file1.2022.FRENCH.aaa.bbb.ccc.ogv
  #     ├── file2.2022.FRENCH.AAA.bbb.ddd.ogv
  #     └── file3.2022.FRENCH.aaa.eee.ggg.ogv.10
  @max_files 10
  defp create_some_files do
    for {_, path} <- @volumes,
        i <- 10..@max_files,
        do: HelperTest.create_file(path, "#{@f3}.#{i}", size: i)
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

  test "match size" do
    duplicates =
      HelperTest.get_merged_index(default_store())
      |> MergedIndex.search_similar_size()

    assert MatchSize.size(duplicates) == 1
    assert 2 = Enum.at(duplicates, 0) |> elem(1) |> length()
  end

  test "pretty_print" do
    {_result, output} =
      with_io(fn ->
        HelperTest.get_merged_index(default_store())
        |> MergedIndex.search_similar_size()
        |> Superls.MatchSize.to_string()
        |> IO.puts()
      end)

    assert 2 == Regex.scan(~r/file3/, output) |> length()
  end
end
