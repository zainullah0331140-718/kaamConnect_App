# KaamConnect Flutter App (iOS, Android, Windows PC, Web)

A modern, responsive cross-platform Flutter application for **KaamConnect** - connecting customers with verified local service providers (electricians, plumbers, carpenters, painters, AC technicians, and cleaners) across Pakistan.

Built with **Dart & Flutter 3.x**, supporting:
- 📱 **Android** (Smartphones & Tablets)
- 🍏 **iOS** (iPhone & iPad)
- 💻 **PC / Desktop** (Windows, macOS, Linux)
- 🌐 **Web** (Chrome, Edge, Safari, Firefox)

---

## 🌟 Key Features

### 1. 🛡️ Admin Management Console (`/admin`)
- **Dashboard Stats**: Real-time overview of users, verified/pending providers, pending reviews, open complaints, and pending ads.
- **Provider Verification**: Review pending provider profiles and approve (verify) or reject with admin notes.
- **Advertisements Moderation**: Review provider-submitted ad banners, verify campaign details, and approve or reject ads.
- **Categories Management**: Add new service categories (name, slug, icon key, description) and manage existing categories.
- **Review Moderation**: Moderate and approve/reject customer feedback before public listing.

### 2. 🏪 Provider Business Portal (`/providers/me`)
- **Profile Picture Upload**: Take a photo with camera or pick from gallery to update the business avatar.
- **Account & Business Editing**: Edit business name, city, area, street address, experience years, contact phone, WhatsApp number, and bio.
- **Product & Work Portfolio (Up to 5 Photos)**: Upload and display up to 5 high-resolution photos of completed jobs or products, with instant deletion and slot tracking.
- **Advertisements & Promotions**: Create banner ads with title, description, destination link, and date range. Track approval status (`Pending`, `Approved / Live`, `Rejected`, `Expired`).
- **Services & Rates**: List services with custom price ranges in PKR.

### 3. 🔐 Password Management & Security
- **In-App Password Change**: Logged-in users can update their account password securely under Settings.
- **Forgot Password Workflow**: Step 1 generates/receives a reset token; Step 2 validates token and sets a new password.

### 4. 👥 Customer Experience
- **Explore & Search Services**: Filter across major Pakistani cities (Karachi, Lahore, Islamabad, Rawalpindi, Faisalabad, Multan, Peshawar, Quetta, etc.).
- **Direct Call & WhatsApp**: One-tap phone dialer and WhatsApp chat integration.
- **Customer Reviews & Complaints**: Star ratings, detailed feedback, and official complaint filing.
- **Favorites**: Save trusted providers for quick future access.

### 5. 💻 Multiplatform Responsive UI
- **Mobile Mode (iPhone & Android)**: Bottom navigation bar for effortless single-hand thumb navigation.
- **Desktop Mode (Windows PC & Web)**: Left navigation rail with brand header and wide-screen responsiveness.
- **Theme Modes**: Full Material 3 Light and Dark mode toggle.
- **Dynamic Server URL**: In-app configuration dialog to switch seamlessly between `localhost:8000`, Android emulator `10.0.2.2:8000`, or custom LAN IP.

---

## 🚀 How to Run the App

First, make sure the KaamConnect FastAPI backend is running:

```powershell
# From the KaamConnect root directory:
.\.venv\Scripts\python.exe -m uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

### 1. Run on Windows PC (Desktop)
```powershell
cd kaamconnect_app
flutter run -d windows
```

### 2. Run on Android (Device or Emulator)
```powershell
cd kaamconnect_app
flutter run -d android
```

### 3. Run on iPhone / iOS (Mac with Xcode)
```bash
cd kaamconnect_app
flutter run -d ios
```

### 4. Run on Chrome (Web)
```powershell
cd kaamconnect_app
flutter run -d chrome
```
