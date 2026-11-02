# 09 — Group Policy (GPO)

## Group Policy Object (GPO)
**Định nghĩa:** tập hợp **thiết lập cấu hình** (bảo mật, registry, script, cài
phần mềm…) áp lên user/máy một cách tập trung.

**Chi tiết — GPO gồm 2 phần lưu ở 2 nơi:**
- **GPC (Group Policy Container):** object trong AD, dưới
  `CN=Policies,CN=System,DC=corp,DC=local`, chứa metadata (version, trạng thái).
- **GPT (Group Policy Template):** thư mục file trong **SYSVOL**:
  `\\corp.local\SYSVOL\corp.local\Policies\{GUID}\` chứa thiết lập thực tế
  (`GptTmpl.inf`, `Registry.pol`, script…).

*Ví dụ:* GPO "Default Domain Policy" có GUID `{31B2F340-016D-11D2-945F-00C04FB984F9}`.

*Tài liệu gốc:* [[MS-GPOL]](https://learn.microsoft.com/openspecs/windows_protocols/ms-gpol/),
[Group Policy overview](https://learn.microsoft.com/previous-versions/windows/it-pro/windows-server-2012-r2-and-2012/hh831791(v=ws.11)).

---

## Link & phạm vi áp dụng (scope)
**Định nghĩa:** GPO **link** vào **Site / Domain / OU** mới có hiệu lực; không
link vào container thường (vd `CN=Users`).

**Chi tiết thứ tự ưu tiên — LSDOU:** áp theo thứ tự **Local → Site → Domain → OU**
(OU trong cùng áp sau cùng → **thắng** khi xung đột). GPO link gần object nhất
có ưu tiên cao nhất.

*Ví dụ:* GPO ở OU `Finance` ghi đè GPO ở domain cho user trong OU đó.

---

## Precedence, Enforced, Block Inheritance
- **Precedence (link order):** nhiều GPO cùng cấp → số thứ tự nhỏ thắng.
- **Enforced (No Override):** ép GPO thắng mọi cấp dưới, không bị chặn.
- **Block Inheritance:** OU chặn GPO kế thừa từ trên (trừ GPO Enforced).

---

## Security Filtering & WMI Filtering
- **Security Filtering:** GPO chỉ áp cho principal có quyền **Read + Apply Group
  Policy** (mặc định `Authenticated Users`). → thu hẹp đối tượng áp dụng.
- **WMI Filtering:** chỉ áp khi truy vấn WMI đúng (vd chỉ máy Windows 10).

*Ví dụ:* đặt Security Filtering = nhóm `Finance-PCs` để GPO chỉ áp các máy đó.

---

## Loopback Processing
**Định nghĩa:** chế độ áp **cấu hình User** của GPO theo **máy** thay vì theo user
(Replace/Merge). Dùng cho máy chung (kiosk, RDS).

*Tài liệu:* [Loopback](https://learn.microsoft.com/troubleshoot/windows-server/group-policy/loopback-processing-of-group-policy).

---

## Computer vs User Configuration & gpupdate
- GPO có 2 nhánh: **Computer Configuration** (áp lúc khởi động/định kỳ) và **User
  Configuration** (lúc đăng nhập).
- Làm mới: `gpupdate /force`; chu kỳ nền ~90 phút (±30) cho máy trạm.

*Ví dụ:* `gpresult /r` xem GPO đang áp cho user/máy hiện tại.

---

## Group Policy Preferences (GPP) & lỗ hổng cpassword (MS14-025)
**Định nghĩa:** GPP cho phép đặt cấu hình "mềm" (map drive, tạo user local, đặt
mật khẩu local admin…).

**Chi tiết lỗ hổng:** GPP lưu mật khẩu trong file XML ở SYSVOL dưới dạng
`cpassword` mã hoá **AES với khóa Microsoft công bố công khai** → ai đọc SYSVOL
(mọi domain user) đều giải mã được. Microsoft vá bằng cách cấm đặt mật khẩu mới
qua GPP (MS14-025) nhưng **file cũ vẫn còn**.

*Ví dụ:*
```bash
findstr /S /I cpassword \\corp.local\sysvol\corp.local\policies\*.xml
Get-GPPPassword.py corp.local/alice:'Password123!'@dc01.corp.local
gpp-decrypt '<cpassword_base64>'
```

*Tài liệu:* [MS14-025](https://learn.microsoft.com/security-updates/securitybulletins/2014/ms14-025).

---

## Lạm dụng GPO (tấn công)
Có quyền ghi (GenericWrite/WriteDacl) trên GPO, hoặc quyền **link GPO vào OU** →
thêm immediate scheduled task/startup script chạy trên mọi máy áp GPO → local
admin/SYSTEM. Xem [mindmaps/09 §GPO](../mindmaps/AD-2025.03/09-acl-ace-abuse.md).

```cypher
MATCH p=((n:Base)-[]->(gp:GPO)) RETURN p   // ai điều khiển GPO (BloodHound)
```

---

## Thực hành liệt kê
```powershell
Get-GPO -All | select DisplayName, Id
gpresult /r ; gpresult /h report.html
Get-DomainGPO | select displayname, gpcfilesyspath   # PowerView
```
