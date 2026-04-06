FROM odoo:16.0

LABEL maintainer="Escodoo"

USER root

ARG DEBIAN_FRONTEND=noninteractive

# Clone dependency repos from escodoo_dependencies.txt
# Each addon is copied into /mnt/extra-addons/
# which the base odoo image already includes in addons_path
#
# escodoo_dependencies.txt format: OWNER/REPO BRANCH  (one per line, # for comments)
RUN apt-get update && \
    apt-get install -y --no-install-recommends git && \
    rm -rf /var/lib/apt/lists/* && \
    mkdir -p /tmp/dep-repos && \
    (while IFS= read -r line || [ -n "$line" ]; do \
        line=$(echo "$line" | sed 's/#.*//' | xargs 2>/dev/null || true); \
        [ -z "$line" ] && continue; \
        repo=$(echo "$line" | awk '{print $1}'); \
        branch=$(echo "$line" | awk '{print $2}'); \
        dir_name=$(echo "$repo" | awk -F/ '{print $2}'); \
        echo "[$(ls /tmp/dep-repos | wc -l)] Cloning ${repo} (${branch})..."; \
        git clone --depth 1 --branch "$branch" "https://github.com/${repo}.git" "/tmp/dep-repos/${dir_name}" || echo "  WARNING: Failed to clone ${repo}"; \
    done < escodoo_dependencies.txt; true) && \
    # Copy needed sub-addons from monorepos into extra-addons
    for repo_dir in /tmp/dep-repos/*/; do \
        for addon_dir in "$repo_dir"*/; do \
            if [ -f "$addon_dir/__manifest__.py" ]; then \
                addon_name=$(basename "$addon_dir"); \
                cp -r "$addon_dir" "/mnt/extra-addons/${addon_name}"; \
            fi; \
        done; \
    done && \
    rm -rf /tmp/dep-repos && \
    pip install --no-cache-dir psycogreen watchdog

# Copy custom addons (this repo) — each module into extra-addons
# Also generate /modules.txt with this repo's addons for dynamic auto-install
COPY --chown=odoo:odoo . /tmp/custom-repo/
RUN REPO_MODULES="" && \
    for dir in /tmp/custom-repo/*/; do \
        if [ -f "$dir/__manifest__.py" ]; then \
            addon_name=$(basename "$dir"); \
            cp -r "$dir" "/mnt/extra-addons/${addon_name}"; \
            REPO_MODULES="${REPO_MODULES:+$REPO_MODULES }$addon_name"; \
        fi; \
    done && \
    rm -rf /tmp/custom-repo && \
    echo "$REPO_MODULES" > /modules.txt

# Runtime entrypoint that generates odoo.conf from env vars
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Memory limits for free-tier hosting
ENV ODOO_RC=/etc/odoo/odoo.conf

ENTRYPOINT ["/entrypoint.sh"]
CMD ["odoo"]

USER odoo

EXPOSE 8069
