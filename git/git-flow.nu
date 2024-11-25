use utils.nu *
use core.nu *
use complete.nu *

export-env {
    $env.GIT_FLOW = {
        branches: {
            dev: dev
            main: main
            release: release
            hotfix: hotfix
            feature: feature
        }
        separator: '/'
    }
}

def git-flow-select [kind] {
    git branch
    | lines
    | filter { $in | str starts-with '*' | not $in }
    | each {|x| $"($x|str trim)"}
    | filter {|x|
        let branches = $env.GIT_FLOW.branches
        let sep = $env.GIT_FLOW.separator
        $x | str starts-with $"($branches | get $kind)($sep)"
    }
}

export def cmpl-git-features [] {
    git-flow-select feature
}

export def git-flow-branches [kind] {
    let branches = $env.GIT_FLOW.branches
    let sep = $env.GIT_FLOW.separator
    let curr = (_git_status).branch
    mut obj = $curr
    if not ($obj | str starts-with $"($branches | get $kind)($sep)") {
        $obj = git-flow-select $kind | input list $"There are no ($kind) currently, pick?"
    }
    {
        curr: $curr
        $kind: $obj
        dev: $branches.dev
        main: $branches.main
    }
}

export def git-flow-open-feature [
    name: string
] {
    let branches = $env.GIT_FLOW.branches
    let sep = $env.GIT_FLOW.separator
    git checkout -b $"($branches.feature)($sep)($name)" $branches.dev
}

export def git-flow-close-feature [
    --pr
] {
    let b = git-flow-branches feature
    git checkout $b.dev
    git merge --no-ff $b.feature
    let remote = git remote show
    if $pr {
        git checkout $b.feature
        git push -u $remote $b.feature
    } else {
        git push -u $remote $b.dev
        git branch -d $b.feature
    }
    git checkout $b.dev
}

export def git-flow-resolve-feature [
    --pr
] {
    git checkout $env.GIT_FLOW.branches.dev
    git add .
    git commit
    git push
}

export def git-flow-release [
    tag: string
] {
    let branches = $env.GIT_FLOW.branches
    let sep = $env.GIT_FLOW.separator
    let rb = $"($branches.release)($sep)($tag)"
    git checkout -b $rb $branches.dev
    # ... bump
    do -i { git commit -a -m $"Bumped version number to ($tag)" }

    let remote = git remote show
    git checkout $branches.main
    git merge --no-ff $rb
    git push -u $remote $branches.main
    git tag -a $tag
    git push $remote tag $tag

    do -i { git branch -d $rb }
    git checkout $branches.dev
}


export def git-flow-open-hotfix [
    tag: string
] {
    let branches = $env.GIT_FLOW.branches
    let sep = $env.GIT_FLOW.separator
    let rb = $"($branches.hotfix)($sep)($tag)"
    git checkout -b $rb $branches.main
    # ... bump
    git commit -a -m $"Bumped version number to ($tag)"
}


export def git-flow-close-hotfix [
    message: string
] {

    let b = git-flow-branches hotfix
    git checkout $b.hotfix

    do -i { git commit -m $"Fixed: ($message)" }

    git checkout $b.main
    git merge --no-ff $b.hotfix
    let sep = $env.GIT_FLOW.separator
    git tag -a ($b.hotfix | split row $sep | range 1.. | str join $sep)

    git checkout $b.dev
    git merge --no-ff $b.hotfix

    git branch -d $b.hotfix
}
