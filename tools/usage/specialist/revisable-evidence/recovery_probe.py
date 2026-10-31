#!/usr/bin/env python3
"""Actual-host two-stage probe. Central runner restarts its own host between stages.

The loss stage discards a received mutation acknowledgement before the consumer
can retire its pending record. It never stops/restarts a process itself.
"""
import argparse
import json
from pathlib import Path
import sys
sys.path.insert(0,str(Path(__file__).resolve().parents[2]))
from hosted_reasoning import Client
from revisable_evidence import resumable, strict_json


class DiscardFirstMutationAck(Client):
    def transport(self,path,body=None):
        result=super().transport(path,body)
        if body is not None and body.get('operation_id')=='logic.workspace':
            raise ConnectionError('injected lost mutation acknowledgement after server completed')
        return result


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--url',required=True)
    parser.add_argument('--tenant',required=True)
    parser.add_argument('--cursor',type=Path,required=True)
    parser.add_argument('--stage',choices=['lose','resume'],required=True)
    parser.add_argument('--scenario',type=Path,default=Path(__file__).with_name('incident-history.json'))
    args=parser.parse_args()
    scenario=strict_json(args.scenario.read_text())
    if args.stage=='lose':
        if args.cursor.exists():raise ValueError('loss probe requires a fresh explicit cursor path')
        try:resumable(DiscardFirstMutationAck(args.url,args.tenant),scenario,args.cursor,1)
        except ConnectionError:
            record=strict_json(args.cursor.read_text())
            if record['pending'] is None:raise ValueError('pending exact request was not retained')
            print(json.dumps({'stage':'lost_ack','pending_request':record['pending']['request']['request_id'],
                              'next':'central runner restarts the admitted host, then invokes --stage resume'}))
            return
        raise ValueError('loss injection was not reached')
    rows=resumable(Client(args.url,args.tenant),scenario,args.cursor)
    print(json.dumps({'stage':'resumed','rows':rows},indent=2))


if __name__=='__main__':main()
