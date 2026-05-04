# Zen Spend

Modern personal finance tracker for Flutter course.

Requirements covered:
- Dart + Flutter
- Bloc state management
- Backend request: DummyJSON products API for starter transactions
- Master page: transaction list/dashboard
- View page: transaction details
- Add transaction
- Edit transaction
- Delete transaction
- Local saving with SharedPreferences
- Search and filters

## Main Features

- View all transactions
- Add a new income or expense
- Edit transaction details
- Delete transactions
- Search transactions by title or category
- Filter transactions by:
    - All
    - Income
    - Expense
- Save transactions locally using SharedPreferences
- Load initial data from backend API
- Modern Gen Z style user interface

Run:
```powershell
flutter create zen_spend_app
```
Then replace `pubspec.yaml` and `lib/main.dart` with files from this zip

```powershell
cd C:\zen_spend_app
flutter clean
flutter pub get
flutter run -d chrome
```

For Android emulator:
```powershell
flutter devices
flutter run
```
<img width="1919" height="885" alt="image" src="https://github.com/user-attachments/assets/6afa3084-930e-4668-be38-29071f3bfb22" />

How the App Works

When the app starts, it sends a request to the DummyJSON backend
The received data is transformed into finance transactions

Users can then:

See total balance, income, and expenses
View a list of transactions
Open each transaction to see details
Add a new transaction
Edit existing transaction information
Delete transactions
Search and filter transactions

<img width="1919" height="893" alt="image" src="https://github.com/user-attachments/assets/3919c128-ec5d-4e72-ba2b-4fcba313194f" />

Bloc is used to manage the application state
This means all actions such as loading, adding, editing, deleting, searching, and filtering are controlled through Bloc events and states
