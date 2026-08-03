$InformationPreference = 'Continue'

function Get-ChangedFiles {
    # Lấy tag gần nhất để làm mốc so sánh
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
    # Trích xuất hành động Git sang từ ngữ tiếng Việt ngắn gọn theo ý bạn
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
    # Tự động lấy phần tên file và loại bỏ phần đuôi mở rộng (ví dụ: .txt)
    # Cách này an toàn tuyệt đối cho cả file ở thư mục gốc Text/ lẫn thư mục con Text/Event/
    $FileBaseName = Split-Path $FilePath -LeafBase
    return $FileBaseName
}

function Get-ChangelogParentFolder {
    param (
        [string]$FilePath
    )
    # Nếu file nằm trong thư mục con (ví dụ: Text/Event/Arisa.txt)
    if ($FilePath -match "^Text/[^/]+/.+") {
        $ParentFolder = $FilePath.Split("/")[1]
        
        # Định dạng chuẩn Title Case (ví dụ: event -> Event)
        $FormattedFolder = (Get-Culture).TextInfo.ToTitleCase($ParentFolder)
        return "${FormattedFolder}: "
    }
    # Nếu file nằm ngay thư mục gốc Text/ thì không cần trả về tên thư mục con
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
        
        # Tách trạng thái Git và đường dẫn file bằng phím Tab (\t)
        $Elements = $file.Split("`t")
        $Status = $Elements[0]
        $FilePath = $Elements[1]
    
        # Gọi đầy đủ các hàm xử lý thành phần
        $ChangelogStatus = $Status | ConvertTo-ChangelogStatus
        $ChangelogParent = Get-ChangelogParentFolder $FilePath # <-- Đã thêm bước gọi hàm này của bạn vào đây
        $ChangelogFile = $FilePath | ConvertTo-ChangelogFile

        # Ghép chuỗi hoàn chỉnh đầy đủ danh mục thư mục con
        $ChangelogFull = $ChangelogStatus + $ChangelogParent + $ChangelogFile
        
        # Lọc bỏ trùng lặp nếu có nhiều file trùng tên được xử lý
        if ($ChangelogFull -notin $Changelog) {
            $null = $Changelog.Add($ChangelogFull)
        }
    }
    return ($Changelog -join "`r`n")
}

# --- TIẾN TRÌNH XỬ LÝ CHÍNH ---
$ChangedFiles = Get-ChangedFiles

# Lọc riêng các file thay đổi thuộc phạm vi thư mục Text/ của repo PriconneRe-VN
$CharacterChanges = Get-Changelog ($ChangedFiles -match "^Text/" )

Write-Output "::group::Final Changelog`n"

# Khởi tạo file RELEASE_NOTE chứa cấu trúc tiêu đề tĩnh theo ảnh mẫu
Set-Content -Path ./RELEASE_NOTE -Value "## Thông Tin Cập Nhật:`r`n"

if ($CharacterChanges) {
    Add-Content -Path ./RELEASE_NOTE -Value $CharacterChanges
} else {
    # Nội dung mặc định nếu bản release này không có file Text nào thay đổi
    Add-Content -Path ./RELEASE_NOTE -Value "- Cập nhật hệ thống dữ liệu dịch thuật."
}

Write-Output "::endgroup::`n"
