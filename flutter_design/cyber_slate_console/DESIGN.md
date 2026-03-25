```markdown
# Design System Specification: High-Density Windows Monitoring Console

## 1. Overview & Creative North Star: "The Orchestrator"
The objective of this design system is to transform raw technical data into an authoritative, editorial-grade monitoring experience. We are moving away from the "clunky dashboard" trope toward **"The Orchestrator"**—a visual metaphor for a high-end command center that feels both surgically precise and aesthetically sophisticated.

The system rejects the rigid, "boxed-in" look of traditional enterprise software. Instead, it utilizes **Tonal Layering** and **Intentional Asymmetry** to guide the eye. By leveraging high-contrast typography scales (Manrope for headlines, Inter for data) and soft, glass-like depth, we create a tool that feels less like a spreadsheet and more like a professional instrument.

---

## 2. Color Strategy & The "No-Line" Rule
Our palette is rooted in 'Deep Slate' (`surface: #0b1326`) and 'Cyber Blue' (`primary: #98cbff`). The goal is to create a UI that breathes through color shifts rather than structural lines.

### The "No-Line" Rule
**Explicit Instruction:** Designers are prohibited from using 1px solid borders to define sections or cards. 
- **Method:** Define boundaries strictly through background color transitions. A `surface-container-low` (`#131b2e`) element should sit on a `surface` (`#0b1326`) background to create a "soft" edge.
- **Surface Nesting:** Use the hierarchical tiers (`lowest` to `highest`) to create a sense of physical stacking. The more critical the information, the higher the surface tier (and thus, the lighter the slate tone in dark mode).

### The "Glass & Gradient" Rule
To elevate the "Cyber Blue" identity, main CTAs and critical status headers should utilize a subtle linear gradient:
- **Signature Gradient:** `primary` (`#98cbff`) to `primary_container` (`#0097ec`) at a 135-degree angle.
- **Glassmorphism:** For floating panels (modals, dropdowns), use `surface_container_high` at 80% opacity with a `20px` backdrop-blur. This ensures the technical data underneath is felt, but not distracting.

---

## 3. Typography: Editorial Authority
We use a dual-font system to balance human readability with technical density.

*   **Display & Headlines (Manrope):** Chosen for its geometric precision. Use `display-md` or `headline-sm` for high-level metrics (e.g., "99.9% Uptime") to give them an editorial, "hero" feel.
*   **Body & Labels (Inter):** The workhorse for high-density data. `label-sm` (`0.6875rem`) is our primary tool for status tags and micro-copy, ensuring legibility even at small scales.
*   **Hierarchy Tip:** Never use bold for everything. Use `on_surface_variant` (`#c1c6d7`) for secondary labels to create a "recessed" look, allowing the `primary` blue data points to pop.

---

## 4. Elevation & Depth: Tonal Layering
In this system, elevation is a color property, not a shadow property.

*   **The Layering Principle:** 
    1.  **Base:** `surface` (#0b1326)
    2.  **Sectioning:** `surface_container_low` (#131b2e)
    3.  **Individual Cards:** `surface_container` (#171f33)
    4.  **Active/Hover States:** `surface_container_high` (#222a3d)
*   **Ambient Shadows:** If an element must "float" (e.g., a context menu), use a `12px` blur shadow with 6% opacity using the `on_surface` color. It should feel like a soft glow, not a dark drop-shadow.
*   **The "Ghost Border" Fallback:** If accessibility requires a border, use `outline_variant` (#414754) at **15% opacity**. It should be felt, not seen.

---

## 5. Components & UI Patterns

### Buttons
- **Primary:** Gradient fill (Cyber Blue to Sky), `roundness-md` (0.375rem). No border.
- **Secondary:** `surface_container_highest` fill with `on_surface` text. 
- **Tertiary:** Ghost style; no fill, `primary` text. Use for low-emphasis actions like "Clear Filters."

### Data Cards (The Core Component)
- **Rule:** Forbid divider lines. 
- **Structure:** Use `spacing-4` (0.9rem) padding. Separate header from body using a background shift to `surface_container_low`.
- **Status Indicators:** Use `tertiary` (Cyan) for active states and `error` (Soft Red) for critical alerts. Apply a subtle outer glow (0 0 8px) to the indicator icon to simulate a "live" LED.

### High-Density Lists
- **Separation:** Instead of lines, use alternating row colors (Zebra striping) using `surface` and `surface_container_lowest`.
- **Interaction:** On hover, the row should transition to `surface_container_highest` with a `primary` left-accent bar (2px wide).

### Inputs & Search
- **Style:** Understated. Use `surface_container_lowest` with a "Ghost Border" (15% opacity).
- **Focus State:** The border opacity increases to 100% `primary`, and a subtle `surface_tint` glow is applied.

---

## 6. Do’s and Don'ts

### Do:
*   **Do** use `spacing-8` (1.75rem) between major functional groups to prevent visual fatigue.
*   **Do** use `tertiary` (Cyan) for "Secondary Success" metrics—it feels more "Cyber" and professional than a standard green.
*   **Do** lean into `manrope` for large numeric values to emphasize the "Monitoring" aspect of the console.

### Don’t:
*   **Don’t** use pure black or pure white. Always use the Slate tones provided in the `surface` tokens to maintain the premium, layered feel.
*   **Don’t** use standard Material 3 "elevated" shadows. Stick to Tonal Layering.
*   **Don’t** clutter the UI with icons. Use typography and color shifts to denote hierarchy first; use icons only for primary navigation or critical alerts.

---

## 7. Signature Detail: The "Pulse"
For critical endpoint failures, do not just turn the text red. Use a slow, 2-second opacity pulse (100% to 60%) on the `error_container` background. This mimics a hardware alarm and creates an "Active" feeling that static dashboards lack.