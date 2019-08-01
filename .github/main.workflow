workflow "Automated testing" {
  on = "push"
  resolves = ["test_elixir_1.7", "test_elixir_1.9"]
}

action "test_elixir_1.7" {
  uses = "docker://elixir:1.7-alpine"
  runs = [".github/ci/entrypoint.sh"]
}

action "test_elixir_1.9" {
  uses = "docker://elixir:1.9-alpine"
  runs = [".github/ci/entrypoint.sh"]
}

workflow "Publish on release" {
  on = "release"
  resolves = ["publish"]
}

action "published-release-only" {
  uses = "actions/bin/filter@master"
  args = "action 'published'"
}

action "admins-only" {
  needs = "published-release-only"
  uses = "actions/bin/filter@master"
  args = ["actor", "juulSme", "TimPelgrim", "EvertVerboven"]
}

action "publish" {
  needs = "admins-only"
  uses = "docker://elixir:1.9-alpine"
  runs = [".github/cd/entrypoint.sh"]
  secrets = ["HEX_API_KEY"]
}