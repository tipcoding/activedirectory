# 11 — Quy trình khi thi OSCP (phần Active Directory)

## 1. Cấu trúc phần AD trong kỳ thi OSCP+

- Phần AD gồm một **chuỗi máy** (thường 3 máy: 1 client, 1 server, 1 DC) được
  nối thành **một domain**.
- Tính **60 điểm trọn gói** — chỉ được điểm khi chiếm **toàn bộ** chuỗi tới DC
  (không có điểm lẻ cho từng máy AD như máy standalone).
- Thường là **assumed breach**: đề cho sẵn một credential domain ban đầu → bạn
  bắt đầu ở [file 03](03-co-credential-enum.md).
- 3 máy standalone còn lại 60 điểm (20 mỗi máy, có điểm local.txt/proof.txt).
- Cần **70/100** để đậu. Chiến lược phổ biến: lấy trọn 60 điểm AD + 1 máy
  standalone, hoặc 2.5 máy standalone.

---

## 2. Quy trình AD (lặp cho tới khi tới DC)

```
┌─ Có credential (đề cho) ─────────────────────────────┐
│ 1. nxc smb/winrm/rdp/mssql/ldap <range>  → ở đâu vào được?
│ 2. BloodHound (Mark Owned → Shortest path to DA)
│ 3. Enum: share, GPP, description, Kerberoast, AS-REP, ADCS, LAPS, gMSA, delegation
│ 4. Có foothold shell? → whoami /priv → SeImpersonate? → SYSTEM
│ 5. Dump credential (SAM/LSA/LSASS/DPAPI) → credential MỚI
│ 6. Credential mới → quay lại bước 1   ◄── vòng lặp
└──────────────────────────────────────────────────────┘
          │  khi có quyền DA / replication
          ▼
   DCSync krbtgt + Administrator → PtH DC → proof.txt
```

**Nguyên tắc sống còn:**
- **Mỗi credential/hash/ticket mới → thử trên MỌI máy, MỌI giao thức.** Password
  reuse là chủ đề số 1 của OSCP AD.
- **Enum lại từ đầu sau mỗi lần có quyền mới.** BloodHound lại với tài khoản mới.
- Nếu bí > 30 phút: quay lại enum cơ bản bạn đã bỏ qua (share, description,
  pass-pol, một giao thức chưa thử). **99% là đã bỏ sót enum, không phải thiếu exploit.**

---

## 3. Những điều ĐƯỢC và KHÔNG được dùng (kiểm tra lại OSCP Exam Guide mới nhất)

**KHÔNG được:**
- Metasploit/Meterpreter: **chỉ được dùng trên 1 máy duy nhất** trong cả kỳ thi
  (gồm cả phần AD). Giữ "lá bài" này cẩn thận; phần AD nên làm tay hoàn toàn.
- Công cụ tự động khai thác nhiều bước: `sqlmap` (trừ học tập), autoexploit,
  `AutoRecon` cho khai thác, các script "one-click to DA".
- ⚠️ **ZeroLogon, và các exploit phá hoại** — về mặt kỹ thuật có thể bị cấm hoặc
  gây hỏng máy không khôi phục được → tránh. Đọc kỹ Exam Guide.

**ĐƯỢC:**
- NetExec/CrackMapExec, Impacket, BloodHound, Responder, mimikatz, Rubeus,
  certipy, bloodyAD, evil-winrm, hashcat/john, nmap, ligolo-ng/chisel,
  winPEAS — tất cả tool thủ công trong tài liệu này.
- `nmap` scripts, `nuclei` (quét), `ffuf`/`gobuster`.

> Quy định thay đổi theo thời gian — **luôn đọc OSCP Exam Guide chính thức ngay
> trước kỳ thi** để xác nhận danh sách công cụ bị hạn chế.

---

## 4. Ghi chép (bắt buộc, phục vụ báo cáo)

Chụp màn hình + lưu lệnh cho **mọi bước**: enum, exploit, `whoami`, local.txt,
proof.txt. Báo cáo thiếu bằng chứng = không được điểm dù đã chiếm máy.

```bash
# Khung thư mục mỗi máy
mkdir -p exam/{AD-DC01,AD-WS01,AD-SRV02,standalone1,standalone2,standalone3}/{nmap,loot,screenshots}
# Log toàn bộ phiên terminal
script -q exam/AD-DC01/session.log
```

Mỗi khi lấy flag:

```powershell
PS> type C:\Users\Administrator\Desktop\proof.txt
PS> whoami ; hostname ; ipconfig            # chụp cùng flag để chứng minh
```

Công cụ ghi chú gợi ý: **CherryTree**, **Obsidian**, **Sysreptor** (có template
OSCP), hoặc Markdown + Flameshot.

---

## 5. Checklist nhanh khi vào phần AD

- [ ] Đặt biến `$DC $DOMAIN $USER $PASS $LHOST` (file 00)
- [ ] `/etc/hosts`, `krb5.conf`, đồng bộ giờ
- [ ] `nxc smb/winrm/rdp/mssql/ldap <range>` với credential ban đầu
- [ ] BloodHound (`-c All`) → Mark Owned → Shortest Path to DA
- [ ] Enum đầy đủ (share/GPP/desc/Kerberoast/AS-REP/ADCS/LAPS/gMSA/delegation)
- [ ] `certipy find -vulnerable` (ADCS là shortcut hay gặp)
- [ ] Foothold → `whoami /priv` → SeImpersonate → SYSTEM
- [ ] Dump creds → thử lại khắp mạng
- [ ] DA → DCSync → proof.txt mọi máy AD
- [ ] Chụp màn hình + lưu lệnh từng bước

---

## 6. Quản lý thời gian (24 giờ khai thác)

| Giờ | Việc |
|-----|------|
| 0–0.5 | Quét toàn bộ mục tiêu, đặt /etc/hosts, chạy BloodHound phần AD ngay |
| 0.5–6 | Tập trung **phần AD** khi đầu óc tỉnh táo (chuỗi dài, dễ sai) |
| 6–7 | Nghỉ, ăn |
| 7–16 | Các máy standalone, xen kẽ nếu AD bí |
| 16–20 | Quay lại chỗ bí, enum lại, thử credential reuse chéo |
| 20–24 | **Kiểm tra bằng chứng/screenshot**, lấy lại flag nếu rớt phiên, nghỉ |
| +24 (báo cáo) | Viết report từ ghi chú; nộp trong 24h tiếp theo |

**Khi stuck:** đổi máy khác 1 tiếng rồi quay lại; enum lại giao thức/bước đã bỏ;
đọc lại mọi file đã tải về (`grep -ri pass`). Đừng cố một exploit "lạ" khi chưa
enum hết cơ bản.
