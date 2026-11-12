# 🛍️ LAQTA | لَقطة

### Discover Hidden Treasures. Buy, Sell & Connect.

## About LAQTA

LAQTA is an Arabic-first mobile marketplace built with Flutter and Supabase, designed to make buying and selling second-hand products, antiques, and collectibles simple and accessible.

The application brings buyers and sellers together through a modern digital marketplace, inspired by the traditional Friday market experience.

## Features

### Marketplace
- Browse second-hand products and collectibles.
- Search for available items.
- View product details and image galleries.
- Save favorite products.
- Create and manage product listings.

### User Accounts
- User registration and login.
- Profile management.
- Password recovery.
- User authentication through Supabase.

### Communication
- In-app messaging.
- Buyer and seller conversations.
- Notifications.

### Administration
- Dedicated admin interface.
- Product and user management functionality.

### User Experience
- Arabic-first interface with RTL support.
- Custom visual theme.
- Bottom navigation.
- Responsive Flutter UI.

## Technologies Used

- **Flutter & Dart** — Mobile application development
- **Supabase Auth** — Authentication
- **Supabase PostgreSQL** — Database
- **Supabase Storage** — Image storage
- **Provider** — State management
- **Image Picker** — Product image selection
- **Cached Network Image** — Image loading and caching

## Getting Started

### Prerequisites
- Flutter SDK
- Dart SDK
- Android Studio or VS Code
- A configured Supabase project

### Installation

Clone the repository:

```bash
git clone https://github.com/YOUR_USERNAME/laqta-app.git
```

Navigate to the directory:

```bash
cd laqta-app
```

Install dependencies:

```bash
flutter pub get
```

Configure Supabase in `lib/supabase_config.dart` using your own project URL and publishable key.

Run the application:

```bash
flutter run
```

## Project Structure

```text
lib/
├── data/
├── models/
├── screens/
├── services/
├── state/
├── theme/
├── utils/
├── widgets/
├── main.dart
└── supabase_config.dart
```

## Vision

To create a trusted digital marketplace that gives second-hand items a new life and makes discovering unique products easier for everyone.

## Project Status

Under Development

---

**LAQTA — Every Item Has a Story.**
