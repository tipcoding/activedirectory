# 15 — Mô hình bảo mật & Tiering

Các khái niệm phòng thủ — hiểu để biết tổ chức "nên" bảo vệ thế nào, và vì sao
tấn công thành công khi mô hình bị phá.

---

## Tier model (mô hình phân tầng đặc quyền)
**Định nghĩa:** chia tài sản & tài khoản quản trị thành các tầng, **cấm** tài
khoản tầng cao đăng nhập máy tầng thấp (chống credential theft lan lên).

| Tier | Quản lý | Ví dụ |
|------|---------|-------|
| **Tier 0** | danh tính & hạ tầng kiểm soát domain | DC, AD CS, ADFS, Domain/Enterprise Admins, krbtgt |
| **Tier 1** | server & ứng dụng | file server, DB, app server |
| **Tier 2** | thiết bị người dùng | workstation, laptop |

**Chi tiết:** nguyên tắc "**không đăng nhập xuống**": admin Tier 0 **không** login
máy Tier 2 (nếu login, hash/ticket của họ nằm trong LSASS máy đó → kẻ tấn công
chiếm máy Tier 2 lấy được → leo lên Tier 0). Phá vỡ quy tắc này là lý do phổ biến
nhất để pentest đi từ workstation tới DA.

*Tài liệu gốc:* [Securing Privileged Access / Enterprise Access Model](https://learn.microsoft.com/security/privileged-access-workstations/privileged-access-access-model).

---

## PAW (Privileged Access Workstation)
**Định nghĩa:** máy trạm **riêng, cứng hoá** chỉ dùng cho tác vụ quản trị đặc
quyền (tách khỏi email/web).

**Chi tiết:** giảm rủi ro credential của admin bị dính malware khi duyệt web/mở
mail trên máy thường.

*Tài liệu:* [PAW](https://learn.microsoft.com/security/privileged-access-workstations/privileged-access-devices).

---

## Protected Users (nhóm bảo vệ)
**Định nghĩa:** nhóm (RID 525) mà thành viên được áp bảo vệ mạnh:
- **không dùng NTLM**, không RC4/DES Kerberos (chỉ AES),
- **không delegation** (unconstrained/constrained),
- **không cached logon** (không đăng nhập offline).

**Chi tiết:** đặt admin vào Protected Users giảm nhiều kỹ thuật (PtH NTLM, một số
delegation). Nhưng cũng gây rủi ro vận hành (không login offline).

*Tài liệu:* [Protected Users](https://learn.microsoft.com/windows-server/security/credentials-protection-and-management/protected-users-security-group).

---

## AdminSDHolder & SDProp
**Định nghĩa:** `AdminSDHolder` là object mẫu (`CN=AdminSDHolder,CN=System,...`)
giữ **ACL chuẩn** cho các tài khoản/nhóm đặc quyền. Tiến trình **SDProp** (chạy
~60 phút trên PDC) **áp lại** ACL đó lên mọi principal được bảo vệ, **ghi đè**
mọi thay đổi ACL.

**Chi tiết:**
- Tài khoản được bảo vệ có `adminCount = 1`.
- **Phòng thủ:** chống kẻ tấn công âm thầm cấp quyền trên nhóm admin (SDProp xoá đi).
- **Tấn công/persistence:** nếu ghi được ACE vào **AdminSDHolder**, SDProp sẽ
  **tự nhân bản** ACE đó lên nhóm admin mỗi chu kỳ → backdoor bền.

*Ví dụ:*
```powershell
# Tìm principal được bảo vệ
Get-ADUser -LDAPFilter "(adminCount=1)"
# Persistence (tấn công): thêm quyền vào AdminSDHolder
Add-DomainObjectAcl -TargetIdentity 'CN=AdminSDHolder,CN=System,DC=corp,DC=local' -PrincipalIdentity attacker -Rights All
```

*Tài liệu:* [AdminSDHolder/SDProp](https://learn.microsoft.com/windows-server/identity/ad-ds/plan/security-best-practices/appendix-c--protected-accounts-and-groups-in-active-directory).

---

## adminCount
**Định nghĩa:** thuộc tính =1 nếu object (từng) được SDProp bảo vệ.

**Chi tiết:** lưu ý "**stale adminCount**" — user từng là admin, bị gỡ khỏi nhóm
nhưng `adminCount` vẫn =1 và ACL vẫn bị khoá → gây nhầm khi enum. BloodHound đánh
dấu các node này.

---

## Least Privilege & RBAC
**Định nghĩa:** cấp **đúng mức quyền tối thiểu** cần thiết; dùng **role-based**
(nhóm theo vai trò) thay vì gán trực tiếp.

**Chi tiết:** kết hợp mô hình **AGDLP** ([file 06](06-groups.md)) để quản lý. Vi
phạm least privilege (vd user thường có quyền ghi trên object nhạy) chính là các
**ACL edge** mà BloodHound tìm ra.

---

## Các biện pháp cứng hoá liên quan khác
| Biện pháp | Chống |
|-----------|-------|
| **LAPS** | hash local admin dùng chung (PtH lan ngang) |
| **Credential Guard** (VBS) | dump LSASS |
| **SMB signing / LDAP signing + channel binding** | NTLM relay |
| **Kerberos Armoring (FAST)** | một số tấn công Kerberos |
| **Disable RC4 etype** | Kerberoast RC4 dễ crack |
| **gMSA** | mật khẩu service tĩnh/yếu |
| **Tiering + PAW + Protected Users** | credential theft leo tầng |
| **Đổi krbtgt định kỳ (2 lần)** | Golden Ticket tồn dư |

*Tài liệu:* [Best Practices for Securing AD](https://learn.microsoft.com/windows-server/identity/ad-ds/plan/security-best-practices/best-practices-for-securing-active-directory).
