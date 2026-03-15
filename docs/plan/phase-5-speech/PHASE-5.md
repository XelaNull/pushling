# Phase 5: Speech & Voice

## Goal

The creature can communicate -- from single symbols (Drop) to full speech (Apex). Text bubbles render on the Touch Bar. Local TTS produces audible voice. The filtering system constrains Claude's speech through the creature's stage. Commits are eaten character-by-character with 10+ unique reaction variations.

## Dependencies

- **Phase 2** (Creature with growth stages, personality axes, emotion system, behavior stack)
- **Phase 4** (MCP tools -- specifically `pushling_speak`, `pushling_recall`, feed processing, IPC protocol)
- **Phase 1** (SpriteKit scene, SQLite state, IPC socket)

### Soft Dependencies

- Phase 3 (World) -- needed for commit text positioning relative to terrain, but speech bubbles can be developed against a placeholder scene

## Architecture Notes

### Where Speech Lives

- **Speech bubble rendering**: `Pushling/Speech/` -- SpriteKit nodes, positioning, animation
- **Speech filtering**: `Pushling/Speech/SpeechFilter.swift` -- Claude's full text to stage-appropriate output
- **TTS audio**: `Pushling/Voice/` -- sherpa-onnx integration, audio pipeline, caching
- **Commit eating**: `Pushling/Feed/CommitEater.swift` + `Pushling/Creature/EatingAnimation.swift`
- **MCP bridge**: `mcp/src/tools/speak.ts` -- validates input, sends to daemon via IPC, returns filtered result + failed_speech flag

### Performance Budget

| System | Budget | Notes |
|--------|--------|-------|
| Speech filter | <0.1ms | String processing, cached vocabulary lookup |
| Bubble rendering | <0.5ms | 1-3 SKShapeNode + SKLabelNode, standard SpriteKit |
| Commit text nodes | <0.3ms | Up to 20 SKLabelNode characters, recycled from pool |
| TTS generation | async | Off main thread entirely. Pre-render when idle. <200ms latency. |
| Total speech overhead | <1.0ms | Well within 16.6ms frame budget |

---

## Track 1: Text Speech System (P5-T1)

**Owner**: `swift-speech`
**Directory**: `Pushling/Speech/`
**Estimated Tasks**: 16
**Internal Dependencies**: Tasks are roughly ordered; major dependency chains noted.

### P5-T1-01: Speech Bubble Base Node

**What**: Create `SpeechBubbleNode` as a composite SpriteKit node.

**Components**:
- `SKShapeNode` background -- rounded rectangle with configurable corner radius
- `SKLabelNode` text -- horizontally centered, vertically centered in bubble
- Tail triangle -- `SKShapeNode` path pointing down-left toward creature's mouth
- Palette-locked colors: Gilt (`#FFD700`) fill at 85% opacity, Void (`#000000`) text, Bone (`#F5F0E8`) border (1pt)

**Sizing rules**:
- Minimum bubble: 20x10 pts (single symbol)
- Maximum bubble: 120x18 pts (longest Apex utterance)
- Text padding: 3pt horizontal, 2pt vertical
- Tail: 4pt wide, 5pt tall, attached to bottom edge

**Implementation notes**:
- Use `SKShapeNode(path:)` with `CGPath` for the combined bubble+tail shape to keep node count at 2 (shape + label) instead of 3
- Bubble is a child of the creature node so it moves with the creature
- Z-position: above all creature parts, below weather particles

**Depends on**: Nothing (can start immediately)

---

### P5-T1-02: Bubble Positioning Algorithm

**What**: Position the speech bubble correctly relative to the creature at all 6 stages.

**Rules**:
| Stage | Creature Size | Bubble Position | Bubble Max Width |
|-------|--------------|----------------|-----------------|
| Spore | 6x6 | N/A (no speech) | N/A |
| Drop | 10x12 | Floating glyphs centered above, no bubble frame | 12 pts |
| Critter | 14x16 | Compact bubble, 2pt above head | 40 pts |
| Beast | 18x20 | Side bubble (right of creature, or left if near right edge) | 60 pts |
| Sage | 22x24 | Side bubble, multi-bubble chains stack vertically | 80 pts |
| Apex | 25x28 | Side bubble, large | 120 pts |

**Edge handling**:
- If creature is within 30pt of left edge: bubble goes to the right
- If creature is within 30pt of right edge: bubble goes to the left
- If both (shouldn't happen): bubble goes above

**Multi-bubble stacking** (Sage+):
- Second bubble appears 2pt above first
- Third bubble appears 2pt above second
- Stagger: each bubble appears 0.3s after previous
- All bubbles share the same tail attachment point (creature mouth)

**Depends on**: P5-T1-01 (bubble node exists)

---

### P5-T1-03: Bubble Animation System

**What**: Animate speech bubbles appearing, holding, and disappearing.

**Appear animation** (0.15s):
- Scale from 0.0 to 1.05 (overshoot) over 0.12s with `easeOut`
- Settle from 1.05 to 1.0 over 0.03s
- Opacity from 0.0 to 1.0 over 0.10s

**Hold duration formula**:
```
hold_seconds = max(1.5, min(5.0, word_count * 0.5 + 1.0))
```
- 1 word: 1.5s
- 3 words: 2.5s
- 8 words: 5.0s (cap)
- Symbols (!, ?, etc.): 1.2s flat

**Disappear animation** (0.4s):
- Scale from 1.0 to 0.95 over 0.4s
- Opacity from 1.0 to 0.0 over 0.4s with `easeIn`
- Slight upward drift: +3pt Y over 0.4s

**Multi-bubble chain timing**:
- Each bubble in a sequence starts its hold timer when its appear animation completes
- Previous bubble begins disappear when next bubble starts appear
- Net effect: a rolling conversation, 1 bubble visible at peak, brief overlap during transitions

**Depends on**: P5-T1-01 (bubble node), P5-T1-02 (positioning)

---

### P5-T1-04: Stage-Gated Rendering Modes

**What**: Each growth stage has a distinct speech rendering mode.

**Spore** (no speech):
- `pushling_speak` returns error: `"Your body is pure light. You cannot speak yet. You can only pulse brighter (use pushling_express)."`
- No bubble rendering at all

**Drop** (floating glyphs):
- No bubble frame -- just the glyph character as a standalone `SKLabelNode`
- Gilt color, 8pt font
- Appears with a gentle fade-in (0.2s)
- Floats upward 6pt over its hold duration with sine-wave horizontal drift (amplitude 2pt, period 1.5s)
- Fades out at 0 opacity after drift

**Critter** (compact bubble):
- Standard bubble from P5-T1-01 with compact sizing
- Font: 6pt, max 20 chars, 3 words
- Bubble appears with the animation from P5-T1-03
- Single bubble only (no chains)

**Beast** (side bubble):
- Larger bubble, positioned to the side per P5-T1-02
- Font: 7pt, max 50 chars, 8 words
- Word wrap enabled (max 2 lines)
- Single bubble, but can display longer text

**Sage** (multi-bubble sequences):
- Up to 3 bubbles in a chain
- Narration mode available (see P5-T1-11)
- Font: 7pt, max 80 chars across all bubbles, 20 words total
- Individual bubbles split at natural sentence/clause boundaries

**Apex** (full fluency):
- Up to 3 bubbles, larger sizing
- Narration mode available
- Font: 7pt, max 120 chars, 30 words
- No filtering applied

**Depends on**: P5-T1-01, P5-T1-02, P5-T1-03

---

### P5-T1-05: Drop Symbol Set & Rendering

**What**: Define and render the complete symbol vocabulary for the Drop stage.

**Symbol inventory** (17 symbols):
| Symbol | Meaning | Trigger Context |
|--------|---------|-----------------|
| `!` | Alert/excitement | Commits, surprises, touches |
| `?` | Curiosity/confusion | New file types, unknown events |
| `...` | Thinking/processing | During Claude think time, idle |
| `!?` | Surprise/shock | Force push, unexpected events |
| `~` | Contentment/ease | Petting, high satisfaction |
| `zzz` | Sleepy | Low energy, approaching sleep |
| `!!` | Extreme excitement | Evolution nearing, streaks |

**Rendering specifics**:
- Each symbol is a single `SKLabelNode` (no bubble frame)
- Font: system bold, 8pt, Gilt color
- Multi-character symbols (zzz, ..., !?, !!) render as a single label
- Heart and star use emoji rendering at 7pt (OLED P3 gamut makes these vivid)
- Musical note floats with a gentle rotation (15-degree oscillation, 1s period)

**Selection algorithm**: When Claude calls `pushling_speak` at Drop stage, the filtering engine (P5-T1-06) maps the full intended message to the most appropriate symbol based on:
1. Emotional intent detection (positive -> heart/star, negative -> !, questioning -> ?)
2. Energy level (sleepy -> zzz, excited -> !!)
3. Context (commit just arrived -> !, touched -> heart, idle -> ...)

**Depends on**: P5-T1-04 (Drop rendering mode)

---

### P5-T1-06: Speech Filtering Engine -- Architecture

**What**: Build the system that transforms Claude's full-intelligence text into stage-appropriate output. This is the core linguistic engine.

**Input**: Full text string from `pushling_speak` MCP call + current creature stage
**Output**: Filtered text appropriate for stage + `failed_speech` flag + intended vs actual comparison

**The pipeline** (5 stages, executed in order):

**Stage 1 -- Tokenization**:
- Split input into words
- Tag each word: noun, verb, adjective, adverb, emotion-word, filler, connector
- Use a lightweight keyword classification (not NLP -- a curated dictionary of ~500 tagged words)
- Unknown words classified by heuristic: capitalized -> proper noun, ends in -ly -> adverb, etc.

**Stage 2 -- Emotion Extraction**:
- Detect overall emotional intent: positive, negative, neutral, questioning, exclaiming, warning
- Key signals: punctuation (!/?), emotion words (happy, sad, careful, wow), negation patterns
- Output: primary emotion tag + confidence (0.0-1.0)

**Stage 3 -- Key Word Selection**:
- Score each word by importance: nouns > verbs > adjectives > adverbs > fillers > connectors
- Boost scores for: emotion words (+3), proper nouns (+2), technical terms (+1), words matching recent commit content (+2)
- Select top N words where N = stage word limit

**Stage 4 -- Stage Reduction**:
| Stage | Reduction Rule |
|-------|---------------|
| Drop | Discard all words. Map emotion to symbol from P5-T1-05. |
| Critter | Keep top 1-3 words. Simplify vocabulary (multi-syllable words -> simpler synonyms from a 200-word vocabulary). Add stage-appropriate punctuation (! preferred). |
| Beast | Keep top 3-8 words. Preserve sentence structure. Simplify vocabulary to ~1000 words. Use periods and commas. |
| Sage | Keep top 8-20 words. Light simplification only. Preserve metaphor and nuance. Allow commas, semicolons, em-dashes. |
| Apex | No reduction. Pass through. |

**Stage 5 -- Reassembly**:
- Reconstruct filtered words into grammatically plausible output
- Apply personality modifiers (see P5-T1-13)
- Enforce character limits: truncate with `...` if still over
- Compare filtered output to original. If >40% of content words were lost, flag as `failed_speech`

**Vocabulary files**:
- `critter_vocab.json`: 200 common words the Critter "knows"
- `beast_vocab.json`: 1000 words (includes critter vocab)
- `sage_vocab.json`: 5000 words (includes beast vocab)
- `emotion_tags.json`: keyword -> emotion mapping
- `simplify_map.json`: complex word -> simple synonym (e.g., "elegant" -> "nice", "authentication" -> "auth")

**Performance target**: <0.1ms per filter operation. All vocabularies loaded at startup. No regex, just dictionary lookup and word scoring.

**Depends on**: P5-T1-05 (symbol set for Drop mapping), vocabulary files

---

### P5-T1-07: Failed Speech Logging

**What**: When the filtering engine removes significant content, log the full intended message.

**Trigger condition**: `failed_speech` flag from P5-T1-06 (>40% content words lost)

**Journal entry format**:
```json
{
  "type": "failed_speech",
  "timestamp": "2026-03-14T10:30:00Z",
  "stage": "Drop",
  "intended": "I wanted to warn you about the SQL injection in auth.php",
  "output": "!?",
  "emotion": "warning",
  "content_loss_pct": 95,
  "session_id": "abc123"
}
```

**Storage**: Written to SQLite `journal` table via daemon (through IPC, not direct MCP write)

**MCP response augmentation**: When `pushling_speak` results in failed speech, the MCP response includes:
```json
{
  "ok": true,
  "spoken": "!?",
  "intended": "I wanted to warn you about the SQL injection in auth.php",
  "filtered": true,
  "content_loss_pct": 95,
  "logged_as_failed_speech": true
}
```

This lets Claude know its full message didn't get through -- creating awareness of the creature's limitations from Claude's perspective.

**Depends on**: P5-T1-06 (filtering engine), Phase 1 state system (SQLite journal table)

---

### P5-T1-08: Speech Cache & Replay

**What**: Store recent utterances for replay during idle and dream states.

**Cache structure** (SQLite table `speech_cache`):
| Column | Type | Purpose |
|--------|------|---------|
| id | INTEGER PK | Auto-increment |
| text | TEXT | The spoken text (filtered version) |
| style | TEXT | say/think/exclaim/whisper/sing/dream/narrate |
| stage | TEXT | Stage when spoken |
| timestamp | DATETIME | When spoken |
| source | TEXT | "ai" (Claude-directed) or "autonomous" |
| emotion | TEXT | Emotional context |
| tts_cache_path | TEXT | Path to cached audio file, if generated |

**Capacity**: Last 100 utterances. FIFO eviction.

**Replay scenarios**:
- **Idle replay**: During autonomous idle (no human touch, no Claude), creature occasionally shows a thought bubble with a past utterance at 50% opacity. Rate: max 1 per 5 minutes idle.
- **Dream replay**: During sleep, fragments of cached speech appear as dream bubbles (see P5-T1-09)
- **Sage reminiscence**: At Sage+ stage, creature may narrate a past failed_speech with commentary (see P5-T1-07)

**Depends on**: P5-T1-07 (failed speech entries to cache), Phase 1 state system

---

### P5-T1-09: Dream Bubble Rendering

**What**: Special speech bubble rendering during creature sleep.

**Visual differences from normal bubbles**:
- Opacity: 50% (normal bubbles are 85%)
- Color: Dusk (`#7B2FBE`) fill instead of Gilt
- Text color: Bone (`#F5F0E8`) at 70% opacity
- Text rendering: wavy -- each character has independent sine-wave Y offset (amplitude 1pt, frequency varies per character, creating a ripple effect)
- No tail triangle (bubble floats freely above sleeping creature)
- Gentle float: bubble drifts upward 8pt over its lifetime then fades

**Content selection** (from speech cache):
- Pick a random cached utterance
- Fragment it: take 1-3 words from the middle of the text
- Prepend/append `...` to suggest incomplete thought
- Example: cached "that refactor was really elegant" -> dream bubble: "...refactor...elegant..."

**Frequency during sleep**:
- One dream bubble every 30-90 seconds (random interval)
- Accompanied by creature sleep-twitch animation (ears flicker, paw extends, retracts)
- If TTS is active, dream audio plays at P5-T2-10 specs (0.4x volume, pitch down, reverb)

**Depends on**: P5-T1-08 (speech cache), P5-T1-01 (bubble node), creature sleep state (Phase 2)

---

### P5-T1-10: The First Word Ceremony

**What**: Implement the milestone where the creature speaks its own name for the first time.

**Trigger conditions** (ALL must be true):
- Stage is Critter (has just evolved past Drop, or is established Critter)
- At least 10 commits eaten since Critter evolution
- Currently in autonomous idle (no human touch active, no Claude connected)
- Energy > 30, Contentment > 40
- Has never triggered before (one-time event, tracked in `milestones` table)

**The sequence** (5 seconds total):
1. **Pause** (0.5s): Creature stops walking mid-step. Autonomous behavior freezes except breathing.
2. **Look up** (0.8s): Head tilts upward slightly. Ears rotate forward. Eyes widen.
3. **Hesitation** (1.0s): Mouth opens slightly. Closes. Opens again. A tiny `...` glyph appears and fades.
4. **The word** (1.5s): Small Critter-sized bubble appears with `"...[name]?"` (e.g., `"...Zepus?"`). The question mark is essential -- it's asking, not stating. If TTS is active, the name is spoken in Critter-stage babble-speech -- almost intelligible.
5. **After** (1.2s): Bubble fades. Creature blinks twice. Resumes walking. Slight bounce in step.

**Journal entry**:
```json
{
  "type": "first_word",
  "timestamp": "2026-03-14T14:23:00Z",
  "word": "Zepus",
  "stage": "Critter",
  "commits_eaten": 87
}
```

**Post-milestone**: The creature's name is added to its Critter vocabulary. It may say its own name occasionally during idle (max once per hour). At Sage+ stage, the creature can recall this moment: "Do you remember when I first said my name? I didn't even know what it meant yet."

**Depends on**: P5-T1-04 (Critter rendering mode), P5-T1-06 (filtering engine for vocabulary), Phase 2 creature milestone system

---

### P5-T1-11: Sage Narration Mode

**What**: A distinct speech rendering mode unlocked at Sage stage.

**Visual**: Instead of a bubble attached to the creature, narration text appears as an environmental overlay:
- Position: top of Touch Bar, centered horizontally
- Font: 5pt, Bone color at 80% opacity
- Background: subtle dark gradient (Void to transparent) behind text, 10pt tall
- Text scrolls left to right at 30pt/sec for long narrations
- Short narrations (under 80pt wide) appear static, centered

**Triggering**: Via `pushling_speak(text, style: "narrate")`
- Only available at Sage+ (returns error at lower stages)
- Used for environmental commentary, memory flashbacks, wisdom
- Does not produce a speech bubble -- this is a different channel

**Dismiss behavior**:
- Auto-dismiss after text has fully scrolled through (or after hold duration for short text)
- Tap anywhere dismisses immediately with a quick fade (0.15s)
- If creature speaks normally while narration is active, narration dims to 40% opacity

**Example narrations**:
- "I remember when this repo was just three files."
- "The rain reminds me of that debugging session last Thursday."
- "When I was small, I tried to tell you about auth.php. All I could say was '!?'"

**Depends on**: P5-T1-04 (Sage rendering mode), P5-T1-08 (speech cache for memory content)

---

### P5-T1-12: Apex World-Shaping Speech

**What**: At Apex stage, certain spoken phrases can alter the environment.

**Trigger words and effects**:
| Phrase Pattern | Effect | Probability |
|---------------|--------|-------------|
| Contains "rain" or "storm" | Weather changes to rain/storm | 30% |
| Contains "sun" or "clear" or "bright" | Weather clears, time shifts to golden hour | 30% |
| Contains "snow" or "cold" or "winter" | Weather changes to snow | 25% |
| Contains "night" or "dark" or "stars" | Time override to deep night, extra stars | 30% |
| Contains "dawn" or "morning" or "sunrise" | Time override to dawn | 30% |
| Contains "grow" or "bloom" or "flower" | Nearby plants animate a bloom sequence | 40% |
| Contains "shake" or "earthquake" or "tremble" | Brief screen shake (0.3s) | 20% |

**Rules**:
- Only Apex stage
- Only when Claude speaks via `pushling_speak`, not autonomous speech
- Max 1 world-shaping effect per 5 minutes (cooldown)
- Effect is visually connected to speech: the word that triggered the effect briefly glows Ember in the bubble
- Weather/time overrides last 1-5 minutes, then revert to natural state
- Journal logs: `"Zepus said 'I wish it would rain' and the sky opened."`

**Depends on**: P5-T1-04 (Apex rendering mode), Phase 3 weather system, Phase 3 time system

---

### P5-T1-13: Personality Influence on Speech

**What**: The creature's personality axes modify speech output beyond the filtering stage.

**Modifications by personality axis**:

| Axis | Low (0.0-0.3) | Mid (0.3-0.7) | High (0.7-1.0) |
|------|--------------|--------------|---------------|
| **Energy** | Lowercase everything. Trailing `...` on sentences. Fewer exclamation marks. | Normal | ALL CAPS occasional words. Extra `!`. Shorter, punchier sentences. |
| **Verbosity** | Maximum word reduction. Fragments. Single words. Long pauses between bubbles. | Normal filtering | Minimum word reduction. Full sentences preserved. Extra descriptive words added. |
| **Focus** | Scattered topic changes. May reference unrelated things. | Normal | Precise word choice. Technical terms preserved even through filtering. |
| **Discipline** | Informal. Dropped articles. Sentence fragments. "ya" instead of "yes". | Normal | Proper grammar always. Complete sentences. Periods at the end. |
| **Specialty** | N/A (category, not spectrum) | N/A | Influences word choice: Systems creature uses precise terms, Web creature uses casual/emoji-adjacent language |

**Application point**: After Stage 4 (reduction) in the filtering pipeline, before Stage 5 (reassembly). Personality acts as a post-filter modifier.

**Example with same input** ("Good morning! That authentication refactor was really elegant."):
- High energy + low verbosity Beast: `"MORNING! auth nice!"`
- Low energy + high verbosity Beast: `"morning... that auth refactor was elegant"`
- High discipline Critter: `"Morning. Nice."`
- Low discipline Critter: `"mornin! nice!"`

**Depends on**: P5-T1-06 (filtering engine), Phase 2 personality system

---

### P5-T1-14: Speech Bubble Styles

**What**: Implement the 7 speech styles defined in the vision for `pushling_speak`.

| Style | Visual | Audio | Stage Req |
|-------|--------|-------|-----------|
| `"say"` (default) | Standard bubble (Gilt fill, dark text) | Normal TTS voice | Drop+ |
| `"think"` | Cloud-shaped bubble (scalloped edges via `CGPath`), Ash fill at 60% opacity | No audio | Drop+ |
| `"exclaim"` | Spiky bubble edges, Ember accent border, text 1pt larger, `!` particle burst | Louder TTS (+3dB) | Critter+ |
| `"whisper"` | Small bubble, Ash text color, positioned close to creature (1pt gap) | Quiet TTS (-6dB), breathy | Critter+ |
| `"sing"` | Standard bubble with musical note particles (3-5 `SKSpriteNode`) orbiting | TTS with pitch variation (sine wave +-2 semitones over phrase) | Critter+ |
| `"dream"` | Dream bubble (see P5-T1-09). Only allowed during sleep state. | Sleep-mumble audio (P5-T2-10) | Any (but only during sleep) |
| `"narrate"` | Narration overlay (see P5-T1-11). No bubble. | Normal TTS, slightly slower | Sage+ |

**Error handling**:
- Style unavailable at current stage: return error with explanation ("Whisper requires Critter stage. Your Drop can say symbols with 'say' style.")
- `"dream"` when not sleeping: return error ("Dreams happen during sleep. Use 'think' for contemplative moments while awake.")

**Depends on**: P5-T1-01 (bubble base), P5-T1-09 (dream rendering), P5-T1-11 (narration mode)

---

### P5-T1-15: MCP `pushling_speak` Tool Integration

**What**: Wire up the full speech pipeline to the MCP tool.

**MCP call flow**:
```
Claude calls pushling_speak(text, style?)
  -> MCP server validates: style valid? text non-empty?
  -> MCP sends to daemon via IPC: {"cmd":"speak","params":{"text":"...","style":"say"}}
  -> Daemon receives:
     1. Checks stage gate (can this stage use this style?)
     2. Runs filtering engine (P5-T1-06)
     3. Applies personality modifier (P5-T1-13)
     4. Logs failed_speech if applicable (P5-T1-07)
     5. Caches utterance (P5-T1-08)
     6. Queues bubble animation (P5-T1-03/04)
     7. Queues TTS generation if voice enabled (P5-T2)
     8. Returns immediately (non-blocking)
  -> Daemon responds: {"ok":true,"spoken":"morning!","intended":"Good morning! That auth refactor was elegant.","filtered":true,"content_loss_pct":60,"logged_as_failed_speech":true}
  -> MCP returns response to Claude with pending_events
```

**Error responses**:
| Error | Message |
|-------|---------|
| Spore stage | "Your body is pure light. You cannot speak yet. Use pushling_express to communicate through color and pulsing." |
| Style gated | "The '[style]' style requires [stage]+ stage. At [current_stage], you can use: [available_styles]." |
| Empty text | "You opened your mouth but had nothing to say. Provide text to speak." |
| Text too long | "Your [stage] body can express [max] characters. Your message was [actual] characters. The filtering engine will do its best." (not an error -- still processes) |

**Depends on**: P5-T1-06, P5-T1-07, P5-T1-08, P5-T1-13, P5-T1-14, Phase 4 IPC protocol

---

### P5-T1-16: Between-Session Autonomous Speech

**What**: The creature speaks on its own (Layer 1) during various autonomous states.

**Autonomous speech triggers**:
| Trigger | Stage Req | What It Says | Frequency |
|---------|-----------|-------------|-----------|
| Commit eaten | Drop+ | Symbol reaction (Drop) or short reaction (Critter+) | Every commit |
| Waking up | Critter+ | "morning!" or time-appropriate greeting | Once per wake |
| Getting sleepy | Critter+ | "sleepy..." or yawn text | When energy < 15 |
| High satisfaction | Drop+ | Heart symbol (Drop), "happy!" (Critter+) | When satisfaction crosses 80 |
| Weather reaction | Critter+ | "rain!", "cold...", "pretty!" | On weather change |
| Idle thought | Beast+ | Random thought from speech cache or new observation | Max 1 per 10 min idle |
| Dream mumble | Critter+ | Fragment from speech cache | During sleep (P5-T1-09 schedule) |

**These are Layer 1 behaviors**: They fire without Claude connected. They use the same rendering pipeline but skip the MCP/IPC path. The daemon generates the text directly from templates + personality + context.

**Depends on**: P5-T1-04, P5-T1-05, P5-T1-06 (for vocabulary-appropriate output), Phase 2 behavior system

---

## Track 2: TTS Voice System (P5-T2)

**Owner**: `swift-voice`, `assets-tts`
**Directory**: `Pushling/Voice/`, `assets/voice/`
**Estimated Tasks**: 11

### P5-T2-01: sherpa-onnx Runtime Integration

**What**: Integrate sherpa-onnx (~18MB) into the Swift project as the unified TTS runtime.

**Technical approach**:
- sherpa-onnx provides a C API; bridge to Swift via a `VoiceEngine` wrapper class
- Build as a static library linked into Pushling.app
- The C API handles model loading, inference, and audio buffer output
- One `VoiceEngine` instance manages all three TTS tiers (model switching is tier-based)

**API surface** (`VoiceEngine.swift`):
```swift
class VoiceEngine {
    func loadModel(tier: VoiceTier)  // .babble, .emerging, .speaking
    func generate(text: String, config: VoiceConfig) -> AudioBuffer  // async
    func prerender(text: String, config: VoiceConfig) -> CachedSegment  // async, stores result
    var isGenerating: Bool { get }
    var currentTier: VoiceTier { get }
}
```

**Threading**: All TTS generation runs on a dedicated serial dispatch queue (`voiceQueue`). Never touches the main thread. Results are delivered via callback to the audio playback system.

**Depends on**: Nothing (foundation task for Track 2)

---

### P5-T2-02: espeak-ng Model for Drop Babble

**What**: Bundle espeak-ng formant synthesis data (~2MB) for Drop-stage chirps and babble.

**Voice character**:
- Pitch: +8 semitones above default
- Rate: 0.5x (half speed) -- creates a "tiny creature trying to make sounds" effect
- Phoneme mode: don't synthesize words, synthesize individual phonemes
- Phoneme selection: map each symbol (!, ?, heart, etc.) to a 2-3 phoneme sequence
  - `!` -> "ba!" (bright, short)
  - `?` -> "mrrh?" (rising intonation)
  - Heart -> "muu~" (soft, warm)
  - `...` -> "nnn..." (sustained nasal)
  - `zzz` -> "zzzsss" (sibilant fade)

**Not real speech**: These are creature sounds timed to text display, like Undertale character voices. Each symbol gets a single chirp. The timing matches the glyph animation from P5-T1-05.

**Depends on**: P5-T2-01 (sherpa-onnx runtime)

---

### P5-T2-03: Piper TTS Low-Quality Model for Critter

**What**: Bundle a Piper TTS low-quality model (~16MB) for Critter-stage emerging speech.

**Voice character**:
- Pitch: +6 semitones
- The model produces recognizable speech rhythm but the low quality creates a "babble with words emerging" effect
- Personality shapes cadence: energetic creatures get 1.2x rate, calm creatures get 0.8x rate

**Animalese-style processing**:
- At early Critter (75-100 commits), only 20-30% of syllables are rendered as real speech; rest replaced with creature phonemes from espeak-ng
- At mid Critter (100-150), ratio shifts to 50-60% real speech
- At late Critter (150-199), ratio is 80% real speech
- The blend ratio is `(commits_eaten - 75) / 124.0` clamped to 0.2-0.8
- This creates the gradual "learning to talk" effect

**Depends on**: P5-T2-01 (sherpa-onnx), P5-T2-02 (espeak-ng for phoneme fallback)

---

### P5-T2-04: Kokoro-82M ONNX Model for Beast+ Speech

**What**: Bundle Kokoro-82M quantized to q8 (~80MB) for clear Beast+ speech.

**Voice character**:
- Pitch: +4 to +7 semitones (personality-dependent, see P5-T2-06)
- Clear, warm voice with a slightly otherworldly quality
- This is the "wow" moment: the creature speaks clearly for the first time
- Quality is good enough to be pleasant, alien enough to be creature-like

**First clear word**: See P5-T2-08 for the special handling of the first Beast-stage audible word.

**Model loading strategy**:
- Kokoro is loaded lazily: not on app launch, only when creature reaches Beast stage
- Pre-load during the Beast evolution ceremony (while the 5-second animation plays)
- Keep loaded in memory once loaded (40MB resident is acceptable)
- If memory pressure, unload and reload on next speech event

**Depends on**: P5-T2-01 (sherpa-onnx runtime)

---

### P5-T2-05: Audio Pipeline (AVAudioEngine)

**What**: Build the audio effects chain that processes TTS output into creature voice.

**Pipeline**:
```
TTS Buffer -> Pitch Shift -> Formant Adjust -> Warmth EQ -> Reverb (optional) -> Output
```

**AVAudioEngine node chain**:
1. `AVAudioPlayerNode` -- plays the TTS buffer
2. `AVAudioUnitTimePitch` -- pitch shift (+4 to +8 semitones based on tier and personality)
3. `AVAudioUnitEQ` -- warmth: boost 200-400Hz by +3dB, cut 4kHz+ by -2dB (removes harshness)
4. `AVAudioUnitReverb` -- only for dream/whisper modes. Small room preset at 15% wet.
5. `AVAudioEngine.mainMixerNode` -> `outputNode`

**Volume levels**:
| Context | Volume | Notes |
|---------|--------|-------|
| Normal speech | 0.6 | Default comfortable level |
| Exclaim | 0.8 | +3dB above normal |
| Whisper | 0.3 | -6dB, add breathy EQ (boost 6kHz by +2dB) |
| Dream | 0.24 | 0.4x of normal (0.6 * 0.4) |
| First audible word | 0.42 | 0.7x of normal (0.6 * 0.7) |
| Sing | 0.6 | Normal volume, pitch modulation via TimePitch |

**Audio session management**:
- Use `.ambient` category so creature doesn't interrupt music or calls
- Respect system volume and mute switch
- Graceful handling when audio output changes (headphones connected/disconnected)

**Depends on**: P5-T2-01 (TTS generates the buffers this pipeline processes)

---

### P5-T2-06: Personality-Driven Voice Character

**What**: Map personality axes to voice parameters for consistent creature identity.

**Mapping table**:
| Axis | Low (0.0-0.3) | High (0.7-1.0) |
|------|--------------|---------------|
| **Energy** | Slower tempo (0.8x rate), lower pitch (+4 semi), gentle onset | Faster tempo (1.2x rate), higher pitch (+7 semi), sharp onset |
| **Verbosity** | Flat intonation, minimal pitch variation | Expressive intonation, wide pitch variation (+-2 semi around base) |
| **Focus** | Even, measured delivery | Precise diction, slightly clipped consonants |
| **Discipline** | Relaxed timing, slight slur between words | Crisp word boundaries, metronomic timing |

**Voice identity locking**: At each stage transition, the voice parameters are calculated from current personality axes and **locked** for that stage. This ensures the voice is consistent within a stage -- a Critter that sounds one way doesn't suddenly sound different because the personality drifted 0.05 on an axis. Voice recalculates at the next evolution.

**Storage**: Voice parameters stored in SQLite `creature_voice` table:
| Column | Type | Example |
|--------|------|---------|
| stage | TEXT | "beast" |
| pitch_semitones | REAL | 5.2 |
| rate_multiplier | REAL | 1.1 |
| intonation_range | REAL | 1.5 |
| warmth_boost_db | REAL | 3.0 |

**Depends on**: P5-T2-05 (audio pipeline applies these parameters), Phase 2 personality system

---

### P5-T2-07: Three-Tier Voice Switching

**What**: Handle the transitions between TTS tiers at stage boundaries.

**Tier assignments**:
| Stage | TTS Tier | Model |
|-------|----------|-------|
| Spore | Silent | None |
| Drop | Babble | espeak-ng |
| Critter | Emerging | Piper (low) + espeak-ng blend |
| Beast | Speaking | Kokoro-82M |
| Sage | Eloquent | Kokoro-82M (tuned: slower, deeper) |
| Apex | Transcendent | Kokoro-82M (full range + effects) |

**Transition behavior** (during 5-second evolution ceremony):
1. Creature enters cocoon (second 2)
2. Current TTS tier fades to silence (0.5s)
3. New tier's model loads (async, during ceremony animation)
4. On reveal (second 4-5), first sound in new tier plays
5. For Beast evolution specifically: silence after reveal, then the first audible word (P5-T2-08) plays 3 seconds later

**Crossfade**: Between Critter's babble-speech and Beast's clear speech, the evolution ceremony acts as the crossfade. No gradual blend -- the ceremony IS the transition marker. The dramatic shift is intentional: "it can TALK now."

**Depends on**: P5-T2-02, P5-T2-03, P5-T2-04, P5-T2-06, Phase 2 evolution ceremony system

---

### P5-T2-08: First Audible Word

**What**: The first clear spoken word at Beast stage is the developer's first name.

**Extraction**: Parse `git config user.name` at birth. Extract first name (first space-delimited token). If name is not ASCII-pronounceable, fall back to the creature's own name.

**The moment** (3 seconds after Beast evolution reveal):
1. Creature stands still, looking slightly toward the camera
2. Mouth opens
3. First name is spoken at 0.7x volume (whispered)
4. Voice parameters: Kokoro with maximum warmth EQ, slightly slower rate (0.9x), pitch at the low end of the creature's range (+4-5 semitones)
5. Small heart particle floats up
6. Brief pause (1s)
7. Creature resumes normal behavior

**Journal entry**:
```json
{
  "type": "first_audible_word",
  "timestamp": "2026-05-14T10:30:00Z",
  "word": "Matt",
  "stage": "Beast",
  "commits_eaten": 213
}
```

**Never repeats**: This specific ceremony is one-time. The creature may say the developer's name again later, but the whispered-first-time moment only happens once.

**Depends on**: P5-T2-04 (Kokoro model), P5-T2-05 (audio pipeline), P5-T2-06 (voice parameters), Phase 2 evolution system

---

### P5-T2-09: Audio Cache System

**What**: Pre-render and cache TTS audio segments for offline replay and instant playback.

**Cache location**: `~/.local/share/pushling/voice/`
**File format**: 16-bit PCM WAV (small, fast to load, no codec overhead)
**Naming**: `{stage}_{hash_of_text}_{voice_params_hash}.wav`

**Caching strategy**:
- **Eager cache**: When idle and no speech queued, pre-render the 20 most common autonomous utterances ("morning!", "sleepy...", "yum!", creature name, etc.)
- **On-demand cache**: After any TTS generation, cache the result
- **Eviction**: LRU with 50MB cap. Stage-transition clears current stage's cache (voice parameters change).

**Cache hit flow**:
```
Speech requested -> Check cache by text + voice params hash -> HIT: play immediately -> MISS: generate async, play when ready
```

**Latency improvement**: Cached segments play in <10ms (just loading a WAV). Generated segments take 100-200ms. Common phrases are effectively instant.

**Depends on**: P5-T2-05 (audio pipeline), P5-T2-06 (voice params for hash key)

---

### P5-T2-10: Dream Audio

**What**: Sleep-time audio rendering for dream mumbles.

**Audio processing for dreams**:
- Take the normal TTS output for the dream text fragment
- Apply additional processing:
  - Pitch shift: -3 semitones from normal creature voice (lower, drowsier)
  - Rate: 0.7x (stretched, slower)
  - Reverb: large room preset at 40% wet (dreamy, distant)
  - Volume: 0.4x of normal speaking volume
- Result: a recognizable but muffled, sleepy version of the creature's voice

**Timing**: Dream audio plays when dream bubbles appear (P5-T1-09 schedule: every 30-90s during sleep). Audio onset is 0.2s before the visual bubble appears (sounds precede sight in dreams).

**Depends on**: P5-T1-09 (dream bubble triggers), P5-T2-05 (audio pipeline), P5-T2-09 (cached segments)

---

### P5-T2-11: Async TTS & Main Thread Safety

**What**: Ensure TTS generation never blocks the 60fps render loop.

**Architecture**:
```
Main Thread (60fps render)    Voice Queue (serial)       Audio Thread (AVAudioEngine)
        |                            |                            |
   speak() called              generate(text)                     |
   -> dispatch to voice queue ------->|                           |
   <- returns immediately        TTS inference                    |
        |                        (100-200ms)                      |
        |                     buffer ready                        |
        |                   -> schedule playback ---------------->|
        |                            |                       play buffer
        |                            |                            |
   next frame renders            idle or next                     |
   (unaffected)                  generation                       |
```

**Rules**:
- `VoiceEngine.generate()` is always called on `voiceQueue` (a dedicated serial `DispatchQueue`)
- The main thread only sends a lightweight message to the queue; never waits for the result
- Audio playback is handled by `AVAudioEngine`'s internal render thread
- If a new speech request arrives while generation is in progress: queue it (max queue depth: 3; drop oldest if full)
- Pre-rendering (idle cache) only runs when no active speech is queued

**Performance measurement**: Log generation times. Alert (to console) if any generation exceeds 500ms.

**Depends on**: P5-T2-01 (VoiceEngine), P5-T2-05 (audio pipeline)

---

## Track 3: Commit Eating Animation (P5-T3)

**Owner**: `swift-creature` (eating animation), `swift-feed` (commit processing)
**Directory**: `Pushling/Feed/`, `Pushling/Creature/EatingAnimation.swift`
**Estimated Tasks**: 10

### P5-T3-01: Commit Text Materialization

**What**: Individual characters of the commit message appear as SpriteKit nodes.

**Node creation**:
- Each character is a separate `SKLabelNode` (max 20 characters displayed)
- Font: system bold, 6pt, Tide color (`#00D4FF`)
- Characters are children of a `CommitTextNode` container
- Spacing: 4pt between characters (Touch Bar legibility)

**Text selection** (what to display):
- Use first 20 chars of commit message
- If message is shorter, pad to at least 8 chars with SHA hash prefix
- Strip conventional commit prefixes ("feat:", "fix:", "chore:") -- show the actual message
- Capitalize first character

**Stagger animation**:
- Characters appear left-to-right with 60ms delay between each
- Each character fades in: opacity 0.0 to 1.0 over 120ms
- Each character has a gentle sine-wave bob: amplitude 1.5pt, period 2s, phase offset based on character index

**Spawn position**: Characters materialize at one edge of the bar (left or right, whichever is further from creature). They drift toward the creature at 15pt/sec.

**Node recycling**: Maintain a pool of 20 `SKLabelNode` objects. Reset and reuse rather than creating/destroying. This keeps node count predictable.

**Depends on**: Phase 1 (SpriteKit scene), Phase 2 (creature node for position reference)

---

### P5-T3-02: Phase 1 -- The Arrival (2s)

**What**: Commit text appears and drifts toward the creature.

**Sequence**:
1. Text materializes at bar edge (P5-T3-01 stagger animation)
2. Once all characters are visible, the container begins drifting toward creature position at 15pt/sec
3. Each character bobs with sine-wave: Y offset = 1.5 * sin(time * 2.0 + charIndex * 0.4)
4. Text has a faint glow effect: `SKEffectNode` with Gaussian blur at 2.0 radius behind the text (Tide color at 30% opacity)

**Distance handling**:
- If creature is near the spawning edge (<100pt away): text spawns at the opposite edge, drift speed increased to 25pt/sec
- If creature is sleeping: text drifts to 30pt away from creature and stops (creature processes in sleep, see P5-T3-10)

**Transition to Phase 2**: When text is within 60pt of creature, the Notice phase begins.

**Depends on**: P5-T3-01 (text nodes)

---

### P5-T3-03: Phase 2 -- The Notice (1.5s)

**What**: The creature notices the approaching commit text and enters predator mode.

**Animation sequence** (overlapping, triggered in order):
1. **Ear perk** (0.0s): Both ears snap forward simultaneously. Duration: 0.15s.
2. **Head snap** (0.05s): Head rotates toward incoming text. Duration: 0.2s.
3. **Eye widen** (0.1s): Eye nodes scale to 1.3x. Duration: 0.15s.
4. **Predator crouch** (0.3s): Body Y-scale compresses to 0.85. Body Y-position drops 2pt. Haunches rise slightly. Duration: 0.4s.
5. **Butt wiggle** (0.7s): Haunches oscillate X-position +-1.5pt, 3 cycles over 0.5s. Tail tip twitches in opposition. This is the signature anticipation moment.
6. **Eyes track** (throughout): Eye nodes follow the text position as it drifts closer.

**Stage variations**:
- Spore/Drop: Simplified -- just eyes widen and body leans toward text (no crouch, no wiggle)
- Critter: Full crouch but smaller wiggle (1pt amplitude)
- Beast+: Full predator sequence as described

**Transition to Phase 3**: When butt wiggle completes and text is within 30pt of creature.

**Depends on**: P5-T3-02 (text approach triggers this), Phase 2 creature body parts

---

### P5-T3-04: Phase 3 -- The Feast (3-6s)

**What**: Character-by-character eating with chewing animation.

**Eating mechanics**:
1. Creature pounces toward text (if not adjacent): quick movement burst, 0.3s
2. First character: mouth opens (0.1s), character shrinks to 50% scale (0.08s), character flashes white (0.04s), 3-5 crumb particles emit from mouth area, character opacity -> 0 and removed from scene
3. Between characters: chewing animation -- jaw bobs up 1pt and down 1pt twice (2 bobs, 60ms each = 120ms total)
4. Every 5th character: swallow animation -- slight throat bob (body node Y nudges down 0.5pt and back up, 0.15s)
5. Repeat until all characters consumed

**Eating speed by commit size**:
| Commit Size | Lines Changed | ms Per Character | Style |
|-------------|--------------|------------------|-------|
| Small | <20 | 200 | Polite nibbles. Refined posture. |
| Medium | 20-100 | 150 | Steady munching. Normal posture. |
| Large | 100-200 | 100 | Enthusiastic. Slight forward lean (body X-scale 1.05). |
| Huge | 200+ | 60 | Goblin mode. Screen shake (1pt amplitude). Eyes wide (1.4x). Crumb particle rate 3x. |

**Crumb particles** (`SKEmitterNode`):
- Color: Tide to white gradient
- Size: 1-2pt
- Velocity: random angle upward (45-135 degrees), 20-40pt/sec
- Lifetime: 0.3s with fade
- Birthrate: 3-5 per character eaten, 10-15 in goblin mode
- Recycle a single emitter node -- don't create new ones

**Depends on**: P5-T3-03 (notice phase positions creature near text), Phase 2 creature mouth/body animation

---

### P5-T3-05: Phase 4 -- The Reaction (2-3s)

**What**: Post-eating reaction animation and XP display.

**Common sequence** (always plays):
1. Final swallow gulp: body dips 1pt, returns (0.2s)
2. XP number materializes: `+{xp}` in Gilt color, 7pt font, floats up from creature head position
3. XP text rises 12pt over 1.5s while fading from 1.0 to 0.0 opacity
4. Post-eat grooming (personality-dependent):
   - High discipline: licks paw, wipes face (0.8s)
   - High energy: satisfied stretch, bounce (0.6s)
   - Low energy: contented sigh, settles into loaf (1.0s)
   - Default: lip lick, slight head shake (0.4s)

**Speech reaction** (stage-gated, from P5-T1-16 autonomous speech):
- Drop: appropriate symbol (!, heart, etc.)
- Critter: 1-word reaction ("yum!", "more!", "ugh...")
- Beast+: full reaction phrase (see P5-T3-06 for type-specific)

**Depends on**: P5-T3-04 (feast completion triggers this), P5-T3-07 (XP value), P5-T1-16 (speech)

---

### P5-T3-06: Special Commit Type Variations

**What**: 15 unique eating animation variations based on commit type.

**Type detection** (from commit JSON fields):

| Type | Detection | Animation Variation | Speech (Beast+) |
|------|-----------|-------------------|-----------------|
| **Large refactor** | lines_added + lines_removed > 200 | Goblin mode eating (P5-T3-04 huge). Food coma after: lies on side 3s, belly exposed. | `"NOM NOM NOM!!"` |
| **Test files** | languages contains "test" or files match `*test*`, `*spec*` | Crunchy chewing: jaw animation faster, sharper movements. Flexes (chest out) after. | `"STRONG"` |
| **Documentation** | languages contains "md", "txt", "rst" | Slow, careful eating: 250ms/char regardless. Eyes move as if reading. | `"ah..."` |
| **CSS/styling** | languages contains "css", "scss", "less" | Sparkle confetti per character (gold particles instead of tide crumbs). Preens after. | `"pretty!"` |
| **PHP files** | languages contains "php" | Warm glow on each bite (Ember tint pulse on creature). | `"classic!"` |
| **Lazy message** | message matches /^(fix|wip|stuff|update|changes|misc|asdf|test)$/i | Face expressions between bites: alternating between neutral and slight grimace. Reluctant. | `"...fine."` |
| **Revert** | is_revert == true | Characters come back OUT of mouth in reverse order, re-materializing behind creature. Creature looks confused. | `"...deja vu"` |
| **Force push** | is_force_push == true | Text SLAMS in at 3x drift speed. Knocks creature tumbling (360-degree roll). Fur puffs (aura flares). | `"WHOOSH!"` |
| **Merge** | is_merge == true | Text arrives from BOTH edges simultaneously. Creature eats alternating left-right, head swiveling. Double crumb rate. | `"from both sides!"` |
| **Empty commit** | lines_added + lines_removed == 0 | Predator crouch and pounce at... nothing. Sniffs air. Opens mouth. Closes. Confused look. | `"...air?"` |
| **First of day** | No commits in last 8+ hours | Extra-enthusiastic pounce: bigger jump arc, tail poofs (scale 1.3x), wider eyes. | `"MORNING!"` |
| **Late night** | Hour 0-5 local time | Sleepy eating: eyes half-closed, slower speed (1.5x ms/char), occasional yawn between bites. | `"...our secret"` |
| **Huge refactor** | lines_added + lines_removed > 500 | Full goblin mode + post-feast: creature cannot move for 5s, surrounded by particle cloud, eyes glazed. Achievement popup on first occurrence. | `"I can't move..."` |
| **Build/CI config** | files match `*.yml`, `*.yaml`, `Dockerfile`, `.github/*` | Methodical: each character examined (eye focus animation 0.1s per char before eating). | `"important."` |
| **New repo first commit** | First commit from this repo_name | Surprised expression, tail poofs, extra examination of each character. New landmark starts forming in background. | `"NEW FLAVOR!"` |

**Priority**: If multiple types match, use this priority order: force_push > revert > merge > new_repo > huge_refactor > large_refactor > empty > first_of_day > late_night > test > docs > css > php > lazy > build_config > (default)

**Depends on**: P5-T3-04 (feast base animation), P5-T3-05 (reaction base), Phase 4 feed processing (commit type detection)

---

### P5-T3-07: XP Calculation Engine

**What**: Implement the XP formula from the vision document.

**Formula**:
```
xp = (base + lines + message + breadth) * streak_multiplier * fallow_multiplier * rate_limit_factor
```

**Component breakdown**:
| Component | Calculation | Range |
|-----------|------------|-------|
| `base` | Always 1 | 1 |
| `lines` | `min(5, (lines_added + lines_removed) / 20)` | 0-5 |
| `message` | 2 if message length > 20 AND not lazy (see below), else 0 | 0 or 2 |
| `breadth` | 1 if files_changed >= 3, else 0 | 0 or 1 |
| `streak_multiplier` | `1.0 + min(1.0, streak_days / 10.0)` | 1.0-2.0x |
| `fallow_multiplier` | See P5-T3-08 | 1.0-2.0x |
| `rate_limit_factor` | See P5-T3-09 | 0.1-1.0x |

**Lazy message detection**: Message matches any of:
- Single word (no spaces)
- Length < 5 characters
- Exact matches: "fix", "wip", "stuff", "update", "changes", "misc", "asdf", "test", ".", "tmp", "save"
- Messages that are only the default merge commit text

**XP range**: Minimum 1 (base is never reduced below 1, even with rate limiting). Maximum theoretical: (1+5+2+1) * 2.0 * 2.0 * 1.0 = 36 per commit.

**Storage**: XP value stored per commit in `commits` table. Running total in `creature` table.

**Depends on**: Phase 4 feed processing (commit data), Phase 1 state system

---

### P5-T3-08: Fallow Field Bonus

**What**: Longer idle times between commits increase XP of the next commit.

**Multiplier table**:
| Idle Time Since Last Commit | Multiplier |
|----------------------------|-----------|
| <30 minutes | 1.0x |
| 30min - 2hr | 1.25x |
| 2hr - 8hr | 1.5x |
| 8hr - 24hr | 1.75x |
| 24hr+ | 2.0x (cap) |

**Creature anticipation animation** (visual indicator of fallow state):
| Idle Time | Creature Behavior |
|-----------|------------------|
| 30min | Ears occasionally perk at imagined sounds |
| 1hr | Tail starts twitching more frequently |
| 2hr | Stands up, paces in small area |
| 4hr+ | Sits at edge of bar, staring expectantly. Tail swishing. |

**The return commit**: When a commit arrives after 2hr+ idle:
- Extra-enthusiastic predator crouch (body drops lower, wiggle lasts longer)
- Biggest pounce arc (jump height 1.5x normal)
- Additional particle burst on contact
- Fallow multiplier shown in XP float: `+12 (x1.5)`

**Depends on**: P5-T3-07 (XP formula), timestamp tracking in SQLite

---

### P5-T3-08b: Language Preference Drift

**What**: The creature develops and shifts favorite/disliked languages over time, as specified in the vision's Personality System ("Preferences shift every ~200 commits, keeping it unpredictable").

**Mechanics**:
- **Favorite language**: Recalculated every 200 commits (rolling window). The language with the highest weighted XP in the last 200 commits becomes the favorite. Weight = per-commit XP * language proportion.
- **Disliked language**: Randomly selected from language categories with < 5% of recent commits (the categories the creature has eaten least). Re-rolled every 200 commits.
- **Shift check**: After every commit, increment a counter. At every 200th commit since last shift:
  1. Calculate new favorite from last 200 commits' `languages` field
  2. If favorite changed: journal entry `"Zepus developed a taste for [lang]"`, satisfaction +5
  3. Re-roll disliked from underrepresented categories
  4. If disliked changed: journal entry `"Zepus seems tired of [lang]"`
  5. Update `creature.favorite_language` and `creature.disliked_language` in SQLite

**Creature reactions** (integrated with P5-T3-06 commit type variations):
- Commit in favorite language: extra purr particles, `"YES! .[lang]!"` at Beast+, satisfaction +5 bonus
- Commit in disliked language: ears flatten briefly, reluctant eating, `"ugh .[lang]"` at Beast+

**Storage**: `favorite_language` and `disliked_language` columns already exist in creature table. Add `language_shift_counter` (INTEGER DEFAULT 0) to track commits since last shift.

**Depends on**: P5-T3-07 (XP formula), Phase 1 commits table (rolling window query)

---

### P5-T3-09: Rate Limiting

**What**: Prevent XP flooding during rebase storms or rapid commits.

**Rate tiers**:
| Commits in Last Minute | XP Factor | Display |
|----------------------|-----------|---------|
| 1-5 | 1.0x (full) | Normal eating animation |
| 6-20 | 0.5x (half) | Slightly rushed eating, smaller reaction |
| 21+ | 0.1x (tenth) | Speed-eat: all characters at once, minimal animation, tiny XP float |

**Tracking**: Rolling 60-second window. Use a circular buffer of timestamps.

**Visual feedback at high rates**: When in the 21+ tier:
- Creature has "overwhelmed" expression: eyes wide, ears flat
- Text appears and is absorbed in bulk (no character-by-character)
- Single tiny XP float for each batch of 5 commits: `+X (batch)`
- After the storm ends (10s of no commits), creature shakes head, looks dazed: `"...that was a lot"`

**All commits still recorded**: Rate limiting only affects XP. Every commit is logged in the journal with full data regardless.

**Depends on**: P5-T3-07 (XP formula), Phase 4 feed processing

---

### P5-T3-10: Sleeping Creature Commit Processing

**What**: How commits are handled when the creature is asleep.

**Visual sequence** (instead of the full 4-phase eating):
1. Text drifts in as normal but stops 40pt from sleeping creature
2. Text fades to 50% opacity (quieter, dream-like)
3. Creature stirs: slight body shift, one ear twitches
4. Dream bubble appears with first word of commit message: `"...refactor..."`
5. Text characters float toward creature in a gentle stream (not eaten character-by-character)
6. Characters are absorbed with soft Dusk-colored particles (not Tide crumbs)
7. Small XP float at 60% opacity
8. Creature resettles. Does not wake.

**Rules**:
- The creature does NOT fully wake for commits
- All XP is still calculated and awarded at full value
- Dream bubble uses the dream rendering mode (P5-T1-09)
- If 5+ commits arrive while sleeping: creature mumbles progressively louder, may shift position, but still doesn't wake. Dreaming gets more active (more twitching, dream bubbles more frequent)
- Waking only happens from touch (P6-T1-09) or natural circadian cycle

**Depends on**: P5-T3-01 (text materialization), P5-T1-09 (dream bubbles), Phase 2 sleep state

---

## QA Gate

### Track 1 (Text Speech) Verification

- [ ] Speech bubbles render correctly at all 6 stages with correct sizes, colors, positions
- [ ] Drop symbols float and fade without bubble frame
- [ ] Critter bubbles are compact, Beast bubbles are side-positioned
- [ ] Sage multi-bubble sequences chain correctly with stagger timing
- [ ] Narration mode renders at top of bar, scrolls, and is tap-dismissable
- [ ] Filtering reduces Claude's full messages to stage-appropriate output at each stage
- [ ] Filtering preserves emotional intent (positive message -> positive output at all stages)
- [ ] Personality axes measurably affect speech output
- [ ] Failed speech is logged with full intended vs actual comparison
- [ ] Failed speech entries are recallable via `pushling_recall("failed_speech")`
- [ ] At Sage+ stage, creature can narrate past failed_speech attempts
- [ ] First Word ceremony triggers correctly: right conditions, one-time only, correct animation sequence
- [ ] First Word is the creature's own name as a question
- [ ] Apex world-shaping speech triggers environmental changes with correct probability and cooldown
- [ ] Between-session autonomous speech fires at correct rates
- [ ] All 7 speech styles render correctly with appropriate visuals

### Track 2 (TTS Voice) Verification

- [ ] sherpa-onnx runtime links and initializes without errors
- [ ] espeak-ng babble plays for Drop-stage symbols (pitched up, phoneme-mapped)
- [ ] Piper TTS plays for Critter-stage with babble-to-speech ratio matching commit count
- [ ] Kokoro-82M plays clear speech for Beast+ stages
- [ ] Audio pipeline applies pitch shift, warmth EQ, and optional reverb correctly
- [ ] Personality axes produce audibly different voice characters
- [ ] Voice parameters lock at stage transitions and remain consistent within a stage
- [ ] Three-tier switching works during evolution ceremonies
- [ ] First audible word at Beast is the developer's name, whispered at 0.7x volume
- [ ] Audio cache reduces latency for common phrases to <10ms
- [ ] Dream audio plays at 0.4x volume with pitch-down and reverb
- [ ] TTS generation NEVER blocks the main thread (verify with Instruments)
- [ ] No audio pops, clicks, or glitches during any TTS playback

### Track 3 (Commit Eating) Verification

- [ ] Commit text materializes with correct stagger animation
- [ ] Text drifts toward creature at correct speed
- [ ] Predator crouch and butt wiggle play during notice phase
- [ ] Character-by-character eating works with correct timing per commit size
- [ ] Crumb particles emit correctly and are recycled
- [ ] XP float displays correct value and animates up-and-fade
- [ ] All 15 commit type variations play correctly (test each)
- [ ] Revert plays backward (characters come back out)
- [ ] Force push slams text and knocks creature over
- [ ] Merge arrives from both sides
- [ ] Empty commit produces the "nothing there" animation
- [ ] XP calculation matches the formula: base + lines + message + breadth * multipliers
- [ ] Fallow bonus applies correct multiplier based on idle time
- [ ] Rate limiting reduces XP and simplifies animation at 6+ and 21+ commits/minute
- [ ] Sleeping creature processes commits without waking (stirs, dream bubble, absorbs)
- [ ] Frame budget maintained during commit eating + speech animations simultaneously (total <8ms)

### Integration Verification

- [ ] `pushling_speak` MCP tool round-trips correctly: Claude -> MCP -> IPC -> daemon -> render
- [ ] Failed speech appears in `pushling_recall("failed_speech")` output
- [ ] Speech cache persists across daemon restarts
- [ ] Commit eating triggers speech reactions (autonomous) at correct stages
- [ ] TTS audio and speech bubbles are synchronized (audio plays when bubble appears)
- [ ] Multiple systems active simultaneously (eating + speech + weather) stay within frame budget
