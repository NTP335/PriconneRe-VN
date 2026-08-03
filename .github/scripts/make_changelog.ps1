$InformationPreference = 'Continue'

function Get-ChangedFiles {
    $LatestTag = git describe --tags --abbrev=0
    
    # So sánh tag hiện tại với commit ngay trước nó để lấy chính xác danh sách file thay đổi
    $ChangedFiles = git diff --find-renames --name-status "$LatestTag^" "$LatestTag"
    
    # Danh sách các file hệ thống và cài đặt cần bỏ qua không đưa vào changelog
    $Blacklist = "^.github/|^README.md|^installer.exe"
    
    Write-Information "Latest tag: $LatestTag`n"
    Write-Information "::group::Changed Files`n$($ChangedFiles | Join-String -Separator "`r`n")`n::endgroup::`n"

    return ($ChangedFiles -notmatch $Blacklist)
}

function ConvertTo-ChangelogStatus {
    param (
        [parameter(ValueFromPipeline)]
        [string] $Status
    )
    switch -Wildcard ($Status) {
        "A*" { return "- Thêm " }
        "M*" { return "- Cập Nhật " }
        "R*" { return "- Cập Nhật " }
        "D*" { return "- Xóa " }
    }
}

function Get-ChangelogFileName {
    param (
        [string]$FilePath
    )
    $FileBaseName = Split-Path $FilePath -LeafBase
    return $FileBaseName
}

function Get-ChangelogParentFolder {
    param (
        [string]$FilePath
    )
    if ($FilePath -match "^Text/[^/]+/.+") {
        $ParentFolder = $FilePath.Split("/")[1]
        
        # Tự động viết hoa chữ đầu chuẩn mã nguồn (ví dụ: event -> Event, story -> Story)
        $FormattedFolder = $ParentFolder.Substring(0,1).ToUpper() + $ParentFolder.Substring(1).ToLower()
        return "${FormattedFolder}: "
    }
    return ""
}

function ConvertTo-ChangelogFile {
    param (
        [parameter(ValueFromPipeline)]
        [string]$FilePath
    )
    $FileName = Get-ChangelogFileName $FilePath
    return "$FileName"
}

function Get-Changelog {
    param (
        [array]$Files
    )
    $Changelog = [System.Collections.ArrayList]@()

    foreach ($file in $Files) {
        if ([string]::IsNullOrWhiteSpace($file)) { continue }
        
        $Elements = $file.Split("`t")
        $Status = $Elements[0]
        $FilePath = $Elements[1]
    
        $ChangelogStatus = $Status | ConvertTo-ChangelogStatus
        $ChangelogParent = Get-ChangelogParentFolder $FilePath
        $ChangelogFile = $FilePath | ConvertTo-ChangelogFile

        $ChangelogFull = $ChangelogStatus + $ChangelogParent + $ChangelogFile
        
        if ($ChangelogFull -notin $Changelog) {
            $null = $Changelog.Add($ChangelogFull)
        }
    }
    return ($Changelog -join "`r`n")
}

# --- TIẾN TRÌNH XỬ LÝ CHÍNH ---
$ChangedFiles = Get-ChangedFiles
$CharacterChanges = Get-Changelog ($ChangedFiles -match "^Text/" )

Write-Output "::group::Final Changelog`n"

# Khởi tạo tiêu đề tĩnh chuẩn theo ảnh
Set-Content -Path ./RELEASE_NOTE -Value "## Thông Tin Cập Nhật:`r`n"

if ($CharacterChanges) {
    Add-Content -Path ./RELEASE_NOTE -Value $CharacterChanges
} else {
    Add-Content -Path ./RELEASE_NOTE -Value "- Cập nhật hệ thống dữ liệu dịch thuật."
}

Write-Output "::endgroup::`n"
