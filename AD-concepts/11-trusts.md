# 11 — Trusts (quan hệ tin cậy)

## Trust là gì
**Định nghĩa:** quan hệ cho phép principal của **domain A** được xác thực &
truy cập tài nguyên ở **domain B**.

**Chi tiết:** trust thiết lập **inter-realm key** chung giữa 2 domain → KDC cấp
**referral ticket** để nhảy realm. Hiểu trust để biết đường **nhảy domain/forest**.

*Tài liệu gốc:* [How trusts work](https://learn.microsoft.com/windows-server/identity/ad-ds/manage/how-domain-and-forest-trusts-work),
[[MS-ADTS] Trusts](https://learn.microsoft.com/openspecs/windows_protocols/ms-adts/).

---

## Hướng (direction)
**Định nghĩa:** trust một chiều hay hai chiều.
- **One-way:** A tin B → principal **B** truy cập tài nguyên **A** (hướng tin cậy
  ngược hướng truy cập — dễ nhầm!).
- **Two-way:** cả hai cùng tin nhau.

*Ví dụ:* "A trusts B" (A→B) nghĩa là user của B dùng được tài nguyên của A.

---

## Transitivity (bắc cầu)
**Định nghĩa:** trust có lan truyền hay không.
- **Transitive:** A tin B, B tin C → A tin C (mặc định trong forest).
- **Non-transitive:** chỉ giữa đúng 2 domain (vd external trust, realm trust).

---

## Các loại trust
| Loại | Phạm vi | Transitive? | Ghi chú |
|------|---------|-------------|---------|
| **Parent-Child** | giữa domain cha-con cùng forest | ✅ | tạo tự động khi thêm domain con |
| **Tree-Root** | giữa các tree-root trong 1 forest | ✅ | nối namespace khác nhau |
| **Shortcut** | giữa 2 domain cùng forest | ✅ | rút ngắn đường xác thực |
| **External** | giữa 2 domain khác forest | ❌ | thường có **SID filtering** |
| **Forest** | giữa 2 forest (root↔root) | ✅ (trong phạm vi forest trust) | SID filtering mặc định |
| **Realm** | giữa AD và Kerberos non-Windows (MIT) | tùy | ít gặp |

---

## SID Filtering
**Định nghĩa:** cơ chế **loại bỏ SID "lạ"** (ngoài domain nguồn) trong token khi
đi qua trust → chống **SID history injection**.

**Chi tiết:**
- **Trong cùng forest:** SID filtering **không áp** cho SID history → cho phép
  **child→parent escalation** (thêm `EnterpriseAdmins-519` vào golden ticket).
- **External/Forest trust:** SID filtering **bật mặc định** → chỉ SID thuộc
  domain nguồn qua được; với forest trust, SID nhóm **> 1000** (không phải
  built-in) vẫn qua nếu bật *SID history*.

*Tài liệu:* [Security considerations for trusts / SID filtering](https://learn.microsoft.com/windows-server/identity/ad-ds/plan/security-best-practices/appendix-b--privileged-accounts-and-groups-in-active-directory).

---

## SID History
**Định nghĩa:** thuộc tính `sIDHistory` giữ SID cũ của principal khi **migrate**
giữa domain → giữ nguyên quyền truy cập tài nguyên cũ.

**Chi tiết tấn công:** nếu forge được token/ticket có `sIDHistory` =
`<root>-519` (Enterprise Admins), và SID filtering không chặn (nội forest) →
chiếm forest. Đây là lõi của **child→parent escalation**.

*Ví dụ (golden ticket + extra SID):*
```bash
ticketer.py -nthash <child_krbtgt> -domain-sid <child_sid> -domain child.corp.local \
  -extra-sid <root_sid>-519 fakeadmin
```

---

## Trust key & Trust ticket
**Định nghĩa:** inter-realm key (mật khẩu của trust account `B$`) → forge
**inter-realm TGT** (trust ticket) để truy cập domain tin cậy.

*Ví dụ lấy trust key:*
```bash
secretsdump.py -just-dc-user 'corp.local\CORP$' corp.local/alice:'pass'@dc01   # trust account
mimikatz lsadump::trust /patch
```

---

## Thực hành enum trust
```powershell
nltest /domain_trusts /all_trusts
Get-DomainTrust ; Get-DomainTrustMapping        # PowerView
Get-ADTrust -Filter *
```
```cypher
MATCH p=(:Domain)-[:TrustedBy]->(:Domain) RETURN p   // BloodHound
```

Khai thác chuỗi trust chi tiết: [mindmaps/13](../mindmaps/AD-2025.03/13-trusts.md).

*Tài liệu bổ sung:* [adsecurity.org — Trust attacks](https://adsecurity.org/?p=1588),
[The Hacker Recipes — Trusts](https://www.thehacker.recipes/ad/movement/trusts).
