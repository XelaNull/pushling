---
type: Research Note
title: Game Creature Voice Sound-Design References
description: Survey of how Animal Crossing, Undertale, Banjo-Kazooie, Pikmin, Studio Ghibli, and Spore designed non-human creature voices, with what-to-steal notes for Pushling.
status: Current
tags: [research, voice, sound-design, prior-art]
timestamp: 2026-07-02T00:00:00Z
---

Migrated from `docs/CREATURE-VOICE-DESIGN.md` §7 (Sound Design References)
and Appendix C (external citations). See
[creature-voice-design](/REFERENCE/creature-voice-design.md) for how these
references distilled into Pushling's own voice-identity contract, and
[voice-psychoacoustics](/RESEARCH/voice-psychoacoustics.md) for the acoustic
theory behind the techniques described below.

# Animal Crossing — Animalese

**How it works**: each letter of the displayed text maps to a pre-recorded
syllable sound. When a character "speaks," the system plays through the
syllable sequence at a pace matching the text's display speed. In the
`animalese.js` reimplementation: 26 syllable samples (one per letter A–Z),
text shortened to first letters of words (or played in full), each syllable
pitched based on the character's species and personality, non-alphabetical
characters producing silence, and per-character pitch variance creating the
illusion of speech.

**What to steal for Pushling**: the letter-to-syllable mapping concept (for
a Critter-stage babble system); species-based pitch variation (the
personality axes serve this purpose); rhythm preservation — you can "hear"
question marks and exclamation points in the cadence even without words.

**Swift implementation exists**: `animalese-swift` by jakubpetrik — a Swift
port of `animalese.js`, available as an SwiftPM package, was identified as a
potential starting point (see
[creature-voice-design](/REFERENCE/creature-voice-design.md)'s "Superseded
Design History" for why the shipped Critter-stage system took a different
path — TTS-based babble mixing via sherpa-onnx rather than a syllable-sample
library).

# Undertale — Per-Character Voice Beeps

**How it works**: each character has a unique sound effect that plays once
per displayed character (or per word), chosen to suggest the character's
voice quality without being actual speech. Character examples: Undyne
(lower, hoarse beeps), Alphys (high, nasally beeps), Mettaton (9 distinct
voice beeps for variety), Flowey (two variants — normal and threatening),
Sans (low, casual beeps matching his laid-back personality), Papyrus
(higher, more energetic beeps).

**What to steal for Pushling**: a single distinctive sound per character
(for the Drop stage); the idea that personality *is* the voice — characters
can be distinguished without any real words; the extra beep at the end of a
text box, giving finality to a statement; using entirely different sounds
for different emotional states.

# Banjo-Kazooie — Gibberish Voices

**How it works**: voice samples with hardware-randomized speed and pitch.
Each character has its own base sample set, creating recognizable "voices"
without any real language.

**What to steal for Pushling**: randomized pitch per-syllable to prevent
monotony; character-specific base tones (the personality system serves this
purpose); tone conveying more than words — anger, joy, or sarcasm all read
through delivery alone.

# Pikmin — Tiny Creature Sounds

**How it works**: pitched-up vocalizations that suggest tiny size. Later
Pikmin games use vaguely Japanese-sounding gibberish with occasional
recognizable words peeking through.

**What to steal for Pushling**: the "occasional recognizable word" technique
— exactly the Beast-stage approach (see
[speech-milestones](/REFERENCE/speech-milestones.md) and
[voice-tts-stack](/SYSTEMS/voice-tts-stack.md)'s Critter babble-mix ratio);
pitch tied to species/size (the growth stages serve this purpose); the
feeling of smallness conveyed through more than just pitch — timbre matters
too.

# Studio Ghibli Creatures

**How it works**: Ghibli's sound design philosophy holds that creatures
perceive sound differently based on their size — small creatures get sounds
that suggest their scale, with almost-silent details upscaled to suggest
their world-perspective. Sound designers reportedly "thought about how each
character perceives sounds," highlighting nearly-inaudible details and
scaling them to create a creature's-eye view of the world acoustically.

**What to steal for Pushling**: the philosophy of creature-scale audio
perception; warmth and organic quality above all else; the *Wind Rises*
technique — all earthquake sounds in that film were made by human mouths,
proof that mouth-made sounds can represent anything if processed right; the
emotional weight non-verbal sound can carry on its own.

# Spore — Voice Evolution Through Stages

**How it works**: Spore's sound design evolves across game stages.
Cell-stage creatures use pitched-up vocalizations (recorded by voice actor
Roger Jackson). Creature-stage uses hundreds of processed animal recordings,
spliced and electronically altered. Civilization stage introduces
"Sporelish," a full creature language. A key production detail: mouth
pieces placed in Spore's creature editor affect the creature's voice —
different mouth types produce different vocal qualities, mapping the
creature's physical form directly onto its voice.

**What to steal for Pushling**: the staged voice-evolution concept itself
(directly mirrored in Pushling's growth-stage voice tiers); using real
recordings as base material and processing them extensively rather than
synthesizing from nothing; the concept that a creature's physical form
should influence its voice; the professional lesson that Spore's team
recorded trained animals (monkeys, elephants) and processed the results
heavily rather than relying on synthesis alone.

# Citations

[1] `docs/CREATURE-VOICE-DESIGN.md` §7, Appendix C
[2] [Formant Shifting Techniques (Baby Audio)](https://babyaud.io/blog/formant-shifting)
[3] [Animalese — Nookipedia](https://nookipedia.com/wiki/Animalese)
[4] [Character Voicing Techniques (Mitchell Vitez)](https://vitez.me/character-voicing)
[5] [Spore Sound Design (Mix Magazine)](https://www.mixonline.com/sfp/sfp-magical-world-spore-369211)
[6] [Studio Ghibli Sound Design Analysis](https://www.asoundeffect.com/fhayao-miyazaki-film-sound/)
[7] [Creature Vocalisations for Games (Abbey Road Institute)](https://abbeyroadinstitute.com.au/blog/sound-design-creature-vocal/)
[8] [GDC: Next Level Creature Sound Design](https://gdcvault.com/play/1024623/Next-Level-Creature-Sound)
[9] [Crafting Creature Sound Design (Shaping Waves)](https://www.shapingwaves.com/crafting-convincing-powerful-and-emotional-creature-sound-design-for-games/)
[10] `animalese-swift` (Swift port of Animalese): https://github.com/jakubpetrik/animalese-swift
[11] `animalese.js` (reference implementation): https://github.com/Acedio/animalese.js
