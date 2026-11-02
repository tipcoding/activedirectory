# 10 — Danh sách Lab theo từng kỹ thuật

Đây là phần quan trọng nhất để **luyện tay**. Mỗi bảng liệt kê lab + kỹ thuật
chính; cột "Chuỗi tóm tắt" cho biết đường đi để bạn tự kiểm chứng sau khi làm.

Nguồn:
- **HTB** = HackTheBox (máy Active Directory; cần VIP cho máy retired).
- **PG** = Proving Grounds Practice (Offensive Security — sát OSCP nhất).
- **THM** = TryHackMe (có hướng dẫn, tốt cho người mới).
- **PEN-200** = Challenge Labs chính thức của khóa OSCP.
- **GOAD** / **Vulnlab** = lab AD nhiều máy, tự dựng/thuê (luyện chuỗi dài).

> Ưu tiên theo thứ tự: **PEN-200 Challenge Labs → HTB AD boxes → PG → GOAD**.
> PG và PEN-200 sát phong cách thi nhất.

---

## A. Khởi đầu không credential / OSINT / poisoning

| Lab | Nguồn | Kỹ thuật (file) | Chuỗi tóm tắt |
|-----|-------|-----------------|---------------|
| Attacktive Directory | THM | kerbrute, AS-REP, enum SMB (01,02) | enum4linux → kerbrute userenum → AS-REP `svc-admin` → crack → SMB → secretsdump → PtH admin |
| Breaching Active Directory | THM | Responder, NTLM relay, LDAP bind (01) | Loạt bài nhỏ về mọi cách "breach" ban đầu |
| Responder | HTB (Starting Point) | LFI → UNC → NetNTLM (01) | LFI đọc file → ép tải `\\LHOST` → crack NetNTLMv2 → WinRM |
| Active | HTB | GPP, Kerberoast (01,03) | share `Replication` anon → Groups.xml `cpassword` → GPP decrypt → `SVC_TGS` → Kerberoast Administrator → DA |
| Cicada | HTB | guest, spray, share (01,02) | guest → HR notice có mật khẩu mặc định → spray → share → secretsdump |
| Intelligence | HTB | DNS record → Responder, gMSA, constrained deleg (01,04) | PDF metadata → spray → ghi DNS → Responder → gMSA → constrained delegation → DC |

## B. AS-REP / Kerberoast / Spray

| Lab | Nguồn | Kỹ thuật | Chuỗi tóm tắt |
|-----|-------|----------|---------------|
| Forest | HTB | AS-REP, ACL (WriteDacl), DCSync (02,04,08) | anon LDAP → `svc-alfresco` AS-REP → Exchange perms → WriteDacl domain → DCSync |
| Sauna | HTB | AS-REP, autologon, DCSync (02,06,08) | web team → `fsmith` AS-REP → autologon creds → `svc_loanmgr` → DCSync |
| Monteverde | HTB | spray (user=pass), Azure AD Connect (02) | enum user → `SABatchJobs`:`SABatchJobs` → share → DB Azure AD Connect → admin |
| Resolute | HTB | description, spray, DnsAdmins (01,04) | LDAP description có pass → spray → DnsAdmins → DLL → SYSTEM |
| Fuse | HTB | print job → user, spray, SeLoadDriver (01,02) | printer web → username → spray pass gợi ý → SeLoadDriver → SYSTEM |
| Nagoya | PG | spray, Kerberoast, ESC1, Silver ticket (02,03,05,08) | team page → spray → kerberoast → ADCS ESC1 / Silver ticket MSSQL |

## C. ACL / Delegation / Shadow Credentials

| Lab | Nguồn | Kỹ thuật | Chuỗi tóm tắt |
|-----|-------|----------|---------------|
| Support | HTB | LDAP, GenericWrite → RBCD / shadow cred (03,04) | `.exe` share → decompile → LDAP pass → GenericWrite computer → RBCD → DC |
| Blackfield | HTB | AS-REP, WriteOwner, Backup Operators (02,04,06,08) | rid-brute → AS-REP `support` → WriteOwner `audit2020` → SeBackup → NTDS.dit |
| Cascade | HTB | LDAP legacy pwd, group, DPAPI (01,03,06) | LDAP `cascadeLegacyPwd` → b64 → `Audit$` share → decrypt → DeletedObjects → DA |
| Administrator | HTB | targeted kerberoast, WriteOwner chain (03,04) | assumed breach → WriteOwner chain → targeted kerberoast `ethan` → DCSync |
| Resourced | PG | rid-brute, RBCD, shadow cred (01,04) | description pass → RBCD/shadow cred → DC |
| Hutch | PG | LDAP anon, GPP/LAPS (01,04) | LDAP anon → user → LAPS/GPP → admin |
| Access / Vault | PG | `.url` poisoning, delegation | share ghi được → `.url` → NetNTLM → … |

## D. ADCS

| Lab | Nguồn | Kỹ thuật | Chuỗi tóm tắt |
|-----|-------|----------|---------------|
| Authority | HTB | PWM creds, ESC1 (05) | Ansible vault → PWM → LDAP → ESC1 `certipy` → DA |
| Certified | HTB | ESC4 → ESC... (04,05) | assumed breach → WriteOwner → ESC4 sửa template → ESC1 → DCSync |
| EscapeTwo | HTB | MSSQL, ADCS (03,05) | creds cho sẵn → MSSQL → cred reuse → ESC → DA |
| Escape | HTB | MSSQL `xp_dirtree`, ADCS ESC1 (01,03,05) | PDF guest creds → MSSQL → NetNTLM `sql_svc` → ESC1 → DA |

## E. MSSQL / service foothold → SeImpersonate

| Lab | Nguồn | Kỹ thuật | Chuỗi tóm tắt |
|-----|-------|----------|---------------|
| Querier | HTB | MSSQL `xp_dirtree`, GPP, SeImpersonate (01,03,06) | macro xls → MSSQL creds → `xp_dirtree` NetNTLM → GPP → SeImpersonate |
| Scrambled | HTB | Kerberos only, Silver ticket, constrained deleg (03,07,08) | no NTLM → Kerberoast → Silver ticket MSSQL → constrained delegation |
| Jeeves/Jerry | HTB | web → SeImpersonate (06) | web upload → shell → Potato → SYSTEM (luyện Potato) |

## F. Chuỗi nhiều máy / pivot (sát kỳ thi nhất)

| Lab | Nguồn | Ghi chú |
|-----|-------|---------|
| **PEN-200 Challenge Labs** (OSCP A/B/C, Medtech, Relia, Skylark…) | PEN-200 | Mô phỏng chính xác môi trường thi 3 máy AD + pivot. **Làm hết trước khi thi.** |
| **GOAD / GOAD-Light** | Tự dựng (Vagrant/VMware) | Forest nhiều domain + trust; luyện ExtraSID, delegation, ADCS, relay |
| **Vulnlab** (Intercept, Hybrid, Reflection, Retro, Baby…) | Vulnlab | Chuỗi hiện đại; "AD chains" rất sát OSCP mới |
| Cascade, Blackfield, Forest, Sauna, Monteverde | HTB | Bộ "kinh điển" ai thi OSCP cũng nên làm |

---

## Gợi ý cách làm lab để ôn thi hiệu quả

1. **Không xem writeup trước.** Tự enum theo checklist file 01/03.
2. Ghi lại **từng lệnh + output** vào ghi chú (như khi thi) — xem [file 11](11-quy-trinh-thi-oscp.md).
3. Làm xong mới đọc 1 writeup để xem mình bỏ sót bước nào.
4. Làm lại lần 2 **không nhìn ghi chú** → tốc độ.
5. Phân loại lab theo file kỹ thuật ở trên; nếu một kỹ thuật (ví dụ RBCD) còn
   lúng túng → làm 2–3 lab cùng loại liên tiếp.

## Dựng lab AD tại nhà (miễn phí)

- **GOAD**: https://github.com/Orange-Cyberdefense/GOAD — cùng nhóm làm mindmap;
  dùng chính mindmap để tập đi path. Bản `GOAD-Light` nhẹ máy.
- **Tự dựng**: 1 Windows Server (DC) + 1–2 Windows 10/11 + máy Kali. Cài AD DS,
  tạo vài user, cố ý cấu hình sai (SPN, AS-REP, GPP, ADCS template ESC1) để luyện.
- **vulnerable-AD** (WazeHell): script tự tạo cấu hình sai trên DC có sẵn.
