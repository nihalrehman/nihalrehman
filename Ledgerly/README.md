# Ledgerly — Private Expense Tracker for iOS

A native SwiftUI app for logging every expense and managing your whole financial picture: day‑to‑day spending, budgets, bills, savings goals, and debts like mortgages, car loans and credit cards. Everything stays on your device and is encrypted.

## Features

| Area | What you can do |
|---|---|
| **Transactions** | Log expenses, income and transfers between accounts. Search, filter by type/account/category/month, duplicate, swipe to delete. |
| **Categories** | 16 expense groups with 69 subcategories ready to use (see below), plus 8 income categories. Add, rename, recolor, re‑icon or nest your own. |
| **Overview** | Monthly cash flow, savings rate, net worth, spending donut chart, daily spending chart with average, budget status, upcoming bills, goals and recent activity. One tap hides all amounts. |
| **Budgets** | Monthly limits for any category group, a single subcategory, or all spending. Shows warnings at a threshold you choose (e.g. 80%), what's left, and a safe amount to spend per day. |
| **Debts** | Home mortgage, car loan, credit card, personal, student, business and medical debt. Monthly payment (EMI) calculator, payoff date, interest still to pay, full amortization schedule, a "what if I pay more" slider, credit utilization, and an avalanche/snowball payoff plan. Recording a payment splits it into principal and interest and can log it as an expense too. |
| **Accounts** | Cash, current/checking, savings, credit cards, digital wallets, investments. Balances update from transactions; transfers move money between them. |
| **Bills & recurring** | Rent, utilities, subscriptions, school fees, salary, and so on. Daily to yearly schedules. They can be logged automatically when due, or you can mark them paid or skip them. Optional reminders. |
| **Savings goals** | Targets with deadlines, progress, and how much to save each month to get there. |
| **Reports** | Income vs. expenses by month, spending by category or subcategory, top merchants, income sources, average monthly spend. Covers this month up to the last 12 months. |
| **Profile** | Your personal details (name, contact, address, date of birth, ID/tax number, employer, income). All of it is encrypted. |
| **Data** | CSV export, password‑encrypted backup and restore (for moving to a new phone), and a secure erase that wipes everything. |

### Built‑in expense categories

Housing (rent, mortgage, property tax, home insurance, maintenance, service charges) · Household (furniture, appliances, supplies, cleaning, decor, domestic help) · Utilities (electricity, water, gas, internet, mobile, TV) · Food & Dining (groceries, eating out, coffee, delivery) · Transport (fuel, public transit, taxi, parking & tolls, car maintenance, car insurance, car loan, registration & fines) · Shopping · Health · Education · Entertainment · Travel · Family & Kids · Pets · Debt Payments · Financial & Fees · Giving · Miscellaneous.

## Security

Personal financial data needs more than one layer of protection, so Ledgerly uses several:

1. **Stays on the device.** There is no account, no server, no analytics and no third‑party SDK. CloudKit sync is explicitly turned off. The app makes no network requests.
2. **Encrypted database (iOS Data Protection).** The SwiftData store sits in its own folder with `NSFileProtectionCompleteUnlessOpen`. iOS encrypts it with a key tied to your device passcode, so it can't be read while the phone is locked.
3. **Field‑level AES‑256‑GCM encryption.** Fields that could identify you are encrypted again before they are saved: all profile details, account and card numbers, bank/lender names, payees and every note. This uses authenticated encryption (CryptoKit) with a fresh random nonce for each value, so any tampering is detected.
4. **Key kept in the Keychain.** The 256‑bit data key is created on the device and stored in the Keychain as `WhenUnlockedThisDeviceOnly`. It is never synced to iCloud Keychain and never included in backups. It is only held in memory while the app is unlocked.
5. **App lock.** Face ID or Touch ID, with the device passcode as a fallback. You can set auto‑lock to happen immediately or after a delay. While the app is locked, none of the data screens are even created.
6. **Privacy screen and masking.** The app's content is covered in the app switcher. Account numbers, ID numbers, email, phone, address and date of birth are masked until you authenticate again. "Hide amounts" mode hides every figure.
7. **Discreet notifications.** Bill reminders never mention a bill's name or amount.
8. **Backups are off by default.** The store is excluded from iCloud and computer backups (you can change this). To move to a new phone, use an **encrypted Ledgerly backup**: AES‑256‑GCM with a key derived from your password using PBKDF2‑HMAC‑SHA256 (600,000 rounds) and a random salt.
9. **Safer exports.** Exporting, backing up, restoring and erasing all require Face ID or your passcode. CSV files are written with complete file protection to a temporary folder that is cleared on the next launch. Cells are escaped so a spreadsheet can't treat them as formulas.
10. **Secure erase.** Deletes every record and then destroys the encryption key, so any leftover encrypted data on disk can never be read.

> ⚠️ Security on iOS depends on your device having a passcode. Without one, iOS cannot encrypt files, and Ledgerly will tell you that App Lock can't be turned on.

## Requirements

- Xcode 16 or later (the project uses folder‑synchronized groups)
- iOS 17.0+ (iPhone and iPad)

## Running it

1. Open `Ledgerly/Ledgerly.xcodeproj` in Xcode.
2. Select the **Ledgerly** target → *Signing & Capabilities*. Choose your Team and, if needed, change the bundle identifier (`com.nihalrehman.ledgerly`) to one that is unique to you.
3. Pick a simulator or your iPhone and press **Run** (⌘R). To use it on your own iPhone, enable Developer Mode on the phone the first time.
4. Run the tests with ⌘U. They cover encryption, password‑based backups, masking, CSV escaping, loan maths and recurrence.

New Swift files you add inside the `Ledgerly/` folder are picked up automatically. You don't need to edit the project file.

## Project layout

```
Ledgerly/
├── Ledgerly.xcodeproj
├── Ledgerly/
│   ├── App/            App entry, root view, lock screen, onboarding, tabs
│   ├── Models/         SwiftData models (transactions, categories, accounts, budgets,
│   │                   recurring rules, loans & payments, goals, profile)
│   ├── Security/       Keychain, AES-GCM field crypto, PBKDF2 backup crypto,
│   │                   app lock (LocalAuthentication), file protection, masking
│   ├── Services/       Persistence, seed data, loan calculator, analytics,
│   │                   recurrence engine, reminders, CSV export, backups, erase
│   ├── Utilities/      Settings keys, formatting and colour helpers
│   └── Views/          Dashboard, Transactions, Budgets, Debts, Accounts, Goals,
│                       Recurring, Reports, Categories, Profile, Settings
└── LedgerlyTests/      Unit tests
```

## Ideas for later

- Scanning receipts with VisionKit
- Splitting one receipt across several categories
- Multiple currencies with exchange rates
- Home‑screen widgets and Siri / App Intents ("log 50 for fuel")
- Optional end‑to‑end encrypted iCloud sync
