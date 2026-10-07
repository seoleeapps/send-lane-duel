#!/usr/bin/env python3
"""Original music-box score and clockwork SFX, rendered without external assets."""
import array
import hashlib
import json
import math
import random
import subprocess
import wave
from pathlib import Path

RATE = 22050
OUT = Path(__file__).resolve().parents[1] / "assets/audio"


def note(samples, start, duration, midi, volume=0.12, tone="bell", loop=False):
    hz = 440 * 2 ** ((midi - 69) / 12)
    first = round(start * RATE)
    for k in range(round(duration * RATE)):
        t = k / RATE
        attack = min(1, t / 0.004)
        release = min(1, (duration - t) / 0.03)
        envelope = attack * release * math.exp(-t * (7 if tone == "bell" else 3))
        signal = math.sin(2 * math.pi * hz * t)
        if tone == "bell":
            signal += 0.28 * math.sin(2 * math.pi * 2 * hz * t) + 0.08 * math.sin(2 * math.pi * 3 * hz * t)
        index = first + k
        if loop:
            index %= len(samples)
        if index < len(samples):
            samples[index] += volume * signal * envelope


def save(name, samples, loop=False):
    peak = max(abs(x) for x in samples)
    assert peak < 0.95, (name, "clipping", peak)
    pcm = array.array("h", [round(x * 32767) for x in samples])
    path = OUT / f"{name}.wav"
    with wave.open(str(path), "wb") as stream:
        stream.setnchannels(1)
        stream.setsampwidth(2)
        stream.setframerate(RATE)
        stream.writeframes(pcm.tobytes())
    if loop:
        target = OUT / f"{name}.ogg"
        subprocess.run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-i", str(path), "-ac", "2", "-c:a", "vorbis", "-strict", "-2", "-q:a", "4", str(target)], check=True)
        path.unlink()
        path = target
    return {"name": name, "path": str(path.relative_to(OUT)), "seconds": round(len(samples)/RATE, 3),
            "peak": round(peak, 4), "seamDelta": round(abs(samples[0]-samples[-1]), 6) if loop else None,
            "sha256": hashlib.sha256(path.read_bytes()).hexdigest()}


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    tracks = []
    melody = [74, 78, 81, 78, 76, 78, 74, 69, 71, 74, 78, 74, 73, 76, 81, 76,
              74, 78, 83, 81, 78, 76, 74, 71, 69, 73, 76, 78, 76, 73, 69, 73]
    for name, bpm, shift in [("menu", 76, 0), ("march", 86, 0), ("boss", 86, -2)]:
        beat = 60 / bpm
        samples = [0.0] * round(32 * beat * RATE)
        for i, midi in enumerate(melody):
            note(samples, i * beat, beat * 1.3, midi + shift, 0.085, loop=True)
            note(samples, i * beat + beat/2, beat * 0.8, midi - 12 + shift, 0.025, loop=True)
            if i % 2 == 0:
                bass = [50, 47, 55, 45][i // 8] + shift
                note(samples, i * beat, beat * 1.8, bass, 0.055, "wood", True)
        tracks.append(save(name, samples, True))
    for name, notes in {
        "click": [84], "place": [62, 74], "worker": [71, 78, 83], "send": [62, 66, 69],
        "coin": [83, 86], "shot": [76], "magic": [86, 90], "hoof": [48, 55],
        "victory": [74, 78, 81, 86], "defeat": [66, 62, 59], "reveal": [57, 64, 69],
    }.items():
        duration = 0.25 + len(notes)*0.08
        samples = [0.0] * round(duration*RATE)
        for i, midi in enumerate(notes):
            note(samples, i*0.08, 0.22, midi, 0.16 if name not in ["shot", "hoof"] else 0.08)
        tracks.append(save(name, samples))
    for name, duration, base in [("boom", 0.18, 95), ("leak", 0.3, 140)]:
        samples = []
        rng = random.Random(name)
        for i in range(round(duration*RATE)):
            t = i/RATE
            envelope = min(1, t/0.004)*math.exp(-t*18)*min(1, (duration-t)/0.015)
            samples.append(0.12*envelope*(math.sin(2*math.pi*base*t) + 0.3*rng.uniform(-1, 1)))
        tracks.append(save(name, samples))
    manifest = {"source": "Original score and synthesis in tools/build_audio.py", "license": "Project-owned original audio",
                "apiCalls": 0, "tracks": tracks, "listeningReview": "Pending human review of finished build; numerical peak and seam analysis performed"}
    (OUT/"sound-manifest.json").write_text(json.dumps(manifest, indent=2)+'\n')
    print(f"AUDIO {len(tracks)} tracks; clipping=0; max loop seam={max(t['seamDelta'] or 0 for t in tracks):.6f}")


if __name__ == "__main__":
    main()
