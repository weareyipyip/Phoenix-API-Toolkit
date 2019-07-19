workflow "Automated testing" {
  on = "push"
  resolves = ["test"]
}

action "test" {
  uses = "docker://elixir:1.9-alpine"
  runs = [".github/ci/entrypoint.sh"]
}

workflow "Publish on release" {
  on = "release"
  resolves = ["publish"]
}

action "admins-only" {
  args = ["actor", "juulSme", "TimPelgrim", "EvertVerboven"]
  uses = "actions/bin/filter@master"
}

action "publish" {
  uses = "docker://elixir:1.9-alpine"
  needs = "admins-only"
  runs = [".github/cd/entrypoint.sh"]
  secrets = ["HEX_API_KEY"]
}