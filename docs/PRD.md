# PiggyFlow – Product Requirements (Version 2.0)

## Objective

Build a mobile-first personal and business finance application that enables users to capture,
categorize, and analyze expenses by photographing bills and invoices, while also tracking
income, recurring commitments, and budget goals. The system automatically extracts expense
details using AI/OCR and provides meaningful spending reports.

Version 2.0 merges two products into one application:

* The AI bill-scanning expense system defined in Version 1.0.
* The existing PiggyFlow tracker (income, subscriptions, EMI, budget goals, cloud sync).

## Scope Changes from Version 1.0

New in this version:

* Income tracking and net balance.
* Subscription and EMI tracking with due dates.
* Category budget goals with progress tracking.
* Manual expense entry as a fast alternative to scanning.
* Dual extraction: on-device processing and cloud AI, user-selectable.
* Offline-first operation with background cloud sync.
* Recurring expense detection that creates subscription trackers automatically.

## Core Features

### Expense Capture

* Upload invoice or bill images from camera or gallery.
* Support multiple image uploads per expense.
* Automatically enhance image quality before processing.
* Extract text using OCR/AI.
* Detect:
   * Vendor/Merchant Name
   * Invoice Date
   * Invoice Number
   * Total Amount
   * Tax Amount (if available)
   * Subtotal (if available)
   * Currency
   * Payment Method (if available)
   * Individual Line Items
      * Item Name
      * Quantity
      * Unit Price
      * Total Price
* Present all extracted values for user review before saving.
* Flag low-confidence fields so the user knows what to check.
* Show fields that could not be detected rather than leaving them blank.
* Allow every extracted field to be edited in place.
* Record the invoice date separately from the capture date, so a bill photographed later
  still reports under the date it was issued.

### Manual Expense Entry

* Add an expense without an image.
* Select category, amount, date, and account type.
* Add optional note and tags.
* Complete entry in under 15 seconds.

### Income Tracking

* Record income entries with amount, date, and source.
* Categorize income (Salary, Freelance, Investments, Rental, Interest, Bonus, Gifts, Refund, Other).
* Assign income to Personal, Family, or Business.
* Display net balance (income minus expenses).
* Display savings rate.

### Expense Categorization

Automatically categorize expenses into:

**Primary Categories**

* Personal
* Family
* Business

**Expense Categories**

* Food & Dining
* Grocery
* Fuel
* Travel
* Medical
* Shopping
* Utilities
* Entertainment
* Education
* Office Supplies
* Client Meeting
* Software & Subscriptions
* Miscellaneous

Allow users to:

* Change AI-suggested category.
* Create custom categories.
* Move expenses between categories.
* Hide unused system categories without deleting them.
* Assign expenses to a primary category independently of the expense category.

### Recurring Trackers

* Track active subscriptions with billing cycle and due date.
* Track EMIs with amount and due date.
* Mark trackers as paid or unpaid.
* Display monthly and yearly cost estimates.
* Show due-soon indicators for upcoming payments.
* Automatically suggest a new tracker when a recurring expense pattern is detected.

### Budget Goals

* Set a monthly spending limit per category.
* Display spend against limit with progress indication.
* Show remaining budget or overspend amount.
* Trigger an alert when a category exceeds its limit.

### Expense Storage

Store:

* Original bill image
* OCR text
* Structured expense data
* Itemized purchases
* Category
* Primary category
* Tags
* Notes
* Timestamp
* Extraction source and confidence
* Location (optional)

### Search & Filters

Search by:

* Merchant
* Item name
* Category
* Date
* Amount
* Tags
* Note

Filters:

* Today
* Yesterday
* This Week
* Last Week
* This Month
* Last Month
* Custom Date Range
* Personal / Family / Business
* Category
* Payment Method
* Amount range
* Has receipt image

Additional requirements:

* Item-name search must find the bill a product appeared on.
* Active filters must be visible and individually removable.
* Results must appear immediately without a network request.

### Reports & Dashboard

Dashboard should display:

**Summary Cards**

* Total Expenses
* Personal Expenses
* Family Expenses
* Business Expenses
* Net Balance
* Savings Rate

**Charts**

* Daily Spending
* Weekly Spending
* Monthly Spending
* Category-wise Spending
* Merchant-wise Spending
* Payment Method Breakdown

**Reports**

* Date-wise report
* Week-wise report
* Month-wise report
* Year-wise report
* Custom Date Range report

### Expense Details

Clicking an expense should show:

* Original bill image
* OCR text
* Itemized products
* Taxes
* Total
* Category
* Primary category
* Payment method
* Tags
* Notes
* Extraction source
* Edit option
* Delete option

Additional requirements:

* Image and OCR sections hide entirely for manually entered expenses.
* Multi-page bills are swipeable.
* Images open full screen with zoom.

### AI Features

* Automatic bill understanding.
* Automatic categorization.
* Duplicate bill detection.
* Merchant recognition and name normalization.
* Smart suggestions for category correction.
* Detect recurring expenses.
* Learn from user corrections for improved categorization over time.

Additional requirements:

* Two extraction modes, selectable by the user:
   * On-device: free, offline, private. Default.
   * Cloud AI: higher accuracy, requires network and sign-in.
* Cloud extraction falls back to on-device automatically on failure or timeout.
* Duplicate detection presents both bills for comparison and never discards one silently.
* AI output is always presented as a suggestion and is always editable.

### Export

Export reports as:

* PDF
* Excel
* CSV

Include:

* Summary
* Itemized expenses
* Category totals
* Merchant totals

### Notifications

Optional reminders:

* Upload today's bills
* Monthly expense summary
* High spending alert
* Missing bills reminder
* Subscription or EMI due

Additional requirements:

* All reminders are off by default.
* Notification permission is requested when the first reminder is enabled, not at launch.

### Accounts & Sync

* Sign in with Google or Apple.
* Continue without an account using local-only storage.
* Sign in later and retain all existing local data.
* Automatic background sync of records across devices.
* Bill images sync separately and lazily.
* Full functionality offline; all reads are local.
* Manual account deletion and local data clearing.

### Privacy & Data Control

* On-device extraction sends no data off the device.
* Cloud extraction is opt-in, clearly labelled, and reversible.
* Cloud image storage is a separate opt-in from cloud extraction.
* Bill images are stored privately and accessed only through time-limited signed URLs.
* AI provider keys are never stored in the application.

## User Flows

### Capture a Bill

1. Open App
2. Tap Upload Bill
3. Capture or select image
4. AI extracts invoice details
5. User reviews extracted information
6. Save expense
7. Dashboard updates automatically
8. View reports anytime

### Add an Expense Manually

1. Open App
2. Tap Add Manually
3. Select category and primary category
4. Enter amount and date
5. Save expense

### Record Income

1. Open App
2. Tap Add Manually
3. Switch to Income
4. Select income category
5. Enter amount and date
6. Save

### Track a Subscription or EMI

1. Open Tracker
2. Select Subscriptions or EMI
3. Add name, amount, billing cycle, due date
4. Save
5. Receive a reminder before the due date
6. Mark as paid when settled

### Set a Budget Goal

1. Open Tracker
2. Select Budget Goals
3. Choose a category
4. Set a monthly limit
5. Monitor progress as expenses are recorded

### Export a Report

1. Open Reports
2. Select date range
3. Tap Export
4. Choose format and contents
5. Share or save the generated file

## Technology Stack

**Mobile**

* Native iOS (SwiftUI)

**Local Storage**

* SwiftData (offline-first, source of truth for all reads)

**Backend**

* Supabase (PostgreSQL, Auth, Storage, Edge Functions)

**Database**

* PostgreSQL for structured data
* Supabase Storage for bill images

**AI/OCR**

* Apple Vision framework for on-device OCR
* OpenAI Vision or Anthropic Vision for cloud extraction, accessed through a Supabase Edge
  Function so that provider keys are never shipped in the application

**Notes on deviation from Version 1.0**

* Version 1.0 suggested Flutter or React Native. Native SwiftUI is used instead because the
  existing application is already built in it and a rewrite would discard working software.
* Version 1.0 suggested Spring Boot or Node.js with separate object storage. Supabase covers
  database, authentication, storage, and server-side functions in one service, removing the
  need to build and host a separate backend.

## Future Enhancements

* Voice-based expense logging
* Email invoice import
* WhatsApp invoice import
* GST invoice support
* Business mileage tracking
* Expense approval workflow
* Multi-user family accounts
* Team/business shared expenses
* Credit card and bank statement import
* Accounting software integration (Tally, Zoho Books, QuickBooks)
* Tax-ready expense reports
* AI spending insights and savings recommendations
* Android application

## Success Criteria

* Bill processing completed in under 5 seconds for most invoices.
* OCR accuracy above 95% for clear images using cloud extraction.
* Automatic categorization accuracy above 90%, with continuous improvement from user feedback.
* Expense searchable immediately after saving.
* Reports generated instantly for any selected date range.
* Simple workflow enabling users to record an expense in under 30 seconds.
* Application fully functional without a network connection.
* No user data accessible to any other user.

## Measurement

* Categorization accuracy is measured as the percentage of saved expenses where the user did
  not change the suggested category.
* Extraction accuracy is measured field-by-field against a fixed set of reference bills.
* Processing time is measured from capture completion to the review screen appearing.
* Time to record an expense is measured from the upload action to a successful save.

## Out of Scope for Version 2.0

* Android application.
* Shared or multi-user accounts.
* Bank and credit card statement import.
* Accounting software integrations.
* Any item listed under Future Enhancements.
