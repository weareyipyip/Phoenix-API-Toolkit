# Get the current git tag and expected version from the CI system
"refs/tags/v" <> expected_version =
  System.get_env("GITHUB_REF", "Environment variable GITHUB_REF not found")

# Read the readme
readme = File.read!("README.md")

# capture 0.3.0-alpha from {:phoenix_api_toolkit, "~> 0.3.0-alpha"}
readme_version_regex = ~r/:phoenix_api_toolkit,\s\"~>\s(?<version>.*)\"/

%{"version" => readme_version} =
  Regex.named_captures(readme_version_regex, readme, [:all_but_first])

# get the mix version
mix_version = Mix.Project.config()[:version]

# raise when mismatched
if mix_version != expected_version do
  raise ArgumentError,
        "Mix version '#{mix_version}' does not match expected version '#{expected_version}'"
end

if readme_version != expected_version do
  raise ArgumentError,
        "Readme version '#{readme_version}' does not match expected version '#{expected_version}'"
end
