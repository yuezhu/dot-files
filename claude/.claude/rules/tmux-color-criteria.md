---
paths:
  - "**/.tmux.conf"
---

# tmux Color Scheme — Design Criteria & Audit Standards

## 1. Text Contrast (WCAG)

All foreground text on its background must meet these thresholds:

| Role | Target CR | WCAG Grade | Notes |
|------|-----------|------------|-------|
| name (window title, session name) | ≥ 7.0 | AAA | Primary readable text |
| index (window number, flags) | ≥ 4.5 | AA | Secondary identifier |
| colon (`:` separator, `∣` divider) | ≈ 2.10 | Decorative | Deliberately low — structural punctuation, not content |

## 2. Contrast Hierarchy

Each tab type independently maintains the contrast hierarchy: **name CR > index CR > colon CR**. Target values, applied consistently across all four tab types (inactive, current, bell, activity):

    name:  ~7.50 (±0.10)   — AAA, primary readable text
    index: ~4.65 (±0.10)   — AA, secondary identifier
    colon: ~2.10 (±0.05)   — decorative, structural punctuation

Session and message fg inherit inactive fg values and therefore share the same hierarchy.

## 3. Structural Separation (bg ↔ bg)

Chromatic background blocks must be visually distinguishable from the status bar bg.

| Threshold | Assessment | Usage |
|-----------|------------|-------|
| CR ≥ 1.40 | Clear | Ideal for important elements |
| CR ≥ 1.30 | Visible | Acceptable for focus indicators |
| CR ≥ 1.15 | Subtle | Minimum for structural elements |
| CR < 1.15 | Weak | Requires strong chroma/hue compensation |
| CR < 1.05 | Invisible | Not acceptable |

Current design targets CR=1.25 for the two chromatic bgs (current, bell) against the unified bar bg, maintaining symmetry.

### Directional constraint

- **Bell bg** must be brighter than bar (L_bell > L_bar) — alert semantics require visual "pop"
- **Current bg** is brighter than bar — focus/highlight semantics

Both chromatic bgs sit in the brighter-than-bar zone. Session, message, activity tabs, and all mode states share the unified bg — no darker-than-bar bg exists. See §9 and §11.

### Lightness collision avoidance

Multiple bg blocks must not occupy the same OKLCH L band (ΔL < 0.015 without sufficient hue separation). At CR=1.25, brighter-than-bar bgs land in L≈0.41–0.43; current and bell are separated within this band by hue (teal vs red, ΔH ≈ 170°), which is well above the §5 threshold.

## 4. Activity vs Inactive Distinguishability

Activity tabs share the bar bg and are distinguished by fg color only. The distinction relies on chroma contrast:

    ΔC > 0.03: minimum for distinction
    ΔC > 0.05: clearly distinguishable
    ΔC > 0.07: recommended

Activity fg uses a chromatic tint (currently gold-orange H≈70°, C≈0.080–0.090) against achromatic inactive fg (C≈0).

## 5. Hue Wheel — Collision Avoidance

Every chromatic element occupies a hue on the OKLCH wheel. Adjacent hues must maintain minimum separation:

| Minimum ΔH | Context |
|------------|---------|
| ≥ 60° | Same visual layer (e.g., two bg blocks that can appear simultaneously) |
| ≥ 36° | Different visual layers (e.g., bg block vs fg-only element with different bg) |
| < 30° | Collision risk — requires strong secondary cues (different bg, L difference) |

Current hue assignments:

    H≈24°   bell bg (red)
    H≈70°   activity fg (gold-orange)
    H≈195°  current bg (teal)
    H≈229°  pane active border (blue)

Key gaps: bell→activity 46°, activity→current 125°, current→pane 34° (different UI zones — below the 36° same-layer threshold but acceptable since pane border and status bar are distinct visual layers).

## 6. Chroma Hierarchy (bg urgency encoding)

Background chroma encodes urgency/importance:

    bell_bg    C≈0.090  — highest urgency (alert)
    current_bg C≈0.069  — focus (active window)
    unified_bg C≈0.012  — neutral surface (near-achromatic, C < 0.020)

## 7. Lightness Ladder

All palette colors should form a coherent lightness gradient without collisions. The ladder has three zones:

**Background zone (L ≈ 0.35–0.50):**

    unified_bg  L≈0.365  (bar/session/border/message surface)
    current_bg  L≈0.411  (focus tab)
    bell_bg     L≈0.428  (alert tab)
    pane_active L≈0.484  (active border)

**Colon zone (L ≈ 0.48–0.55):**

    ac_colon, in_colon cluster here

**Index zone (L ≈ 0.70–0.75):**

    ac_index, in_index cluster here

**Name zone (L ≈ 0.82–0.90):**

    ac_name, in_name cluster here

## 8. 256-Color Fallback

True-color (24-bit) over SSH is the primary rendering environment. 256-color is a degraded fallback but should remain usable.

### Checks

- **bg colors**: verify the 256-color index and ensure chromatic bgs don't collapse to the same index
- **fg colors**: verify chromatic tints (activity amber, bell red, current teal) retain their hue identity in 256-color. Pure grays (inactive) should map to grayscale ramp indices
- **Activity fg**: amber at high L maps to color cube indices (e.g., 222, 179) which preserve warm hue; at low L may collapse to gray — acceptable if true-color is primary

### Acceptable tradeoffs

- Activity/inactive distinction may weaken in 256-color (chroma collapses)
- Bell bg may lose red identity if quantized to gray ramp — accepted since true-color SSH is primary

## 9. Unified Background Roles

In the unified design, a single color serves multiple roles:

    unified_bg = status_bg = session_bg = pane_border = message_bg

This unification holds across **all** modes (normal, prefix, copy) — mode does not alter any bg.

**Implications**: Session name floats as text with no bounding box across all modes — mode state is signaled by a trailing letter only (§11). Pane borders match the bar, creating continuity; active pane (pane_active) provides contrast. Message bar inherits unified bg and uses session fg.

## 10. Session/Message Fg Consistency

Session fg and message fg must equal inactive name fg. Session divider must equal inactive colon fg. This reduces the palette to two achromatic levels for all non-chromatic text on the bar:

    name-level:  #RRGGBB  (CR ≈ 7.50 against unified_bg)
    colon-level: #RRGGBB  (CR ≈ 2.10 against unified_bg)

Status-right uses the same two levels across all modes — no mode-specific fg.

## 11. Mode Indication

Mode state (normal / prefix / copy) is signaled **only** by a single trailing character in the session block:

    normal  →  " #S - "
    prefix  →  " #S P "
    copy    →  " #S C "

All three states share the unified bg and use the same fg (inactive name fg, `#d8d8d8`). There is no color differentiation between modes on the status bar.

This is an intentionally weak signal by status-bar-only standards — at glance-distance the letter alone does not stand out.

### Constraints if/when stronger signaling is added

If stronger mode signaling is added: prefer swapping `window-status-current-style` bg by mode (teal → gold → blue-violet), keeping §6 chroma hierarchy and §5 hue separation, with CR ≥ 1.25 against unified_bg (§3 symmetry). Must not alter the unified_bg invariant stated in §9.

## 12. tmux-Specific Configuration Checks

- `window-status-activity-style` must be set to `"none"` to prevent tmux's default `reverse` attribute from overriding the amber fg colors
- `window-status-bell-style` only needs `bg=` — setting bg implicitly clears reverse
- Activity indication is purely fg-based in `window-status-format` via `#{?window_activity_flag,...}` conditionals
- Mode indication in `status-left` uses `#{?pane_in_mode,C,#{?client_prefix,P,-}}` — a single format expression; no style-level branching

## 13. OKLCH Color Space Methodology

All color design work is done in OKLCH:

- **L** (lightness): controls WCAG contrast ratio positioning
- **C** (chroma): controls saturation/vividness; used for activity vs inactive distinction
- **H** (hue): controls color identity; checked against hue wheel for collisions

### sRGB Gamut Awareness

OKLCH coordinates must be checked against sRGB gamut boundaries. At high L and high C, colors clip. Key constraints:

- Activity name fg at L≈0.88: gamut limit varies by hue (H=70° maxC≈0.104)
- Bell bg at L≈0.43: gamut is generous for red (H=24° maxC>0.15)
- Current bg at L≈0.41: teal (H=195°) has moderate gamut

When a computed OKLCH color clips, the actual C achieved will be lower than requested. Verify by round-tripping: `oklch_to_hex()` → `hex_to_oklch()` and checking C deviation < 0.005.

## 14. Design Principles

- **Data-driven**: all decisions backed by numerical metrics (CR, ΔC, ΔH, ΔL)
- **Visual verification**: HTML previews rendered before committing to changes
- **Incremental refinement**: one dimension at a time (L, then C, then H)
- **Symmetry where possible**: chromatic bg separation should be uniform (all CR=1.25)
- **Semantic encoding**: color properties map to meaning (chroma→urgency, hue→category, lightness→hierarchy)
- **Graceful degradation**: true-color is primary; 256-color should be usable but not optimized for
- **Minimal by default, extensible by design**: mode indication is currently minimal (letter only, §11); the criteria explicitly reserve the design space for a future stronger signal without disturbing the unified_bg invariant
