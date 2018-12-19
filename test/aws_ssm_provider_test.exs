defmodule AwsSsmProviderTest do
  use ExUnit.Case
  doctest AwsSsmProvider

  test "can initialize provider from sample json" do
    file = Path.join([__DIR__, "fixtures", "provider.json"])

    assert nil == AwsSsmProvider.init([file])

    assert [
             pool_timeout: 60000,
             port: 3306,
             nested: [test1: "44773"],
             test1: "39202",
             test1: "39201"
           ] = Application.get_env(:aws_ssm_provider, CaredoxGraphql.Repo)

    assert true = Application.get_env(:aws_ssm_provider, :use_logger)
    assert System.get_env("HOME") == Application.get_env(:aws_ssm_provider, :home)
  end
end
