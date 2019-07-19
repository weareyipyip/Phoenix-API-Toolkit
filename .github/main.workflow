workflow "CI/CD" {
  on = "push"
  resolves = ["Test"]
}

action "Test" {
  uses = "docker://elixir:1.9-alpine"
  runs = [".github/ci/entrypoint.sh"]
}

workflow "Publish" {
  on = "release"
  resolves = ["publish"]
}

action "master-branch-only" {
  args = "branch master"
  uses = "actions/bin/filter@master"
}

action "tags-only" {
  args = "tag v*"
  needs = "master-branch-only"
  uses = "actions/bin/filter@master"
}

action "admins-only" {
  args = ["actor", "juulSme", "TimPelgrim", "EvertVerboven"]
  needs = "tags-only"
  uses = "actions/bin/filter@master"
}

action "publish" {
  uses = "docker://elixir:1.9-alpine"
  needs = "admins-only"
  runs = [".github/cd/entrypoint.sh"]
  secrets = ["HEX_API_KEY"]
}