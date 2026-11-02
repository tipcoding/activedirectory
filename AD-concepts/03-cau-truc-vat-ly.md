# 03 — Cấu trúc vật lý

## Domain Controller (DC)
**Định nghĩa:** máy chủ Windows chạy vai trò AD DS, lưu bản sao của database AD
(**NTDS.dit**) và xử lý xác thực (Kerberos/NTLM), LDAP, replication.

**Chi tiết:** mọi DC trong domain đều **ghi được** (multi-master) trừ RODC. DC
chạy **KDC** (Kerberos), **Netlogon**, **DNS** (thường), và giữ `SYSVOL`. Chiếm
được DC = chiếm domain (truy cập được toàn bộ hash qua NTDS.dit/DCSync).

*Ví dụ nhận biết DC:* mở port **88 (Kerberos) + 389 (LDAP) + 445 + 53 (DNS)**.

*Tài liệu:* [What is a DC](https://learn.microsoft.com/windows-server/identity/ad-ds/get-started/virtual-dc/active-directory-domain-services-overview).

---

## NTDS.dit
**Định nghĩa:** file database của AD (ESE/JET) trên DC, tại
`C:\Windows\NTDS\ntds.dit`.

**Chi tiết:** chứa **mọi object + hash mật khẩu** của domain. Lấy được (cần DA
hoặc SeBackup trên DC) → trích toàn bộ hash kể cả `krbtgt`. Chi tiết dump:
[file 14](14-credentials-va-secrets.md).

---

## Site
**Định nghĩa:** biểu diễn **vị trí vật lý/mạng** (thường = một văn phòng / dải
mạng tốc độ cao), dùng để tối ưu **replication** và **định tuyến đăng nhập**
client tới DC gần nhất.

**Chi tiết:** site liên kết với **subnet**. Client dùng site để tìm DC cùng site
(qua DNS SRV). Thông tin site nằm trong **Configuration NC** → mọi DC forest biết.

*Ví dụ:* site `HQ-Hanoi` gắn subnet `10.10.0.0/16`; site `Branch-HCM` gắn
`10.20.0.0/16`.

*Tài liệu:* [AD DS sites](https://learn.microsoft.com/windows-server/identity/ad-ds/plan/understanding-active-directory-site-topology).

---

## Subnet
**Định nghĩa:** dải IP gán cho một site. Client so IP của mình với subnet để biết
mình thuộc site nào.

---

## Replication (sao chép)
**Định nghĩa:** cơ chế đồng bộ dữ liệu giữa các DC (**multi-master**: mọi DC
ghi được).

**Chi tiết:** dùng **USN**, **high-watermark**, giải quyết xung đột; **KCC**
(Knowledge Consistency Checker) tự dựng topology; **intra-site** (nhanh,
không nén) vs **inter-site** (theo lịch, nén). DCSync lạm dụng chính giao thức
replication (`DRSUAPI`) để "xin" hash. Chi tiết: [file 12](12-replication-va-fsmo.md).

---

## Global Catalog (GC)
**Định nghĩa:** DC đặc biệt giữ **bản sao đầy đủ của domain mình + bản sao một
phần (read-only) của MỌI domain trong forest**. Cổng **3268/3269**.

**Chi tiết:** phục vụ tìm kiếm toàn forest (ví dụ đăng nhập UPN, tra cứu nhóm
Universal). Thiếu GC → một số đăng nhập thất bại. Khi query cross-domain, trỏ
LDAP tới cổng GC 3268.

*Ví dụ:*
```bash
ldapsearch -H ldap://dc01.corp.local:3268 -b "" -s base   # query GC
```

*Tài liệu:* [Global Catalog](https://learn.microsoft.com/windows-server/identity/ad-ds/plan/understanding-the-global-catalog).

---

## RODC (Read-Only Domain Controller)
**Định nghĩa:** DC **chỉ đọc**, không lưu mật khẩu (trừ các tài khoản được phép
qua *Password Replication Policy*), dùng cho chi nhánh kém an toàn.

**Chi tiết:** RODC không replicate đi; nếu lấy được RODC, chỉ lộ hash của các
tài khoản nằm trong PRP (không toàn domain). Có thể là bước đệm.

*Tài liệu:* [RODC](https://learn.microsoft.com/windows-server/identity/ad-ds/deploy/rodc/read-only-domain-controllers).

---

## SYSVOL & NETLOGON
**Định nghĩa:**
- **SYSVOL** — share trên mọi DC (`C:\Windows\SYSVOL\sysvol`) chứa **GPO (GPT)**
  và logon script; replicate qua DFS-R (hoặc FRS cũ).
- **NETLOGON** — share chứa logon script cũ.

**Chi tiết:** **mọi domain user đọc được SYSVOL** → là nơi tìm **GPP cpassword**
(MS14-025) và script chứa mật khẩu.

*Ví dụ:*
```bash
smbclient //dc01/SYSVOL -U 'corp/alice%Password123!'
findstr /S /I cpassword \\corp.local\sysvol\corp.local\policies\*.xml
```

*Tài liệu:* [SYSVOL](https://learn.microsoft.com/troubleshoot/windows-server/group-policy/sysvol-share-overview).

---

## Functional Level (Domain / Forest)
**Định nghĩa:** "mức" tính năng, phụ thuộc phiên bản Windows Server thấp nhất của
DC. Quyết định tính năng khả dụng (vd gMSA cần 2012+, PAM/bastion cần 2016).

*Ví dụ:* `Get-ADDomain | select DomainMode` → `Windows2016Domain`.
