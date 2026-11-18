# NAS2 SMB NetBackup 공유폴더 장애 수정완료보고서 v2026-11-17

> 원인보고서: `docs/보고서/NAS2_SMB_NetBackup_장애_원인보고서_v2026-11-17.md`
> 대상: **NAS2** — Synology DS1019+, DSM **7.4.1-90080 Update 1**, Samba 4.15.13-4251
> 작업일시: 2026-11-17 18:15 ~ 18:19 (KST)
> 작업 계정: `atom` + `sudo`
> 결과: **✅ 완료 — SMB 인증 복구, NetBackup 목록 표시/읽기/쓰기 정상**

---

## 1. 수정 내역 (원인 대비)

| ID | 원인 | 조치 내용 | 대상 | 상태 |
|----|------|-----------|------|------|
| F-1 | smb.conf `include` 위치 오류 | `include` 대상을 `smb.share.conf` → `smb.netbios.aliases.conf`로 원복 | `/etc/samba/smb.conf` | ✅ 완료 |
| F-2 | 설정 반영 | smbd 재시작 | `pkg-synosamba-smbd` | ✅ 완료 |
| F-3 | ACL 그룹 deny | ACE `group:SmartCC_Kibal:deny` 삭제 (index 1) | `/volume1/NetBackup` | ✅ 완료 |
| F-4 | 공유 권한 확인 | ACL RW 목록에 임상택/@관리자/atom 확인 | `synoshare NetBackup` | ✅ 확인 |

### F-1. smb.conf 수정

```diff
 [global]
 	printcap name=cups
 	winbind enum groups=yes
-	include=/etc/samba/smb.share.conf
+	include=/var/tmp/nginx/smb.netbios.aliases.conf
 	fruit:locking=netatalk
 	encrypt passwords=yes
 	...
 ```

적용 명령:

```bash
cp -a /etc/samba/smb.conf /etc/samba/smb.conf.bak.20261117181511
sed -i 's#^[[:space:]]*include=/etc/samba/smb.share.conf#\tinclude=/var/tmp/nginx/smb.netbios.aliases.conf#' /etc/samba/smb.conf
```

### F-2. SMB 서비스 재시작

```bash
systemctl restart pkg-synosamba-smbd
# 결과: active
```

### F-3. ACL deny ACE 제거

```bash
synoacltool -get /volume1/NetBackup > /root/acl_NetBackup.20261117181739.txt
synoacltool -del /volume1/NetBackup 1      # ACE [1] group:SmartCC_Kibal:deny
```

> 계정 단위가 아닌 **그룹 ACE 단위** 수정이므로, `SmartCC_Kibal` 구성원(atom, 임상택, 박주홍) 전체에 적용됨. `user:박주홍:deny`, `user:admin:deny`, `user:AIbot:deny`, `user:guest:deny`는 별도 ACE로 그대로 유지됨.

---

## 2. 검증 결과

| 항목 | 결과 |
|---|---|
| `testparm -s -v` — `passdb backend` | ✅ `smbpasswd` |
| `testparm -s -v` — `security` / `workgroup` / `fruit:locking` | ✅ `USER` / `WORKGROUP` / `netatalk` |
| `pdbedit -L` | ✅ **7개 계정 조회** (임상택, guest, atom, AIbot, AI-Master, admin, 박주홍) |
| `smbclient -L 127.0.0.1 -U atom` | ✅ 로그인 성공, **NetBackup 목록 표시** |
| `smbclient //127.0.0.1/NetBackup -U atom -c ls` | ✅ Home, NEW_stock_reports, gitRepo, 보관함, sparsebundle 조회 |
| SMB 쓰기 테스트 (put → ls → del) | ✅ 성공 |
| OS 레벨 접근 (`sudo -u atom ls`) | ✅ OK |
| OS 레벨 접근 (`sudo -u 임상택 ls`) | ✅ OK |
| `systemctl is-active pkg-synosamba-smbd` / `nmbd` | ✅ active / active |

### 검증 스냅샷

```
Sharename       Type      Comment
---------       ----      -------
homes           Disk      user home
NetBackup       Disk      System default shared folder
IPC$            IPC       IPC Service ()
home            Disk      Home directory of atom
```

```
passdb backend = smbpasswd
security = USER
workgroup = WORKGROUP
fruit:locking = netatalk
```

---

## 3. 백업 및 롤백

| 구분 | 경로 |
|---|---|
| smb.conf 백업 | `/etc/samba/smb.conf.bak.20261117181511` |
| NetBackup ACL 백업 | `/root/acl_NetBackup.20261117181739.txt` |

롤백 절차(필요 시):

```bash
cp -a /etc/samba/smb.conf.bak.20261117181511 /etc/samba/smb.conf
systemctl restart pkg-synosamba-smbd
# ACL은 백업 파일 내용을 참고해 synoacltool -add 로 복원
```

---

## 4. 잔여 사항 / 후속 조치

| # | 항목 | 담당 | 비고 |
|---|------|------|------|
| R-1 | **12개 공유폴더의 `group:SmartCC_Kibal:deny` 잔존** | 정책 결정 후 조치 | ActiveBackupforBusiness, docker, music, NAS_문서_공유함, NAS_연구개발자료공유폴더, photo, stock_reports, video, web, web_packages, 모두의_폴더, 보안_자료실 |
| R-2 | 재부팅 후 `smb.conf` include 줄 재확인 | 운영 | 재생성 시 재발 가능 |
| R-3 | 재발 시 대응 | 운영 | `NAS_공유폴더_smb수정_프롬프트_v1.0.md` 사용 |
| R-4 | 임상택 계정 실제 SMB 로그인 검증 | 운영 | ACL상 허용, 비밀번호 미보유로 미검증 |
| R-5 | 공유된 계정 비밀번호 교체 | 보안 | 채팅으로 전달된 비밀번호 |

> 참고: `synoshare --get NetBackup`의 legacy `Deny list`에는 임상택이 남아 있으나, 해당 공유는 `skip smb perm=yes`(ACL 기반)로 운영되어 실제 접근제어는 파일시스템 ACL이 담당합니다. SMB 설정과 ACL의 표기 불일치는 DSM이 자동 생성하는 값으로, 필요 시 DSM UI 권한 화면에서 재적용하면 정합됩니다.

---

## 5. 변경 파일 목록

| 구분 | 파일/항목 | 변경 |
|---|---|---|
| 설정 | `/etc/samba/smb.conf` | include 1줄 원복 |
| 권한 | `/volume1/NetBackup` ACL | `group:SmartCC_Kibal:deny` 1개 삭제 |
| 백업 | `/etc/samba/smb.conf.bak.20261117181511` | 신규 |
| 백업 | `/root/acl_NetBackup.20261117181739.txt` | 신규 |
| 서비스 | `pkg-synosamba-smbd` | 재시작 (수 초 순단) |

---

## 6. 결론

- SMB 인증 장애와 NetBackup ACL 차단을 모두 해소하여 **atom 계정 기준 NetBackup 접근(목록/읽기/쓰기)이 정상**임을 확인했습니다.
- 다만 원인 2(그룹 deny)는 **12개 공유폴더에 동일하게 남아 있고 적용 출처를 특정하지 못했으므로**, 재발 감시와 정책 결정이 필요합니다.
- 재발 시에는 `NAS_공유폴더_smb수정_프롬프트_v1.0.md`를 AI 에이전트에 그대로 전달하면 동일 절차로 진단·수정할 수 있습니다.
