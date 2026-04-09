# AI à la Carte - Product Vision

## The Problem

Diners frequently encounter menus they don't fully understand:

- **Abroad**: Foreign-language menus with non-Latin scripts (Japanese, Korean, Thai, Arabic)
- **Locally**: Unfamiliar ethnic cuisines with untranslated or unexplained dish names
- **Upscale dining**: Culinary jargon that even experienced diners don't always recognize

Current solutions are inadequate:
- **Google Translate camera**: Handles language but gives literal translations that don't explain what a dish IS ("braised lion's head" → still confused)
- **Google Lens**: Identifies some dishes but provides no depth — no ingredients, spice level, or "what's it similar to?"
- **Asking the server**: Awkward, slow, and servers often can't explain well
- **Yelp/TripAdvisor photos**: Not organized by menu item, so you're scrolling through random plates hoping to match
- **Random googling**: Slow, inconsistent, and kills the dining moment

No integrated solution exists that combines translation + explanation + visual preview.

## The Solution

A mobile-first app where you photograph a menu and instantly get:

1. **Dish Identification** — what each item is, in plain language
2. **Rich Explanations** — ingredients, flavors, cooking methods, spice level, texture, portion size
3. **Visual Preview** — AI-generated example images of dishes (generated on demand, cached per restaurant)
4. **Community Photos** — real photos from other diners at that restaurant (user-uploaded, cached per restaurant/dish)
5. **Dietary Flags** — allergens, vegetarian/vegan/halal/kosher indicators
6. **"Similar To" Anchors** — relates unfamiliar dishes to familiar ones ("like a thick Japanese pancake with cabbage and pork")

## Key Capabilities

- Works with **foreign languages AND unfamiliar culinary terms** in any language
- **Photo-based input** — no typing menu items manually
- **Works offline** for recently cached restaurants (critical for travelers)
- **Community contribution model** — diners upload real photos that get matched to menu items
- **Restaurant-aware caching** — builds knowledge over time per restaurant location

## Technical Foundation (for PM's awareness)

- Menu OCR + LLM pipeline for identification and explanation
- Image generation API for dish previews (with aggressive caching layer)
- Restaurant-keyed photo cache for community uploads
- Mobile-first (iOS/Android or cross-platform)
- Offline-capable with pre-cached restaurant data

## Competitive Landscape

| Solution | Translation | Explanation | Visual | Dietary | Offline |
|----------|:-----------:|:-----------:|:------:|:-------:|:-------:|
| Google Translate | Yes | No | No | No | Partial |
| Google Lens | Partial | Minimal | No | No | No |
| Yelp Photos | No | No | Partial | No | No |
| **AI à la Carte** | **Yes** | **Yes** | **Yes** | **Yes** | **Yes** |
