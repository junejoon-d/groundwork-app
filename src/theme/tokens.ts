// Harbor ("Middle Distance") design tokens: the single source for colors, type and spacing.
// App code imports from here. Never hard-code a hex value, font size or spacing number in a component.
//
// Values marked TODO weren't in the project files when this was made; copy them from the
// Harbor visual-language doc (the .docx that replaces brief §10) before phase 3 locks tokens in.

export const palette = {
  light: {
    bg: '#F3F1EA', // chalk
    text: '#232C30', // ink-navy
    accent: '#F0664B', // coral: the tap color (see .claude/rules/ui-design.md)
    secondary: '#3B7A8C', // steel-teal
    card: 'TODO',
    border: 'TODO',
    textMuted: 'TODO',
    tintAccent: 'TODO',
    tintSecondary: 'TODO',
    onAccent: '#232C30', // ink labels on coral buttons: the Harbor review's AA contrast fix
    danger: 'TODO', // recommended in the handoff review, not yet decided
    warn: 'TODO', // recommended in the handoff review, not yet decided
  },
  dark: {
    bg: '#12171A',
    text: '#ECEFF0',
    accent: '#F5806A',
    secondary: '#5FA3B8',
    card: '#1B2226',
    border: '#333C42',
    textMuted: '#8B969C',
    tintAccent: '#3A2620',
    tintSecondary: '#1C2F34',
    onAccent: 'TODO',
    danger: 'TODO',
    warn: 'TODO',
  },
} as const;

export const fonts = {
  // Roles are TODO: confirm which of Outfit / Figtree / IBM Plex Mono is display, body and numeric in the Harbor doc.
  display: 'Outfit',
  body: 'Figtree',
  mono: 'IBM Plex Mono',
} as const;

// Few, far-apart steps on purpose: one big thing per screen, everything else small, nothing in between.
// TODO: replace with the Harbor type scale once checked against the wireframes.
export const type = {
  hero: 40, // one per screen at most
  title: 24,
  body: 16,
  caption: 13,
} as const;

// TODO: replace with Harbor's spacing and radius scale.
export const space = { xs: 4, sm: 8, md: 16, lg: 24, xl: 40 } as const;
export const radius = { sm: 8, md: 14, pill: 999 } as const;

export type Scheme = keyof typeof palette;
