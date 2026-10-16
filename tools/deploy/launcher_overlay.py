#!/usr/bin/env python3
"""Attach exact standalone bootstrap bytes without replacing native/UI producers."""
import argparse
from pathlib import Path
from launcher_assets import attach_launcher
from stage import spec_from_generation, stage


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('generation',type=Path)
    parser.add_argument('archive',type=Path)
    parser.add_argument('installation',type=Path)
    parser.add_argument('--candidate-only',action='store_true')
    args=parser.parse_args()
    spec=spec_from_generation(args.generation)
    attach_launcher(spec,args.archive)
    print(stage(spec,args.installation,select=not args.candidate_only))

if __name__=='__main__':main()
