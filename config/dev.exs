import Config

config :superls,
  stores_path: :filename.basedir(:user_cache, "superls/stores"),
  default_store_name: "default",
  jaro_threshold: 0.8,
  # size_threshold: in percent (0..100), a value of 1 means 2 sizes match if their difference is less than 1% 
  size_threshold: 0.001,
  num_files_search_oldness: 1000,
  num_days_search_bydate: 30
