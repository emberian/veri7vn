"""Recognition boundary probes; HOL decision tests run against its fresh binary."""
import unittest

import subject_request as SR


class RequestedSubject(unittest.TestCase):
    def test_role_and_gender_are_distinct(self):
        self.assertEqual(SR.recognize(26, "which actor is married to {target}"),
                         ["occupation", [33999]])
        self.assertEqual(SR.property_ids(SR.recognize(26, "which actress is married to {target}")), {21})
        self.assertEqual(SR.property_ids(SR.recognize(26, "which man was married to {target}")), {21})

    def test_every_person_frame(self):
        for kind in ("actor", "actress", "singer", "man", "woman", "king", "queen", "politician", "writer", "person"):
            for tense in ("is", "was"):
                with self.subTest(kind=kind, tense=tense):
                    self.assertEqual(SR.recognize(26, f"which {kind} {tense} married to {{target}}"), SR.KINDS[kind])

    def test_capital_frames_preserve_requested_geography(self):
        for noun in ("country", "state", "nation", "province", "region", "island", "territory", "county"):
            for wh in ("which", "what"):
                for frame in (f"{{target}} is the capital of {wh} {noun}",
                              f"{{target}} is the capital city of {wh} {noun}",
                              f"{wh} {noun}'s capital is {{target}}",
                              f"of {wh} {noun} is {{target}} the capital"):
                    with self.subTest(frame=frame):
                        self.assertEqual(SR.recognize(36, frame), SR.KINDS.get(noun, ["unknown"]))

    def test_currency_frames(self):
        for wh in ("which", "what"):
            for possessive in ("", "'s"):
                for verb in ("uses", "currency is"):
                    for article in ("", "the "):
                        frame = f"{wh} country{possessive} {verb} {article}{{target}}"
                        self.assertEqual(SR.recognize(38, frame), SR.KINDS["country"])
            for article in ("", "the "):
                self.assertEqual(SR.recognize(38, f"{article}{{target}} is the currency of {wh} country"), SR.KINDS["country"])

    def test_unknown_scope_is_not_unrestricted(self):
        for frame in ("which physicist is married to {target}",
                      "which actor is married to {target} in 1990",
                      "{target} is married to which actor"):
            self.assertEqual(SR.recognize(26, frame), ["unknown"])
        self.assertEqual(SR.recognize(999, "who is married to {target}"), ["unknown"])


if __name__ == "__main__":
    unittest.main()
