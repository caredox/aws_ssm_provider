defmodule AwsSsmProviderTest do
  use ExUnit.Case
  doctest AwsSsmProvider

  setup_all do
    file = Path.join([__DIR__, "fixtures", "provider.json"])

    AwsSsmProvider.init([file])
    %{}
  end

  test "can initialize provider from sample json" do
    assert [
             pattern: ~r/(\d{4}.csv)/,
             pool_timeout: 60000,
             port: 3306,
             cors_origins: [
               ~r/^https?:\/\/localhost:8081$/,
               ~r/^https?:\/\/.*mydomain\.com$/,
               "http://myapp.elb.amazonaws.com"
             ],
             nested: [test1: "44773"],
             test1: "39202",
             test1: "39201"
           ] == Application.get_env(:aws_ssm_provider, CaredoxGraphql.Repo)

    assert true == Application.get_env(:aws_ssm_provider, :use_logger)
    assert System.get_env("HOME") == Application.get_env(:aws_ssm_provider, :home)
  end

  test "regex patterns are usable" do
    repo_vars = Application.get_env(:aws_ssm_provider, CaredoxGraphql.Repo)
    assert true == Regex.match?(repo_vars[:pattern], "2019.csv")
  end

  test "regex patterns in list are usable" do
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
