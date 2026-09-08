#!/usr/bin/env bash
# 45-engagements.sh — engagement note-taking + report generation.
# pandoc + LaTeX turn Markdown notes into clean PDF reports; a scaffold keeps
# each target's recon/loot/notes/report organized.

info "pandoc + LaTeX (Markdown -> PDF reports)"
apt_install \
  pandoc \
  texlive-latex-recommended texlive-latex-extra \
  texlive-fonts-recommended \
  cherrytree

# --- engagement scaffold in the user's home ---------------------------------
ENG="$RUN_HOME/engagements"
TPL="$ENG/_template"
if [[ ! -d "$ENG" ]]; then
  info "creating engagement scaffold at ~/engagements"
  install -d -o "$RUN_USER" -g "$RUN_USER" \
    "$TPL/recon" "$TPL/loot" "$TPL/notes" "$TPL/report" "$TPL/screenshots"
  cat > "$TPL/report/report.md" <<'EOF'
---
title: "Security Assessment — <CLIENT>"
author: "<YOUR HANDLE>"
date: "<DATE>"
---

# Executive summary

# Scope & authorization
- In-scope:
- Authorization ref / RoE:

# Findings
## <Title>  (Severity: Critical/High/Medium/Low)
**Description**

**Impact**

**Evidence**

**Remediation**

# Appendix — methodology & tools
EOF
  cat > "$ENG/README.md" <<'EOF'
# Engagements

One folder per target. Start a new one with:  new-engagement <name>

Each has: recon/ loot/ notes/ report/ screenshots/
Build the PDF:  cd <name>/report && pandoc report.md -o report.pdf
EOF
  chown -R "$RUN_USER:$RUN_USER" "$ENG"
fi

# --- new-engagement helper ---------------------------------------------------
cat > /usr/local/bin/new-engagement <<'EOF'
#!/usr/bin/env bash
# Scaffold a new engagement folder from the template.
set -euo pipefail
name="${1:?usage: new-engagement <name>}"
root="$HOME/engagements"
dest="$root/$name"
[[ -e "$dest" ]] && { echo "already exists: $dest"; exit 1; }
cp -r "$root/_template" "$dest"
echo "created $dest"
echo "  notes/  recon/  loot/  report/  screenshots/"
echo "  build the report: (cd '$dest/report' && pandoc report.md -o report.pdf)"
EOF
chmod +x /usr/local/bin/new-engagement
ok "installed helper: new-engagement <name>"

ok "engagements module complete"
