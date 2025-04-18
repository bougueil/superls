defmodule Superls.TagTest do
  use ExUnit.Case
  alias Superls.Tag

  @msg "aaa"
  test @msg, do: assert(["aaa"] = Tag.extract_tokens(@msg))

  @msg "aaa aaa"
  test @msg, do: assert(["aaa", "aaa"] = Tag.extract_tokens(@msg))

  @msg "aaa_bbb"
  test @msg, do: assert(["aaa", "bbb"] = Tag.extract_tokens(@msg))

  @msg "aaa\tbbb"
  test @msg, do: assert(["aaa", "bbb"] = Tag.extract_tokens(@msg))

  @msg "aaa\t\n\|bbb"
  test @msg, do: assert(["aaa", "bbb"] = Tag.extract_tokens(@msg))

  @msg "aaa[bbb]"
  test @msg, do: assert(["aaa", "bbb"] = Tag.extract_tokens(@msg))

  @msg "16.07.04"
  test @msg, do: assert(["16.07.04"] = Tag.extract_tokens(@msg))

  @msg "16.07.04aaa"
  test @msg, do: assert(["16.07.04", "aaa"] = Tag.extract_tokens(@msg))

  @msg "aaa16.07.04"
  test @msg, do: assert(["16.07.04", "aaa"] = Tag.extract_tokens(@msg))

  @msg "aaa11:0"
  test @msg, do: assert(["aaa"] = Tag.extract_tokens(@msg))

  @msg "aaa 11:02"
  test @msg, do: assert(["aaa"] = Tag.extract_tokens(@msg))

  @msg "aaa12:2:55"
  test @msg, do: assert(["aaa"] = Tag.extract_tokens(@msg))

  @msg "a1:2:55 22.01.12 1:4 26.03.18b"
  test @msg,
    do: assert(["22.01.12", "26.03.18", "a", "b"] = Tag.extract_tokens(@msg))

  @msg "aaa ⭐️/bbb"
  test @msg, do: assert(["aaa", "⭐️", "bbb"] = Tag.extract_tokens(@msg))

  @msg "aaa💡bbb"
  test @msg, do: assert(["aaa💡bbb"] = Tag.extract_tokens(@msg))
end
