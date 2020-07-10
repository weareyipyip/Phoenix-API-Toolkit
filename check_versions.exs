# get the mix version
mix_version = Mix.Project.config()[:version]

if System.argv() |> Enum.member?("match_git_tag") do
  exp_git_tag = "refs/tags/v#{mix_version}"

  # Get the current git tag and Git tag version from the CI system
  case System.get_env("GITHUB_REF") do
    ^exp_git_tag ->
      :ok

    "refs/tags/" <> tag ->
      raise "Git tag '#{tag}' does not match mix version '#{mix_version}' " <>
              "(note that a 'v' must be prefixed in tags, so the expected tag is 'v#{mix_version}')"

    nil ->
      raise "GITHUB_REF not found in env"

    other ->
      raise "GITHUB_REF '#{other}' is not a tag"
  end
end

# Read the readme
readme = File.read!("README.md")

# capture 0.3.0-alpha from {:phoenix_api_toolkit, "~> 0.3.0-alpha"}
readme_version_regex = ~r/:phoenix_api_toolkit,\s\"~>\s(?<version>.*)\"/

%{"version" => readme_version} =
  Regex.named_captures(readme_version_regex, readme, [:all_but_first])

if readme_version != mix_version do
  raise "Readme version '#{readme_version}' does not match mix version '#{mix_version}'"
end
