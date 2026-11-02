# 00 — Ký hiệu, cách đọc mindmap & biến dùng chung

## Cách đọc một box trong mindmap

Mỗi kỹ thuật trong tài liệu được trình bày theo khối:

> ### Tên box (đúng như mindmap)
> - **Khi nào chạy:** điều kiện tiên quyết (bạn đang ở trạng thái nào, cần gì).
> - **Lệnh:** đúng lệnh mindmap + chú thích.
> - **Kết quả:** output mong đợi / dấu hiệu thành công.
> - **Tại sao:** cơ chế & mục đích.

## Màu & hình trong mindmap gốc

| Ký hiệu | Ý nghĩa |
|---------|---------|
| Box xanh dương | Hành động / câu lệnh cần chạy |
| Box cam | Kết quả trung gian (ví dụ `Username`, `Hash found ASREP`) |
| Box đỏ / "Admin" / "Domain admin" | Mốc quyền đạt được |
| `⚠️` | Cảnh báo (dễ khóa tài khoản, exploit phá hoại, IPv6…) |
| Mũi tên | Chuyển sang trạng thái/kỹ thuật kế tiếp |

## Biến dùng chung

```bash
export DC=10.10.10.100          # IP (hoặc FQDN) Domain Controller
export DCIP=10.10.10.100        # IP DC (mindmap hay ghi <dc_ip>)
export DOMAIN=corp.local        # FQDN domain
export USER=alice               # user hiện có
export PASS='Password123!'      # mật khẩu (nháy đơn vì có ký tự đặc biệt)
export HASH=2b576acbe6bcfda7294d6bd18041b8fe   # NT hash
export LHOST=$(ip -4 addr show tun0 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}')  # IP Kali
export IPRANGE=10.10.10.0/24    # dải quét
```

Các `<...>` trong lệnh mindmap tương ứng:
`<ip_range>`=`$IPRANGE`, `<dc_ip>`=`$DCIP`, `<domain>`=`$DOMAIN`,
`<user>`=`$USER`, `<password>`=`$PASS`, `<hash>`=`$HASH`,
`<attacker_ip>`/`<listener>`=`$LHOST`, `<interface>`=`tun0`.

## Bảng loại hash & hashcat mode (gom từ toàn mindmap)

Mindmap v2025.03 liệt kê rõ từng loại hash + lệnh crack. Tổng hợp:

| Loại (như mindmap) | Ví dụ prefix | hashcat | john |
|--------------------|--------------|---------|------|
| LM | `299bd128c1101fd6` | `-m 3000` | `--format=lm` |
| NT | `b4b9b02e6f09a9bd760…` | `-m 1000` | `--format=nt` |
| NTLMv1 | `user::85D5BC…` | `-m 5500` | `--format=netntlm` |
| NTLMv2 | `user::N46iSNek…` | `-m 5600` | `--format=netntlmv2` |
| Kerberos 5 ASREP | `$krb5asrep$23$…` | `-m 18200` | `--format=krb5asrep` |
| Kerberos 5 TGS RC4 | `$krb5tgs$23$…` | `-m 13100` | `--format=krb5tgs` |
| Kerberos 5 TGS AES128 | `$krb5tgs$17…` | `-m 19600` | |
| Kerberos 5 TGS AES256 | `$krb5tgs$18…` | `-m 19700` | |
| MSCache2 (DCC2) | `$DCC2$10240…` | `-m 2100` | |
| Timeroast | `$sntp-ms$…` | `-m 31300 -a 3 ?l?l?l?l?l?l?l` | |
| PXE (SCCM) | `$sccm$aes128$…` | `-m 19850` | |

Lệnh mẫu mindmap:

```bash
hashcat -m 1000 -a 0 hash.txt rockyou.txt
john --format=nt hash.txt --wordlist=rockyou.txt
```

## Ba dạng xác thực (cột "Valid Credentials" của mindmap)

Mindmap gộp 3 thứ vào một trạng thái vì chúng tương đương về khả năng:

1. **Cleartext creds** (user + password) → dùng trực tiếp.
2. **NT hash** → Pass-the-Hash (NTLM) hoặc OverPass-the-Hash (→ TGT).
3. **Kerberos ticket** (TGT `.ccache`/`.kirbi`) → Pass-the-Ticket.

Quy tắc chuyển đổi (có trong mindmap):
- NT hash → TGT: `getTGT.py <domain>/<user> -hashes :<hash>`
- Convert `.kirbi` ↔ `.ccache`: `ticketConverter.py <in> <out>`
- Dùng ticket với Impacket: thêm `-k -no-pass` và `export KRB5CCNAME=ticket.ccache`

## Lưu ý thi OSCP

Mindmap có cả lệnh `msf>` (Metasploit) và exploit phá hoại (ZeroLogon). Trong
thi OSCP: Metasploit chỉ được dùng **1 máy duy nhất**; ZeroLogon unsafe có thể
hỏng DC → tránh. Các chỗ này được đánh dấu ⚠️ trong tài liệu.
