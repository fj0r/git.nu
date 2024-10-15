export def 'precent' [] {
    ($in * 10000 | math round) / 100
}

export def 'frequency' [-w: int] {
    let o = $in
    '' | fill -c '*' -w ($o * $w | math round)
}

export def 'histogram-column' [column --len(-l):int = 50] {
    let o = $in
    let total = $o | get $column | math sum
    let max = $o | get $column | math max | ($in / $total)
    $o
    | each {|x|
        let c = $x | get $column | $in / $total
        $x
        | insert precent $"($c | precent)%"
        | insert frequency ($c / $max | frequency -w $len)
    }
}
