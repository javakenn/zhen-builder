#!/usr/bin/env python3
"""Local Whisper transcription via faster-whisper.

Usage:
  python3 transcribe.py --file /path/to/audio.m4a
  python3 transcribe.py --file audio.m4a --model medium
  python3 transcribe.py --file audio.m4a --output ~/workflow/result.json

Output: JSON with segments + timestamps → stdout or --output file
"""
import argparse, json, sys, time

def transcribe(filepath, model_size="medium"):
    from faster_whisper import WhisperModel

    print(f"[transcribe] loading model {model_size}...", file=sys.stderr)
    model = WhisperModel(model_size, device="cpu", compute_type="int8")

    print(f"[transcribe] transcribing {filepath}...", file=sys.stderr)
    start = time.time()
    segments, info = model.transcribe(filepath, language="en", beam_size=5)

    result_segments = []
    for seg in segments:
        result_segments.append({
            "start": round(seg.start, 2),
            "end": round(seg.end, 2),
            "text": seg.text.strip(),
        })

    elapsed = time.time() - start
    print(f"[transcribe] done in {elapsed:.1f}s, {len(result_segments)} segments, language={info.language} prob={info.language_probability:.2f}", file=sys.stderr)

    return {
        "text": " ".join(s["text"] for s in result_segments),
        "segments": result_segments,
        "language": info.language,
        "duration": round(info.duration, 2),
    }


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--file", required=True, help="Local audio file path")
    p.add_argument("--model", default="medium", help="Whisper model size (default: medium)")
    p.add_argument("--output", "-o", help="Output file path (default: stdout)")
    args = p.parse_args()

    result = transcribe(args.file, args.model)

    output = json.dumps(result, ensure_ascii=False, indent=2)
    if args.output:
        with open(args.output, "w") as f:
            f.write(output)
        print(f"[transcribe] saved to {args.output}", file=sys.stderr)
    else:
        print(output)


if __name__ == "__main__":
    main()
