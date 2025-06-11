use utils.nu *
use core.nu *
use complete.nu *
use stat.nu *

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

def git-kind-select [kind] {
    git branch
    | lines
    | where { $in | str starts-with '*' | not $in }
    | each {|x| $"($x|str trim)"}
    | where {|x|
        let branches = $env.GIT_FLOW.branches
        let sep = $env.GIT_FLOW.separator
        $x | str starts-with $"($branches | get $kind)($sep)"
    }
}

def cmpl-git-features [] {
    git-kind-select feature
}

export def git-kind-branches [kind] {
    let branches = $env.GIT_FLOW.branches
    let sep = $env.GIT_FLOW.separator
    let curr = (_git_status).branch
    mut obj = $curr
    if not ($obj | str starts-with $"($branches | get $kind)($sep)") {
        let r = git-kind-select $kind
        $obj = if ($r | is-empty) { $r } else { $r | input list $"There are no ($kind) currently, pick?" }
    }
    {
        curr: $curr
        $kind: $obj
        dev: $branches.dev
        main: $branches.main
    }
}

export def gitflow-open-feature [
    name: string
] {
    let b = $env.GIT_FLOW.branches
    let sep = $env.GIT_FLOW.separator
    git checkout -b $"($b.feature)($sep)($name)" $b.dev
}

export def gitflow-close-feature [
    --fast-farward (-f)
] {
    let b = git-kind-branches feature
    if ($b.feature | is-empty) {
        print $"(ansi grey)There are no feature branches.(ansi reset)"
        return
    }
    git checkout $b.dev
    let f = if $fast_farward {[--ff]} else {[--no-ff]}
    git merge ...$f $b.feature
    let remote = git remote show
    git push -u $remote $b.dev
    git branch -d $b.feature
    git checkout $b.dev
}

export def gitflow-resolve-feature [
] {
    git checkout $env.GIT_FLOW.branches.dev
    git add .
    git commit
    git push
}

export def gitflow-release [
    tag?: string
    --action(-a): closure
] {
    let b = $env.GIT_FLOW.branches
    let sep = $env.GIT_FLOW.separator
    let remote = git remote show
    git checkout $b.dev
    git push -u $remote $b.dev

    let rb = if ($tag | is-empty) {
        $b.dev
    } else {
        let rb = $"($b.release)($sep)($tag)"
        git checkout -b $rb $b.dev

        if ($action | is-not-empty) {
            do $action $tag
        }
        do -i { git commit -a -m $"Bumped version number to ($tag)" }

        $rb
    }

    git checkout $b.main
    let f = if ($tag | is-empty) {[--ff]} else {[--no-ff]}
    git merge ...$f $rb
    git push -u $remote $b.main
    if ($tag | is-not-empty) {
        git tag -a $tag
        git push $remote tag $tag

        do -i { git branch -d $rb }
    }

    git checkout $b.dev
}


export def gitflow-open-hotfix [
    tag: string
] {
    let b = $env.GIT_FLOW.branches
    let sep = $env.GIT_FLOW.separator
    let rb = $"($b.hotfix)($sep)($tag)"
    git checkout -b $rb $b.main
    # ... bump
    git commit -a -m $"Bumped version number to ($tag)"
}


export def gitflow-close-hotfix [
    message?: string
] {

    let b = git-kind-branches hotfix
    if ($b.hotfix | is-empty) {
        print $"(ansi grey)There are no hotfix branches.(ansi reset)"
        return
    }
    git checkout $b.hotfix

    do -i { git commit -m $"Fixed: ($message)" }

    let remote = git remote show
    let f = if ($message | is-empty) {[--ff]} else {[--no-ff]}
    git checkout $b.main
    git merge ...$f $b.hotfix
    git push -u $remote $b.main
    if ($message | is-not-empty) {
        let sep = $env.GIT_FLOW.separator
        let t = $b.hotfix | split row $sep | slice 1.. | str join $sep
        git tag -a $t
        git push $remote tag $t
    }

    git checkout $b.dev
    git merge ...$f $b.hotfix

    git branch -d $b.hotfix
}

export def gitlab-open-feature [
    name: string
    --local(-l)
] {
    let b = $env.GIT_FLOW.branches
    let sep = $env.GIT_FLOW.separator
    let remote = git remote show
    let f = $"($b.feature)($sep)($name)"
    git checkout -b $f $b.main
    if not $local {
        git push -u $remote $f
    }
}

export def gitlab-close-feature [
    --fast-farward (-f)
    --local(-l)
] {
    let b = git-kind-branches feature
    if ($b.feature | is-empty) {
        print $"(ansi grey)There are no feature branches.(ansi reset)"
        return
    }

    let remote = git remote show
    git checkout $b.main
    if $local {
        let f = if $fast_farward {[--ff]} else {[--no-ff]}
        git merge ...$f $b.feature
        git push
    } else {
        git pull
    }
    git branch -D $b.feature
    let rb = $'($remote)/($b.feature)'
    if $rb in (remote_branches) {
        git branch -D -r $rb
        git push $remote -d $b.feature
    }
}

export def gitlab-resolve-feature [
] {
    git checkout $env.GIT_FLOW.branches.main
    git add .
    git commit
    git push
}


export def gitlab-release [
    tag?: string
    --from(-f): string
    --to(-t): string = 'pre-production'
    --action(-a): closure
] {
    let b = $env.GIT_FLOW.branches
    let sep = $env.GIT_FLOW.separator
    let remote = git remote show
    let $from = if ($from | is-empty) { $b.main } else { $from }
    git checkout $from
    git push -u $remote $from

    let rb = if ($tag | is-empty) {
        $from
    } else {
        let rb = $"($b.release)($sep)($tag)"
        git checkout -b $rb $from

        if ($action | is-not-empty) {
            do $action $tag
        }
        do -i { git commit -a -m $"Bumped version number to ($tag)" }

        $rb
    }

    git checkout $to
    let f = if ($tag | is-empty) {[--ff]} else {[--no-ff]}
    git merge ...$f $rb
    git push -u $remote $rb
    if ($tag | is-not-empty) {
        git tag -a $tag
        git push $remote tag $tag

        do -i { git branch -d $rb }
    }

    git checkout $b.main
}
