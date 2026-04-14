## Plan: Premium Brand UI + Appwrite Foundation

Redesign IVEX from a single-flow demo into a polished, brand-led product: cleaner visual language, stronger layout rhythm, and a full user journey (not just upload/result). The approach is to define a premium design system first, then rebuild screens/components around it, and finally align Appwrite data/auth/permissions so the new UX works reliably. I also included a low-cost/free API direction so you can keep running costs near zero while iterating.

### Steps
1. Audit current UX flow in [lib/main.dart](lib/main.dart), [lib/screens/home_screen.dart](lib/screens/home_screen.dart), and `HomeScreen`/`ResultScreen` pain points.
2. Define premium brand system (type, spacing, motion, surfaces) in [lib/main.dart](lib/main.dart) `ThemeData` and new `design_tokens.dart`.
3. Expand app IA with essential screens: onboarding, auth, home, scan, result, history, profile, settings in [lib/screens/](lib/screens/) with a consistent navigation shell.
4. Extract reusable branded components (buttons, cards, app bars, status blocks) into [lib/widgets/](lib/widgets/) and replace duplicated screen styling.
5. Upgrade backend contracts in [lib/config/appwrite_config.dart](lib/config/appwrite_config.dart), [lib/services/appwrite_service.dart](lib/services/appwrite_service.dart), and [APPWRITE_SETUP.md](APPWRITE_SETUP.md) for auth, user profiles, saved analyses, and stricter permissions.
6. Rationalize AI providers in [functions/analyze-hairstyle/main.py](functions/analyze-hairstyle/main.py) and [functions/analyze-hairstyle/src/main.py](functions/analyze-hairstyle/src/main.py), choosing one free-tier-friendly pipeline with fallback handling.

### Further Considerations
1. Which brand direction should lead? Option A minimal Apple-like, Option B bold Nike-like, Option C balanced hybrid.
2. Appwrite now has no user auth flow; should we add anonymous first or full email/OAuth from day one?
3. Free API route: Option A Pollinations + Hugging Face free models, Option B Replicate free credits, Option C keep current providers and cap usage budgets.

