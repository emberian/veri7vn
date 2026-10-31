"""Untrusted literal supplied-interval translation specialist using the local host."""
import importlib.util
import sys
import json
from pathlib import Path
PATH=Path(__file__).resolve().parents[2]/'sequence_translation.py'
sys.path.insert(0,str(PATH.parent))
SPEC=importlib.util.spec_from_file_location('supplied_translation_consumer',PATH)
CLIENT=importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(CLIENT)
PREFIX='Translate supplied coding intervals: '

class Organ:
    def __init__(self,url='http://127.0.0.1:8765',tenant='translation-specialist'):
        self.client=CLIENT.Client(url,tenant)
    def answer(self,text,session):
        if not isinstance(text,str) or not text.startswith(PREFIX):
            return None
        if len(text.encode())>262144:
            return {'status':'withheld','kind':'sequence_translation_input','reason':'invalid_input','response':'Supplied translation exceeds byte cap.'}
        try:
            arguments=json.loads(text[len(PREFIX):])
            CLIENT.validate_arguments(arguments)
            CLIENT.reference(arguments)
        except (ValueError,KeyError,TypeError) as error:
            return {'status':'withheld','kind':'sequence_translation_input','reason':'invalid_input','response':str(error)}
        try:
            result=CLIENT.translate(self.client.invoke,arguments)
        except (ValueError,KeyError,TypeError,OSError) as error:
            return {'status':'withheld','kind':'sequence_translation_input','reason':'execution_failure','response':str(error)}
        return {'status':'answered','kind':'sequence_translation','result':result['result'],
                'response':'Literal standard-code translation of the supplied intervals: '+', '.join(t['protein'] for t in result['result']['translations'])+'. Original source codon coordinates retained.'}
