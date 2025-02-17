param(
    [Parameter(Mandatory=$true)]
    [string]$FilePath
)

function Parse-InspecProfile {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Content
    )

    # 1) 匹配 control 块
    #   - (?s)   : Singleline (DOTALL) 模式，让 . 能匹配换行
    #   - control\s+"([^"]+)"\s+do(.*?)end
    #
    #   第1个捕获组 => control "..." 之间的名称
    #   第2个捕获组 => control 块中间的所有内容
    $controlRegex = [regex]'(?s)control\s+"([^"]+)"\s+do(.*?)end'
    $controlMatches = $controlRegex.Matches($Content)

    $controlObjects = foreach ($controlMatch in $controlMatches) {
        $controlName = $controlMatch.Groups[1].Value
        $controlBody = $controlMatch.Groups[2].Value  # control...end内部内容

        # 2) 在controlBody中匹配 tag key: value
        # --------------------------------------------------------------
        #   需求：value 可能是:
        #       - "xxx"
        #       - 'xxx'
        #       - 不带引号(如linux, 2.3.1等)
        # --------------------------------------------------------------
        #
        #   用(?m) 多行模式，^ 匹配行首
        #
        #   正则分两步看：
        #   ^\s*tag\s+(\w+)\s*:\s*
        #       - 匹配 "tag key:"
        #   接下来匹配value:
        #       - 如果是带引号 (" 或 ' ) => (["'])([^"']+)\1
        #       - 否则匹配连续非空白 => [^\s]+
        #
        #   利用非捕获分组 (?: ... ) 和 alternation | 来兼容。
        # --------------------------------------------------------------
        #
        #   总体写法：
        #   ^\s*tag\s+(\w+)\s*:\s*(?:(["'])([^"']+)\2|[^\s]+)
        #
        #   分析：
        #       - ^\s*                  => 行首可有若干空格
        #       - tag\s+                => "tag + 空格"
        #       - (\w+)                 => 捕获 key (字母数字下划线)
        #       - \s*:\s*               => 冒号前后可有空格
        #       - (?:...)               => 非捕获分组
        #           | (["'])([^"']+)\2  => 如果有引号，捕获内部文本
        #           | [^\s]+            => 否则，匹配非空白即可
        #
        #   最终我们只需要捕获 key、value，为方便，故意写成2处捕获：
        #
        #   1) key =>  (\w+)   => $tagMatch.Groups[1]
        #   2) 
        #      如果有引号 => $tagMatch.Groups[3]
        #      如果没引号 => $tagMatch.Groups[0].Value算不上，因为没我们想要的捕获
        #
        #   我们可以通过一个统一处理的思路：
        #       - 如果 Groups[3] 有值 => 说明匹配到引号
        #       - 否则 => 提取与第整个匹配相同 ( 或者抽出 [^\s]+ )       
        #
        #
        $tagLineRegex = [regex]'(?m)^\s*tag\s+(\w+)\s*:\s*(?:(["''])([^"']+)\2|[^\s]+)'
        $tagMatches   = $tagLineRegex.Matches($controlBody)

        $tags = foreach($tagMatch in $tagMatches) {

            # $tagMatch.Groups[1].Value   => key
            # $tagMatch.Groups[2].Value   => 引号符 (若无引号则为空)
            # $tagMatch.Groups[3].Value   => 如果有引号则是value，否则为空

            $key = $tagMatch.Groups[1].Value

            # 处理 value
            if ($tagMatch.Groups[3].Success -and $tagMatch.Groups[3].Value) {
                # 说明是 'xxx' or "xxx" 写法
                $val = $tagMatch.Groups[3].Value
            }
            else {
                # 否则说明不带引号 => 先从整个匹配行提取
                #    "tag key: value"  => Group[0] 是整行
                # 但我们只想拿最后的value。
                #
                #   $tagMatch.Groups[0] 如: "tag key: linux"
                #   不过我们其实可以直接 .Value.Substring(...) 再写正则
                #
                # 为简单起见，用另外一个小正则 / 或Split:

                # let's do a quick approach:
                #   整个捕获 => "tag  key:  linux"
                #   去掉前面的 "tag ". "key: "
                $tagLineFull   = $tagMatch.Groups[0].Value
                # ref:  key => $key
                #   先移除头部 "tag "
                $temp = $tagLineFull -replace '^\s*tag\s+',''
                #   再移除 "key: "
                $temp = $temp -replace '^\s*' + [regex]::Escape($key) + '\s*:\s*',''
                #   剩下的就是value
                $val = $temp.Trim()
            }

            [PSCustomObject]@{
                Key   = $key
                Value = $val
            }
        }

        # 返回一个control对象
        [PSCustomObject]@{
            ControlName = $controlName
            Tags        = $tags
        }
    }

    return $controlObjects
}

if (Test-Path $FilePath) {
    $content = Get-Content -Path $FilePath -Raw
    $results = Parse-InspecProfile -Content $content

    # 输出（也可以做更多处理）
    $results | ForEach-Object {
        "Control: $($_.ControlName)"
        foreach($t in $_.Tags) {
            "  Tag => Key: '$($t.Key)', Value: '$($t.Value)'"
        }
        ""
    }
}
else {
    Write-Host "❌ 找不到文件: $FilePath"
}
$tagLineRegex = [regex]"(?m)^\s*tag\s+(\w+)\s*:\s*(?:(['""])([^'""]+)\2|[^\s]+)"
