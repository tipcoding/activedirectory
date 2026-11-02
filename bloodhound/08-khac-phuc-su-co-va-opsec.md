# 08 — Khắc phục sự cố & OPSEC

## A. Lỗi thường gặp

### 1. Import xong đồ thị trống / lỗi định dạng
- **Nguyên nhân:** sai dòng phiên bản (collector v1 ↔ CE, hoặc v2 ↔ Legacy).
- **Khắc phục:** thu lại bằng collector đúng dòng, hoặc nạp vào UI đúng dòng.
  Tải collector từ **Download Collectors** trong CE để chắc khớp.

### 2. `bloodhound-python` không phân giải tên (DNS)
```
[!] Could not find the domain / Cannot resolve <dc>
```
- **Khắc phục:**
  ```bash
  bloodhound-ce-python ... -ns $DC                 # chỉ định name server
  bloodhound-ce-python ... -ns $DC --dns-tcp       # ép DNS qua TCP
  bloodhound-ce-python ... -dc $DCFQDN -gc $DCFQDN # chỉ định DC/GC theo FQDN
  echo "$DC  $DCFQDN  $DOMAIN" | sudo tee -a /etc/hosts
  ```

### 3. Kerberos lỗi clock skew / cần FQDN
```
KRB_AP_ERR_SKEW (Clock skew too great)
```
- **Khắc phục:** đồng bộ giờ với DC và dùng FQDN:
  ```bash
  sudo ntpdate -u $DC          # hoặc: sudo rdate -n $DC
  # dùng -k -no-pass + KRB5CCNAME, krb5.conf đúng realm (xem OSCP-AD/00)
  ```

### 4. Thiếu Session / LocalAdmin
- **Nguyên nhân:** collector không chạm được máy trạm hoặc bạn thiếu quyền.
- **Khắc phục:** chạy thêm `-c Session,LocalAdmin` (python) hoặc
  `SharpHound.exe -c Session,LocalAdmin` từ Windows với quyền admin local; hoặc
  chấp nhận chỉ có dữ liệu `DCOnly`.

### 5. Môi trường lớn → chậm / timeout
```bash
rusthound-ce ... --ldap-filter '(objectGuid=*)'        # chia tải
SharpHound.exe -c All --searchbase "OU=...,DC=corp,DC=local"
SharpHound.exe -c All --throttle 1000 --jitter 30
SOAPHound.exe ... --autosplit --threshold 900
```

### 6. CE: quên mật khẩu admin / reset
```bash
docker compose down -v && docker compose up -d    # reset sạch (MẤT dữ liệu)
docker compose logs bloodhound | grep -i "Initial Password"
```

### 7. Neo4j (Legacy) không kết nối
```bash
sudo neo4j console                 # xem log lỗi
# UI nhập đúng bolt://localhost:7687 + mật khẩu đã đổi (không còn neo4j/neo4j)
sudo ss -lntp | grep 7687          # kiểm tra Neo4j đang nghe
```

### 8. "Access denied" khi thu LDAP
- User bị hạn chế đọc một số thuộc tính → vẫn thu được phần lớn; thử user khác,
  hoặc bổ sung bằng SharpHound chạy trong ngữ cảnh domain.

## B. OPSEC — giảm dấu vết

| Rủi ro | Giảm thiểu |
|--------|------------|
| LDAP recon ồn (nhiều truy vấn lạ) | `DCOnly`, `--throttle/--jitter`, SOAPHound (ADWS), AD Explorer snapshot |
| Chạm hàng loạt máy (Session/LocalAdmin) tạo nhiều kết nối SMB | hạn chế `--searchbase`, chỉ chạy khi cần; tách lượt |
| `SharpHound.exe` bị AV/EDR bắt | `SharpHound.ps1` fileless, hoặc thu từ Kali (không chạm Windows) |
| Ghi file zip trên máy nạn nhân | xuất ra thư mục tạm rồi xóa; hoặc thu từ xa |
| `--loop` session rất ồn | chỉ dùng khi thật cần bắt session theo thời gian |

### Collector kín nhất → ồn nhất (xếp hạng)
1. **AD Explorer snapshot** (tool Microsoft ký) — kín nhất, nhưng thiếu session.
2. **SOAPHound** (ADWS thay LDAP) — né nhiều luật LDAP.
3. **bloodhound-ce-python `-c DCOnly`** — chỉ hỏi DC.
4. **SharpHound `-c All`** — đầy đủ nhưng ồn.
5. **SharpHound `-c Session --loop`** — ồn nhất.

## C. Dọn dẹp sau khi thu

```powershell
del *_BloodHound.zip ; del *.bin        # xoá file trên máy Windows
```
```bash
rm -f *_bloodhound.zip output.zip       # trên Kali sau khi đã import
```

## D. Checklist xử lý khi "BloodHound không ra gì"

- [ ] Collector đúng dòng với UI? (v1↔Legacy / v2↔CE)
- [ ] `-ns <dc_ip>` và `/etc/hosts` đúng?
- [ ] Giờ đồng bộ (nếu `-k`)?
- [ ] Credential còn hợp lệ (chưa bị lock/expire)?
- [ ] Cần session/localadmin → chạy đúng method + quyền?
- [ ] Import đúng loại file (zip cho SharpHound, json cho AzureHound)?
