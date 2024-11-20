export def Q [...t --sep:string=''] {
    let s = $t | str join $sep | str replace -a "'" "''"
    $"'($s)'"
}

export def sqlx [s] {
    open $env.GIT_FLOW_STATE | query db $s
}

export def --env init-db [env_name:string, file:string, hook: closure] {
    let begin = date now
    if $env_name not-in $env {
        {$env_name: $file} | load-env
    }
    if ($file | path exists) { return }
    {_: '.'} | into sqlite -t _ $file
    open $file | query db "DROP TABLE _;"
    do $hook {|s| open $file | query db $s } {|...t| Q ...$t }
    print $"(ansi grey)created database: $env.($env_name), takes ((date now) - $begin)(ansi reset)"
}
