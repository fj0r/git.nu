use utils.nu *
use core.nu *
use complete.nu *

const default_config = {
    branches: {
        dev: dev
        main: main
        release: release-
        hotfix: hotfix-
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

def ensure-branch [branch] {
    if (_git_status).branch != $branch {
        if ([y n] | input list $"The current branch is not `($branch)`, checkout?") == 'y' {
            checkout $branch
            return true
        }
    }
    return false
}

export def git-flow-push [
    branch: string@cmpl-git-branches
] {
    git-pull-push
    git branch -d $branch
    git push origin --delete $branch
}

export def git-flow-new-feature [
    branch: string@cmpl-git-branches
] {
    let cfg = git-flow-config
    $cfg | upsert current_feature $branch | save -f (config-file)
    git checkout -b $branch $cfg.branches.dev
}

export def git-flow-merge-feature [
] {
    let cfg = git-flow-config
    if ($cfg.current_feature? | is-empty) {
        error make -u {msg: $"There are no features currently" }
    }
    if not (ensure-branch $cfg.current_feature) { return }
    git checkout $cfg.branches.dev
    git merge --no-ff $cfg.current_feature
    git-flow-push $cfg.current_feature
    $cfg | upsert current_feature '' | save -f (config-file)
}

export def git-flow-resolve [
    branch: string@cmpl-git-branches
] {
    let cfg = git-flow-config
    if not (ensure-branch $cfg.branches.dev) { return }
    git add .
    git commit
    git-flow-push $branch
}

export def git-flow-release [
    tag: number
] {
    let cfg = git-flow-config
    let rb = $"($cfg.branches.release)($tag)"
    git checkout -b $rb $cfg.branches.dev
    # ... bump
    git commit -a -m "Bumped version number to ($tag)"

    git checkout $cfg.branches.main
    git merge --no-ff $rb
    git tag -a $tag

    git checkout $cfg.branches.dev
    git merge --no-ff $rb

    git branch -d $rb
}


export def git-flow-new-hotfix [
    tag: number
] {
    let cfg = git-flow-config
    let rb = $"($cfg.branches.hotfix)($tag)"
    git checkout -b $rb $cfg.branches.main
    # ... bump
    git commit -a -m "Bumped version number to ($tag)"
}


export def git-flow-merge-hotfix [
    tag: number
    message: string
] {
    let cfg = git-flow-config
    let rb = $"($cfg.branches.hotfix)($tag)"

    git commit -m $"Fixed: ($message)"

    git checkout -b $rb $cfg.branches.main
    git merge --no-ff $rb
    git tag -a $tag

    git checkout $cfg.branches.dev
    git merge --no-ff $rb

    git branch -d $rb
}
