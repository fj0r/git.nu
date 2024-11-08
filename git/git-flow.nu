use utils.nu *
use core.nu *
use complete.nu *

const default_config = {
    branches: {
        dev: dev
        main: main
        release: release-*
        hotfix: hotfix-*
    }
}

def config-file [] {
    [(git-repo-path) .gitflow] | path join
}

export def git-flow-init [] {
    $default_config
    | to toml
    | save -f (config-file)
}

export def git-flow-config [] {
    let p = config-file
    let $s = if ($p | path exists) {
        open $p | from toml
    } else {
        {}
    }
    $default_config | merge $s
}

export def git-flow-new-feature [
    branch: string@cmpl-git-branches
] {
    let cfg = git-flow-config
    git checkout -b $branch $cfg.branches.dev
}

export def git-flow-merge [
    branch: string@cmpl-git-branches
] {
    let cfg = git-flow-config
    git checkout $cfg.branches.dev
    git merge --no-ff $branch
    git-pull-push
    git branch -d $branch
    git push origin --delete $branch
}

export def git-flow-resolve [
    branch: string@cmpl-git-branches
] {
    let cfg = git-flow-config
    git add .
    git commit
    git-pull-push
    git branch -d $branch
    git push origin --delete $branch
}
