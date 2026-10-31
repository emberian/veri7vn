"""Focused independent cone replay contracts, authored without execution."""
import copy
import math
from pathlib import Path
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
from events_exposure import replay_finiteness, replay_separation, request_preserved, ContractError


class IndependentReplay(unittest.TestCase):
    def test_native_defaults_do_not_break_provided_request_binding(self):
        request={'solver':{'max_iterations':1},'predictions':[{'features':[0],'trials':20}]}
        normalized={'solver':{'max_iterations':1,'max_backtracks':24},
                    'predictions':[{'features':[0.0],'trials':20,'exposure':None}]}
        self.assertTrue(request_preserved(request,normalized))
        normalized['predictions'][0]['features']=[1.0]
        self.assertFalse(request_preserved(request,normalized))

    def binomial(self):
        return {'family':'grouped_binomial_logit','method':'maximum_likelihood','features':[[-.1],[-.1],[.1],[.1]],
                'intercept':True,'successes':[1,0,1,0],'trials':[1,1,1,1]}

    def test_noninteger_dyadic_balance_and_one_ulp_rejection(self):
        supplied=self.binomial()
        certificate={'family':supplied['family'],'weights':['1']*4,'basis_rows':[0,2]}
        self.assertTrue(replay_finiteness(supplied,certificate)['accepted'])
        supplied['features'][0][0]=math.nextafter(-.1,-math.inf)
        with self.assertRaises(ContractError):
            replay_finiteness(supplied,certificate)

    def test_count_trial_and_exposure_support_are_mathematical_premises(self):
        poisson={'family':'poisson_log','method':'maximum_likelihood','features':[[]],'intercept':True,'counts':[1],'exposures':[1]}
        certificate={'family':'poisson_log','weights':['0'],'basis_rows':[0]}
        self.assertTrue(replay_finiteness(poisson,certificate)['accepted'])
        for changes in ({'counts':[-1]},{'counts':[True]},{'counts':[1.5]},{'exposures':[0]},
                        {'exposures':[-1]},{'exposures':[float('inf')]},{'exposures':[1e300]}):
            with self.subTest(changes=changes), self.assertRaises(ContractError):
                replay_finiteness({**poisson,**changes},certificate)
        binomial=self.binomial()
        certificate={'family':binomial['family'],'weights':['1']*4,'basis_rows':[0,2]}
        for changes in ({'successes':[-1,0,1,0]},{'trials':[0,1,1,1]},{'successes':[2,0,1,0]},
                        {'trials':[1.5,1,1,1]},{'counts':[1,1,1,1]}):
            with self.subTest(changes=changes), self.assertRaises(ContractError):
                replay_finiteness({**binomial,**changes},certificate)

    def test_quasi_separation_and_poisson_recession_are_checked_not_guessed(self):
        binomial={'family':'grouped_binomial_logit','method':'maximum_likelihood','features':[[-1],[0],[1]],
                  'intercept':True,'successes':[0,1,2],'trials':[2,2,2]}
        certificate={'family':binomial['family'],'direction':['0','1']}
        self.assertTrue(replay_separation(binomial,certificate)['accepted'])
        with self.assertRaises(ContractError):
            replay_separation(binomial,{**certificate,'direction':['1','1']})
        poisson={'family':'poisson_log','method':'maximum_likelihood','features':[[0],[1]],'intercept':True,
                 'counts':[1,0],'exposures':[1,1]}
        certificate={'family':poisson['family'],'direction':['0','-1']}
        self.assertTrue(replay_separation(poisson,certificate)['accepted'])
        with self.assertRaises(ContractError):
            replay_separation(poisson,{**certificate,'direction':['1','-1']})

    def test_positive_poisson_balance_without_positive_row_full_rank(self):
        supplied={'family':'poisson_log','method':'maximum_likelihood','features':[[-1],[0],[1]],'intercept':True,
                  'counts':[0,1,0],'exposures':[1,1,1]}
        certificate={'family':supplied['family'],'weights':['1','-2','1'],'basis_rows':[0,1]}
        self.assertTrue(replay_finiteness(supplied,certificate)['accepted'])
        with self.assertRaises(ContractError):
            replay_finiteness(supplied,{**certificate,'weights':['0','0','0']})
        with self.assertRaises(ContractError):
            replay_separation(supplied,{'family':supplied['family'],'direction':['0','1']})


if __name__=='__main__':
    unittest.main()
