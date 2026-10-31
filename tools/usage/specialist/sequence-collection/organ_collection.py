"""Untrusted specialist using supplied DNA and the fixed local native host only."""
import importlib.util
import json
from pathlib import Path

PATH = Path(__file__).resolve().parents[2] / 'sequence_collection.py'
SPEC = importlib.util.spec_from_file_location('supplied_sequence_consumer', PATH)
CLIENT = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(CLIENT)
PREFIX = 'Find exact fragments: '


class Organ:
    def __init__(self, url='http://127.0.0.1:8765', tenant='sequence-collection-specialist'):
        self.client = CLIENT.Client(url, tenant)

    def answer(self, text, session):
        if not isinstance(text, str) or not text.startswith(PREFIX):
            return None
        if len(text.encode()) > 262144:
            return {'kind':'sequence_collection_input','status':'withheld','response':'Supplied collection exceeds byte cap.'}
        try:
            arguments = json.loads(text[len(PREFIX):])
            result = CLIENT.search_all(self.client.invoke, arguments)
        except (ValueError, KeyError, TypeError, OSError) as error:
            return {'kind':'sequence_collection_input','status':'withheld','response':str(error)}
        return {'kind':'sequence_collection_hits','status':'answered',
                'response':f"Exact supplied fragment matches: {len(result['hits'])}. All supplied records searched in both strands; original zero-based half-open coordinates.",
                'result':result}
