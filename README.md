# PRXYRMM / Docu-2026ReaderPlus.msi — ניתוח סטטי

## מקור

פוסט בפורום [מתמחים.טופ — נושא 104004](https://mitmachim.top/topic/104004) (נמחק).

מייל מחשבון שנפרץ → דף ביניים עם Cloudflare Turnstile → הורדה מ-Dropbox → MSI שמתקין שליטה מרחוק.

## שרשרת ההדבקה

```
מייל מזויף (חשבון אמיתי שנפרץ)
  └─ vazt.om0[.]site  (דף ביניים + Cloudflare verification)
       └─ Dropbox direct download (dl=1)
            └─ Docu-2026ReaderPlus.msi  (חתום: PRXY TECHNOLOGIES LLC)
                 └─ PowerShell -EncodedCommand  (המסך השחור)
                      └─ curl → api.prxyrmm[.]com/api/public/autopush-proxy/<UUID>
                           └─ sc-<id>.zip → fix-<id>.msi  (ScreenConnect)
                                └─ שליטה מרחוק קבועה (SYSTEM, שורד Safe Mode)
```

## קובץ

| שדה | ערך |
|-----|------|
| שם | `Docu-2026ReaderPlus.msi` |
| גודל | 30,019,584 bytes |
| SHA-256 | `e95bb197a0b40156416720b33b94da2f5035007d9914e43ff2d335666b88ab03` |
| SHA-1 | `eaf548351f83fbccf7a12b963f777fd3da474d21` |
| MD5 | `884b76149e5460ca33d245786c6c9a60` |
| Builder | WiX Toolset 3.14 |
| Build time | 2026-11-13 14:01:50 UTC |
| Signed | 2026-11-13 14:02:00 UTC (10 שניות אחרי build) |
| Signer | PRXY TECHNOLOGIES LLC |
| Issuer | SSL.com Code Signing Intermediate CA RSA R1 |

## IOCs

### דומיינים
- `vazt.om0[.]site` — דף פישינג (Cloudflare)
- `prxyrmm[.]com` / `api.prxyrmm[.]com` — C2 panel (רשום 2026-08-03, Dynadot)
- `gracioushope[.]com` — ScreenConnect relay

### IPs
- `95.133.230[.]225` — gracioushope
- `172.67.195[.]198`, `104.21.60[.]103` — Cloudflare (לא לחסום)

### Payload
- `sc-<id>.zip` (5.5MB, 10/66 VT)
- `fix-<id>.msi` (12.8MB, 13/62 VT)

## ניתוח

> הניתוח הסטטי רץ ב-GitHub Actions — ראו artifacts ב-workflow run.
>
> הממצאים יתעדכנו כאן אחרי שה-workflow ירוץ.

---

*ניתוח לצרכי הגנה ומודעות בלבד. הקובץ לא הורץ — ניתוח סטטי בלבד.*
