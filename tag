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
    #   - (?s)   ：Singleline(DOTALL)模式，让 . 匹配换行
    #   - control\s+"([^"]+)"\s+do(.*?)end
    #
    #   第一个捕获组  => control "..." 中间的名称
    #   第二个捕获组  => 整个控制块的内容
    $controlRegex = [regex]'(?s)control\s+"([^"]+)"\s+do(.*?)end'
    $controlMatches = $controlRegex.Matches($Content)

    $controlObjects = foreach ($controlMatch in $controlMatches) {
        $controlName = $controlMatch.Groups[1].Value
        $controlBody = $controlMatch.Groups[2].Value  # control block 里的所有内容

        # 2) 在 controlBody 中匹配 tag key: 'value' 或 tag key: "value"
        #
        #   - 用 (?m) 多行模式，^ 才能匹配行首
        #   - ^\s*tag\s+(\w+)\s*:\s*(["'])([^"']+)\2
        #       · ^\s*tag       => 行首 + 若干空格 + "tag"
        #       · (\w+)         => 捕捉 key (仅限字母数字下划线)，如 severity、family 等
        #       · \s*:\s*       => 冒号前后可有空格
        #       · (["'])        => 捕捉引号（可能是单引号或双引号）
        #       · ([^"']+)      => 引号之间的内容
        #       · \2            => 引用前面捕捉到的引号（确保用的是同样的引号符号）
        #
        $tagLineRegex = [regex]'(?m)^\s*tag\s+(\w+)\s*:\s*(["''])([^"'']+)\2'
        $tagMatches = $tagLineRegex.Matches($controlBody)

        $tags = foreach($tm in $tagMatches) {
            $key   = $tm.Groups[1].Value
            $value = $tm.Groups[3].Value

            # 组装成一个对象
            [PSCustomObject]@{
                Key   = $key
                Value = $value
            }
        }

        # 返回当前 control 名称及其所有 tags
        [PSCustomObject]@{
            ControlName = $controlName
            Tags        = $tags
        }
    }

    return $controlObjects
}

# 主体逻辑
if (Test-Path $FilePath) {
    # 读取文件内容 ( -Raw 读入完整多行文本)
    $content = Get-Content -Path $FilePath -Raw

    # 调用函数解析
    $results = Parse-InspecProfile -Content $content

    # Demo: 打印结果 (control名和tag键值)
    $results | ForEach-Object {
        $_
        $_.Tags | Format-Table -AutoSize
        "`n"
    }
}
else {
    Write-Host "❌ 找不到文件: $FilePath"
}
