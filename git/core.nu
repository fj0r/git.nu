use common.nu *
use complete.nu *
use stat.nu *

def sum_prefix [p] {
    $in | items {|k,v| if ($k | str starts-with $p) { $v } else { 0 } } | math sum
}

# git stash
export def git-stash [
    --apply (-a)
    --clear (-c)
    --drop (-d)
    --list (-l)
    --pop (-p)
    --show (-s)
    --all (-A)
    --include-untracked (-i)
] {
    if $apply {
        git stash apply
    } else if $clear {
        git stash clear
    } else if $drop {
        git stash drop
    } else if $list {
        git stash list
    } else if $pop {
        git stash pop
    } else if $show {
        git stash show --text
    } else if $all {
        git stash --all ...(if $include_untracked {[--include-untracked]} else {[]})
    } else {
        let s = _git_status
        if ($s | sum_prefix 'wt_') > 0 {
            git stash
        } else {
            git stash pop
        }
    }
}

# git branch
export def git-branch [
    branch?:                 string@cmpl-git-branches
    --remote (-r)='origin':  string@cmpl-git-remotes
    --delete (-d)
    --no-merged (-n)
] {
    let bs = git branch | lines | each {|x| $x | str substring 2..}
    if $delete {
        let remote_branches = remote_branches
        if ($branch | is-empty) {
            let dels = if $no_merged { gb } else {
                 gb
                | where { $in.merged | is-not-empty }
            }
            | where { ($in.remote | is-empty) and ($in.current | is-empty) }
            | each {|x|
                let pf = if ($x.current | is-empty) { "  " } else { $"(ansi cyan)* " }
                let nm = if ($x.merged | is-not-empty ) { $"(ansi green)☑ " } else { "  " }
                $x | insert display $"($nm)($pf)(ansi reset)($x.branch)"
            }
            if ($dels | is-empty) {
                tips "no branches to delete"
                return
            }
            let $dels = $dels
            | input list -d display --multi
            | get branch
            for b in $dels {
                tips $"delete (ansi yellow)($b)"
                git branch -D $b
            }
            if ($dels | is-not-empty) and (agree 'delete remote branch?!') {
                for b in ($dels | where { $"($remote)/($in)" in $remote_branches }) {
                    tips $"delete (ansi yellow)($remote)/($b)"
                    git branch -D -r $'($remote)/($b)'
                    git push $remote -d $b
                }
            }
        } else {
            if $branch in $bs and (agree $'branch `($branch)` will be delete!') {
                    git branch -D $branch
            }
            if $"($remote)/($branch)" in $remote_branches and (agree $'remote branch `($branch)` will be delete!') {
                git branch -D -r $'($remote)/($branch)'
                git push $remote -d $branch
            }
        }
    } else if ($branch | is-empty) {
        let merged = git branch --merged
        | lines
        | each { $in | parse -r '\s*\*?\s*(?<b>[^\s]+)' | get 0.b }
        {
            local: (git branch)
            remote: (git branch --remote)
        }
        | transpose k v
        | each {|x|
            $x.v | lines
            | each {|n|
                let n = $n | parse -r '\s*(?<c>\*)?\s*(?<b>[^\s]+)( -> )?(?<r>[^\s]+)?' | get 0
                let c = if ($n.c | is-empty) { null } else { true }
                let r = if ($n.r | is-empty) { null } else { $n.r }
                let m = if $n.b in $merged { true } else { null }
                let rm = if $x.k == 'remote' { true } else { null }
                { current: $c, remote: $rm, branch: $n.b, ref: $r, merged: $m }
            }
        }
        | flatten
    } else if $branch in $bs {
        git checkout $branch
    } else {
        if (agree 'create new branch?') {
            git checkout -b $branch
        }
    }
}

# git clone, init
export def --env git-new [
    repo?:            string@cmpl-git-branches
    local?:           path
    --submodule (-s)  # git submodule
    --init (-i)       # git init
] {
     if $init {
        if ($repo | is-empty) {
            git init --initial-branch main
        } else {
            git init $repo --initial-branch main
            cd $repo
        }
        if $submodule {
            git submodule init
        }
    } else {
        let local = if ($local | is-empty) {
            $repo | path basename | split row '.' | get 0
        } else {
            $local
        }
        git clone ...(if $submodule {[--recurse-submodules]} else {[]}) $repo $local
        cd $local
    }
}

# edit .gitignore
export def git-ignore [--empty-dir] {
    if $empty_dir {
        [
            '# Ignore everything in this directory'
            '*'
            '# Except this file'
            '!.gitignore'
        ] | str join (char newline) | save .gitignore
    } else {
        ^$env.EDITOR ([(git rev-parse --show-toplevel) .gitignore] | path join)
    }
}

# git pull, push and switch
export def git-pull-push [
    branch?:                 string@cmpl-git-branches # branch
    --remote (-r)='origin':  string@cmpl-git-remotes  # remote
    --rebase
    --force (-f)             # git push -f
    --empty: string
    --submodule (-s)         # git submodule
    --init (-i)              # git init
    --autostash (-a)         # git pull --autostash
    --back-to-prev (-b)      # back to branch
] {
    if $submodule {
        git submodule update
    } else if $rebase {
        git pull --rebase
    } else if ($empty | is-not-empty) {
        git pull --rebase
        git add --all
        git commit --allow-empty -m $"🫙($empty)"
        git push
    } else {
        # git fetch --prune
        let m = if $rebase { [--rebase] } else { [] }
        let a = if $autostash {[--autostash]} else {[]}
        let prev = (_git_status).branch
        let branch = if ($branch | is-empty) { $prev } else { $branch }
        let branch_repr = $'(ansi yellow)($branch)(ansi light_gray)'
        let lbs = git branch | lines | each { $in | str substring 2..}
        let rbs = remote_branches
        if $"($remote)/($branch)" in $rbs {
            if $branch in $lbs {
                let bmsg = $'both local and remote have ($branch_repr) branch'
                if $force {
                    tips $'($bmsg), with `--force`, push'
                    git branch -u $'($remote)/($branch)' $branch
                    git push --force
                } else {
                    tips $'($bmsg), pull'
                    if $prev != $branch {
                        tips $'switch to ($branch_repr)'
                        git checkout $branch
                    }
                    git pull ...$m ...$a
                }
            } else {
                tips $"local doesn't have ($branch_repr) branch, fetch"
                git fetch $remote $"($branch):($branch)"
                git checkout $branch
                git branch -u $'($remote)/($branch)' $branch
                git pull ...$m ...$a -v
            }
        } else {
            let bmsg = $"remote doesn't have ($branch_repr) branch"
            let force = if $force {[--force]} else {[]}
            if $branch in $lbs {
                tips $'($bmsg), set upstream and push'
                git checkout $branch
            } else {
                tips $'($bmsg), create and push'
                git checkout -b $branch
            }
            git push ...$force --set-upstream $remote $branch
        }

        if $back_to_prev {
            git checkout $prev
        }

        let s = _git_status
        if $s.ahead > 0 {
            tips 'remote is behind, push'
            git push
        }
    }
}

# git add and restore
export def git-add [
    ...file:          path
    --all (-A)
    --patch (-p)
    --update (-u)
    --verbose (-v)
    --delete (-d)   # git rm
    --cached (-c)
    --force (-f)
    --restore (-r)  # git restore
    --staged (-s)
    --source (-o):  string
] {
    mut args = []
    if $restore {
        if ($source | is-not-empty) { $args ++= [--source $source] }
        if $staged { $args ++= [--staged]}
        $args ++= if ($file | is-empty) { [.] } else { $file }
        git restore ...$args
    } else {
        if $all { $args ++= [--all] }
        if $patch { $args ++= [--patch] }
        if $update { $args ++= [--update] }
        if $verbose { $args ++= [--verbose] }
        if $force { $args ++= [--force] }
        $args ++= if ($file | is-empty) { [.] } else { $file }
        git add ...$args
    }

}

# git delete
export def git-delete [
    ...file:          path
    --force (-f)
    --cached (-c)
    --history (-h)
] {
    mut args = []
    if $history {
        let f = $file | str join " "
        (git filter-branch --force --index-filter
            $'git rm --cached --ignore-unmatch ($f)'
            --prune-empty --tag-name-filter cat
            -- --all)
        rm -rf ([(git rev-parse --show-toplevel) .git/refs/original/] | path join)
        ggc
    } else {
        if $cached { $args ++= [--cached] }
        if $force { $args ++= [--force] }
        git rm ...$args -r ...$file
    }
}


def cmpl-commit-type [] {
    $env.GIT_COMMIT_TYPE | columns
}

# git commit
export def git-commit [
    ...message:     string
    --type (-t): string@cmpl-commit-type
    --all (-A)
    --amend (-a)
    --keep (-k)
] {
    mut args = []
    if ($message | is-not-empty) {
        let message = $message | str join ' '
        let message = if ($type | is-empty) {
            $message
        } else {
            $env.GIT_COMMIT_TYPE | get $type | str replace '{}' $message
        }
        $args ++= [-m $message]
    } else {
        if ($type | is-not-empty) {
            let message = $env.GIT_COMMIT_TYPE | get $type | str replace '{}' ''
            $args ++= [-m $message -e]
        }
    }
    if $all { $args ++= [--all] }
    if $amend { $args ++= [--amend] }
    if $keep { $args ++= [--no-edit] }
    git commit -v ...$args
}



# git diff
export def git-diff [
    commit?:          string@cmpl-git-log-all
    commit2?:         string@cmpl-git-log-all
    --cached (-c)     # cached
    --unstashed (-u)  # unstashed
    --word-diff (-w)  # word-diff
    --staged (-s)     # staged
] {
    mut args = []
    if $word_diff { $args ++= [--word-diff] }
    if $cached { $args ++= [--cached] }
    if $staged { $args ++= [--staged] }
    let s = _git_status
    if ($commit | is-empty) {
        if ($s | sum_prefix 'wt_') > 0 {
            git diff ...$args
        } else if ($s | sum_prefix 'idx_') > 0 {
            git diff ...$args --staged
        }
    } else {
        if ($commit2 | is-empty) {
            git diff ...$args $s.branch $commit
        } else {
            git diff ...$args $commit $commit2
        }
    }
}

# git merge
export def git-merge [
    branch?:            string@cmpl-git-branches
    --abort (-a)
    --continue (-c)
    --quit (-q)
    --squash (-s)
    --fast-farward (-f)
    --remote (-r)='origin':  string@cmpl-git-remotes
] {
    mut args = []
    if $squash { $args ++= [--squash] }
    if $fast_farward { $args ++= [--ff] } else { $args ++= [--no-ff] }
    if ($branch | is-empty) {
        git merge ...$args $"($remote)/(git_main_branch)"
    } else {
        git merge ...$args $branch
    }
    if $squash {
        git commit -v
    }
}

# git rebase
# TODO: --onto: (commit_id)
export def git-rebase [
    branch?:            string@cmpl-git-branches
    --interactive (-i)
    --onto (-o):        string
    --abort (-a)
    --continue (-c)
    --skip (-s)
    --quit (-q)
] {
    if $abort {
        git rebase --abort
    } else if $continue {
        git rebase --continue
    } else if $skip {
        git rebase --skip
    } else if $quit {
        git rebase --quit
    } else if ($onto | is-not-empty) {
        git rebase --onto $branch
    } else {
        let i = if $interactive {[--interactive]} else {[]}
        if ($branch | is-empty) {
            git rebase ...$i (git_main_branch)
        } else {
            git rebase ...$i $branch
        }
    }
}

# git cherry-pick
export def git-cherry-pick [
    commit?:         string@cmpl-git-log-all
    --abort (-a)
    --continue (-c)
    --skip (-s)
    --quit (-q)
    --no-commit (-n)
] {
    mut args = []
    if $abort {
        $args ++= [--abort]
    } else if $continue {
        $args ++= [--continue]
    } else if $skip {
        $args ++= [--skip]
    } else if $quit {
        $args ++= [--quit]
    } else {
        if $no_commit {
            $args ++= [--no-commit]
        }
        $args ++= [$commit]
    }
    git cherry-pick ...$args
}

# copy file from other branch
export def git-copy-file [
    branch:     string@cmpl-git-branches
    ...file:    string@cmpl-git-branch-files
] {
    ^git checkout $branch $file
}

# git reset
export def git-reset [
    commit?:      string@cmpl-git-log
    --hard (-h)
    --soft (-s)
    --clean (-c)
] {
    mut args = []
    if $hard { $args ++= [--hard] }
    if $soft { $args ++= [--soft] }
    if ($commit | is-not-empty) { $args ++= [$commit] }
    git reset ...$args
    if $clean {
        git clean -fd
    }
}


# git remote
export def git-remote [
    remote?:       string@cmpl-git-remotes
    uri?:          string
    --add (-a)
    --rename (-r)
    --delete (-d)
    --update (-u)
    --set (-s)
] {
    if ($remote | is-empty) {
        git remote -v
    } else if $add {
        git remote add $remote $uri
    } else if $set {
        git remote set-url $remote $uri
    } else if $rename {
        let old = $remote
        let new = $uri
        git remote rename $old $new
    } else if $delete {
        git remote remove $remote
    } else if $update {
        git remote update $remote
    } else {
        git remote show $remote
    }
}

# git bisect
export def git-bisect [
    --bad (-b)
    --good (-g)
    --reset (-r)
    --start (-s)
] {
    if $good {
        git bisect good
    } else if $bad {
        git bisect bad
    } else if $reset {
        git bisect reset
    } else if $start {
        git bisect start
    } else {
        git bisect
    }
}

export def git-garbage-collect [] {
    git reflog expire --all --expire=now
    git gc --aggressive --prune=now
}

export def git-truncate-history [
    retain:int=10
    --message:string="Truncate history"
] {
    let h = git log --pretty=%H --reverse -n $retain | lines | first
    let s = _git_status
    git checkout -f --orphan temp $h
    git add .
    git commit -m $message
    git rebase --onto temp $h $s.branch
}

export def git-squash-last [
    num:int
] {
    let l = git log  --pretty=»»¦««%s»¦«%b -n $num
    | split row '»»¦««' | slice 1..
    | split column '»¦«' message body
    | each { $"($in.message)\n\n($in.body)" }
    | str join "\n===\n"
    git reset --soft $"HEAD~($num)"
    git commit --edit -m $l
}
