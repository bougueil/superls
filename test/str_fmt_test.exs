defmodule Superls.StrFmtTest do
  use ExUnit.Case
  alias Superls.StrFmt

  test ":sizeb" do
    assert [{1024, :sizeb, []}] |> StrFmt.pp() == "  1024B"
  end

  test ":sizeb + color" do
    assert [{1024, :sizeb, [:blue_background]}]
           |> StrFmt.pp() == "\e[44m  1024B\e[0m"
  end

  test ":void + color" do
    assert [{"Example", :void, [:blue_background]}]
           |> StrFmt.pp() == "\e[44mExample\e[0m"
  end

  test ":date" do
    assert [{1_696_153_262, :date, []}]
           |> StrFmt.pp() == "2023-10-01"
  end

  test ":date + color" do
    assert [{1_696_153_262, :date, [:blue]}]
           |> StrFmt.pp() == "\e[34m2023-10-01\e[0m"
  end

  test ":datetime" do
    assert [{1_696_153_262, :datetime, []}]
           |> StrFmt.pp() == "23-10-01 09:41:02"
  end

  # str_fmt_specs length = 40, size of the terminal.
  @screen_w_str "_123456789_123456789_123456789_123456789"

  test ":fit_width, string = screen_w" do
    long = @screen_w_str

    assert [{long, :fit_width, []}]
           |> StrFmt.pp() == long
  end

  test ":fit_width, string = screen_w + color" do
    long = @screen_w_str

    assert [{long, :fit_width, [:blue]}]
           |> StrFmt.pp() == "\e[34m_123456789_123456789_123456789_123456789\e[0m"
  end

  test ":fit_width, string = screen_w - 1" do
    long = String.slice(@screen_w_str, 0..38)

    assert [{long, :fit_width, []}]
           |> StrFmt.pp() == long
  end

  test ":fit_width, string = screen_w + 2" do
    long = "a" <> @screen_w_str <> "b"

    assert [{long, :fit_width, []}]
           |> StrFmt.pp() == "a_123456789_1234567..23456789_123456789b"
  end

  test ":fit_width, string = screen_w + 2 + color" do
    long = "a" <> @screen_w_str <> "b"

    assert [{long, :fit_width, [:blue]}]
           |> StrFmt.pp() == "\e[34ma_123456789_1234567..23456789_123456789b\e[0m"
  end

  test "{:fit, 50}, string = screen_w" do
    long = "a" <> @screen_w_str <> "b"

    assert [{long, {:fit, 50}, []}]
           |> StrFmt.pp() == "a_1234567..23456789b"
  end

  test "{:fit, 50}, string = screen_w/2" do
    str_20chars = String.slice(@screen_w_str, 0..19)

    assert [{str_20chars, {:fit, 50}, []}]
           |> StrFmt.pp() == str_20chars
  end
end
