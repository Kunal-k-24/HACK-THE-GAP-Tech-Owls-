# OnlineEx - Online Examination Platform

A Flutter application for conducting online exams with proctoring features.

## Features

### For Students
- Login with email/password
- View available exams
- Take exams with timer
- View exam results
- View past exam history

### For Teachers
- Create and manage exams
- Add various question types (multiple choice, text, essay)
- View student submissions
- Monitor exam progress
- View exam statistics

## Technical Details

- **State Management**: Provider
- **Authentication**: Custom auth service (JWT-based)
- **Backend**: RESTful API
- **Local Storage**: Shared Preferences
- **UI Framework**: Flutter Material 3

## Getting Started

### Prerequisites
- Flutter SDK (3.0.0 or higher)
- Dart SDK (3.0.0 or higher)
- Android Studio / VS Code

### Installation

1. Clone the repository:
```
git clone https://github.com/yourusername/onlineex.git
```

2. Navigate to the project directory:
```
cd onlineex
```

3. Install dependencies:
```
flutter pub get
```

4. Run the app:
```
flutter run
```

## Project Structure

- `lib/`
  - `main.dart` - Application entry point
  - `models/` - Data models
  - `screens/` - UI screens
    - `auth/` - Login and registration screens
    - `student/` - Student-specific screens
    - `teacher/` - Teacher-specific screens
  - `services/` - Business logic and API services
  - `widgets/` - Reusable UI components

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

- Flutter team for the amazing framework
- All contributors who have helped with the project
