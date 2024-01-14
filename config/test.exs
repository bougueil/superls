import Config

config :superls,
  stores_path:
    System.tmp_dir!()
    |> Path.join("test_superls")
    |> Path.join("stores"),
  default_store_name: "test_superls",
  jaro_threshold: 2 / 3,
  # size_threshold: in percent, 1 % means 2 sizes similar if less than 1%
  size_threshold: 0.1,
  num_files_search_oldness: 10,
  num_days_search_bydate: 1
