---
name: Solar Flare
colors:
  surface: '#1a0935'
  surface-dim: '#1a0935'
  surface-bright: '#41315d'
  surface-container-lowest: '#150330'
  surface-container-low: '#23123d'
  surface-container: '#271642'
  surface-container-high: '#32214d'
  surface-container-highest: '#3d2c58'
  on-surface: '#ecdcff'
  on-surface-variant: '#e0c0af'
  inverse-surface: '#ecdcff'
  inverse-on-surface: '#382854'
  outline: '#a78b7c'
  outline-variant: '#584235'
  surface-tint: '#ffb68b'
  primary: '#ffb68b'
  on-primary: '#522300'
  primary-container: '#ff7a00'
  on-primary-container: '#5c2800'
  inverse-primary: '#994700'
  secondary: '#deb7ff'
  on-secondary: '#4a007f'
  secondary-container: '#6b13af'
  on-secondary-container: '#d4a5ff'
  tertiary: '#e9c400'
  on-tertiary: '#3a3000'
  tertiary-container: '#bd9e00'
  on-tertiary-container: '#423600'
  error: '#ffb4ab'
  on-error: '#690005'
  error-container: '#93000a'
  on-error-container: '#ffdad6'
  primary-fixed: '#ffdbc8'
  primary-fixed-dim: '#ffb68b'
  on-primary-fixed: '#321200'
  on-primary-fixed-variant: '#753400'
  secondary-fixed: '#f1dbff'
  secondary-fixed-dim: '#deb7ff'
  on-secondary-fixed: '#2d0050'
  on-secondary-fixed-variant: '#680eac'
  tertiary-fixed: '#ffe170'
  tertiary-fixed-dim: '#e9c400'
  on-tertiary-fixed: '#221b00'
  on-tertiary-fixed-variant: '#544600'
  background: '#1a0935'
  on-background: '#ecdcff'
  surface-variant: '#3d2c58'
typography:
  display:
    fontFamily: Space Grotesk
    fontSize: 48px
    fontWeight: '700'
    lineHeight: '1.1'
    letterSpacing: -0.02em
  headline-lg:
    fontFamily: Space Grotesk
    fontSize: 32px
    fontWeight: '700'
    lineHeight: '1.2'
  headline-md:
    fontFamily: Space Grotesk
    fontSize: 24px
    fontWeight: '600'
    lineHeight: '1.3'
  body-lg:
    fontFamily: Space Grotesk
    fontSize: 18px
    fontWeight: '400'
    lineHeight: '1.6'
  body-md:
    fontFamily: Space Grotesk
    fontSize: 16px
    fontWeight: '400'
    lineHeight: '1.6'
  label-bold:
    fontFamily: Space Grotesk
    fontSize: 14px
    fontWeight: '600'
    lineHeight: '1.0'
    letterSpacing: 0.05em
  label-sm:
    fontFamily: Space Grotesk
    fontSize: 12px
    fontWeight: '500'
    lineHeight: '1.0'
rounded:
  sm: 0.5rem
  DEFAULT: 1rem
  md: 1.5rem
  lg: 2rem
  xl: 3rem
  full: 9999px
spacing:
  base: 8px
  xs: 4px
  sm: 12px
  md: 24px
  lg: 40px
  xl: 64px
  gutter: 20px
  margin: 24px
---

## Brand & Style

This design system captures the high-energy transition of a celestial sunset, blending the premium sophistication of electric mobility with a playful, Gen Z-focused aesthetic. The brand personality is energetic, futuristic, and approachable, moving away from the cold minimalism often found in the EV sector.

The visual style is defined by **Glassmorphism** and **High-Fidelity 3D Surrealism**. It utilizes deep, multi-layered purple backgrounds to establish a sense of infinite space, while interactive elements appear as frosted glass "shards" that catch light from a nearby "solar flare." This is augmented by 3D cartoonish illustrations—high-gloss, chunky, and expressive—to make technical EV data feel tactile and entertaining.

## Colors

The palette is anchored in a dark-mode-first ecosystem. The foundation is built on deep cosmic purples, providing a high-contrast stage for the "Solar Flare" accents.

- **Primary (Solar Flare):** A vibrant, glowing orange used for calls to action, active states, and critical EV metrics like range or charging status.
- **Secondary (Deep Nebula):** A rich purple used for structural depth and softer UI background layers.
- **Tertiary (Sunlight):** A bright yellow used sparingly for micro-interactions and warnings to maintain high visibility.
- **Surface/Neutral:** The base background is a near-black purple (`#10002B`), ensuring that the glassmorphism effects have sufficient contrast to appear translucent.

## Typography

This design system exclusively uses **Space Grotesk** to maintain a cohesive, technical, and futuristic voice. The typeface’s geometric quirks align perfectly with the "Solar Flare" narrative.

Headlines should be treated with tight tracking and bold weights to feel impactful and modern. Body text maintains generous line height to ensure readability against complex, blurred backgrounds. All labels should be uppercase when used in buttons or navigational chips to enhance the "control center" feel of the EV interface.

## Layout & Spacing

The layout follows a **Fluid Grid** model with an emphasis on "Safe Zones" for 3D assets. Components are grouped into logical clusters (cards) that float within the layout, rather than being constrained by rigid vertical lines.

We use an 8px base rhythm. Spacing between glass cards should be generous (`lg`) to allow the background gradients and blurs to breathe, preventing the interface from feeling cluttered. Content within cards uses consistent internal padding (`md`) to maintain a premium, spacious feel.

## Elevation & Depth

Depth is achieved through **Glassmorphism and Tonal Layering** rather than traditional drop shadows.

- **Level 1 (Background):** Deepest purple with large, slow-moving radial gradients of orange and purple.
- **Level 2 (Glass Cards):** Semi-transparent white or purple fills (10-15% opacity) with a `20px` to `40px` backdrop blur.
- **Level 3 (Interactive Elements):** Buttons and active states utilize "Inner Glows" and "Outer Neon Glows" in the primary orange color to appear as if they are self-illuminated.
- **Level 4 (3D Assets):** Cartoonish 3D illustrations sit at the highest elevation, casting soft, purple-tinted ambient shadows onto the glass surfaces below.

## Shapes

The shape language is defined by **Full Roundness**. There are no sharp corners in this design system. 

All containers, buttons, and input fields use pill-shaped or heavily rounded profiles. This softens the technical nature of the EV data, making the app feel more like a friendly companion or a high-end gaming interface. 3D icons should mirror this, favoring "squishy," inflated geometries over thin or skeletal forms.

## Components

- **Buttons:** Primary buttons are pill-shaped, using a vibrant orange gradient with a subtle outer glow. Secondary buttons use the frosted glass effect with a thin, 1px semi-transparent orange border.
- **Cards:** The signature component. Glassmorphic containers with a `backdrop-filter: blur(24px)`. They feature a subtle "top-light" highlight on the upper edge to simulate a 3D glass pane.
- **Input Fields:** Recessed, dark purple wells with high roundedness. When focused, the border glows orange, and the 3D cursor becomes a small glowing spark.
- **Chips/Status Indicators:** Small, fully rounded capsules. For EV charging, these should pulse with a soft orange glow.
- **Progress Bars (Battery):** Thick, rounded tracks. The "fill" should be a gradient from orange to yellow, appearing liquid or "glowing" inside the glass container.
- **3D Icons:** Used for primary navigation (Home, Charging, Climate, Vehicle). These should be high-gloss, cartoonish 3D models that "bounce" slightly when tapped.