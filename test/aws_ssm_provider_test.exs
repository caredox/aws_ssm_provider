defmodule AwsSsmProviderTest do
  use ExUnit.Case
  doctest AwsSsmProvider

  setup_all do
    System.put_env("APP_NAME", "aws_ssm_provider")

    app_configs = Path.join([__DIR__, "fixtures", "app_configs.json"])
    global_configs = Path.join([__DIR__, "fixtures", "global_configs.json"])
    initial_state = %{}

    AwsSsmProvider.load(initial_state, global_configs)
    AwsSsmProvider.load(initial_state, app_configs)
    %{}
  end

  defp cors_origins do
    [
      ~r/^https?:\/\/localhost:8081$/,
      ~r/^https?:\/\/.*mydomain\.com$/,
      "http://myapp.elb.amazonaws.com"
    ]
  end

  defp repo_vars do
    [
      nested: [shared_with_nested: "44773"],
      shared_with_nested: "39202",
      cors_origins: cors_origins(),
      port: 3306,
      pool_timeout: 60000,
      pattern: ~r/(\d{4}.csv)/
    ]
  end

  defp nested_vars do
    [
      nested_duplicate_string: "dup_string_4",
      nested_duplicate_integer: 4,
      nested_duplicate_regex: ~r/(\d{3}.csv)/,
      nested_duplicate_system_var: System.get_env("USER"),
      nested_duplicate_json_array: [9, 2, 2]
    ]
  end

  test "set string on root level" do
    assert "a string" == Application.get_env(:aws_ssm_provider, :string_val)
  end

  test "set integer on root level" do
    assert 1001 == Application.get_env(:aws_ssm_provider, :int_val)
  end

  test "set regex on root level" do
    assert ~r/(\d{4}.csv)/ == Application.get_env(:aws_ssm_provider, :use_logger4)
  end

  test "set json array on root level" do
    assert cors_origins() == Application.get_env(:aws_ssm_provider, :cors_origins)
  end

  test "set system variable on root level" do
    assert System.get_env("HOME") == Application.get_env(:aws_ssm_provider, :home)
  end

  test "set string on nested level" do
    assert "1003" == Application.get_env(:aws_ssm_provider, :nested)[:string_val]
  end

  test "set integer on nested level" do
    assert 1002 == Application.get_env(:aws_ssm_provider, :nested)[:int_val]
  end

  test "set regex on nested level" do
    assert ~r/(\d{5}.csv)/ == Application.get_env(:aws_ssm_provider, :nested)[:file_name]
  end

  test "set json array on nested level" do
    assert cors_origins() ==
             Application.get_env(:aws_ssm_provider, CaredoxGraphql.Repo)[:cors_origins]
  end

  test "set system variable on nested level" do
    assert System.get_env("USER") == Application.get_env(:aws_ssm_provider, :nested)[:user]
  end

  test "converts true/false to booleans" do
    assert true == Application.get_env(:aws_ssm_provider, :use_logger)
  end

  test "set nested application variables from sample json" do
    assert repo_vars() == Application.get_env(:aws_ssm_provider, CaredoxGraphql.Repo)
  end

  test "regex patterns are usable" do
    repo_vars = Application.get_env(:aws_ssm_provider, CaredoxGraphql.Repo)
    assert true == Regex.match?(repo_vars[:pattern], "2019.csv")
  end

  test "regex patterns in list are usable" do
    [_o1, origin2, _o3] = Application.get_env(:aws_ssm_provider, :cors_origins)
    assert true == Regex.match?(origin2, "http://xyz.mydomain.com")
  end

  test "ints in jsonArray are usable" do
    assert [1, 8, 2] == Application.get_env(:aws_ssm_provider, :int_array)
  end

  test "ints in nested jsonArray are usable" do
    assert [7, 0, 2] == Application.get_env(:aws_ssm_provider, :nested)[:int_array]
  end

  test "arrays in jsonArray are usable" do
    assert [2, "root_string", [3, "root_nested_string"]] ==
             Application.get_env(:aws_ssm_provider, :nested_array)
  end

  test "arrays in nested jsonArray are usable" do
    assert [9, "string", [8, "nested_string"]] ==
             Application.get_env(:aws_ssm_provider, :nested)[:nested_array]
  end

  test "regex patterns in nested list are usable" do
    repo_vars = Application.get_env(:aws_ssm_provider, CaredoxGraphql.Repo)
    [_o1, origin2, _o3] = repo_vars[:cors_origins]
    assert true == Regex.match?(origin2, "http://xyz.mydomain.com")
  end

  test "regex patterns enforce special characters" do
    repo_vars = Application.get_env(:aws_ssm_provider, CaredoxGraphql.Repo)
    [_o1, origin2, _o3] = repo_vars[:cors_origins]
    assert false == Regex.match?(origin2, "http://xyz.mydomainPcom")
  end

  test "duplicate strings are overwritten at the root level config" do
    assert "dup_string_2" == Application.get_env(:aws_ssm_provider, :duplicate_string)
  end

  test "duplicate integers are overwritten at the root level config" do
    assert 2 == Application.get_env(:aws_ssm_provider, :duplicate_integer)
  end

  test "duplicate regex are overwritten at the root level config" do
    assert ~r/(\d{2}.csv)/ == Application.get_env(:aws_ssm_provider, :duplicate_regex)
  end

  test "duplicate system vars are overwritten at the root level config" do
    assert System.get_env("HOME") == Application.get_env(:aws_ssm_provider, :duplicate_system_var)
  end

  test "duplicate JSON arrays are overwritten at the root level config" do
    assert [6, 5, 4] == Application.get_env(:aws_ssm_provider, :duplicate_json_array)
  end

  test "duplicate strings are overwritten in nested config" do
    nested_duplicates = Application.get_env(:aws_ssm_provider, :nested_dups)

    assert nested_duplicates == nested_vars()
  end

  test "global var is overwritten by app config" do
    assert "this was overwritten" == Application.get_env(:aws_ssm_provider, :overwritten_config)
  end

  test "global var was overwritten with key name starting with global/global" do
    assert "app and env is global was overwritten" ==
             Application.get_env(:aws_ssm_provider, :overwritten_app_and_env_config)
  end

  test "global var was overwritten when just the app was global" do
    assert "app is global this was overwritten" ==
             Application.get_env(:aws_ssm_provider, :overwritten_app_config)
  end

  test "global nested var overwritten nested" do
    assert "this was overwritten nested" ==
             Application.get_env(:aws_ssm_provider, :nested)[:overwritten_nested_config]
  end

  test "global nested app var overwritten" do
    assert "app is global nested was overwritten" ==
             Application.get_env(:aws_ssm_provider, :nested)[:overwritten_nested_app_config]
  end

  test "global nested app and env var overwritten" do
    assert "app and env is global nested was overwritten" ==
             Application.get_env(:aws_ssm_provider, :nested)[
               :overwritten_nested_app_and_env_config
             ]
  end

  test "unique global var is present" do
    assert "from global" == Application.get_env(:aws_ssm_provider, :unique_global_config)
  end

  test "unique global app var is present" do
    assert "app is global from global" ==
             Application.get_env(:aws_ssm_provider, :unique_global_app_config)
  end

  test "unique global app and env var is present" do
    assert "app and env is global from global" ==
             Application.get_env(:aws_ssm_provider, :unique_global_app_and_env_config)
  end

  test "nested unique global var is present" do
    assert "nested from global" ==
             Application.get_env(:aws_ssm_provider, :nested)[:unique_nested_global_config]
  end

  test "nested unique global app var is present" do
    assert "app is global nested from global" ==
             Application.get_env(:aws_ssm_provider, :nested)[:unique_nested_app_global_config]
  end

  test "nested unique global app and env var is present" do
    assert "app and env is global nested from global" ==
             Application.get_env(:aws_ssm_provider, :nested)[
               :unique_nested_app_and_env_global_config
             ]
  end
end
