# Design System Specification: The Command Horizon

## 1. Overview & Creative North Star: "The Digital Curator"
This design system moves beyond the "utility dashboard" aesthetic to embrace a philosophy we call **The Digital Curator**. In an environment as dense as Windows endpoint monitoring, our goal is not just to display data, but to curate it through authoritative typography and architectural depth.

We reject the "flat" look of generic SaaS tools. Instead, we use **Organic Brutalism**: a high-contrast, structured layout that feels heavy, reliable, and indestructible. By utilizing intentional asymmetry—such as offset technical metadata and wide-margined editorial headers—we create a professional environment that feels like a high-end command center rather than a consumer toy.

## 2. Color Strategy: Tonal Sophistication
Our palette is rooted in deep slate and charcoal, ensuring the "Cyber Blue" primary actions feel like glowing physical controls in a darkened cockpit.

### The "No-Line" Rule
**Standard 1px solid borders are strictly prohibited for sectioning.** To define boundaries, you must use background color shifts. A `surface-container-low` (#1C1B1B) section sitting on a `surface` (#131313) background creates a more sophisticated, "machined" look than a stroke ever could.

### Surface Hierarchy & Nesting
Treat the UI as a series of nested physical layers. 
- **Base Layer:** `surface` (#131313) for the main application background.
- **Sectioning:** `surface-container-low` (#1C1B1B) for large content blocks.
- **Interactive/Raised Elements:** `surface-container-high` (#2A2A2A) for items that require immediate user focus.
- **The "Glass & Gradient" Rule:** Floating modals or high-level overlays should use `surface-variant` (#353534) at 80% opacity with a `20px` backdrop-blur. 

### Signature Textures
Main CTAs should not be flat. Apply a subtle linear gradient from `primary_container` (#3F51B5) to `primary` (#BAC3FF) at a 135-degree angle to give buttons a "lithographic" depth.

## 3. Typography: The Editorial Scale
We pair the technical precision of **Inter** with the architectural character of **Space Grotesk**.

*   **Display & Headlines (Space Grotesk):** These are your "Editorial" anchors. Use `display-lg` (3.5rem) for high-level system health overviews. The slightly eccentric letterforms of Space Grotesk communicate a "next-gen" technical edge.
*   **Titles & Body (Inter):** Use Inter for all functional data. It is engineered for legibility at small sizes.
*   **The Monospace Exception:** All technical strings (IP addresses, Process IDs, Logs) must use a monospace font-family. This distinguishes "data" from "UI labels," allowing a sysadmin to scan logs without visual interference from the interface text.

## 4. Elevation & Depth: Tonal Layering
In this system, elevation is a product of light, not lines.

*   **The Layering Principle:** Depth is achieved by "stacking" the surface-container tiers. Place a `surface-container-lowest` (#0E0E0E) card inside a `surface-container-low` (#1C1B1B) section to create a "recessed" well for data tables.
*   **Ambient Shadows:** For floating elements, use a `24px` blur with 6% opacity. The shadow color must be a tinted Indigo (derived from `on-surface`) to prevent the "dirty gray" look of standard shadows.
*   **The "Ghost Border" Fallback:** If a layout requires a container for accessibility, use a "Ghost Border": `outline-variant` (#454652) at 15% opacity. This provides a hint of structure without cluttering the visual field.

## 5. Components: Precision Primitives

### Buttons & Chips
*   **Primary Action:** Use the signature gradient (Primary to Primary-Container). Roundedness: `md` (0.375rem).
*   **Status Chips:** Use `tertiary` (#44DDC1) for healthy states and `error` (#FFB4AB) for critical failures. Use `label-md` for text within chips to maintain a compact, "pro-tool" density.

### Data Tables & Lists
*   **No Dividers:** Forbid the use of horizontal rules between list items. Instead, use a `spacing-2` (0.4rem) vertical gap and a subtle background hover state change to `surface-container-highest` (#353534).
*   **Density:** Use `spacing-1.5` (0.3rem) for internal cell padding to maximize data density, reflecting the "efficient and robust" requirement.

### Input Fields
*   **Stateful Borders:** Inputs use `surface-container-lowest` as a base. Only on `focus` does a high-contrast `primary` (#BAC3FF) "Ghost Border" appear to signal activity.
*   **Monospace Inputs:** Technical input fields (filtering by IP or PID) must default to monospace typography.

### Cards
*   Cards should use `surface-container` (#201F1F) with a `DEFAULT` roundedness (0.25rem). This sharper corner radius feels more "industrial" and Windows-native than the overly rounded "mobile-first" containers.

## 6. Do’s and Don’ts

### Do
*   **DO** use whitespace as a separator. Use `spacing-10` (2.25rem) between major functional groups.
*   **DO** use `tertiary` (#44DDC1) sparingly. It is a "high-visibility" accent for healthy system status, not a general-purpose brand color.
*   **DO** align technical data (numbers, IDs) to the right in tables to allow for easy vertical scanning of decimal places.

### Don’t
*   **DON'T** use pure black (#000000) or pure white (#FFFFFF). Use the provided `surface` and `on-surface` tokens to maintain the "charcoal and slate" sophistication.
*   **DON'T** use 100% opaque borders. They create "visual noise" that fatigues the user during long monitoring sessions.
*   **DON'T** use "Consumer Blue." Always lean into the `primary_container` (#3F51B5) Indigo tones to keep the vibe "Technical/Military Grade."