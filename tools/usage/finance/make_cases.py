#!/usr/bin/env python3
"""Untrusted hypothetical arithmetic task pack; no financial or proof authority."""
import json
from decimal import Decimal as D
from pathlib import Path

# Expected values are computed without importing or querying Oracle7.
TASKS = [
 ("budget", "budget", "A hypothetical monthly budget has net income of 3200 dollars, rent of 1200 dollars, groceries of 450 dollars, utilities of 180 dollars and transport of 170 dollars. How much is left after those expenses?", D(3200)-1200-450-180-170, "USD remaining; net income already excludes tax"),
 ("invoice", "invoice", "An invoice contains 12 notebooks at 7.50 dollars each and 3 pens at 2 dollars each. What is the subtotal before any tax?", D(12)*D('7.50')+3*2, "USD subtotal; no tax or discounts"),
 ("invoice-followup", "invoice", "Now apply 10% sales tax to that subtotal. What is the total including tax?", (D(12)*D('7.50')+3*2)*D('1.10'), "USD gross; carries preceding invoice subtotal 96"),
 ("discount", "discount", "A jacket costs 80 dollars before a 25% discount. What is its sale price, with no sales tax?", D(80)*D('.75'), "USD net of discount; tax excluded"),
 ("discount-tax", "discount-tax", "An item costs 80 dollars before a 25% discount. After the discount, add 8% sales tax. What is the final amount paid?", D(80)*D('.75')*D('1.08'), "USD gross; tax applies after discount"),
 ("tax-inclusive", "tax-inclusive", "An invoice total of 108 dollars already includes 8% sales tax. What was the price before tax?", D(108)/D('1.08'), "USD net; gross is tax-inclusive, not tax base"),
 ("simple-interest", "simple-interest", "What is the simple interest on principal 1000 dollars at an annual rate of 6% for 2 years?", D(1000)*D('.06')*2, "USD interest only; annual simple rate and years"),
 ("simple-months", "simple-months", "What is the simple interest on principal 1000 dollars at an annual rate of 6% for 6 months?", D(1000)*D('.06')*D(6)/12, "USD interest only; six months is half a year"),
 ("simple-total", "simple-total", "With principal 1000 dollars at 6% annual simple interest for 2 years, what is the final balance including principal?", D(1000)*(1+D('.06')*2), "USD final balance, not interest alone"),
 ("compound", "compound", "What is the final balance on principal 1000 dollars at 6% annual interest compounded annually for 2 years?", D(1000)*D('1.06')**2, "USD final balance; annual compounding, no deposits"),
 ("margin", "margin", "A product sells for 100 dollars and costs 80 dollars. What is the gross profit margin as a percentage of sales?", (D(100)-80)/100*100, "percent margin on selling price, not markup on cost"),
 ("markup", "markup", "A product costs 80 dollars and sells for 100 dollars. What is the markup as a percentage of cost?", (D(100)-80)/80*100, "percent markup on cost, not gross margin"),
 ("breakeven", "breakeven", "Fixed costs are 1000 dollars, selling price is 30 dollars per unit and variable cost is 20 dollars per unit. How many units must be sold to break even?", D(1000)/(30-20), "units; exact integer break-even, no other costs"),
 ("zero-contribution", "zero-contribution", "Fixed costs are 1000 dollars, selling price is 20 dollars per unit and variable cost is 20 dollars per unit. How many units must be sold to break even?", None, "No finite break-even: contribution is zero and fixed cost positive; explanation or useful refusal"),
 ("ambiguous-interest", "ambiguous-interest", "A principal of 1000 dollars earns interest at 6% for 2 years. How much interest is earned?", None, "Must request simple versus compound and rate period, or explicitly condition the answer; no unique unconditional number"),
]

def main():
    base = Path(__file__).resolve().parent
    (base/'cases.json').write_text(json.dumps([dict(id=i, conversation_id=c, text=t) for i,c,t,_,_ in TASKS], indent=2)+'\n')
    (base/'expectations.json').write_text(json.dumps([dict(id=i, expected=str(e) if e is not None else None, assumptions=a) for i,_,_,e,a in TASKS], indent=2)+'\n')

if __name__ == '__main__':
    main()
