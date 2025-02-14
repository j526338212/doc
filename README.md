# doc
# 定义解析函数
function Parse-InSpecProfile {
    param(
        [string]$ProfilePath
    )

    # 读取文件内容
    $content = Get-Content -Path $ProfilePath -Raw

    # 正则表达式匹配 control 块
    $controlBlocks = [regex]::Matches($content, '(?s)control\s+"(.*?)"\s+do(.*?)end')

    $controls = @()

    foreach ($block in $controlBlocks) {
        $controlId = $block.Groups[1].Value
        $blockContent = $block.Groups[2].Value

        # 提取字段
        $impact = if ($blockContent -match 'impact\s+([0-9.]+)') { $matches[1] } else { $null }
        $title = if ($blockContent -match 'title\s+"(.*?)"') { $matches[1] } else { $null }
        
        # 处理多行描述（支持单行或多行字符串）
        $descMatch = [regex]::Match($blockContent, '(?s)desc\s+(<<~DESC\s+(.*?)DESC|"(.*?)")')
        $desc = if ($descMatch.Success) {
            if ($descMatch.Groups[2].Value) { $descMatch.Groups[2].Value.Trim() }
            else { $descMatch.Groups[3].Value }
        } else { $null }

        # 构建对象
        $control = [PSCustomObject]@{
            id     = $controlId
            impact = [float]$impact
            title  = $title
            desc   = $desc
        }

        $controls += $control
    }

    return $controls
}

# 示例用法
$profilePath = "C:\path\to\example_profile.rb"
$parsedControls = Parse-InSpecProfile -ProfilePath $profilePath

# 输出为 JSON
$parsedControls | ConvertTo-Json