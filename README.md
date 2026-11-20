# PRXYRMM / Docu-2026ReaderPlus.msi — ניתוח סטטי

## מקור

פוסט בפורום [מתמחים.טופ — נושא 104004](https://mitmachim.top/topic/104004) (נמחק).

מייל מחשבון שנפרץ → דף ביניים עם Cloudflare Turnstile → הורדה מ-Dropbox → MSI שמתקין סוכן שליטה מרחוק.

## שרשרת ההדבקה

```
מייל מזויף (חשבון אמיתי שנפרץ, שם השולח+הנמען בפרמטרים של הURL)
  └─ vazt.om0[.]site  (דף ביניים מאחורי Cloudflare Turnstile — חוסם סורקים)
       └─ Dropbox direct download (dl=1, ב-allow-list של רוב הסינונים)
            └─ Docu-2026ReaderPlus.msi  (חתום: PRXY TECHNOLOGIES LLC)
                 └─ PrxyAgent.exe  (שירות SYSTEM, .NET self-contained)
                      ├─ wss://prxyrmm[.]com  (C2 ראשי — WebSocket)
                      ├─ https://prxyrmm[.]com/updates  (ערוץ עדכונים)
                      └─ stage 2: הורדת ScreenConnect ← api.prxyrmm[.]com/api/public/autopush-proxy/
```

## קובץ

| שדה | ערך |
|-----|------|
| שם | `Docu-2026ReaderPlus.msi` |
| גודל | 30,019,584 bytes (~28.6 MB) |
| SHA-256 | `e95bb197a0b40156416720b33b94da2f5035007d9914e43ff2d335666b88ab03` |
| SHA-1 | `eaf548351f83fbccf7a12b963f777fd3da474d21` |
| MD5 | `884b76149e5460ca33d245786c6c9a60` |
| Builder | WiX Toolset 3.14.1.8722 |
| Build time | 2026-11-13 14:01:50 UTC |
| Timestamp | 2026-11-13 14:02:41 UTC (51 שניות אחרי build — pipeline אוטומטי) |
| MSI UUID | `{57EAA095-2339-42A8-B547-0377DFAFA7FB}` |
| Product Code | `{8852C728-8BA0-4F51-A906-7F9F2787514B}` |
| Upgrade Code | `{33333333-3333-3333-3333-333333333333}` |
| גרסה | 1.1.11 |

## חתימה דיגיטלית

| שדה | ערך |
|-----|------|
| Subject | `CN=PRXY TECHNOLOGIES LLC, O=PRXY TECHNOLOGIES LLC, L=Decatur, ST=Illinois, C=US` |
| Issuer | `SSL.com Code Signing Intermediate CA RSA R1` |
| Serial | `0C4645F0F1D8CC36C7E16E9207FC05E4` |
| Valid | Sep 7 2026 — Sep 7 2027 |
| **סטטוס** | **🔴 REVOKED — התעודה בוטלה** |
| Timestamp CA | SSL.com Timestamping Issuing RSA CA 2 |

> בזמן הפצת ה-MSI (13 בנובמבר) החתימה הייתה תקפה. התעודה בוטלה מאז —
> VirusTotal שבדק קודם עוד הציג "valid signature".

## תוכן ה-MSI

ה-MSI מכיל **שני קבצים בלבד** (בתוך cab1.cab, MSZip):

| קובץ | גודל | סוג |
|-------|-------|------|
| `PrxyAgent.exe` | 67,169,656 bytes (~64 MB) | PE32+ x86-64, .NET self-contained |
| `appsettings.json` | 288 bytes | JSON |

### appsettings.json

```json
{
  "Logging": {
    "LogLevel": {
      "Default": "Information",
      "Microsoft": "Warning",
      "Microsoft.Hosting.Lifetime": "Information"
    }
  },
  "ServerUrl": "wss://prxyrmm.com",
  "UpdateUrl": "https://prxyrmm.com/updates",
  "ServiceName": "PRXY RMM Agent"
}
```

### PrxyAgent.exe

אפליקציית .NET self-contained (כל ה-runtime מובנה — לכן 64MB).

Namespace: `PRXY.RMM.Agent`
- `PRXY.RMM.Agent.Program+<Main>d__0` — entry point
- `PRXY.RMM.Agent.Worker+<ExecuteAsync>d__8` — לולאת העבודה הראשית
- `PRXY.RMM.Agent.Worker+<StopAsync>d__9` — עצירה
- `System.Net.WebClient+<DownloadBitsAsync>d__150` — יכולת הורדה

תיאור עצמי: `Professional Remote Monitoring and Management Agent`

Build path: `D:\a\rmm\rmm\RMM-Agent\src\PRXY.RMM.Agent\` — נבנה ב-GitHub Actions CI.

Source repo (לפי metadata): `https://github.com/prxy/rmm-agent` (פרטי/נמחק).

## ארכיטקטורה פנימית של PrxyAgent.exe

### מבנה כללי

אפליקציית .NET 6.0 self-contained (win-x64), בנויה כ-Windows Service דרך `Microsoft.Extensions.Hosting.WindowsServices`. משתמשת ב-Generic Host pattern עם Dependency Injection.

```
PrxyAgent.exe  (.NET 6.0, self-contained single-file, ~64MB)
│
├─ Program.Main()          ← entry point
├─ Worker.ExecuteAsync()   ← Background service loop
│
├─ Services/
│   ├─ WebSocketClient         ← תקשורת C2 (wss://prxyrmm.com)
│   ├─ ManagementService       ← מעבד פקודות מהשרת (18 handlers)
│   ├─ MonitoringService       ← heartbeat + מטריקות + מידע מערכת
│   ├─ UpdateService           ← עדכון עצמי עם אימות חתימה
│   ├─ DeviceRegistration      ← רישום מכשיר מול השרת
│   ├─ FleetHygieneService     ← סריקת תוכנות מותקנות
│   └─ AgentTelemetry          ← טלמטריה
│
├─ Models/                 ← מודלים לסריאליזציה (Newtonsoft.Json)
└─ appsettings.json        ← ServerUrl, UpdateUrl, ServiceName
```

### שירותים

#### WebSocketClient — תקשורת C2

| method | תפקיד |
|--------|--------|
| `ConnectAsync` | מתחבר ל-`wss://prxyrmm.com` |
| `DisconnectAsync` | מתנתק |
| `SendMessageAsync` | שולח הודעה לשרת |
| `ReceiveMessageAsync` | מקבל פקודות |
| `GetDeviceIdAsync` | מזהה מכשיר ייחודי |

פרוטוקול: WebSocket (לא SignalR), סריאליזציה ב-JSON (Newtonsoft.Json 13.0.3).

#### ManagementService — מעבד פקודות (הליבה)

זה הרכיב המרכזי — מקבל פקודות מה-C2 ומבצע:

| Handler | מה עושה | סיכון |
|---------|---------|-------|
| `HandleCreateSession` | פותח shell session מרחוק | 🔴 |
| `HandleSessionInput` | שולח קלט ל-shell פתוח | 🔴 |
| `HandleCloseSession` | סוגר shell session | |
| `PumpSessionStreamAsync` | סטרימינג פלט shell בזמן אמת | 🔴 |
| `HandleRunScript` | מריץ סקריפט (PowerShell/cmd) | 🔴 |
| `HandleGetProcesses` | מחזיר רשימת תהליכים | 🟡 |
| `HandleKillProcess` | הורג תהליך | 🔴 |
| `HandleGetServices` | מחזיר רשימת שירותים | 🟡 |
| `HandleServiceAction` | מפעיל/עוצר/משנה שירותים | 🔴 |
| `HandleGetRegistry` | קורא מפתחות רגיסטרי | 🟡 |
| `HandleGetFiles` | מחזיר רשימת קבצים | 🟡 |
| `HandleFileOperation` | פעולות על קבצים (העתקה/מחיקה/הורדה/העלאה) | 🔴 |
| `HandleGetEventLogs` | קורא Event Log | 🟡 |
| `HandleGetSoftware` | רשימת תוכנות מותקנות | 🟡 |
| `HandleGetWindowsUpdates` | בודק עדכוני Windows | 🟡 |
| `HandleInstallUpdates` | מתקין עדכוני Windows | 🔴 |
| `HandleGetScheduledTasks` | מחזיר Scheduled Tasks | 🟡 |
| `HandleUninstallAgent` | מסיר את עצמו | ⚪ |
| `HandlePing` | בדיקת חיות | ⚪ |

> **סה"כ: 18 handlers שנותנים שליטה מלאה על המחשב** — shell, קבצים, תהליכים, שירותים, רגיסטרי, סקריפטים, ו-Windows Updates.
> רץ כ-LocalSystem — אין שום הגבלת הרשאות.

#### MonitoringService — ניטור

| method | תפקיד |
|--------|--------|
| `StartMonitoringAsync` | מתחיל לולאת ניטור |
| `SendHeartbeatAsync` | שולח heartbeat לשרת (המכשיר חי) |
| `SendMetricsAsync` | שולח מטריקות (CPU, RAM, דיסק) |
| `SendSystemInfoAsync` | שולח מידע מערכת (OS, חומרה) |

#### UpdateService — עדכון עצמי

| method | תפקיד |
|--------|--------|
| `CheckForUpdatesAsync` | בודק `https://prxyrmm.com/updates` |
| `GetUpdateOfferAsync` | מקבל הצעת עדכון |
| `DownloadUpdateAsync` | מוריד חבילת עדכון |
| `VerifyPackageSignaturesAsync` | מאמת חתימה דיגיטלית |
| `InstallUpdateAsync` | מתקין את העדכון |
| `GetExpectedHashAsync` | מאמת hash |
| `ReportUpdateEventAsync` | מדווח על תוצאת העדכון |

> יש אימות חתימה — אבל מי שמחזיק את שרת העדכונים שולט בחבילות.

#### DeviceRegistration — רישום

| method | תפקיד |
|--------|--------|
| `RegisterDeviceAsync` | רישום ראשוני |
| `RegisterWithServerAsync` | רישום מול C2 |
| `GetDeviceIdAsync` / `SaveDeviceIdAsync` | מזהה מכשיר |
| `ForceReregisterAsync` | רישום מחדש |

> משתמש ב-`OrganizationId` וב-`RegistrationToken` מהרגיסטרי — כל הקורבנות נרשמים לאותו ארגון.

#### FleetHygieneService — סריקת מלאי

| method | תפקיד |
|--------|--------|
| `ScanAndReportAsync` | סורק ומדווח תוכנות מותקנות |
| `ProgramFilesRoots` | סורק Program Files |
| `EnumerateUninstallEntries` | סורק Uninstall entries ברגיסטרי |

> מדווח לשרת מה מותקן — מאפשר לתוקף לתכנן מתקפות מותאמות.

### ספריות חיצוניות מרכזיות

| ספרייה | גרסה | שימוש |
|--------|-------|-------|
| Newtonsoft.Json | 13.0.3 | סריאליזציה (C2 protocol) |
| Microsoft.Extensions.Http | 6.0.0 | HTTP client (הורדות) |
| Microsoft.Extensions.Hosting.WindowsServices | 6.0.1 | הפעלה כ-Windows Service |
| System.ServiceProcess.ServiceController | 6.0.1 | ניהול שירותים |
| System.Management | 6.0.1 | WMI queries |
| System.Diagnostics.EventLog | 6.0.0 | קריאת Event Logs |
| System.Diagnostics.PerformanceCounter | 6.0.1 | מטריקות ביצועים |
| System.Net.WebSockets.Client | 4.3.2 | WebSocket C2 |
| System.Drawing.Common | 6.0.0 | אפשרי: צילומי מסך |

### DLLs מקוריים (native)

| DLL | שימוש |
|-----|-------|
| `advapi32.dll` | רגיסטרי, שירותים, אבטחה |
| `wevtapi.dll` | Event Log API |
| `pdh.dll` | Performance Data Helper (מטריקות) |
| `wtsapi32.dll` | Terminal Services API (sessions) |
| `winhttp.dll` | HTTP/WebSocket |
| `crypt32.dll` | אימות חתימות |
| `user32.dll` | שימוש ב-GUI/screenshots |

### סיכום יכולות

```
┌───────────────────────────────────────────────┐
│          PRXY RMM Agent — יכולות              │
├───────────────────────────────────────────────┤
│ 🖥️  Remote Shell — שורת פקודה מרחוק         │
│ 📜 Script Execution — PowerShell/CMD          │
│ 📁 File Operations — העתקה/מחיקה/הורדה/העלאה │
│ ⚙️  Process Management — רשימה/הריגה          │
│ 🔧 Service Control — הפעלה/עצירה/שינוי       │
│ 📋 Registry Access — קריאה                    │
│ 📊 System Monitoring — CPU/RAM/דיסק          │
│ 📦 Software Inventory — מה מותקן             │
│ 🔄 Windows Updates — בדיקה+התקנה             │
│ ⏰ Scheduled Tasks — ספירה                    │
│ 📰 Event Logs — קריאה                        │
│ 🔄 Self-Update — עדכון עצמי חתום             │
│ 🗑️  Self-Uninstall — הסרה עצמית              │
│ 📡 Stage 2 — הורדת ScreenConnect              │
└───────────────────────────────────────────────┘
```

> **שורה תחתונה**: זה סוכן RMM מלא שנותן שליטה מוחלטת על המחשב.
> הקוד עצמו אינו obfuscated — זה מוצר RMM "לגיטימי" שנמכר לתוקפים.
> הזדוניות בשימוש, לא בקוד: מותקן דרך פישינג, מכוון לשרת C2 של התוקף,
> ומוריד ScreenConnect כ-stage 2 לגישה אינטראקטיבית.

## התנהגות ה-MSI (סטטי)

### שירות Windows

| שדה | ערך |
|-----|------|
| שם שירות | `PRXY RMM Agent` |
| תצוגה | `Docu-2026ReaderPlus` |
| סוג | SERVICE_OWN_PROCESS (16) |
| התחלה | Automatic (2) |
| חשבון | `LocalSystem` |
| ארגומנטים | `--service` |
| תלויות | Tcpip, Dnscache, Winmgmt |
| תיאור | "Docu-2026ReaderPlus - Remote Monitoring and Management Agent for IT administration" |

> **StartType=2 (Automatic) + LocalSystem** — השירות עולה אוטומטית בעליית המחשב עם הרשאות מלאות.
> תלות ב-Tcpip+Dnscache מבטיחה שרשת זמינה לפני שה-agent מתחבר ל-C2.

### רגיסטרי

```
HKLM\SOFTWARE\PRXY TECHNOLOGIES\PRXY RMM Agent
    OrganizationId = b1ccb6e6-b63e-44e4-b737-35900bd71cd4
    RegistrationToken = 1793582247758.0651f203fa9b8f2c97489f54e9821bfe2c7aa46b45fcd0bb

HKCU\Software\PRXY TECHNOLOGIES\PRXY RMM Agent
    installed = 1
```

> `OrganizationId` ו-`RegistrationToken` hardcoded ב-MSI — כל הקורבנות נרשמים לאותו ארגון בפאנל של התוקף.
> ה-LaunchCondition דורש את שני הערכים, מה שמעיד שזה מיועד להתקנה שקטה (msiexec /qn).

### CustomAction

אין שום CustomAction זדוני ב-MSI עצמו! כל ה-CA הם WiX סטנדרטיים:

- `SchedServiceConfig` / `ExecServiceConfig` / `RollbackServiceConfig` — הגדרת השירות
- `SchedSecureObjects` / `ExecSecureObjects` — הרשאות DACL

> **אין PowerShell, אין curl, אין הורדה ב-MSI.**
> הנוזקה כולה ב-PrxyAgent.exe — שירות לגיטימי-למראה שמתחבר ל-C2.
> הסנדבוקסים שדיווחו על PowerShell -EncodedCommand ו-curl ראו ככל הנראה
> את ה-agent בפעולה אחרי ההתקנה (stage 2 — הורדת ScreenConnect מ-api.prxyrmm.com).

## מה קורה אחרי ההתקנה (מסנדבוקסים)

על פי דוחות CAPE/Zenbox/Jujubox ב-VirusTotal (לא מהניתוח הסטטי):

1. PrxyAgent.exe מתחבר ב-WebSocket ל-`wss://prxyrmm[.]com`
2. מקבל פקודה להוריד stage 2 דרך `api.prxyrmm[.]com/api/public/autopush-proxy/<UUID>`
3. מוריד `sc-<id>.zip` (ScreenConnect) ומתקין `fix-<id>.msi` בשקט
4. ScreenConnect מתחבר ל-relay של התוקף (`gracioushope[.]com`)
5. התוקף מקבל שליטה אינטראקטיבית מלאה + ScreenConnect נרשם ב-SafeBoot

## IOCs

### דומיינים
| דומיין | תפקיד |
|--------|--------|
| `vazt.om0[.]site` | דף פישינג (Cloudflare Turnstile) |
| `prxyrmm[.]com` / `api.prxyrmm[.]com` | C2 + פאנל ניהול (רשום 2026-08-03, Dynadot) |
| `gracioushope[.]com` | ScreenConnect relay |

### IP
| IP | הערה |
|----|-------|
| `95.133.230[.]225` | gracioushope |
| `172.67.195[.]198` / `104.21.60[.]103` | Cloudflare — לא לחסום |

### תעודה
| שדה | ערך |
|-----|------|
| Serial | `0C4645F0F1D8CC36C7E16E9207FC05E4` |
| Thumbprint/SHA256 | (ב-msi-sig.pem) |
| Subject | PRXY TECHNOLOGIES LLC, Decatur IL |

### קבצי Payload
| קובץ | SHA-256 | VT |
|-------|---------|-----|
| `Docu-2026ReaderPlus.msi` | `e95bb197...` | 0/62 |
| `PrxyAgent.exe` (בתוך ה-MSI) | `299b5f376ff3f6e3...` (partial) | — |
| `sc-<id>.zip` (stage 2) | — | 10/66 |
| `fix-<id>.msi` (stage 2) | — | 13/62 |

### מפתחות רגיסטרי
```
HKLM\SOFTWARE\PRXY TECHNOLOGIES\PRXY RMM Agent\OrganizationId
HKLM\SOFTWARE\PRXY TECHNOLOGIES\PRXY RMM Agent\RegistrationToken
HKCU\Software\PRXY TECHNOLOGIES\PRXY RMM Agent\installed
```

### שירותים
```
PRXY RMM Agent  (PrxyAgent.exe --service)
ScreenConnect Client (*)  (stage 2)
```

## Hunting

- שירות `PRXY RMM Agent` / `ScreenConnect Client (<hex>)` שה-IT לא התקין
- מפתח רגיסטרי `PRXY TECHNOLOGIES\PRXY RMM Agent`
- DNS queries ל-`prxyrmm.com` / `gracioushope.com`
- WebSocket connection ל-`wss://prxyrmm.com`
- `msiexec.exe` מתקין מוצר "Docu-2026ReaderPlus"
- Upgrade Code `{33333333-3333-3333-3333-333333333333}` (GUIDs חשודים — 3333...3333, 4444...4444, 5555...5555, 6666...6667)

## למה 0/62?

| רכיב | למה "נקי" |
|-------|----------|
| דף הקישור | Cloudflare Turnstile — סורקים לא עוברים |
| Dropbox | allow-list של כל סינון |
| MSI | חתום בתעודה תקפה (באותו זמן) |
| PrxyAgent.exe | .NET self-contained, אין shellcode, אין obfuscation |
| אין CA זדוני ב-MSI | כל ה-CustomActions הם WiX סטנדרטיים |
| ScreenConnect | מוצר מסחרי חתום, מיליוני התקנות לגיטימיות |

> הזדוניות כולה בקונפיגורציה — לאיזה שרת ה-agent מתחבר, ולא בקוד עצמו.

## תיקונים למה שפורסם בפורום

הניתוח של חכמון (מבוסס על דוחות סנדבוקס) קרוב מאוד, עם כמה הבהרות:

1. **ה-MSI לא מריץ PowerShell** — ה-PowerShell ו-curl רצים מתוך PrxyAgent.exe אחרי ההתקנה (stage 2), לא מה-MSI עצמו
2. **Stage 1 הוא PRXY Agent, לא ScreenConnect** — ScreenConnect הוא stage 2 שנמשך מהשרת
3. **Timestamp הוא 51 שניות** (לא 10) — build ב-14:01:50, חתימה ב-14:02:41
4. **התעודה בוטלה** — `Signature CRL verification: failed` ← מאושר, לא רק לפי Triage

## נדבקתם? מה עושים

1. **לנתק מהרשת מיד**
2. **ממכשיר אחר** — להחליף סיסמה למייל + אימות דו-שלבי. אח"כ בנק ושאר
3. **לבדוק במחשב הנגוע** (מנותק!):
   - שירות `PRXY RMM Agent`
   - שירות `ScreenConnect Client`
   - רגיסטרי: `PRXY TECHNOLOGIES`
   - תוכנה: `Docu-2026ReaderPlus`
4. **לפרמט** — אי אפשר לסמוך על ניקוי ידני אחרי גישת SYSTEM
5. **לגבות רק מסמכים** — לא EXE, לא MSI, לא installer
6. **להודיע לאנשי קשר** — הם הבאים בתור

---

*ניתוח סטטי לצרכי הגנה ומודעות. הקובץ לא הורץ — ניתוח רץ ב-GitHub Actions בלבד.*

*raw results: [Actions artifacts](../../actions)*
