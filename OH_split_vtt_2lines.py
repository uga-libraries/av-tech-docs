"""This script takes the exported vtt from Aviary transcript editor and splits the speaker chunking into no more than two lines on the screen for captions. 

This script runs on a single file input and outputs where the user directs. To run this script in terminal: python3 OH_split_vtt_2lines.py [inputfile.webvtt] [outputfile_split.webvtt] 
Note: The user will need to edit the output file name manually before running script/command in terminal for output file name to have _split appended.

"""

#!/usr/bin/env python3
import sys
import os
import re
from datetime import timedelta

# -----------------------------
# Timestamp Helpers
# -----------------------------

def parse_timestamp(ts):
    ts = ts.replace(',', '.')
    h, m, s = ts.split(':')
    s, ms = s.split('.')
    return timedelta(hours=int(h), minutes=int(m), seconds=int(s), milliseconds=int(ms))

def format_timestamp(td):
    total_seconds = int(td.total_seconds())
    ms = int(td.microseconds / 1000)
    h = total_seconds // 3600
    m = (total_seconds % 3600) // 60
    s = total_seconds % 60
    return f"{h:02}:{m:02}:{s:02}.{ms:03}"

# -----------------------------
# Speaker Extraction
# -----------------------------

def extract_speaker(text):
    """
    Extracts <v NAME> and returns (NAME, text_without_tag)
    """
    match = re.match(r"<v\s+([^>]+)>\s*(.*)", text, re.DOTALL)
    if match:
        speaker = match.group(1).strip()
        rest = match.group(2).strip()
        return speaker, rest
    return None, text.strip()

# -----------------------------
# Chunking Logic (70 chars, 2 lines max)
# -----------------------------

def chunk_text(text, limit=70, max_lines=2):
    """
    Break text into ~70 character chunks without breaking words.
    Ensures no chunk exceeds two lines (~35 chars per line).
    """
    words = text.split()
    chunks = []
    current = ""

    # First pass: basic 70-char chunks
    for word in words:
        if len(current) + len(word) + 1 <= limit:
            current = (current + " " + word).strip()
        else:
            chunks.append(current)
            current = word

    if current:
        chunks.append(current)

    # Second pass: enforce two-line max
    final_chunks = []
    per_line_limit = limit // max_lines  # ~35 chars

    for chunk in chunks:
        if len(chunk) <= limit:
            final_chunks.append(chunk)
        else:
            # Split again into two-line-safe chunks
            words = chunk.split()
            sub = ""
            for w in words:
                if len(sub) + len(w) + 1 <= limit:
                    sub = (sub + " " + w).strip()
                else:
                    final_chunks.append(sub)
                    sub = w
            if sub:
                final_chunks.append(sub)

    return final_chunks

# -----------------------------
# Cue Splitting
# -----------------------------

def split_cue(start, end, text):
    speaker, clean_text = extract_speaker(text)
    parts = chunk_text(clean_text, limit=70, max_lines=2)

    if not parts:
        return []

    total = end - start
    slice_duration = total / len(parts)

    cues = []
    current_start = start

    for i, part in enumerate(parts):
        current_end = current_start + slice_duration

        # Speaker name only on first chunk
        if i == 0 and speaker:
            part = f"{speaker}:\n{part}"

        cues.append((current_start, current_end, part))
        current_start = current_end

    return cues

# -----------------------------
# Main VTT Processing
# -----------------------------

def process_vtt(input_path, output_path):
    if not os.path.exists(input_path):
        print(f"ERROR: Input file not found: {input_path}")
        return

    print(f"Reading: {input_path}")

    with open(input_path, 'r', encoding='utf-8') as f:
        lines = f.read().splitlines()

    cues = []
    i = 0

    while i < len(lines):
        line = lines[i].strip()

        if "-->" in line:
            start_str, end_str = [x.strip() for x in line.split("-->")]
            start = parse_timestamp(start_str)
            end = parse_timestamp(end_str)

            text_lines = []
            i += 1

            while i < len(lines) and lines[i].strip() != "":
                text_lines.append(lines[i])
                i += 1

            text = "\n".join(text_lines)
            cues.append((start, end, text))

        i += 1

    print(f"Found {len(cues)} cues. Splitting...")

    output_lines = ["WEBVTT", ""]

    for start, end, text in cues:
        split_cues = split_cue(start, end, text)
        for s, e, t in split_cues:
            output_lines.append(f"{format_timestamp(s)} --> {format_timestamp(e)}")
            output_lines.append(t)
            output_lines.append("")

    with open(output_path, 'w', encoding='utf-8') as f:
        f.write("\n".join(output_lines))

    print(f"Done! Output written to: {output_path}")

# -----------------------------
# Entry Point
# -----------------------------

def main():
    if len(sys.argv) != 3:
        print("Usage: python3 split_vtt.py input.webvtt output.webvtt")
        return

    input_path = sys.argv[1]
    output_path = sys.argv[2]

    process_vtt(input_path, output_path)

if __name__ == "__main__":
    main()