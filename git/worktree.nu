use common.nu *
use complete.nu *
use stat.nu *

def cmpl-git-worktrees [] {
    git worktree list
    | lines
    | each {
        let x = $in | split row -r '\s+' -n 2
        { value: $x.0, description: $x.1 }
    }
}

def ensure-ignore [] {
    let gtl = git-top-level
    let ign = ($gtl)/.gitignore
    let cnt = '/.worktrees/'
    if (open -r $ign | find $cnt | is-empty) {
        $cnt | save -a $ign
    }
    mkdir ($gtl)/.worktrees
}

export def --env git-worktree [
    branch: string@cmpl-git-other-branches
] {
    let wt = $'.worktrees/($branch)'
    let gtl = git-top-level
    # already created before, just cd into it
    if ($gtl | path join $wt | path exists) {
        cd $wt
        return
    }
    ensure-ignore
    let prev = git-current-branch
    if $branch == $prev { return }
    if $branch not-in (git-branches) {
        git checkout -b $branch
        git checkout $prev
    }
    git worktree add $wt $branch
    cd $wt
}

export def git-worktree-remove [
    worktree: string@cmpl-git-worktrees
] {
    git worktree remove $worktree
}


