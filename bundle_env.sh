# Put the CrIS/VIIRS collocation library on PYTHONPATH. matchup_pge's README says to edit the
# sys.path.append line in parallel_run_matchup.py; PYTHONPATH does the same without changing the file.
# Usage, from anywhere: source /path/to/wvcc-matchup-bundle/bundle_env.sh
_bundle_root="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
export PYTHONPATH="${_bundle_root}/CrIS_VIIRS_collocation-master${PYTHONPATH:+:${PYTHONPATH}}"
unset _bundle_root
