#!/bin/sh
# builds var/finance/fresh/{F1,F2}/specialists/<id>/ : symlinked organs + rewritten manifests + fresh panels
set -eu
R=/Users/ember/dev/o7vn; U=$R/upstream/root/specialists; G=$R/var/finance/fresh
gen() { # name src oldseeds newdev newheld out
  sed -e "s/(\"dev\", $3), (\"heldout\", $4)/(\"dev\", $5), (\"heldout\", $6)/" $U/$2 > $G/gen/$1.py
  grep -q "(\"dev\", $5), (\"heldout\", $6)" $G/gen/$1.py || { echo seedsub failed $1; exit 1; }
  PYTHONDONTWRITEBYTECODE=1 python3 $G/gen/$1.py $7 >/dev/null
}
for F in F1:7101:7102 F2:9301:9302; do
  N=${F%%:*}; r=${F#*:}; sd=${r%%:*}; sh=${r#*:}
  D=$G/$N/specialists; mkdir -p $D $G/$N/panels
  gen fin1_$N finance-v2-r2/finance_panel_v1.py 65 6565 $sd $sh $G/$N/panels/finance_panel_v1.json
  gen fin2_$N finance-v2-r2/finance_panel_v2.py 656565 65656565 $((sd*10+1)) $((sh*10+1)) $G/$N/panels/finance_panel_v2.json
  gen eco_$N economics/economics_panel_v1.py 83 8383 $sd $sh $G/$N/panels/economics_panel_v1.json
  for s in finance finance-v2 finance-v2-r2 economics retail; do
    mkdir -p $D/$s
    for f in $U/$s/*; do b=$(basename $f); case $b in manifest.json|__pycache__|*panel*.json) ;; *) ln -sf $f $D/$s/$b;; esac; done
    case $s in
      finance) P=finance_panel_v1.json;; economics) P=economics_panel_v1.json;; retail) P="";; *) P=finance_panel_v2.json;;
    esac
    if [ -n "$P" ]; then
      sed -e "s#__ORACLE7_ROOT__/specialists/[a-z0-9-]*/[a-z0-9_]*panel_v[0-9].json#$G/$N/panels/$P#" $U/$s/manifest.json > $D/$s/manifest.json
    fi
  done
done
