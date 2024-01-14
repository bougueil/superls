defmodule Superls.MatchDateTest do
  use ExUnit.Case
  import ExUnit.CaptureIO

  alias Superls.{Api, Store}
  # defines default_store
  use Superls

  @root_dir Application.compile_env!(:superls, :stores_path) |> Path.dirname()

  # this test uses 2 volumes_paths containing 3 files
  volumes_paths = for e <- ["vol1", "vol2"], do: Path.join(@root_dir, e)
  @volumes Enum.zip(Enum.map(volumes_paths, &Store.Writer.encode_digest_uri/1), volumes_paths)

  @f1_bbb "file1.2022.FRENCH.aaa.bbb.ccc.ogv"
  @f2_bbb "file2.2022.FRENCH.AAA.bbb.ddd.ogv"
  @f3 "file3.2022.FRENCH.aaa.eee.ggg.ogv"
  @files [@f1_bbb, @f2_bbb]

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

  test "match date oldness xo-xn-rn-ro" do
    for search_type <- ~w(xo ro xn rn) do
      {result, _} = with_io(fn -> Api.search_oldness(default_store(), search_type, 10) end)
      assert length(result) == 7
    end
  end

  test "match bydate  xd-rd" do
    for search_type <- ~w(xd rd) do
      {result, _} =
        with_io(fn -> Api.search_bydate(default_store(), search_type, Date.utc_today(), 1) end)

      assert length(result) == 7
    end
  end
end
