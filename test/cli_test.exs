defmodule Superls.CliTest do
  use ExUnit.Case
  import ExUnit.CaptureIO
  alias Superls.{Store}

  # defines default_store
  use Superls

  @stores_path Application.compile_env!(:superls, :stores_path) |> Path.dirname()

  # This test uses 2 volumes_paths containing 3 files
  volumes_paths = for vol <- ["vol1", "vol2"], do: Path.join(@stores_path, vol)
  @volumes Enum.zip(Enum.map(volumes_paths, &Store.encode_digest_uri/1), volumes_paths)

  @f1_bbb "file1.2022.FRENCH.aaa.bbb.ccc.ogv"
  @f2_bbb "file2.2022.FRENCH.AAA.bbb.ddd.ogv"
  @f3 "file3.2022.FRENCH.aaa.eee.ggg.ogv"
  @files [@f1_bbb, @f2_bbb]

  # create the media files to build indexes on
  setup do
    HelperTest.empty_store()

    for {_, path} <- @volumes, fi <- @files, do: HelperTest.create_file(path, fi)

    # create @f3 in one of the @volumes paths
    HelperTest.create_file(elem(hd(@volumes), 1), @f3)

    :ok
  end

  test "superls help" do
    argv = ~w(help)
    {status, result} = with_io(fn -> Superls.CLI.main(argv) end)
    assert String.contains?(result, "Usage")
    assert status == :ok
  end

  test "superls no args, store already present" do
    HelperTest.create_indexes(@volumes)
    argv = ~w()
    assert :ok == Superls.CLI.main(argv)
  end

  test "superls test_superls, store already present" do
    HelperTest.create_indexes(@volumes)
    argv = ~w(test_superls)
    assert :ok == Superls.CLI.main(argv)
  end

  test "superls wrong_index, store already present" do
    HelperTest.create_indexes(@volumes)
    argv = ~w(wrong_index)
    {{:error, :enoent}, result} = with_io(fn -> Superls.CLI.main(argv) end)
    assert String.contains?(result, "`wrong_index` not found")
  end

  test "superls no args, no existing store" do
    argv = ~w()
    {{:error, :enoent}, result} = with_io(fn -> Superls.CLI.main(argv) end)
    assert String.contains?(result, "`test_superls` not found")
  end

  test "superls test_superls, no existing store" do
    argv = ~w(test_superls)
    {{:error, :enoent}, result} = with_io(fn -> Superls.CLI.main(argv) end)
    assert String.contains?(result, "`test_superls` not found")
  end

  test "superls create index, missing vol_path" do
    argv = ["index"]
    {{:error, :volume_path_notfound}, res} = with_io(fn -> Superls.CLI.main(argv) end)
    assert String.contains?(res, "missing volume path")
  end

  test "superls create index media_path, no existing store" do
    for {_, media_path} <- @volumes do
      argv = ["index", media_path]
      res = with_io(fn -> Superls.CLI.main(argv) end)
      assert res == {:ok, ""}
    end
  end

  test "superls create index media_path -p, no existing store" do
    for {_, media_path} <- @volumes do
      argv = ["index", media_path, "-p"]
      res = with_io([input: "secret"], fn -> Superls.CLI.main(argv) end)
      assert res == {:ok, " enter password:  "}
    end
  end

  test "superls create index media_path myindex -p, no existing store" do
    for {_, media_path} <- @volumes do
      argv = ["index", media_path, "-p"]
      res = with_io([input: "secret"], fn -> Superls.CLI.main(argv) end)
      assert res == {:ok, " enter password:  "}
    end
  end

  test "superls create index invalid_directory, no existing store" do
    argv = ~w(index my_invalid_directory)
    {{:error, :invalid_directory}, res} = with_io(fn -> Superls.CLI.main(argv) end)
    assert String.contains?(res, "invalid_directory")
  end

  test "superls create index invalid_directory myindex, no existing store" do
    argv = ~w(index my_invalid_directory myindex)
    {{:error, :invalid_directory}, res} = with_io(fn -> Superls.CLI.main(argv) end)
    assert String.contains?(res, "invalid_directory")
  end

  test "superls create index with -p and read it" do
    {_, media_path} = hd(@volumes)
    argv = ["index", media_path, "-p"]
    {:ok, res} = with_io([input: "secret"], fn -> Superls.CLI.main(argv) end)
    assert String.contains?(res, "enter password:")

    argv = ~w()
    {:ok, result} = with_io(fn -> Superls.CLI.main(argv) end)
    assert String.contains?(result, "bad password")
  end

  test "superls create index with -p and myindex and read it" do
    {_, media_path} = hd(@volumes)
    argv = ["index", media_path, "myindex", "-p"]
    {:ok, res} = with_io([input: "secret"], fn -> Superls.CLI.main(argv) end)
    assert String.contains?(res, "enter password:")

    argv = ~w(myindex)
    {:ok, result} = with_io(fn -> Superls.CLI.main(argv) end)
    assert String.contains?(result, "bad password")
  end
end
