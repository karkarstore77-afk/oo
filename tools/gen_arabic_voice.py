#!/usr/bin/env python3
"""Generate the Egyptian-Arabic story voice files for Roof Groove.

Reads every Arabic line in RoofGroove/scripts/story_data.gd and writes
RoofGroove/audio/voice/ar/<md5-key>_<m|f>.mp3 (same key rule as story_voice.gd).

Backends (pick one, any Egyptian voice works - it does not have to be Microsoft):
  python tools/gen_arabic_voice.py --backend edge          # free, pip install edge-tts
  ELEVEN_API_KEY=... ELEVEN_VOICE_M=<id> ELEVEN_VOICE_F=<id> \
      python tools/gen_arabic_voice.py --backend elevenlabs # pick Egyptian voices from their Voice Library
Re-running skips files that already exist (use --force to redo).
"""
import argparse, asyncio, hashlib, json, os, re, sys, urllib.request

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "RoofGroove")
SRC = os.path.join(ROOT, "scripts", "story_data.gd")
OUT = os.path.join(ROOT, "audio", "voice", "ar")
MIN_LEN = 13  # skips names / short labels that are never spoken


def arabic_lines():
    src = open(SRC, encoding="utf-8").read()
    seen, out = set(), []
    for lit in re.findall(r'"((?:[^"\\]|\\.)*)"', src):
        t = lit.replace("\\n", "\n").replace('\\"', '"')
        if re.search(r"[\u0600-\u06FF]", t) and len(t) >= MIN_LEN and t not in seen:
            seen.add(t)
            out.append(t)
    return out


def key(text, gender):
    return hashlib.md5(text.encode("utf-8")).hexdigest()[:12] + "_" + gender


async def edge(text, gender, path):
    import edge_tts
    voice = "ar-EG-ShakirNeural" if gender == "m" else "ar-EG-SalmaNeural"
    await edge_tts.Communicate(text, voice).save(path)


def eleven(text, gender, path):
    vid = os.environ["ELEVEN_VOICE_M" if gender == "m" else "ELEVEN_VOICE_F"]
    req = urllib.request.Request(
        f"https://api.elevenlabs.io/v1/text-to-speech/{vid}",
        data=json.dumps({"text": text, "model_id": "eleven_multilingual_v2"}).encode(),
        headers={"xi-api-key": os.environ["ELEVEN_API_KEY"], "Content-Type": "application/json",
                 "Accept": "audio/mpeg"})
    with urllib.request.urlopen(req) as r, open(path, "wb") as f:
        f.write(r.read())


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--backend", choices=["edge", "elevenlabs"], default="edge")
    ap.add_argument("--force", action="store_true")
    a = ap.parse_args()
    os.makedirs(OUT, exist_ok=True)
    lines = arabic_lines()
    print(f"{len(lines)} lines x 2 voices")
    failed = 0
    made = 0
    for i, t in enumerate(lines, 1):
        for g in ("m", "f"):
            path = os.path.join(OUT, key(t, g) + ".mp3")
            # an earlier crashed run can leave an empty/partial file: treat tiny files as missing
            if os.path.exists(path) and os.path.getsize(path) > 1000 and not a.force:
                continue
            print(f"[{i}/{len(lines)}] {g} {t[:40]}")
            tmp = path + ".part"
            ok = False
            for attempt in range(3):
                try:
                    if a.backend == "edge":
                        asyncio.run(edge(t, g, tmp))
                    else:
                        eleven(t, g, tmp)
                    if os.path.exists(tmp) and os.path.getsize(tmp) > 1000:
                        os.replace(tmp, path)
                        ok = True
                        break
                except Exception as e:  # network hiccup: retry, then skip this line
                    print("   retry", attempt + 1, e)
            if os.path.exists(tmp):
                os.remove(tmp)
            if ok:
                made += 1
            else:
                failed += 1
    print(f"done - {made} generated, {failed} failed. Open the project in Godot once so it imports the new mp3 files")
    return 1 if failed and not made else 0


if __name__ == "__main__":
    sys.exit(main())
