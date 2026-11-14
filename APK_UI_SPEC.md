# APK UI Spec — extracted from libapp.so strings (com.example.safe_to_spend)

## App identity
- Package: com.example.safe_to_spend, name "Safe to Spend"
- Material You / dynamic color (DynamicColor.fromPalette), Light/Dark, "Match system"
- Time-of-day greeting: GOOD MORNING / GOOD AFTERNOON / GOOD EVENING
- Tagline: "Your bank balance is not the whole story. Rent is due, the phone bill is coming,
  Netflix renews on Thursday. 'Safe to Spend' is what is left after all of that."
- "Everything stays on this phone. No account, no cloud, no cost."

## Screens (from string map)
1. HOME / DASHBOARD
   - Greeting + date (EEEE, MMMM d, y)
   - SAFE TO SPEND hero card: "Tells you the number, and explains why it is that number."
     - "Add your balance to see what is safe to spend."
     - "Every rupee is already spoken for. Nothing is safe to spend today."
     - "Things are tight after your upcoming payments. Spend carefully."
     - "That is what remains after ..."
     - "How this is calculated"
   - Stats: "Where it went" / "What comes out" / "You earned " / "You spent " / "You kept "
     - "No income recorded today" / "Nothing logged today" / "And spent nothing. That is a good day."
   - Transactions list: "No transactions yet" — "Add your first income or expense from the home screen and it will show up here."
   - Income sheet: "Add income" / "Edit income" — "Where did this come from?" / "How much?" / "Pick a category"
   - Expense sheet: "Add expense" / "Edit expense" / "Add an expense" — "What is it?" / "How much?" / "Track it in my spending"
   - Day Grid / "Switch to calendar" / "Switch to input"
   - Category donut chart (CategoryDonut)
2. BUDGETS
   - "Create a budget" / "Monthly limits per category, with alerts before you overshoot."
   - "Approaching your budget on X" / "Over budget on X" / "Warn me at " / "A nudge at "
   - Sheet: "New budget" — "Pick a category" / "Enter a limit" / "Amount must be more than zero"
3. SAVINGS GOALS
   - "Create a goal" / "What are you saving for?" / "Give this goal a name" / "Target amount"
   - "Add money" / "Add to goal" / "ON TRACK" / "Starting balance"
   - "Put money aside on purpose, and watch it add up."
4. RECURRING PAYMENTS
   - "Add a recurring payment" — "Phone bill, on the 9th" / "Give this payment a name"
   - "How often?" (Monthly / Repeat every X / Runs indefinitely) / "Due on day"
   - "Due today" / "Due tomorrow" / "Next payment on" / "No payments yet"
   - Show active / Show paused / Include paused payments / "Payments you pause will show up here."
   - "Subscriptions are " / "Your subscriptions cost "
5. TRANSACTIONS (history + filters)
   - "No matching transactions" — "Try clearing a filter or searching for something else."
   - "Clear filters" / This month / Last 30 days / All time
   - "Delete expense" / "Edit expense" / "Mark " / sensitive transactions
6. INSIGHTS (RuleBasedInsightsEngine — local, rule-based)
   - "Not enough data yet" / savings rate "Aim for 20% or more."
   - category comparison insights, subscription insights, safe-to-spend insights
7. SETTINGS
   - Sections: YOUR DATA / PRIVACY & REMINDERS / MONTHLY COMMITMENT
   - "How far ahead to look" (safe-to-spend horizon)
   - "Export transactions as CSV" / Restore from a backup / "Adds the rows from a backup file. Nothing is deleted."
   - "Erase all data?" / "Erase everything, permanently?" / "Deletes every transaction, payment, budget and goal."
   - App lock: "Verify identity" / "Confirm it is you to enable the lock" / "Biometric required"
     / "Unlock to view your finances" / "Unlock to see your numbers." / "Safe to Spend is locked"
   - Payment reminders / "Daily logging reminder" / "Reminders about upcoming payments and budgets"
   - Home-screen widget (home_widget)
   - Theme: Default Material You / Light / Dark / "Match system"

## Existing insight phrases (RuleBasedInsightsEngine) — the AI should extend these
- "You have logged spending but no earnings. Did you miss one?"
- "You are down X so far. Earned Y." (daily)
- "Savings rate ... Aim for 20% or more."
- "Upcoming payments exceed your balance"

## Data model (Drift): IncomeEntries, ExpenseEntries, Categories, Budgets,
## SavingsGoals, RecurringPayments (paused flag), backups as JSON ("That file is
## not a Safe to Spend backup"), CSV export.
