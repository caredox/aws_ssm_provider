defmodule AwsSsmProviderTest do
  use ExUnit.Case
  doctest AwsSsmProvider

  setup_all do
    file = Path.join([__DIR__, "fixtures", "provider.json"])

    AwsSsmProvider.init([file])
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
      pattern: ~r/(\d{4}.csv)/,
      pool_timeout: 60000,
      port: 3306,
      cors_origins: cors_origins(),
      nested: [test1: "44773"],
      test1: "39202",
      test1: "39201"
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
end
