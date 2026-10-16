"""Original lifecycle bodies with local dependencies; no server or MQTT socket."""
import json
import re
import tempfile
import time
from pathlib import Path
from types import SimpleNamespace
import unittest
from test_background_learning import selected


class WorkbenchLifecycleCases(unittest.TestCase):
    def test_same_cached_mqtt_event_gets_new_poll_timestamp(self):
        with tempfile.TemporaryDirectory() as temp:
            clock = SimpleNamespace(time=lambda: 100, strftime=time.strftime,
                                    localtime=time.localtime)
            cached = SimpleNamespace(last=(50, '{"temperature":20}'), error='')
            env = selected('upstream/workbench/sensors.py', {'read_source', 'poll_once'},
                {'re': re, 'json': json, 'time': clock, 'DIR': Path(temp),
                 '_MQTT': {'fixture/topic': cached}, 'parse_line': lambda text: {},
                 'flatten': lambda obj: obj, 'check': lambda field, value: (True, ''),
                 'QUANTITIES': {}, 'KEEP_S': 86400})
            cfg = {'id': 'fixture', 'kind': 'mqtt', 'address': 'fixture/topic',
                   'fields': [{'path': 'temperature', 'quantity': 'temperature', 'unit': 'C'}]}
            first = env['poll_once'](cfg)[0]
            clock.time = lambda: 200
            second = env['poll_once'](cfg)[0]
            self.assertEqual(cached.last, (50, '{"temperature":20}'))
            self.assertEqual(first['src'], second['src'])
            self.assertEqual([first['t'], second['t']], [100, 200])
            self.assertEqual([first['v'], second['v']], [20, 20])
            # Intended repair: event_clock stays 50; receipt_clock advances.
            # The old stored numeric t is poll time, so it cannot enforce event freshness.

    def test_mqtt_configuration_change_reuses_old_cached_connection(self):
        # Exercise the real MQTT branch without creating a client or socket.
        cached = SimpleNamespace(last=(50, '{"temperature":20}'), error='')
        env = selected('upstream/workbench/sensors.py', {'read_source'},
            {'re': re, 'json': json, 'time': time,
             '_MQTT': {'fixture/topic': cached}, 'parse_line': lambda text: {},
             'flatten': lambda obj: obj})
        old = {'kind': 'mqtt', 'address': 'fixture/topic', 'user': 'old-user', 'password': 'old'}
        new = dict(old, user='new-user', password='new')
        self.assertEqual(env['read_source'](old), env['read_source'](new))
        self.assertIs(env['_MQTT']['fixture/topic'], cached)
        # Intended repair: changed acquisition configuration changes binding epoch
        # and requalifies the connector; cached observations retain old config.

    def test_expired_reader_pronoun_bypasses_live_filter(self):
        env = selected('upstream/workbench/server.py', {'Workbench'},
            {'help_reply': lambda text: None, 'history_reply': lambda text, sid: None,
             'PRONOUN': re.compile(r'\bit\b', re.I)})
        wb = object.__new__(env['Workbench'])
        calls = []
        reader = SimpleNamespace(m={'expires': 1}, reply=lambda text, sid:
            calls.append((text, sid)) or {'status': 'answered', 'response': 'cached'})
        wb.mine = {'expired': reader}
        wb.last = {'fixture': ('expired', 'boiler')}
        wb.remember = lambda text, sid, answer: answer
        answer = wb.chat('where is it?', 'fixture')
        self.assertEqual(calls, [('where is boiler?', 'fixture')])
        self.assertEqual(answer['status'], 'answered')
        self.assertIn('followup', answer['path'])
        # Intended repair: current binding/expiry check before pronoun dispatch.


if __name__ == '__main__':
    unittest.main()
